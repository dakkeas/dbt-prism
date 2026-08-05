{{ config(materialized = 'table') }}

SELECT
    COUNT(*) AS total_matched_doctors,
    
    -- General Utilization
    ROUND(AVG(delta_all_claims_sum_of_util)::numeric, 2) AS avg_delta_total_util,
    ROUND(AVG(delta_ave_12_month_util_per_patient)::numeric, 2) AS avg_delta_util_per_patient,
    ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY delta_ave_12_month_util_per_patient)::numeric, 2) AS median_delta_util_per_patient,
    ROUND((COUNT(CASE WHEN delta_ave_12_month_util_per_patient < 0 THEN 1 END) * 100.0 / NULLIF(COUNT(*), 0))::numeric, 2) AS pct_doctors_util_improved,
    
    -- LOA Type Breakdown
    ROUND(AVG(delta_inp_sum_of_util)::numeric, 2) AS avg_delta_inp_util,
    ROUND(AVG(delta_inp_ave_twelve_month_util_per_px)::numeric, 2) AS avg_delta_inp_util_per_px,
    ROUND(AVG(delta_opl_sum_of_util)::numeric, 2) AS avg_delta_opl_util,
    ROUND(AVG(delta_opl_ave_twelve_month_util_per_px)::numeric, 2) AS avg_delta_opl_util_per_px,
    ROUND(AVG(delta_others_sum_of_util)::numeric, 2) AS avg_delta_others_util,
    ROUND(AVG(delta_others_ave_twelve_month_util_per_px)::numeric, 2) AS avg_delta_others_util_per_px,
    
    -- Spend Type / Claim Type Breakdown
    ROUND(AVG(delta_total_professional_fees)::numeric, 2) AS avg_delta_total_professional_fees,
    ROUND(AVG(delta_ave_professional_fees_per_patient)::numeric, 2) AS avg_delta_pf_per_patient,
    
    ROUND(AVG(delta_total_philhealth)::numeric, 2) AS avg_delta_total_philhealth,
    ROUND(AVG(delta_percent_of_philhealth_util)::numeric, 4) AS avg_delta_philhealth_share_pct,
    
    ROUND(AVG(delta_total_cpt_util)::numeric, 2) AS avg_delta_total_cpt_util,
    ROUND(AVG(delta_cpt_avg_util_per_px)::numeric, 2) AS avg_delta_cpt_util_per_px

FROM {{ ref('md_scorecard_delta_lipidaemias') }}
