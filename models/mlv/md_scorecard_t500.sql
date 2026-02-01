



WITH patient_engine AS (
    SELECT
        maskedcardno,
        MIN(starting_providername) AS starting_providername,
        MIN(starting_physiciancode) AS starting_physiciancode,
        
        -- OVERALL COUNTS
        COUNT(DISTINCT subsequent_claimno) AS overall_count_of_claims,
        SUM(subsequent_approved) AS overall_util,
        
        -- OP LAB COUNTS & UTIL
        COUNT(DISTINCT CASE WHEN subsequent_loatype='OP LAB' THEN subsequent_claimno END) AS opl_coc,
        ROUND(SUM(CASE WHEN subsequent_loatype='OP LAB' THEN subsequent_approved ELSE 0 END)::numeric, 2) AS opl_util,
        
        -- INPATIENT COUNTS & UTIL
        COUNT(DISTINCT CASE WHEN subsequent_loatype='INPATIENT' THEN subsequent_claimno END) AS inp_coc,
        ROUND(SUM(CASE WHEN subsequent_loatype='INPATIENT' THEN subsequent_approved ELSE 0 END)::numeric, 2) AS inp_util,
        
        -- OTHERS (EMERGENCY/OP_CONSULT/ACU) COUNTS & UTIL
        COUNT(DISTINCT CASE WHEN subsequent_loatype IN ('EMERGENCY','OP_CONSULT','ACU') THEN subsequent_claimno END) AS others_coc,
        ROUND(SUM(CASE WHEN subsequent_loatype IN ('EMERGENCY','OP_CONSULT','ACU') THEN subsequent_approved ELSE 0 END)::numeric, 2) AS others_util,
        
        -- PHILHEALTH
        SUM(subsequent_philhealth) AS sum_philhealth,
        COUNT(DISTINCT CASE WHEN subsequent_philhealth > 0 THEN subsequent_claimno END) as philhealth_claim_count

    FROM mlv_px_level_v5_eph
    GROUP BY maskedcardno
),
physician_provider_agg AS (
    SELECT
        -- IDENTIFIERS
        starting_physiciancode || ' - ' || starting_providername AS physician_provider_code,
        starting_physiciancode AS physician_code,
        starting_providername AS provider_code,
        
        -- BASE
        COUNT(DISTINCT maskedcardno) AS total_unique_patient_count,

        -- =============================================
        -- OP LAB METRICS
        -- =============================================
        -- 1. Unique Patient Count with at least one
        COUNT(DISTINCT CASE WHEN opl_coc > 0 THEN maskedcardno END) AS opl_unique_px_count_at_least_one,
        
        -- 2. Unique Patient Count with at least one (%)
        ROUND(
            (COUNT(DISTINCT CASE WHEN opl_coc > 0 THEN maskedcardno END)::numeric 
            / NULLIF(COUNT(DISTINCT maskedcardno), 0)) * 100
        , 2) AS opl_unique_px_count_at_least_one_pct,

        -- 3. Ave count of claims per patient (>=1)
        ROUND(
            SUM(opl_coc)::numeric 
            / NULLIF(COUNT(DISTINCT CASE WHEN opl_coc > 0 THEN maskedcardno END), 0)
        , 2) AS opl_ave_claims_per_px_at_least_one,

        -- 4. Total Claims
        SUM(opl_coc) AS opl_total_claims,

        -- 5. Average cost per claim per patient with at least one (Cost Per Claim)
        ROUND(
            SUM(opl_util)::numeric 
            / NULLIF(SUM(opl_coc), 0)
        , 2) AS opl_ave_cost_per_claim_per_px_at_least_one,

        -- 6. Sum of Util
        SUM(opl_util) AS opl_sum_of_util,

        -- 7. Ave 12-Month Util (per Active Patient)
        ROUND(
            SUM(opl_util)::numeric
            / NULLIF(COUNT(DISTINCT CASE WHEN opl_coc > 0 THEN maskedcardno END), 0)
        , 2) AS opl_ave_twelve_month_util_per_px,


        -- =============================================
        -- INPATIENT METRICS
        -- =============================================
        -- 1. Unique Patient Count with at least one
        COUNT(DISTINCT CASE WHEN inp_coc > 0 THEN maskedcardno END) AS inp_unique_px_count_at_least_one,
        
        -- 2. Unique Patient Count with at least one (%)
        ROUND(
            (COUNT(DISTINCT CASE WHEN inp_coc > 0 THEN maskedcardno END)::numeric 
            / NULLIF(COUNT(DISTINCT maskedcardno), 0)) * 100
        , 2) AS inp_unique_px_count_at_least_one_pct,

        -- 3. Ave count of claims per patient (>=1)
        ROUND(
            SUM(inp_coc)::numeric 
            / NULLIF(COUNT(DISTINCT CASE WHEN inp_coc > 0 THEN maskedcardno END), 0)
        , 2) AS inp_ave_claims_per_px_at_least_one,

        -- 4. Total Claims
        SUM(inp_coc) AS inp_total_claims,

        -- 5. Average cost per claim per patient with at least one
        ROUND(
            SUM(inp_util)::numeric 
            / NULLIF(SUM(inp_coc), 0)
        , 2) AS inp_ave_cost_per_claim_per_px_at_least_one,

        -- 6. Sum of Util
        SUM(inp_util) AS inp_sum_of_util,

        -- 7. Ave 12-Month Util (per Active Patient)
        ROUND(
            SUM(inp_util)::numeric
            / NULLIF(COUNT(DISTINCT CASE WHEN inp_coc > 0 THEN maskedcardno END), 0)
        , 2) AS inp_ave_twelve_month_util_per_px,


        -- =============================================
        -- OTHERS METRICS
        -- =============================================
        -- 1. Unique Patient Count with at least one
        COUNT(DISTINCT CASE WHEN others_coc > 0 THEN maskedcardno END) AS others_unique_px_count_at_least_one,
        
        -- 2. Unique Patient Count with at least one (%)
        ROUND(
            (COUNT(DISTINCT CASE WHEN others_coc > 0 THEN maskedcardno END)::numeric 
            / NULLIF(COUNT(DISTINCT maskedcardno), 0)) * 100
        , 2) AS others_unique_px_count_at_least_one_pct,

        -- 3. Ave count of claims per patient (>=1)
        ROUND(
            SUM(others_coc)::numeric 
            / NULLIF(COUNT(DISTINCT CASE WHEN others_coc > 0 THEN maskedcardno END), 0)
        , 2) AS others_ave_claims_per_px_at_least_one,

        -- 4. Total Claims
        SUM(others_coc) AS others_total_claims,

        -- 5. Average cost per claim per patient with at least one
        ROUND(
            SUM(others_util)::numeric 
            / NULLIF(SUM(others_coc), 0)
        , 2) AS others_ave_cost_per_claim_per_px_at_least_one,

        -- 6. Sum of Util
        SUM(others_util) AS others_sum_of_util,

        -- 7. Ave 12-Month Util (per Active Patient)
        ROUND(
            SUM(others_util)::numeric
            / NULLIF(COUNT(DISTINCT CASE WHEN others_coc > 0 THEN maskedcardno END), 0)
        , 2) AS others_ave_twelve_month_util_per_px

    FROM patient_engine
    WHERE starting_providername IN (
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

    GROUP BY starting_physiciancode, starting_providername
    GROUP BY starting_physiciancode, starting_providername
)