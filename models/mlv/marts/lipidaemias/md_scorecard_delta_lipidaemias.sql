{{ config(materialized = 'table') }}

WITH y24 AS (
    SELECT
        *,
        ROW_NUMBER() OVER (ORDER BY ave_12_month_util_per_patient DESC) AS rank_y24
    FROM {{ ref('md_scorecard_t500_lipidaemias_y24') }}
),
y25 AS (
    SELECT
        *,
        ROW_NUMBER() OVER (ORDER BY ave_12_month_util_per_patient DESC) AS rank_y25
    FROM {{ ref('md_scorecard_t500_lipidaemias_y25') }}
),
combined AS (
    SELECT
        COALESCE(a.physician_providername, b.physician_providername) AS physician_providername,
        COALESCE(a.physiciancode, b.physiciancode) AS physiciancode,
        COALESCE(a.providername, b.providername) AS providername,
        COALESCE(b.physicianname, a.physicianname) AS physicianname,
        COALESCE(b.specialization, a.specialization) AS specialization,
        COALESCE(b.sub_specialization, a.sub_specialization) AS sub_specialization,
        COALESCE(b.is_pcc_coordinator, a.is_pcc_coordinator) AS is_pcc_coordinator,
        COALESCE(b.practices_in_pcc, a.practices_in_pcc) AS practices_in_pcc,
        COALESCE(b.combined_starting_primaryicdgroup, a.combined_starting_primaryicdgroup) AS combined_starting_primaryicdgroup,

        a.rank_y24,
        b.rank_y25,
        (a.rank_y24 - b.rank_y25) AS rank_change,

        -- Patient Counts
        a.total_unique_patient_cnt AS y24_total_unique_patient_cnt,
        b.total_unique_patient_cnt AS y25_total_unique_patient_cnt,
        ROUND(COALESCE(b.total_unique_patient_cnt, 0) - COALESCE(a.total_unique_patient_cnt, 0), 2) AS delta_total_unique_patient_cnt,

        -- Claims Count & Utilization
        a.total_claim_count AS y24_total_claim_count,
        b.total_claim_count AS y25_total_claim_count,
        ROUND(COALESCE(b.total_claim_count, 0) - COALESCE(a.total_claim_count, 0), 2) AS delta_total_claim_count,

        a.all_claims_sum_of_util AS y24_all_claims_sum_of_util,
        b.all_claims_sum_of_util AS y25_all_claims_sum_of_util,
        ROUND(COALESCE(b.all_claims_sum_of_util, 0) - COALESCE(a.all_claims_sum_of_util, 0), 2) AS delta_all_claims_sum_of_util,

        a.ave_12_month_util_per_patient AS y24_ave_12_month_util_per_patient,
        b.ave_12_month_util_per_patient AS y25_ave_12_month_util_per_patient,
        ROUND(COALESCE(b.ave_12_month_util_per_patient, 0) - COALESCE(a.ave_12_month_util_per_patient, 0), 2) AS delta_ave_12_month_util_per_patient,

        -- OP Lab
        a.opl_unique_px_cnt_at_least_one AS y24_opl_unique_px_cnt_at_least_one,
        b.opl_unique_px_cnt_at_least_one AS y25_opl_unique_px_cnt_at_least_one,
        ROUND(COALESCE(b.opl_unique_px_cnt_at_least_one, 0) - COALESCE(a.opl_unique_px_cnt_at_least_one, 0), 2) AS delta_opl_unique_px_cnt_at_least_one,

        a.opl_total_claims AS y24_opl_total_claims,
        b.opl_total_claims AS y25_opl_total_claims,
        ROUND(COALESCE(b.opl_total_claims, 0) - COALESCE(a.opl_total_claims, 0), 2) AS delta_opl_total_claims,

        a.opl_sum_of_util AS y24_opl_sum_of_util,
        b.opl_sum_of_util AS y25_opl_sum_of_util,
        ROUND(COALESCE(b.opl_sum_of_util, 0) - COALESCE(a.opl_sum_of_util, 0), 2) AS delta_opl_sum_of_util,

        a.opl_ave_twelve_month_util_per_px AS y24_opl_ave_twelve_month_util_per_px,
        b.opl_ave_twelve_month_util_per_px AS y25_opl_ave_twelve_month_util_per_px,
        ROUND(COALESCE(b.opl_ave_twelve_month_util_per_px, 0) - COALESCE(a.opl_ave_twelve_month_util_per_px, 0), 2) AS delta_opl_ave_twelve_month_util_per_px,

        -- Inpatient
        a.inp_unique_px_count_at_least_one AS y24_inp_unique_px_count_at_least_one,
        b.inp_unique_px_count_at_least_one AS y25_inp_unique_px_count_at_least_one,
        ROUND(COALESCE(b.inp_unique_px_count_at_least_one, 0) - COALESCE(a.inp_unique_px_count_at_least_one, 0), 2) AS delta_inp_unique_px_count_at_least_one,

        a.inp_total_claims AS y24_inp_total_claims,
        b.inp_total_claims AS y25_inp_total_claims,
        ROUND(COALESCE(b.inp_total_claims, 0) - COALESCE(a.inp_total_claims, 0), 2) AS delta_inp_total_claims,

        a.inp_sum_of_util AS y24_inp_sum_of_util,
        b.inp_sum_of_util AS y25_inp_sum_of_util,
        ROUND(COALESCE(b.inp_sum_of_util, 0) - COALESCE(a.inp_sum_of_util, 0), 2) AS delta_inp_sum_of_util,

        a.inp_ave_twelve_month_util_per_px AS y24_inp_ave_twelve_month_util_per_px,
        b.inp_ave_twelve_month_util_per_px AS y25_inp_ave_twelve_month_util_per_px,
        ROUND(COALESCE(b.inp_ave_twelve_month_util_per_px, 0) - COALESCE(a.inp_ave_twelve_month_util_per_px, 0), 2) AS delta_inp_ave_twelve_month_util_per_px,

        -- Others
        a.others_total_claims AS y24_others_total_claims,
        b.others_total_claims AS y25_others_total_claims,
        ROUND(COALESCE(b.others_total_claims, 0) - COALESCE(a.others_total_claims, 0), 2) AS delta_others_total_claims,

        a.others_sum_of_util AS y24_others_sum_of_util,
        b.others_sum_of_util AS y25_others_sum_of_util,
        ROUND(COALESCE(b.others_sum_of_util, 0) - COALESCE(a.others_sum_of_util, 0), 2) AS delta_others_sum_of_util,

        a.others_ave_twelve_month_util_per_px AS y24_others_ave_twelve_month_util_per_px,
        b.others_ave_twelve_month_util_per_px AS y25_others_ave_twelve_month_util_per_px,
        ROUND(COALESCE(b.others_ave_twelve_month_util_per_px, 0) - COALESCE(a.others_ave_twelve_month_util_per_px, 0), 2) AS delta_others_ave_twelve_month_util_per_px,

        -- Professional Fees & PhilHealth
        a.total_professional_fees AS y24_total_professional_fees,
        b.total_professional_fees AS y25_total_professional_fees,
        ROUND(COALESCE(b.total_professional_fees, 0) - COALESCE(a.total_professional_fees, 0), 2) AS delta_total_professional_fees,

        a.ave_professional_fees_per_patient AS y24_ave_professional_fees_per_patient,
        b.ave_professional_fees_per_patient AS y25_ave_professional_fees_per_patient,
        ROUND(COALESCE(b.ave_professional_fees_per_patient, 0) - COALESCE(a.ave_professional_fees_per_patient, 0), 2) AS delta_ave_professional_fees_per_patient,

        a.total_philhealth AS y24_total_philhealth,
        b.total_philhealth AS y25_total_philhealth,
        ROUND(COALESCE(b.total_philhealth, 0) - COALESCE(a.total_philhealth, 0), 2) AS delta_total_philhealth,

        a.percent_of_philhealth_util AS y24_percent_of_philhealth_util,
        b.percent_of_philhealth_util AS y25_percent_of_philhealth_util,
        ROUND(COALESCE(b.percent_of_philhealth_util, 0) - COALESCE(a.percent_of_philhealth_util, 0), 4) AS delta_percent_of_philhealth_util,

        -- CPT Procedure Spend
        a.total_overall_cptcode_util AS y24_total_cpt_util,
        b.total_overall_cptcode_util AS y25_total_cpt_util,
        ROUND(COALESCE(b.total_overall_cptcode_util, 0) - COALESCE(a.total_overall_cptcode_util, 0), 2) AS delta_total_cpt_util,

        a.overall_cptcode_avg_util_per_px AS y24_cpt_avg_util_per_px,
        b.overall_cptcode_avg_util_per_px AS y25_cpt_avg_util_per_px,
        ROUND(COALESCE(b.overall_cptcode_avg_util_per_px, 0) - COALESCE(a.overall_cptcode_avg_util_per_px, 0), 2) AS delta_cpt_avg_util_per_px,

        -- Clinical Outcomes
        a.readmission_rate AS y24_readmission_rate,
        b.readmission_rate AS y25_readmission_rate,
        ROUND(COALESCE(b.readmission_rate, 0) - COALESCE(a.readmission_rate, 0), 2) AS delta_readmission_rate,

        a.panic_visit_rate AS y24_panic_visit_rate,
        b.panic_visit_rate AS y25_panic_visit_rate,
        ROUND(COALESCE(b.panic_visit_rate, 0) - COALESCE(a.panic_visit_rate, 0), 2) AS delta_panic_visit_rate,

        a.total_patient_lengthofstay AS y24_total_patient_lengthofstay,
        b.total_patient_lengthofstay AS y25_total_patient_lengthofstay,
        ROUND(COALESCE(b.total_patient_lengthofstay, 0) - COALESCE(a.total_patient_lengthofstay, 0), 2) AS delta_total_patient_lengthofstay,

        -- PCC Availments
        a.total_pcc_availment_cost AS y24_total_pcc_availment_cost,
        b.total_pcc_availment_cost AS y25_total_pcc_availment_cost,
        ROUND(COALESCE(b.total_pcc_availment_cost, 0) - COALESCE(a.total_pcc_availment_cost, 0), 2) AS delta_total_pcc_availment_cost

    FROM y24 a
    INNER JOIN y25 b
        ON a.physiciancode = b.physiciancode
       AND a.providername = b.providername
)
SELECT * FROM combined
ORDER BY COALESCE(y25_ave_12_month_util_per_patient, 0) DESC
