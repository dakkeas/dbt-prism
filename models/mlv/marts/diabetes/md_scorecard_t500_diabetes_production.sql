{{ config(materialized = 'table') }}

WITH source AS (
    SELECT *
    FROM {{ ref('md_scorecard_t500_diabetes') }}
),

physician_metrics AS (
    SELECT
        physician_providername AS physician_provider_code,
        physiciancode AS physician_code,
        providername AS provider_code,
        physicianname AS physician_name,
        specialization AS specialization_for_verification,
        sub_specialization,

        CAST(total_unique_patient_cnt AS NUMERIC) AS unique_patient_count,
        CAST(total_claim_count AS NUMERIC) AS total_claims,
        CAST(all_claims_sum_of_util AS NUMERIC) AS total_12_month_cost_of_care,
        CAST(opl_sum_of_util AS NUMERIC) AS total_op_lab_12_month_cost_of_care,
        CAST(inp_sum_of_util AS NUMERIC) AS total_inpatient_12_month_cost_of_care,
        CAST(others_sum_of_util AS NUMERIC) AS total_others_12_month_cost_of_care,
        CAST(ave_12_month_util_per_patient AS NUMERIC) AS average_12_month_cost_per_patient,

        CAST(opl_unique_px_count_at_least_one_pct AS NUMERIC) AS op_lab_prevalence,
        CAST(opl_ave_claims_per_px_at_least_one AS NUMERIC) AS op_lab_frequency,
        CAST(opl_ave_cost_per_claim_per_px_at_least_one AS NUMERIC) AS op_lab_average_cost_per_claim_per_patient_with_at_least_one,
        CAST(opl_ave_twelve_month_util_per_px AS NUMERIC) AS op_lab_cost_per_patient,

        CAST(inp_unique_px_count_at_least_one_pct AS NUMERIC) AS inpatient_prevalence,
        CAST(inp_ave_claims_per_px_at_least_one AS NUMERIC) AS inpatient_frequency,
        CAST(inp_ave_cost_per_claim_per_px_at_least_one AS NUMERIC) AS inpatient_average_cost_per_claim_per_patient_with_at_least_one,
        CAST(inp_ave_twelve_month_util_per_px AS NUMERIC) AS inpatient_cost_per_patient,

        CAST(others_unique_px_count_at_least_one_pct AS NUMERIC) AS others_prevalence,
        CAST(others_ave_claims_per_px_at_least_one AS NUMERIC) AS others_frequency,
        CAST(others_ave_cost_per_claim_per_px_at_least_one AS NUMERIC) AS others_average_cost_per_claim_per_patient_with_at_least_one,
        CAST(others_ave_twelve_month_util_per_px AS NUMERIC) AS others_cost_per_patient,

        CAST(total_overall_cptcode_count AS NUMERIC) AS total_cpt_count,
        CAST(total_overall_cptcode_util AS NUMERIC) AS total_cpt_utilization,
        CAST(overall_cptcode_avg_count_per_px AS NUMERIC) AS total_cpt_count_per_patient,
        CAST(overall_cptcode_avg_util_per_px AS NUMERIC) AS total_cpt_utilization_per_patient,

        CAST(total_philhealth AS NUMERIC) AS total_philhealth_support,
        CAST(total_professional_fees AS NUMERIC) AS total_professional_fees,
        CAST(ave_professional_fees_per_patient AS NUMERIC) AS average_professional_fees
    FROM source
),

flagged AS (
    SELECT
        *,
        unique_patient_count < 15 AS low_volume_flag,
        CASE
            WHEN unique_patient_count >= 30 THEN 'High Volume'
            WHEN unique_patient_count >= 15 THEN 'Medium Volume'
            ELSE 'Low Volume'
        END AS volume_tier,
        CASE
            WHEN unique_patient_count >= 30 THEN 'High Confidence'
            WHEN unique_patient_count >= 15 THEN 'Medium Confidence'
            ELSE 'Low Confidence'
        END AS confidence_level
    FROM physician_metrics
),

network_average AS (
    SELECT
        AVG(average_12_month_cost_per_patient) AS network_average_cost_per_patient
    FROM flagged
),

peer_percentiles AS (
    SELECT
        physician_provider_code,
        ROUND(CAST(100 * PERCENT_RANK() OVER (ORDER BY average_12_month_cost_per_patient) AS NUMERIC), 2) AS cost_percentile,
        ROUND(CAST(100 * PERCENT_RANK() OVER (ORDER BY inpatient_prevalence) AS NUMERIC), 2) AS inpatient_prevalence_percentile,
        ROUND(CAST(100 * PERCENT_RANK() OVER (ORDER BY inpatient_cost_per_patient) AS NUMERIC), 2) AS inpatient_cost_percentile,
        ROUND(CAST(100 * PERCENT_RANK() OVER (ORDER BY op_lab_prevalence) AS NUMERIC), 2) AS op_lab_prevalence_percentile,
        ROUND(CAST(100 * PERCENT_RANK() OVER (ORDER BY op_lab_frequency) AS NUMERIC), 2) AS op_lab_frequency_percentile,
        ROUND(CAST(100 * PERCENT_RANK() OVER (ORDER BY total_cpt_utilization_per_patient) AS NUMERIC), 2) AS cpt_utilization_percentile,
        ROUND(CAST(100 * PERCENT_RANK() OVER (ORDER BY others_cost_per_patient) AS NUMERIC), 2) AS others_cost_percentile,
        ROUND(CAST(100 * PERCENT_RANK() OVER (ORDER BY average_professional_fees) AS NUMERIC), 2) AS professional_fee_percentile,
        ROUND(CAST(100 * PERCENT_RANK() OVER (ORDER BY total_claims) AS NUMERIC), 2) AS total_claims_percentile
    FROM flagged
),

segmented AS (
    SELECT
        f.*,
        ROUND(
            f.average_12_month_cost_per_patient
            / NULLIF(n.network_average_cost_per_patient, 0),
            2
        ) AS efficiency_ratio,
        p.cost_percentile,
        p.inpatient_prevalence_percentile,
        p.inpatient_cost_percentile,
        p.op_lab_prevalence_percentile,
        p.op_lab_frequency_percentile,
        p.cpt_utilization_percentile,
        p.others_cost_percentile,
        p.professional_fee_percentile,
        p.total_claims_percentile,
        CASE
            WHEN p.inpatient_prevalence_percentile <= 50
                AND p.inpatient_cost_percentile <= 50
                AND p.op_lab_prevalence_percentile >= 50
                AND p.op_lab_frequency_percentile >= 50
                AND p.cost_percentile BETWEEN 25 AND 75
                THEN 'Preventative'
            WHEN p.inpatient_prevalence_percentile >= 75
                OR p.inpatient_cost_percentile >= 75
                THEN 'Acute Escalator'
            WHEN p.cost_percentile >= 75
                AND p.inpatient_prevalence_percentile < 75
                AND (
                    p.cpt_utilization_percentile >= 75
                    OR p.others_cost_percentile >= 75
                    OR p.professional_fee_percentile >= 75
                )
                THEN 'Resource Intensive'
            WHEN p.cost_percentile <= 25
                AND p.op_lab_prevalence_percentile <= 25
                AND p.total_claims_percentile <= 25
                THEN 'Minimalist'
            ELSE 'Balanced'
        END AS physician_bucket
    FROM flagged f
    CROSS JOIN network_average n
    LEFT JOIN peer_percentiles p
        ON f.physician_provider_code = p.physician_provider_code
),

bucket_summary AS (
    SELECT
        physician_bucket,
        COUNT(*) AS physician_count_by_bucket,
        ROUND(AVG(efficiency_ratio), 2) AS bucket_average_efficiency_ratio,
        ROUND(AVG(unique_patient_count), 2) AS bucket_average_unique_patient_count,
        ROUND(AVG(total_claims), 2) AS bucket_average_total_claims,
        ROUND(AVG(average_12_month_cost_per_patient), 2) AS bucket_average_12_month_cost_per_patient,
        ROUND(MIN(average_12_month_cost_per_patient), 2) AS bucket_minimum_12_month_cost_per_patient,
        ROUND(MAX(average_12_month_cost_per_patient), 2) AS bucket_maximum_12_month_cost_per_patient,
        ROUND(AVG(inpatient_prevalence), 2) AS bucket_average_inpatient_prevalence,
        ROUND(AVG(inpatient_cost_per_patient), 2) AS bucket_average_inpatient_cost_per_patient,
        ROUND(AVG(op_lab_prevalence), 2) AS bucket_average_op_lab_prevalence,
        ROUND(AVG(op_lab_frequency), 2) AS bucket_average_op_lab_frequency,
        ROUND(AVG(total_cpt_utilization_per_patient), 2) AS bucket_average_cpt_utilization_per_patient,
        ROUND(AVG(others_cost_per_patient), 2) AS bucket_average_others_cost_per_patient,
        ROUND(AVG(average_professional_fees), 2) AS bucket_average_professional_fees
    FROM segmented
    GROUP BY physician_bucket
)

SELECT
    s.physician_provider_code AS {{ env_alias('Physician Provider', 'PhysicianProviderCode') }},
    s.physician_code AS {{ env_alias('Physician Code', 'PhysicianCode') }},
    s.provider_code AS {{ env_alias('Provider Code', 'ProviderCode') }},
    s.physician_name AS {{ env_alias('Physician Name', 'PhysicianName') }},
    s.specialization_for_verification AS {{ env_alias('Specialization For Verification', 'SpecializationForVerification') }},
    s.sub_specialization AS {{ env_alias('Sub Specialization', 'SubSpecialization') }},
    s.physician_bucket AS {{ env_alias('Physician Bucket', 'PhysicianBucket') }},
    s.volume_tier AS {{ env_alias('Volume Tier', 'VolumeTier') }},
    s.confidence_level AS {{ env_alias('Confidence Level', 'ConfidenceLevel') }},
    s.efficiency_ratio AS {{ env_alias('Efficiency Ratio', 'EfficiencyRatio') }},

    s.unique_patient_count AS {{ env_alias('Unique Patient Count', 'UniquePatientCount') }},
    s.total_claims AS {{ env_alias('Total Claims', 'TotalClaims') }},
    s.total_12_month_cost_of_care AS {{ env_alias('Total 12 Month Cost Of Care', 'Total12MonthCostOfCare') }},
    s.total_op_lab_12_month_cost_of_care AS {{ env_alias('Total OP Lab 12 Month Cost Of Care', 'TotalOpLab12MonthCostOfCare') }},
    s.total_inpatient_12_month_cost_of_care AS {{ env_alias('Total Inpatient 12 Month Cost Of Care', 'TotalInpatient12MonthCostOfCare') }},
    s.total_others_12_month_cost_of_care AS {{ env_alias('Total Others 12 Month Cost Of Care', 'TotalOthers12MonthCostOfCare') }},
    s.average_12_month_cost_per_patient AS {{ env_alias('Average 12 Month Cost Per Patient', 'Average12MonthCostPerPatient') }},

    s.op_lab_prevalence AS {{ env_alias('OP Lab Prevalence', 'OpLabPrevalence') }},
    s.op_lab_frequency AS {{ env_alias('OP Lab Frequency', 'OpLabFrequency') }},
    s.op_lab_average_cost_per_claim_per_patient_with_at_least_one AS {{ env_alias('OP Lab Average Cost Per Claim Per Patient With At Least One', 'OpLabAverageCostPerClaimPerPatientWithAtLeastOne') }},
    s.op_lab_cost_per_patient AS {{ env_alias('OP Lab Cost Per Patient', 'OpLabCostPerPatient') }},
    s.inpatient_prevalence AS {{ env_alias('Inpatient Prevalence', 'InpatientPrevalence') }},
    s.inpatient_frequency AS {{ env_alias('Inpatient Frequency', 'InpatientFrequency') }},
    s.inpatient_average_cost_per_claim_per_patient_with_at_least_one AS {{ env_alias('Inpatient Average Cost Per Claim Per Patient With At Least One', 'InpatientAverageCostPerClaimPerPatientWithAtLeastOne') }},
    s.inpatient_cost_per_patient AS {{ env_alias('Inpatient Cost Per Patient', 'InpatientCostPerPatient') }},
    s.others_prevalence AS {{ env_alias('Others Prevalence', 'OthersPrevalence') }},
    s.others_frequency AS {{ env_alias('Others Frequency', 'OthersFrequency') }},
    s.others_average_cost_per_claim_per_patient_with_at_least_one AS {{ env_alias('Others Average Cost Per Claim Per Patient With At Least One', 'OthersAverageCostPerClaimPerPatientWithAtLeastOne') }},
    s.others_cost_per_patient AS {{ env_alias('Others Cost Per Patient', 'OthersCostPerPatient') }},

    s.total_cpt_count AS {{ env_alias('Total CPT Count', 'TotalCptCount') }},
    s.total_cpt_utilization AS {{ env_alias('Total CPT Utilization', 'TotalCptUtilization') }},
    s.total_cpt_count_per_patient AS {{ env_alias('Total CPT Count Per Patient', 'TotalCptCountPerPatient') }},
    s.total_cpt_utilization_per_patient AS {{ env_alias('Total CPT Utilization Per Patient', 'TotalCptUtilizationPerPatient') }},
    s.total_philhealth_support AS {{ env_alias('Total Philhealth Support', 'TotalPhilhealthSupport') }},
    s.total_professional_fees AS {{ env_alias('Total Professional Fees', 'TotalProfessionalFees') }},
    s.average_professional_fees AS {{ env_alias('Average Professional Fees', 'AverageProfessionalFees') }},

    s.low_volume_flag AS {{ env_alias('Low Volume Flag', 'LowVolumeFlag') }},
    s.cost_percentile AS {{ env_alias('Cost Percentile', 'CostPercentile') }},
    s.inpatient_prevalence_percentile AS {{ env_alias('Inpatient Prevalence Percentile', 'InpatientPrevalencePercentile') }},
    s.inpatient_cost_percentile AS {{ env_alias('Inpatient Cost Percentile', 'InpatientCostPercentile') }},
    s.op_lab_prevalence_percentile AS {{ env_alias('OP Lab Prevalence Percentile', 'OpLabPrevalencePercentile') }},
    s.op_lab_frequency_percentile AS {{ env_alias('OP Lab Frequency Percentile', 'OpLabFrequencyPercentile') }},
    s.cpt_utilization_percentile AS {{ env_alias('CPT Utilization Percentile', 'CptUtilizationPercentile') }},
    s.others_cost_percentile AS {{ env_alias('Others Cost Percentile', 'OthersCostPercentile') }},
    s.professional_fee_percentile AS {{ env_alias('Professional Fee Percentile', 'ProfessionalFeePercentile') }},
    s.total_claims_percentile AS {{ env_alias('Total Claims Percentile', 'TotalClaimsPercentile') }},

    bs.physician_count_by_bucket AS {{ env_alias('Physician Count By Bucket', 'PhysicianCountByBucket') }},
    bs.bucket_average_efficiency_ratio AS {{ env_alias('Bucket Average Efficiency Ratio', 'BucketAverageEfficiencyRatio') }},
    bs.bucket_average_unique_patient_count AS {{ env_alias('Bucket Average Unique Patient Count', 'BucketAverageUniquePatientCount') }},
    bs.bucket_average_total_claims AS {{ env_alias('Bucket Average Total Claims', 'BucketAverageTotalClaims') }},
    bs.bucket_average_12_month_cost_per_patient AS {{ env_alias('Bucket Average 12 Month Cost Per Patient', 'BucketAverage12MonthCostPerPatient') }},
    bs.bucket_minimum_12_month_cost_per_patient AS {{ env_alias('Bucket Minimum 12 Month Cost Per Patient', 'BucketMinimum12MonthCostPerPatient') }},
    bs.bucket_maximum_12_month_cost_per_patient AS {{ env_alias('Bucket Maximum 12 Month Cost Per Patient', 'BucketMaximum12MonthCostPerPatient') }},
    bs.bucket_average_inpatient_prevalence AS {{ env_alias('Bucket Average Inpatient Prevalence', 'BucketAverageInpatientPrevalence') }},
    bs.bucket_average_inpatient_cost_per_patient AS {{ env_alias('Bucket Average Inpatient Cost Per Patient', 'BucketAverageInpatientCostPerPatient') }},
    bs.bucket_average_op_lab_prevalence AS {{ env_alias('Bucket Average OP Lab Prevalence', 'BucketAverageOpLabPrevalence') }},
    bs.bucket_average_op_lab_frequency AS {{ env_alias('Bucket Average OP Lab Frequency', 'BucketAverageOpLabFrequency') }},
    bs.bucket_average_cpt_utilization_per_patient AS {{ env_alias('Bucket Average CPT Utilization Per Patient', 'BucketAverageCptUtilizationPerPatient') }},
    bs.bucket_average_others_cost_per_patient AS {{ env_alias('Bucket Average Others Cost Per Patient', 'BucketAverageOthersCostPerPatient') }},
    bs.bucket_average_professional_fees AS {{ env_alias('Bucket Average Professional Fees', 'BucketAverageProfessionalFees') }}
FROM segmented s
LEFT JOIN bucket_summary bs
    ON s.physician_bucket = bs.physician_bucket
