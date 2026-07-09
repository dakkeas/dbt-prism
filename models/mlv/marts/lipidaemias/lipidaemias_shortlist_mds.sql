{{ config(materialized = 'table') }}

WITH scorecard AS (
    SELECT
        {{ env_alias('Physician Code', 'PhysicianCode') }} AS physician_code,
        {{ env_alias('Physician Name', 'PhysicianName') }} AS physician_name,
        {{ env_alias('Specialization For Verification', 'SpecializationForVerification') }} AS specialization,
        {{ env_alias('Sub Specialization', 'SubSpecialization') }} AS sub_specialization,
        {{ env_alias('Provider Code', 'ProviderCode') }} AS provider_name,
        {{ env_alias('Physician Bucket', 'PhysicianBucket') }} AS physician_bucket,
        {{ env_alias('Potential Savings', 'PotentialSavings') }} AS potential_savings,
        {{ env_alias('Unique Patient Count', 'UniquePatientCount') }} AS unique_patient_count,

        -- Metrics needed for driver formatting
        {{ env_alias('Inpatient Cost Per Patient', 'InpatientCostPerPatient') }} AS inpatient_cost_per_patient,
        {{ env_alias('OP Lab Cost Per Patient', 'OpLabCostPerPatient') }} AS op_lab_cost_per_patient,
        {{ env_alias('Average 12 Month Cost Per Patient', 'Average12MonthCostPerPatient') }} AS average_12_month_cost_per_patient,
        {{ env_alias('Total CPT Utilization Per Patient', 'TotalCptUtilizationPerPatient') }} AS total_cpt_utilization_per_patient,
        {{ env_alias('Others Cost Per Patient', 'OthersCostPerPatient') }} AS others_cost_per_patient,
        {{ env_alias('Average Professional Fees', 'AverageProfessionalFees') }} AS average_professional_fees,
        {{ env_alias('Total Philhealth Support', 'TotalPhilhealthSupport') }} AS total_philhealth_support
    FROM {{ ref('md_scorecard_t500_lipidaemias_production') }}
),

-- Compute T500-level averages for Resource Intensive driver identification
t500_averages AS (
    SELECT
        AVG(inpatient_cost_per_patient) AS t500_avg_inpatient_cost_per_patient,
        AVG(op_lab_cost_per_patient) AS t500_avg_op_lab_cost_per_patient,
        AVG(average_12_month_cost_per_patient) AS t500_avg_cost_per_patient,
        AVG(total_cpt_utilization_per_patient) AS t500_avg_cpt_utilization_per_patient,
        AVG(others_cost_per_patient) AS t500_avg_others_cost_per_patient,
        AVG(average_professional_fees) AS t500_avg_professional_fees
    FROM scorecard
),

aggregated_scorecard AS (
    SELECT
        physician_code,
        physician_name,
        provider_name,
        physician_bucket,
        SUM(potential_savings) AS potential_savings,
        SUM(unique_patient_count) AS unique_patient_count,
        STRING_AGG(DISTINCT specialization, ', ') AS specialization,
        STRING_AGG(DISTINCT sub_specialization, ', ') AS sub_specialization,
        COALESCE(
            SUM(inpatient_cost_per_patient * unique_patient_count) / NULLIF(SUM(unique_patient_count), 0),
            AVG(inpatient_cost_per_patient)
        ) AS inpatient_cost_per_patient,
        COALESCE(
            SUM(op_lab_cost_per_patient * unique_patient_count) / NULLIF(SUM(unique_patient_count), 0),
            AVG(op_lab_cost_per_patient)
        ) AS op_lab_cost_per_patient,
        COALESCE(
            SUM(average_12_month_cost_per_patient * unique_patient_count) / NULLIF(SUM(unique_patient_count), 0),
            AVG(average_12_month_cost_per_patient)
        ) AS average_12_month_cost_per_patient,
        COALESCE(
        SUM(total_cpt_utilization_per_patient * unique_patient_count) / NULLIF(SUM(unique_patient_count), 0),
        AVG(total_cpt_utilization_per_patient)
        ) AS total_cpt_utilization_per_patient,
        COALESCE(
            SUM(others_cost_per_patient * unique_patient_count) / NULLIF(SUM(unique_patient_count), 0),
            AVG(others_cost_per_patient)
        ) AS others_cost_per_patient,
        COALESCE(
            SUM(average_professional_fees * unique_patient_count) / NULLIF(SUM(unique_patient_count), 0),
            AVG(average_professional_fees)
        ) AS average_professional_fees
        ,SUM(total_philhealth_support) AS total_philhealth_support
    FROM scorecard
    GROUP BY physician_code, physician_name, provider_name, physician_bucket
),

with_driver AS (
    SELECT
        sc.physician_code,
        sc.physician_name,
        sc.physician_bucket,
        sc.potential_savings,
        sc.provider_name,
        sc.specialization,
        sc.sub_specialization,
        CASE sc.physician_bucket
            WHEN 'High Inpatient Use and Low Philhealth Use' THEN
                'Avg Inpatient Cost (' || {{ format_currency('sc.inpatient_cost_per_patient') }} ||
                ') vs Inpatient T500 Avg (' || {{ format_currency('t500.t500_avg_inpatient_cost_per_patient') }} ||
                ') with ' || {{ format_currency('sc.total_philhealth_support') }} || ' Total PhilHealth Utilization'
            WHEN 'High Inpatient Use' THEN
                'Avg Inpatient Cost (' || {{ format_currency('sc.inpatient_cost_per_patient') }} ||
                ') vs Inpatient T500 Avg (' || {{ format_currency('t500.t500_avg_inpatient_cost_per_patient') }} || ')'
            WHEN 'High Lab Use' THEN
                'OP Lab Cost Per Patient (' || {{ format_currency('sc.op_lab_cost_per_patient') }} ||
                ') vs OP Lab T500 Avg (' || {{ format_currency('t500.t500_avg_op_lab_cost_per_patient') }} || ')'
            WHEN 'Low Use' THEN
                'Avg 12-Month Cost Per Patient (' || {{ format_currency('sc.average_12_month_cost_per_patient') }} ||
                ') vs 12-Month Cost T500 Avg (' || {{ format_currency('t500.t500_avg_cost_per_patient') }} || ')'
            WHEN 'Balanced Use' THEN
                'Avg 12-Month Cost Per Patient (' || {{ format_currency('sc.average_12_month_cost_per_patient') }} ||
                ') vs 12-Month Cost T500 Avg (' || {{ format_currency('t500.t500_avg_cost_per_patient') }} || ')'
            WHEN 'High Resource Use' THEN
                CASE
                    WHEN (COALESCE(sc.total_cpt_utilization_per_patient, 0) - t500.t500_avg_cpt_utilization_per_patient)
                         >= (COALESCE(sc.others_cost_per_patient, 0) - t500.t500_avg_others_cost_per_patient)
                     AND (COALESCE(sc.total_cpt_utilization_per_patient, 0) - t500.t500_avg_cpt_utilization_per_patient)
                         >= (COALESCE(sc.average_professional_fees, 0) - t500.t500_avg_professional_fees)
                        THEN 'CPT Utilization Per Patient (' || {{ format_currency('sc.total_cpt_utilization_per_patient') }} ||
                             ') vs CPT Utilization T500 Avg (' || {{ format_currency('t500.t500_avg_cpt_utilization_per_patient') }} || ')'
                    WHEN (COALESCE(sc.others_cost_per_patient, 0) - t500.t500_avg_others_cost_per_patient)
                         >= (COALESCE(sc.average_professional_fees, 0) - t500.t500_avg_professional_fees)
                        THEN 'Others Cost Per Patient (' || {{ format_currency('sc.others_cost_per_patient') }} ||
                             ') vs Others Cost T500 Avg (' || {{ format_currency('t500.t500_avg_others_cost_per_patient') }} || ')'
                    ELSE 'Professional Fees (' || {{ format_currency('sc.average_professional_fees') }} ||
                         ') vs Professional Fees T500 Avg (' || {{ format_currency('t500.t500_avg_professional_fees') }} || ')'
                END
            ELSE
                'Avg 12-Month Cost Per Patient (' || {{ format_currency('sc.average_12_month_cost_per_patient') }} ||
                ') vs 12-Month Cost T500 Avg (' || {{ format_currency('t500.t500_avg_cost_per_patient') }} || ')'
        END AS driver
    FROM aggregated_scorecard sc
    CROSS JOIN t500_averages t500
),

ranked AS (
    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY physician_bucket
            ORDER BY potential_savings DESC
        ) AS rank_in_bucket
    FROM with_driver
)

SELECT
    rank_in_bucket AS {{ env_alias('Rank', 'Rank') }},
    physician_code AS {{ env_alias('Physician', 'Physician') }},
    physician_name AS {{ env_alias('Physician Name', 'PhysicianName') }},
    specialization AS {{ env_alias('Specialization', 'Specialization') }},
    sub_specialization AS {{ env_alias('Sub Specialization', 'SubSpecialization') }},
    provider_name AS {{ env_alias('Provider Name', 'ProviderName') }},
    physician_bucket AS {{ env_alias('Bucket', 'Bucket') }},
    potential_savings AS {{ env_alias('Potential Savings', 'PotentialSavings') }},
    driver AS {{ env_alias('Driver', 'Driver') }}
FROM ranked
WHERE rank_in_bucket <= 5
ORDER BY physician_bucket, rank_in_bucket
