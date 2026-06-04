{{ config(materialized='table') }}

WITH unique_admissions AS (
    SELECT
        maskedcardno,
        subsequent_admissiondate,
        subsequent_loatype,
        MAX(is_panic_visit) AS is_panic_visit

    FROM {{ ref('mlv_acn_masked') }}
    GROUP BY maskedcardno, subsequent_admissiondate, subsequent_loatype
),
er_agg AS (
    SELECT
        maskedcardno,
        
        COALESCE(COUNT(CASE WHEN is_panic_visit = 1 THEN 1 ELSE NULL END),0) AS count_of_panic_visits,

        COALESCE(COUNT(CASE WHEN is_panic_visit = 0 THEN 1 ELSE NULL END),0) AS count_of_non_panic_visits,

        COALESCE(COUNT(*), 0) AS count_of_unique_emergencies
    
    FROM unique_admissions
    WHERE subsequent_loatype = 'EMERGENCY'
    GROUP BY maskedcardno
),
patient_engine AS (
    SELECT
        mlv.maskedcardno,
        MIN(mlv.starting_corpcode) AS starting_corpcode,
        MIN(mlv.starting_providername) AS starting_providername,
        MIN(mlv.starting_physiciancode) AS starting_physiciancode,
        MIN(mlv.starting_physicianname) AS starting_physicianname,
        MIN(mlv.starting_mainspecialization) AS starting_mainspecialization,
        MIN(mlv.starting_primaryicdgroup) AS starting_primaryicdgroup,
        MIN(mlv.combined_starting_primaryicdgroup) AS combined_starting_primaryicdgroup,
        
        COUNT(DISTINCT mlv.subsequent_claimno) AS overall_count_of_claims,
        SUM(mlv.subsequent_approved) AS overall_util,

        -- LOATYPES
        COUNT(DISTINCT CASE WHEN mlv.subsequent_loatype = 'ACU' THEN mlv.subsequent_claimno END) AS acu_coc,
        ROUND(CAST(SUM(CASE WHEN mlv.subsequent_loatype = 'ACU' THEN mlv.subsequent_approved ELSE 0 END) AS NUMERIC), 2) AS acu_util,

        COUNT(DISTINCT CASE WHEN mlv.subsequent_loatype = 'CONSULT' THEN mlv.subsequent_claimno END) AS consult_coc,
        ROUND(CAST(SUM(CASE WHEN mlv.subsequent_loatype = 'CONSULT' THEN mlv.subsequent_approved ELSE 0 END) AS NUMERIC), 2) AS consult_util,

        COUNT(DISTINCT CASE WHEN mlv.subsequent_loatype = 'Corporate Clinic' THEN mlv.subsequent_claimno END) AS corporate_clinic_coc,
        ROUND(CAST(SUM(CASE WHEN mlv.subsequent_loatype = 'Corporate Clinic' THEN mlv.subsequent_approved ELSE 0 END) AS NUMERIC), 2) AS corporate_clinic_util,

        COUNT(DISTINCT CASE WHEN mlv.subsequent_loatype = 'DENTAL' THEN mlv.subsequent_claimno END) AS dental_coc,
        ROUND(CAST(SUM(CASE WHEN mlv.subsequent_loatype = 'DENTAL' THEN mlv.subsequent_approved ELSE 0 END) AS NUMERIC), 2) AS dental_util,

        COUNT(DISTINCT CASE WHEN mlv.subsequent_loatype = 'EMERGENCY' THEN mlv.subsequent_claimno END) AS emergency_coc,
        ROUND(CAST(SUM(CASE WHEN mlv.subsequent_loatype = 'EMERGENCY' THEN mlv.subsequent_approved ELSE 0 END) AS NUMERIC), 2) AS emergency_util,

        COUNT(DISTINCT CASE WHEN mlv.subsequent_loatype = 'INPATIENT' THEN mlv.subsequent_claimno END) AS inpatient_coc,
        ROUND(CAST(SUM(CASE WHEN mlv.subsequent_loatype = 'INPATIENT' THEN mlv.subsequent_approved ELSE 0 END) AS NUMERIC), 2) AS inpatient_util,

        COUNT(DISTINCT CASE WHEN mlv.subsequent_loatype = 'Medgrocer' THEN mlv.subsequent_claimno END) AS medgrocer_coc,
        ROUND(CAST(SUM(CASE WHEN mlv.subsequent_loatype = 'Medgrocer' THEN mlv.subsequent_approved ELSE 0 END) AS NUMERIC), 2) AS medgrocer_util,

        COUNT(DISTINCT CASE WHEN mlv.subsequent_loatype = 'PROCEDURE' THEN mlv.subsequent_claimno END) AS procedure_coc,
        ROUND(CAST(SUM(CASE WHEN mlv.subsequent_loatype = 'PROCEDURE' THEN mlv.subsequent_approved ELSE 0 END) AS NUMERIC), 2) AS procedure_util,

        COUNT(DISTINCT CASE WHEN mlv.subsequent_loatype = 'VIDEO CALL' THEN mlv.subsequent_claimno END) AS video_call_coc,
        ROUND(CAST(SUM(CASE WHEN mlv.subsequent_loatype = 'VIDEO CALL' THEN mlv.subsequent_approved ELSE 0 END) AS NUMERIC), 2) AS video_call_util,

        COUNT(DISTINCT CASE WHEN mlv.subsequent_loatype = 'VOICE CALL' THEN mlv.subsequent_claimno END) AS voice_call_coc,
        ROUND(CAST(SUM(CASE WHEN mlv.subsequent_loatype = 'VOICE CALL' THEN mlv.subsequent_approved ELSE 0 END) AS NUMERIC), 2) AS voice_call_util,

        COUNT(DISTINCT CASE WHEN mlv.subsequent_loatype = 'Zennya (Home Care)' THEN mlv.subsequent_claimno END) AS zennya_home_care_coc,
        ROUND(CAST(SUM(CASE WHEN mlv.subsequent_loatype = 'Zennya (Home Care)' THEN mlv.subsequent_approved ELSE 0 END) AS NUMERIC), 2) AS zennya_home_care_util,

        -- Journey
        CASE 
            WHEN MAX(CASE WHEN mlv.subsequent_icdcode IN (SELECT primaryicdcode FROM {{ref('end_stage_cardiometabolic_primaryicdcodes')}}) OR mlv.starting_icdcode IN (SELECT primaryicdcode FROM {{ref('end_stage_cardiometabolic_primaryicdcodes')}}) THEN 1 ELSE 0 END) = 1 
            THEN 'End-Stage Cardiometabolic Disease Patient'

            WHEN MAX(CASE WHEN mlv.subsequent_icdcode IN (SELECT primaryicdcode FROM {{ref('end_stage_cardiometabolic_primaryicdcodes')}}) OR mlv.starting_icdcode IN (SELECT primaryicdcode FROM {{ref('end_stage_cardiometabolic_primaryicdcodes')}}) THEN 1 ELSE 0 END) = 0 
                AND MIN(mlv.starting_primaryicdgroup) = 'ESSENTIAL (PRIMARY) HYPERTENSION' 
            THEN 'Essential (Primary) Hypertension Patient Only'

            WHEN MAX(CASE WHEN mlv.subsequent_icdcode IN (SELECT primaryicdcode FROM {{ref('end_stage_cardiometabolic_primaryicdcodes')}}) OR mlv.starting_icdcode IN (SELECT primaryicdcode FROM {{ref('end_stage_cardiometabolic_primaryicdcodes')}}) THEN 1 ELSE 0 END) = 0 
                AND MIN(mlv.combined_starting_primaryicdgroup) = 'DIABETES MELLITUS' 
            THEN 'Diabetes Mellitus Patient Only'

            WHEN MAX(CASE WHEN mlv.subsequent_icdcode IN (SELECT primaryicdcode FROM {{ref('end_stage_cardiometabolic_primaryicdcodes')}}) OR mlv.starting_icdcode IN (SELECT primaryicdcode FROM {{ref('end_stage_cardiometabolic_primaryicdcodes')}}) THEN 1 ELSE 0 END) = 0 
                AND MIN(mlv.starting_primaryicdgroup) = 'DISORDERS OF LIPOPROTEIN METABOLISM AND OTHER LIPIDAEMIAS' 
            THEN 'Dyslipidaemia Patient Only'
            ELSE 'Invalid'
        END AS patient_journey_category

    FROM {{ ref('mlv_acn_masked') }} mlv
    GROUP BY mlv.maskedcardno
)
SELECT 
    p.*
    ,COALESCE(e.count_of_non_panic_visits, 0) AS count_of_non_panic_visits
    ,COALESCE(e.count_of_panic_visits, 0) AS count_of_panic_visits
    ,COALESCE(e.count_of_unique_emergencies, 0) AS count_of_unique_emergencies
    
FROM patient_engine p
LEFT JOIN er_agg e ON p.maskedcardno = e.maskedcardno
