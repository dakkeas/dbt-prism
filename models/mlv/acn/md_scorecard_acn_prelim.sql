{{ config(materialized='table') }}

WITH prism_claims AS (
    SELECT icdcode, icddesc FROM {{ source('mxc_raw_claims', 'prism_2019_jan_to_jun') }}
    UNION ALL
    SELECT icdcode, icddesc FROM {{ source('mxc_raw_claims', 'prism_2019_july_to_dec') }}
    UNION ALL
    SELECT icdcode, icddesc FROM {{ source('mxc_raw_claims', 'prism_2020_jan_to_jun') }}
    UNION ALL
    SELECT icdcode, icddesc FROM {{ source('mxc_raw_claims', 'prism_2020_july_to_dec') }}
    UNION ALL
    SELECT icdcode, icddesc FROM {{ source('mxc_raw_claims', 'prism_2021_jan_to_jun') }}
    UNION ALL
    SELECT icdcode, icddesc FROM {{ source('mxc_raw_claims', 'prism_2021_july_to_dec') }}
    UNION ALL
    SELECT icdcode, icddesc FROM {{ source('mxc_raw_claims', 'prism_2022_jan_to_jun') }}
    UNION ALL
    SELECT icdcode, icddesc FROM {{ source('mxc_raw_claims', 'prism_2022_july_to_dec') }}
    UNION ALL
    SELECT icdcode, icddesc FROM {{ source('mxc_raw_claims', 'prism_2023_jan_to_jun') }}
    UNION ALL
    SELECT icdcode, icddesc FROM {{ source('mxc_raw_claims', 'prism_2023_july_to_dec') }}
    UNION ALL
    SELECT icdcode, icddesc FROM {{ source('mxc_raw_claims', 'prism_2024_jan_to_jun') }}
    UNION ALL
    SELECT icdcode, icddesc FROM {{ source('mxc_raw_claims', 'prism_2024_july_to_dec') }}
    UNION ALL
    SELECT icdcode, icddesc FROM {{ source('mxc_raw_claims', 'prism_2025_jan_to_mar') }}
),

icd_mapping AS (
    SELECT 
        icdcode, 
        MAX(icddesc) AS icddesc
    FROM prism_claims
    WHERE icdcode IS NOT NULL
    GROUP BY icdcode
),

raw_data AS (
    SELECT 
        raw.*, 
        md.formatted_physicianname,
        md.final_score AS md_match_score,
        map.icddesc
    FROM {{ ref('masked_acn_consolidated_raw_data_fy2324_fy2425') }} raw
    LEFT JOIN icd_mapping map
        ON raw.icdcode = map.icdcode
    LEFT JOIN {{ source('md_fuzzy_from_physicianinfo', 'physician_name_matching_results') }} md
        ON raw.physicianname = md.broken_physicianname_original
        AND md.final_score >= 65
),

base_claims AS (
    -- Deduplicate to the claim level before aggregating by physician
    SELECT
        claimno,
        MAX(maskedcardno) AS maskedcardno,
        MAX(COALESCE(formatted_physicianname, physicianname)) AS physicianname,
        MAX(md_match_score) AS md_match_score,
        MAX(physiciancode) AS physiciancode,
        MAX(mainspecialization) AS mainspecialization,
        MAX(loatype) AS loatype,
        MAX(icdcode) AS icdcode,
        MAX(icddesc) AS icddesc,
        MAX(age) AS age,
        MAX(branchdesc) AS branchdesc,
        MAX(corpcode) AS corpcode,
        SUM(approved) AS approved,
        
        -- CPT/RUV Counts & Utils at the claim level
        SUM(CASE WHEN NULLIF(cptdesc, '') IS NOT NULL THEN 1 ELSE 0 END) AS count_of_cptcode,
        SUM(CASE WHEN NULLIF(cptdesc, '') IS NOT NULL THEN approved ELSE 0 END) AS sum_of_util_cptcode,
        
        SUM(CASE WHEN NULLIF(ruvcode, '') IS NOT NULL THEN 1 ELSE 0 END) AS count_of_ruvcode,
        SUM(CASE WHEN NULLIF(ruvcode, '') IS NOT NULL THEN approved ELSE 0 END) AS sum_of_util_ruvcode

    FROM raw_data
    GROUP BY claimno
),

physician_metrics AS (
    SELECT
        physicianname,
    MIN(physiciancode) AS physiciancode,
    MAX(md_match_score) AS md_match_score,
    MIN(mainspecialization) AS mainspecialization,
    
    -- ICD Info
    STRING_AGG(DISTINCT icdcode, ', ') AS icdcodes,
    STRING_AGG(DISTINCT icddesc, ' | ') AS icddescs,

    -- Demographics & Location
    ROUND(CAST(AVG(age) AS NUMERIC), 2) AS avg_patient_age,
    STRING_AGG(DISTINCT corpcode, ', ') AS corpcodes,
    STRING_AGG(DISTINCT branchdesc, ' | ') AS branchdescs,

    -- BASE METRICS
    COUNT(DISTINCT maskedcardno) AS total_unique_patient_cnt,
    COUNT(DISTINCT claimno) AS total_claim_count,
    ROUND(CAST(SUM(approved) AS NUMERIC), 2) AS total_util,
    COALESCE(ROUND(CAST(SUM(approved) AS NUMERIC) / NULLIF(COUNT(DISTINCT maskedcardno), 0), 2), 0) AS ave_12_month_util_per_patient,

    -- OVERALL CPT METRICS
    CAST(SUM(count_of_cptcode) AS NUMERIC) AS total_overall_cptcode_count,
    ROUND(CAST(SUM(sum_of_util_cptcode) AS NUMERIC), 2) AS total_overall_cptcode_util,
    COALESCE(ROUND(CAST(SUM(count_of_cptcode) AS NUMERIC) / NULLIF(COUNT(DISTINCT maskedcardno), 0), 2), 0) AS overall_cptcode_avg_count_per_px,
    COALESCE(ROUND(CAST(SUM(sum_of_util_cptcode) AS NUMERIC) / NULLIF(COUNT(DISTINCT maskedcardno), 0), 2), 0) AS overall_cptcode_avg_util_per_px,

    -- OVERALL RUV METRICS
    CAST(SUM(count_of_ruvcode) AS NUMERIC) AS total_overall_ruvcode_count,
    ROUND(CAST(SUM(sum_of_util_ruvcode) AS NUMERIC), 2) AS total_overall_ruvcode_util,
    COALESCE(ROUND(CAST(SUM(count_of_ruvcode) AS NUMERIC) / NULLIF(COUNT(DISTINCT maskedcardno), 0), 2), 0) AS overall_ruvcode_avg_count_per_px,
    COALESCE(ROUND(CAST(SUM(sum_of_util_ruvcode) AS NUMERIC) / NULLIF(COUNT(DISTINCT maskedcardno), 0), 2), 0) AS overall_ruvcode_avg_util_per_px,


    {% set loatypes = [
        ('ACU', 'acu'), 
        ('CONSULT', 'consult'), 
        ('Corporate Clinic', 'corporate_clinic'), 
        ('DENTAL', 'dental'), 
        ('EMERGENCY', 'emergency'), 
        ('INPATIENT', 'inpatient'), 
        ('Medgrocer', 'medgrocer'), 
        ('PROCEDURE', 'procedure'), 
        ('VIDEO CALL', 'video_call'), 
        ('VOICE CALL', 'voice_call'), 
        ('Zennya (Home Care)', 'zennya_home_care')
    ] %}
    {% for l, l_slug in loatypes %}
    -- =============================================
    -- {{ l | upper }} METRICS
    -- =============================================
    COUNT(DISTINCT CASE WHEN UPPER(TRIM(loatype)) = UPPER('{{ l }}') THEN maskedcardno END) AS {{ l_slug }}_unique_px_count_at_least_one,
    
    COALESCE(ROUND(
        CAST(COUNT(DISTINCT CASE WHEN UPPER(TRIM(loatype)) = UPPER('{{ l }}') THEN maskedcardno END) AS NUMERIC)
        / NULLIF(COUNT(DISTINCT maskedcardno), 0)
    , 2), 0) AS {{ l_slug }}_unique_px_count_at_least_one_pct,

    COALESCE(ROUND(
        CAST(COUNT(DISTINCT CASE WHEN UPPER(TRIM(loatype)) = UPPER('{{ l }}') THEN claimno END) AS NUMERIC)
        / NULLIF(COUNT(DISTINCT CASE WHEN UPPER(TRIM(loatype)) = UPPER('{{ l }}') THEN maskedcardno END), 0)
    , 2), 0) AS {{ l_slug }}_ave_claims_per_px_at_least_one,

    COUNT(DISTINCT CASE WHEN UPPER(TRIM(loatype)) = UPPER('{{ l }}') THEN claimno END) AS {{ l_slug }}_total_claims,

    COALESCE(ROUND(
        CAST(SUM(CASE WHEN UPPER(TRIM(loatype)) = UPPER('{{ l }}') THEN approved END) AS NUMERIC)
        / NULLIF(COUNT(DISTINCT CASE WHEN UPPER(TRIM(loatype)) = UPPER('{{ l }}') THEN claimno END), 0)
    , 2), 0) AS {{ l_slug }}_ave_cost_per_claim_per_px_at_least_one,

    ROUND(CAST(SUM(CASE WHEN UPPER(TRIM(loatype)) = UPPER('{{ l }}') THEN approved END) AS NUMERIC), 2) AS {{ l_slug }}_sum_of_util,

    COALESCE(ROUND(
        CAST(SUM(CASE WHEN UPPER(TRIM(loatype)) = UPPER('{{ l }}') THEN approved END) AS NUMERIC)
        / NULLIF(COUNT(DISTINCT maskedcardno), 0)
    , 2), 0) AS {{ l_slug }}_ave_twelve_month_util_per_px
    {%- if not loop.last %},{% endif %}
    {% endfor %}

    FROM base_claims
    GROUP BY physicianname
)

SELECT
    *

FROM physician_metrics
ORDER BY total_unique_patient_cnt DESC,  ave_12_month_util_per_patient DESC

