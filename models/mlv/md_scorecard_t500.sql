
{{config(materialized = 'table')}}

WITH physician_provider_agg AS (
    SELECT
        -- IDENTIFIERS
        starting_physiciancode || ' - ' || starting_providername AS physician_providercode,
        starting_physiciancode AS physiciancode,
        starting_providername AS providercode,
        MIN(pn.physicianname) AS physicianname,
        
        -- BASE
        COUNT(DISTINCT maskedcardno) AS total_unique_patient_cnt,
        SUM(overall_count_of_claims) AS total_claim_count,
        SUM(overall_util) AS total_util,
        SUM(overall_util) / NULLIF(COUNT(DISTINCT maskedcardno), 0) AS ave_year_util_per_patient,

        -- =============================================
        -- OP LAB METRICS
        -- =============================================
        COUNT(DISTINCT CASE WHEN opl_coc > 0 THEN maskedcardno END) AS opl_unique_px_cnt_at_least_one,

        (COUNT(DISTINCT CASE WHEN opl_coc > 0 THEN maskedcardno END)::numeric
         / NULLIF(COUNT(DISTINCT maskedcardno), 0)
        ) AS opl_unique_px_count_at_least_one_pct,

        (SUM(opl_coc)::numeric
         / NULLIF(COUNT(DISTINCT CASE WHEN opl_coc > 0 THEN maskedcardno END), 0)
        ) AS opl_ave_claims_per_px_at_least_one,

        SUM(opl_coc) AS opl_total_claims,

        (SUM(opl_util)::numeric
         / NULLIF(SUM(opl_coc), 0)
        ) AS opl_ave_cost_per_claim_per_px_at_least_one,

        SUM(opl_util) AS opl_sum_of_util,

        (SUM(opl_util)::numeric
         / NULLIF(COUNT(DISTINCT maskedcardno), 0)
        ) AS opl_ave_twelve_month_util_per_px,

        -- =============================================
        -- INPATIENT METRICS
        -- =============================================
        COUNT(DISTINCT CASE WHEN inp_coc > 0 THEN maskedcardno END) AS inp_unique_px_count_at_least_one,

        (COUNT(DISTINCT CASE WHEN inp_coc > 0 THEN maskedcardno END)::numeric
         / NULLIF(COUNT(DISTINCT maskedcardno), 0)
        ) AS inp_unique_px_count_at_least_one_pct,

        (SUM(inp_coc)::numeric
         / NULLIF(COUNT(DISTINCT CASE WHEN inp_coc > 0 THEN maskedcardno END), 0)
        ) AS inp_ave_claims_per_px_at_least_one,

        SUM(inp_coc) AS inp_total_claims,

        (SUM(inp_util)::numeric
         / NULLIF(SUM(inp_coc), 0)
        ) AS inp_ave_cost_per_claim_per_px_at_least_one,

        SUM(inp_util) AS inp_sum_of_util,

        (SUM(inp_util)::numeric
         / NULLIF(COUNT(DISTINCT maskedcardno), 0)
        ) AS inp_ave_twelve_month_util_per_px,

        -- =============================================
        -- OTHERS METRICS
        -- =============================================
        COUNT(DISTINCT CASE WHEN others_coc > 0 THEN maskedcardno END) AS others_unique_px_count_at_least_one,

        (COUNT(DISTINCT CASE WHEN others_coc > 0 THEN maskedcardno END)::numeric
         / NULLIF(COUNT(DISTINCT maskedcardno), 0)
        ) AS others_unique_px_count_at_least_one_pct,

        (SUM(others_coc)::numeric
         / NULLIF(COUNT(DISTINCT CASE WHEN others_coc > 0 THEN maskedcardno END), 0)
        ) AS others_ave_claims_per_px_at_least_one,

        SUM(others_coc) AS others_total_claims,

        (SUM(others_util)::numeric
         / NULLIF(SUM(others_coc), 0)
        ) AS others_ave_cost_per_claim_per_px_at_least_one,

        SUM(others_util) AS others_sum_of_util,

        (SUM(others_util)::numeric
         / NULLIF(COUNT(DISTINCT maskedcardno), 0)
        ) AS others_ave_twelve_month_util_per_px,

        -- =============================================
        -- PHILHEALTH METRICS
        -- =============================================
        SUM(sum_philhealth) AS total_philhealth,

        SUM(sum_philhealth)::numeric
        / COUNT(DISTINCT maskedcardno)::numeric AS ave_philhealth_claim

    FROM {{ ref('eph_patient_engine') }} pe
    LEFT JOIN {{ ref('physiciannames') }} pn
        ON pe.starting_physiciancode = pn.physiciancode
    GROUP BY starting_physiciancode, starting_providername
)
SELECT
    -- 1. IDENTIFIERS
    physician_providercode,
    p.physiciancode,
    p.providercode,
    p.physicianname,
    d.specialization,


    -- 2. BASE PATIENT METRICS
    total_unique_patient_cnt,
    
    -- -- 3. RANKING & CLASSIFICATION (Derived)
    -- ROUND(PERCENT_RANK() OVER (ORDER BY ave_year_util_per_patient ASC)::numeric, 4) AS percentile_by_avg_12_month_cc,
    -- CASE 
    --     WHEN PERCENT_RANK() OVER (ORDER BY ave_year_util_per_patient ASC) >= 0.8 THEN 'High Cost'
    --     WHEN PERCENT_RANK() OVER (ORDER BY ave_year_util_per_patient ASC) <= 0.2 THEN 'Low Cost'
    --     ELSE 'Average'
    -- END AS classification,

    -- 4. ALL CLAIMS METRICS
    total_claim_count,
    total_util AS all_claims_sum_of_util,
    ave_year_util_per_patient AS ave_12_month_util_per_patient,

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
    ave_philhealth_claim

FROM physician_provider_agg p
LEFT JOIN {{ref('doc_spec')}} d
ON d.physiciancode = p.physiciancode

    WHERE p.providercode IN (
        'MAKATI MEDICAL CENTER',
        'ST. LUKE''S MEDICAL CENTER-GLOBAL CITY',
        'ASIAN HOSPITAL AND MEDICAL CENTER',
        'ST. LUKE''S MEDICAL CENTER-QC',
        'THE MEDICAL CITY',
        'COMMONWEALTH HOSPITAL AND MEDICAL CENTER',
        'THE MEDICAL CITY SATELLITE CLINICS-SM FAIRVIEW CLINIC',
        'CHINESE GENERAL HOSPITAL & MEDICAL CENTER',
        'THE MEDICAL CITY SATELLITE CLINICS-VICTORY MALL',
        'MANILA DOCTORS HOSPITAL',
        'DILIMAN DOCTORS HOSPITAL INC.',
        'MARIKINA VALLEY MEDICAL CENTER INC.',
        'SAN MATEO MEDICAL CENTER',
        'DIVINE GRACE MEDICAL CENTER',
        'UNIVERSITY OF PERPETUAL HELP DALTA MEDICAL CENTER INC',
        'MANILA EAST MEDICAL CENTER, INC.',
        'MEDICAL CENTER MANILA, INC.',
        'THE MEDICAL CITY SATELLITE CLINICS-TRINOMA',
        'CARDINAL SANTOS MEDICAL CENTER',
        'OUR LADY OF LOURDES HOSPITAL-MANILA'
    )
    AND total_unique_patient_cnt > 6
ORDER BY ave_12_month_util_per_patient DESC
LIMIT 500