{{ config(materialized='table') }}

WITH raw_data AS (
    SELECT 
        raw.*, 
        md.formatted_physicianname,
        md.final_score AS md_match_score
    FROM {{ ref('masked_acn_2325') }} raw
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
        MAX(primaryicdgroup) AS primaryicdgroup,
        MAX(age) AS age,
        MAX(CAST(admissiondate AS DATE)) AS admissiondate,
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

inpatient_stays AS (
    SELECT
        maskedcardno,
        admissiondate
    FROM base_claims
    WHERE UPPER(TRIM(loatype)) = 'INPATIENT'
    GROUP BY maskedcardno, admissiondate
),

inpatient_patient_journey AS (
    SELECT
        maskedcardno,
        admissiondate,
        LEAD(admissiondate) OVER (
            PARTITION BY maskedcardno
            ORDER BY admissiondate
        ) AS next_admissiondate
    FROM inpatient_stays
),

readmission_logic AS (
    SELECT
        maskedcardno,
        admissiondate,
        next_admissiondate,
        {% if target.type == 'bigquery' %}
            DATE_DIFF(next_admissiondate, admissiondate, DAY) AS days_to_readmit
        {% else %}
            (next_admissiondate - admissiondate) AS days_to_readmit
        {% endif %}
    FROM inpatient_patient_journey
),

physician_inpatient_stays AS (
    SELECT DISTINCT
        physicianname,
        maskedcardno,
        admissiondate
    FROM base_claims
    WHERE UPPER(TRIM(loatype)) = 'INPATIENT'
),

physician_readmission_metrics AS (
    SELECT
        pis.physicianname,
        COALESCE(SUM(CASE
            WHEN rl.days_to_readmit <= 30
            AND rl.days_to_readmit IS NOT NULL THEN 1 ELSE 0
        END), 0) AS count_of_rapid_readmissions,
        COALESCE(COUNT(*), 0) AS count_of_unique_inpatient_stays
    FROM physician_inpatient_stays pis
    LEFT JOIN readmission_logic rl
        ON pis.maskedcardno = rl.maskedcardno
        AND pis.admissiondate = rl.admissiondate
    GROUP BY pis.physicianname
),

physician_metrics AS (
    SELECT
        physicianname,
    MIN(physiciancode) AS physiciancode,
    COALESCE(MAX(md_match_score), 0) AS md_match_score,
    MIN(mainspecialization) AS mainspecialization,
    
    -- ICD Info
    STRING_AGG(DISTINCT icdcode, ', ') AS icdcodes,
    STRING_AGG(DISTINCT primaryicdgroup, ', ') AS primaryicdgroup,

    -- Demographics & Location
    COALESCE(ROUND(CAST(AVG(age) AS NUMERIC), 2), 0) AS avg_patient_age,
    STRING_AGG(DISTINCT corpcode, ', ') AS corpcodes,
    STRING_AGG(DISTINCT branchdesc, ' | ') AS branchdescs,

    -- BASE METRICS
    COALESCE(COUNT(DISTINCT maskedcardno), 0) AS total_unique_patient_cnt,
    COALESCE(COUNT(DISTINCT claimno), 0) AS total_claim_count,
    COALESCE(ROUND(CAST(SUM(approved) AS NUMERIC), 2), 0) AS total_util,
    COALESCE(ROUND(CAST(SUM(approved) AS NUMERIC) / NULLIF(COUNT(DISTINCT maskedcardno), 0), 2), 0) AS ave_12_month_util_per_patient,

    -- OVERALL CPT METRICS
    COALESCE(CAST(SUM(count_of_cptcode) AS NUMERIC), 0) AS total_overall_cptcode_count,
    COALESCE(ROUND(CAST(SUM(sum_of_util_cptcode) AS NUMERIC), 2), 0) AS total_overall_cptcode_util,
    COALESCE(ROUND(CAST(SUM(count_of_cptcode) AS NUMERIC) / NULLIF(COUNT(DISTINCT maskedcardno), 0), 2), 0) AS overall_cptcode_avg_count_per_px,
    COALESCE(ROUND(CAST(SUM(sum_of_util_cptcode) AS NUMERIC) / NULLIF(COUNT(DISTINCT maskedcardno), 0), 2), 0) AS overall_cptcode_avg_util_per_px,

    -- OVERALL RUV METRICS
    COALESCE(CAST(SUM(count_of_ruvcode) AS NUMERIC), 0) AS total_overall_ruvcode_count,
    COALESCE(ROUND(CAST(SUM(sum_of_util_ruvcode) AS NUMERIC), 2), 0) AS total_overall_ruvcode_util,
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
    COALESCE(COUNT(DISTINCT CASE WHEN UPPER(TRIM(loatype)) = UPPER('{{ l }}') THEN maskedcardno END), 0) AS {{ l_slug }}_unique_px_count_at_least_one,
    
    COALESCE(ROUND(
        CAST(COUNT(DISTINCT CASE WHEN UPPER(TRIM(loatype)) = UPPER('{{ l }}') THEN maskedcardno END) AS NUMERIC)
        / NULLIF(COUNT(DISTINCT maskedcardno), 0)
    , 2), 0) AS {{ l_slug }}_unique_px_count_at_least_one_pct,

    COALESCE(ROUND(
        CAST(COUNT(DISTINCT CASE WHEN UPPER(TRIM(loatype)) = UPPER('{{ l }}') THEN claimno END) AS NUMERIC)
        / NULLIF(COUNT(DISTINCT CASE WHEN UPPER(TRIM(loatype)) = UPPER('{{ l }}') THEN maskedcardno END), 0)
    , 2), 0) AS {{ l_slug }}_ave_claims_per_px_at_least_one,

    COALESCE(COUNT(DISTINCT CASE WHEN UPPER(TRIM(loatype)) = UPPER('{{ l }}') THEN claimno END), 0) AS {{ l_slug }}_total_claims,

    COALESCE(ROUND(
        CAST(SUM(CASE WHEN UPPER(TRIM(loatype)) = UPPER('{{ l }}') THEN approved END) AS NUMERIC)
        / NULLIF(COUNT(DISTINCT CASE WHEN UPPER(TRIM(loatype)) = UPPER('{{ l }}') THEN claimno END), 0)
    , 2), 0) AS {{ l_slug }}_ave_cost_per_claim_per_px_at_least_one,

    COALESCE(ROUND(CAST(SUM(CASE WHEN UPPER(TRIM(loatype)) = UPPER('{{ l }}') THEN approved END) AS NUMERIC), 2), 0) AS {{ l_slug }}_sum_of_util,

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
    pm.*,
    COALESCE(prm.count_of_unique_inpatient_stays, 0) AS count_of_unique_inpatient_stays,
    COALESCE(prm.count_of_rapid_readmissions, 0) AS count_of_rapid_readmissions,
    COALESCE(
        ROUND(
            CAST(COALESCE(prm.count_of_rapid_readmissions, 0) AS NUMERIC)
            / NULLIF(COALESCE(prm.count_of_unique_inpatient_stays, 0), 0),
        2),
    0) AS readmission_rate
FROM physician_metrics pm
LEFT JOIN physician_readmission_metrics prm
    ON pm.physicianname = prm.physicianname
ORDER BY total_unique_patient_cnt DESC,  ave_12_month_util_per_patient DESC
