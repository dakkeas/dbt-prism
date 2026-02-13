
{{config(materialized = 'table')}}

WITH physician_provider_agg AS (
    SELECT
        -- IDENTIFIERS
        
        CONCAT(starting_physiciancode, ' - ', starting_providername) AS physician_providername,
        starting_physiciancode AS physiciancode,
        starting_providername AS providername,
        MIN(pi.physicianname) AS physicianname,
        MIN(pi.specialization) AS specialization,
        -- BASE
        COUNT(DISTINCT maskedcardno) AS total_unique_patient_cnt,
        SUM(overall_count_of_claims) AS total_claim_count,
        SUM(overall_util) AS total_util,
        SUM(overall_util) / NULLIF(COUNT(DISTINCT maskedcardno), 0) AS ave_12_month_util_per_patient,
        

        -- =============================================
        -- OP LAB METRICS
        -- =============================================
        COUNT(DISTINCT CASE WHEN opl_coc > 0 THEN maskedcardno END) AS opl_unique_px_cnt_at_least_one,

        (CAST(COUNT(DISTINCT CASE WHEN opl_coc > 0 THEN maskedcardno END) AS NUMERIC)
         / NULLIF(COUNT(DISTINCT maskedcardno), 0)
        ) AS opl_unique_px_count_at_least_one_pct,

        (CAST(SUM(opl_coc) AS NUMERIC)
         / NULLIF(COUNT(DISTINCT CASE WHEN opl_coc > 0 THEN maskedcardno END), 0)
        ) AS opl_ave_claims_per_px_at_least_one,

        SUM(opl_coc) AS opl_total_claims,

        (CAST(SUM(opl_util) AS NUMERIC)
         / NULLIF(SUM(opl_coc), 0)
        ) AS opl_ave_cost_per_claim_per_px_at_least_one,

        SUM(opl_util) AS opl_sum_of_util,

        (CAST(SUM(opl_util) AS NUMERIC)
         / NULLIF(COUNT(DISTINCT maskedcardno), 0)
        ) AS opl_ave_twelve_month_util_per_px,

        -- =============================================
        -- INPATIENT METRICS
        -- =============================================
        COUNT(DISTINCT CASE WHEN inp_coc > 0 THEN maskedcardno END) AS inp_unique_px_count_at_least_one,

        (CAST(COUNT(DISTINCT CASE WHEN inp_coc > 0 THEN maskedcardno END) AS NUMERIC)
         / NULLIF(COUNT(DISTINCT maskedcardno), 0)
        ) AS inp_unique_px_count_at_least_one_pct,

        (CAST(SUM(inp_coc) AS NUMERIC)
         / NULLIF(COUNT(DISTINCT CASE WHEN inp_coc > 0 THEN maskedcardno END), 0)
        ) AS inp_ave_claims_per_px_at_least_one,

        SUM(inp_coc) AS inp_total_claims,

        (CAST(SUM(inp_util) AS NUMERIC)
         / NULLIF(SUM(inp_coc), 0)
        ) AS inp_ave_cost_per_claim_per_px_at_least_one,

        SUM(inp_util) AS inp_sum_of_util,

        (CAST(SUM(inp_util) AS NUMERIC)
         / NULLIF(COUNT(DISTINCT maskedcardno), 0)
        ) AS inp_ave_twelve_month_util_per_px,

        -- =============================================
        -- OTHERS METRICS
        -- =============================================
        COUNT(DISTINCT CASE WHEN others_coc > 0 THEN maskedcardno END) AS others_unique_px_count_at_least_one,

        (CAST(COUNT(DISTINCT CASE WHEN others_coc > 0 THEN maskedcardno END) AS NUMERIC)
         / NULLIF(COUNT(DISTINCT maskedcardno), 0)
        ) AS others_unique_px_count_at_least_one_pct,

        (CAST(SUM(others_coc) AS NUMERIC)
         / NULLIF(COUNT(DISTINCT CASE WHEN others_coc > 0 THEN maskedcardno END), 0)
        ) AS others_ave_claims_per_px_at_least_one,

        SUM(others_coc) AS others_total_claims,

        (CAST(SUM(others_util) AS NUMERIC)
         / NULLIF(SUM(others_coc), 0)
        ) AS others_ave_cost_per_claim_per_px_at_least_one,

        SUM(others_util) AS others_sum_of_util,

        (CAST(SUM(others_util) AS NUMERIC)
         / NULLIF(COUNT(DISTINCT maskedcardno), 0)
        ) AS others_ave_twelve_month_util_per_px,

        -- =============================================
        -- PHILHEALTH METRICS
        -- =============================================
        SUM(sum_philhealth) AS total_philhealth,

        CAST(SUM(sum_philhealth) AS NUMERIC)
        / CAST(COUNT(DISTINCT maskedcardno) AS NUMERIC) AS ave_philhealth_claim,

        -- =============================================
        -- CPTCODE/RUVCODE METRICS
        -- =============================================

        -- SUM of count of CPT codes
        CAST(SUM(overall_cptcode_coc) AS NUMERIC) AS total_overall_cptcode_count,
        CAST(SUM(opl_cptcode_coc) AS NUMERIC) AS total_opl_cptcode_count,
        CAST(SUM(inp_cptcode_coc) AS NUMERIC) AS total_inp_cptcode_count,
        CAST(SUM(emg_cptcode_coc) AS NUMERIC) AS total_emg_cptcode_count,

        -- SUM of utilization of CPT codes
        CAST(SUM(overall_cptcode_util) AS NUMERIC) AS total_overall_cptcode_util,
        CAST(SUM(opl_cptcode_util) AS NUMERIC) AS total_opl_cptcode_util,
        CAST(SUM(inp_cptcode_util) AS NUMERIC) AS total_inp_cptcode_util,
        CAST(SUM(emg_cptcode_util) AS NUMERIC) AS total_emg_cptcode_util,

        -- AVG count of CPT codes per patient
        CAST(SUM(overall_cptcode_coc) / NULLIF(COUNT(DISTINCT maskedcardno), 0) AS NUMERIC) AS overall_cptcode_avg_count_per_px,
        CAST(SUM(opl_cptcode_coc) / NULLIF(COUNT(DISTINCT maskedcardno), 0) AS NUMERIC) AS opl_cptcode_avg_count_per_px,
        CAST(SUM(inp_cptcode_coc) / NULLIF(COUNT(DISTINCT maskedcardno), 0) AS NUMERIC) AS inp_cptcode_avg_count_per_px,
        CAST(SUM(emg_cptcode_coc) / NULLIF(COUNT(DISTINCT maskedcardno), 0) AS NUMERIC) AS emg_cptcode_avg_count_per_px,

        -- AVG utilization of CPT codes per patient
        CAST(SUM(overall_cptcode_util) / NULLIF(COUNT(DISTINCT maskedcardno), 0) AS NUMERIC) AS overall_cptcode_avg_util_per_px,
        CAST(SUM(opl_cptcode_util) / NULLIF(COUNT(DISTINCT maskedcardno), 0) AS NUMERIC) AS opl_cptcode_avg_util_per_px,
        CAST(SUM(inp_cptcode_util) / NULLIF(COUNT(DISTINCT maskedcardno), 0) AS NUMERIC) AS inp_cptcode_avg_util_per_px,
        CAST(SUM(emg_cptcode_util) / NULLIF(COUNT(DISTINCT maskedcardno), 0) AS NUMERIC) AS emg_cptcode_avg_util_per_px,

        -- SUM of count of RUV codes
        CAST(SUM(overall_ruvcode_coc) AS NUMERIC) AS total_overall_ruvcode_count,
        CAST(SUM(opl_ruvcode_coc) AS NUMERIC) AS total_opl_ruvcode_count,
        CAST(SUM(inp_ruvcode_coc) AS NUMERIC) AS total_inp_ruvcode_count,
        CAST(SUM(emg_ruvcode_coc) AS NUMERIC) AS total_emg_ruvcode_count,

        -- SUM of utilization of RUV codes
        CAST(SUM(overall_ruvcode_util) AS NUMERIC) AS total_overall_ruvcode_util,
        CAST(SUM(opl_ruvcode_util) AS NUMERIC) AS total_opl_ruvcode_util,
        CAST(SUM(inp_ruvcode_util) AS NUMERIC) AS total_inp_ruvcode_util,
        CAST(SUM(emg_ruvcode_util) AS NUMERIC) AS total_emg_ruvcode_util,

        -- AVG count of RUV codes per patient
        CAST(SUM(overall_ruvcode_coc) / NULLIF(COUNT(DISTINCT maskedcardno), 0) AS NUMERIC) AS overall_ruvcode_avg_count_per_px,
        CAST(SUM(opl_ruvcode_coc) / NULLIF(COUNT(DISTINCT maskedcardno), 0) AS NUMERIC) AS opl_ruvcode_avg_count_per_px,
        CAST(SUM(inp_ruvcode_coc) / NULLIF(COUNT(DISTINCT maskedcardno), 0) AS NUMERIC) AS inp_ruvcode_avg_count_per_px,
        CAST(SUM(emg_ruvcode_coc) / NULLIF(COUNT(DISTINCT maskedcardno), 0) AS NUMERIC) AS emg_ruvcode_avg_count_per_px,

        -- AVG utilization of RUV codes per patient
        CAST(SUM(overall_ruvcode_util) / NULLIF(COUNT(DISTINCT maskedcardno), 0) AS NUMERIC) AS overall_ruvcode_avg_util_per_px,
        CAST(SUM(opl_ruvcode_util) / NULLIF(COUNT(DISTINCT maskedcardno), 0) AS NUMERIC) AS opl_ruvcode_avg_util_per_px,
        CAST(SUM(inp_ruvcode_util) / NULLIF(COUNT(DISTINCT maskedcardno), 0) AS NUMERIC) AS inp_ruvcode_avg_util_per_px,
        CAST(SUM(emg_ruvcode_util) / NULLIF(COUNT(DISTINCT maskedcardno), 0) AS NUMERIC) AS emg_ruvcode_avg_util_per_px


        -- RUVCODE

    FROM {{ ref('px_engine') }} pe
    LEFT JOIN (SELECT DISTINCT physiciancode, providername, physicianname, specialization FROM {{ ref('physicianinfo') }}) pi
    ON pe.starting_physiciancode = pi.physiciancode
    AND pe.starting_providername = pi.providername
    WHERE pe.starting_primaryicdgroup IN ('NON-INSULIN-DEPENDENT DIABETES MELLITUS','INSULIN-DEPENDENT DIABETES MELLITUS')
    GROUP BY starting_physiciancode, starting_providername
)
SELECT
    -- 1. IDENTIFIERS
    physician_providername,
    physiciancode,
    providername,
    physicianname,
    specialization,


    -- 2. BASE PATIENT METRICS
    total_unique_patient_cnt,
    

    -- 4. ALL CLAIMS METRICS
    total_claim_count,
    total_util AS all_claims_sum_of_util,
    ave_12_month_util_per_patient,

    -- 5. OP LAB METRICS
    opl_unique_px_cnt_at_least_one,
    opl_unique_px_count_at_least_one_pct,
    opl_ave_claims_per_px_at_least_one,
    opl_total_claims,
    opl_ave_cost_per_claim_per_px_at_least_one,
    opl_sum_of_util,

    opl_unique_px_count_at_least_one_pct * 
    opl_ave_claims_per_px_at_least_one * 
    opl_ave_cost_per_claim_per_px_at_least_one AS opl_per_capita,

    opl_ave_twelve_month_util_per_px,

    -- 6. INPATIENT METRICS
    inp_unique_px_count_at_least_one,
    inp_unique_px_count_at_least_one_pct,
    inp_ave_claims_per_px_at_least_one,
    inp_total_claims,
    inp_ave_cost_per_claim_per_px_at_least_one,
    inp_sum_of_util,

    inp_unique_px_count_at_least_one_pct * 
    inp_ave_claims_per_px_at_least_one * 
    inp_ave_cost_per_claim_per_px_at_least_one AS inp_per_capita,

    inp_ave_twelve_month_util_per_px,

    -- 7. OTHERS METRICS
    others_unique_px_count_at_least_one,
    others_unique_px_count_at_least_one_pct,
    others_ave_claims_per_px_at_least_one,
    others_total_claims,
    others_ave_cost_per_claim_per_px_at_least_one,
    others_sum_of_util,

    others_unique_px_count_at_least_one_pct * 
    others_ave_claims_per_px_at_least_one * 
    others_ave_cost_per_claim_per_px_at_least_one AS others_per_capita,

    others_ave_twelve_month_util_per_px,

    -- 8. PHILHEALTH METRICS
    total_philhealth,
    ave_philhealth_claim,

    total_overall_cptcode_count,
    total_overall_cptcode_util,
    overall_cptcode_avg_count_per_px,
    overall_cptcode_avg_util_per_px,

    
    total_overall_ruvcode_count,
    total_overall_ruvcode_util,
    overall_ruvcode_avg_count_per_px,
    overall_ruvcode_avg_util_per_px

FROM physician_provider_agg

    WHERE providername IN (
        SELECT providername FROM (
            SELECT 
            starting_providername AS providername,
            SUM(total_util) AS total_util_for_diabetes
            FROM {{ref('provider_engine')}}
            WHERE starting_primaryicdgroup IN ('NON-INSULIN-DEPENDENT DIABETES MELLITUS','INSULIN-DEPENDENT DIABETES MELLITUS')
            GROUP BY 1
            ORDER BY total_util_for_diabetes DESC 
            LIMIT 20
        ) t 
    )
    AND total_unique_patient_cnt > 6
ORDER BY ave_12_month_util_per_patient DESC
LIMIT 500