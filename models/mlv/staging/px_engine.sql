
{{ config(materialized='table') }}

WITH unique_admissions AS (
    -- CONTEXT: There can be different claim numbers with the same admissiondate yet have different dischargedates
    -- each of these claims may have different lengthofstays thus baloooning the los count. This only grabs the greatest lengthofstay
    SELECT
        maskedcardno,
        subsequent_admissiondate,
        subsequent_loatype,
        COALESCE(MAX(subsequent_lengthofstay), 0) AS max_lengthofstay,
        MAX(days_to_readmit) AS days_to_readmit,
        MAX(next_stay_is_cardiometabolic) AS next_stay_is_cardiometabolic,
        MAX(is_panic_visit) AS is_panic_visit

    FROM {{ ref('mlv') }}
    -- WHERE subsequent_loatype = 'INPATIENT'
    GROUP BY maskedcardno, subsequent_admissiondate, subsequent_loatype
),
los_agg AS (
    SELECT 
        -- sums only the max lengthofstay per unique admissiondates
        maskedcardno,
        COALESCE(SUM(max_lengthofstay), 0) AS total_lengthofstay
    FROM unique_admissions
    WHERE subsequent_loatype = 'INPATIENT'
    GROUP BY maskedcardno
),
readmission_agg AS (
    SELECT
        maskedcardno,
        COALESCE(SUM(CASE 
            WHEN days_to_readmit <= 30 
            AND days_to_readmit IS NOT NULL THEN 1 ELSE 0
            END), 0) AS count_of_rapid_readmissions,

        COALESCE(COUNT(*), 0) AS count_of_unique_inpatient_stays,

        COALESCE(SUM(CASE 
            WHEN days_to_readmit <= 30 AND 
             days_to_readmit IS NOT NULL AND
             next_stay_is_cardiometabolic = 1 THEN 1 ELSE 0
            END), 0) AS count_of_rapid_cardiometabolic_readmissions,

        COALESCE(COUNT(CASE WHEN next_stay_is_cardiometabolic = 1 THEN 1 ELSE NULL END), 0) AS count_of_unique_cardiometabolic_inpatient_stays

    FROM
        unique_admissions
    WHERE subsequent_loatype = 'INPATIENT'
    GROUP BY maskedcardno
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
        MIN(mlv.bl_cardno) AS bl_cardno,
        MIN(mlv.starting_providername) AS starting_providername,
        MIN(mlv.starting_physiciancode) AS starting_physiciancode,
        MIN(mlv.starting_primaryicdgroup) AS starting_primaryicdgroup,
        MIN(mlv.combined_starting_primaryicdgroup) AS combined_starting_primaryicdgroup,
        
        COUNT(DISTINCT mlv.subsequent_claimno) AS overall_count_of_claims,
        SUM(mlv.subsequent_approved) AS overall_util,

        -- OP LAB
        COUNT(DISTINCT CASE WHEN mlv.subsequent_loatype = 'OP LAB' THEN mlv.subsequent_claimno END) AS opl_coc,
        ROUND(CAST(SUM(CASE WHEN mlv.subsequent_loatype = 'OP LAB' THEN mlv.subsequent_approved ELSE 0 END) AS NUMERIC), 2) AS opl_util,

        -- INPATIENT
        COUNT(DISTINCT CASE WHEN mlv.subsequent_loatype = 'INPATIENT' THEN mlv.subsequent_claimno END) AS inp_coc,
        ROUND(CAST(SUM(CASE WHEN mlv.subsequent_loatype = 'INPATIENT' THEN mlv.subsequent_approved ELSE 0 END) AS NUMERIC), 2) AS inp_util,

        -- OTHERS
        COUNT(DISTINCT CASE WHEN mlv.subsequent_loatype IN ('EMERGENCY','OP_CONSULT','ACU') THEN mlv.subsequent_claimno END) AS others_coc,
        ROUND(CAST(SUM(CASE WHEN mlv.subsequent_loatype IN ('EMERGENCY','OP_CONSULT','ACU') THEN mlv.subsequent_approved ELSE 0 END) AS NUMERIC), 2) AS others_util,

        -- PhilHealth
        SUM(ABS(mlv.subsequent_philhealth)) AS sum_philhealth,
        CAST(SUM(ABS(mlv.subsequent_philhealth)) AS NUMERIC) / NULLIF(CAST(SUM(mlv.subsequent_approved) AS NUMERIC), 0) AS percent_of_philhealth_util,
        COUNT(DISTINCT CASE WHEN mlv.subsequent_philhealth > 0 THEN mlv.subsequent_claimno END) AS philhealth_claim_count,

        -- CPT Code
        SUM(mlv.subsequent_count_of_cptcode) AS overall_cptcode_coc,
        ROUND(CAST(SUM(mlv.subsequent_sum_of_util_cptcode) AS NUMERIC), 2) AS overall_cptcode_util,

        SUM(CASE WHEN mlv.subsequent_loatype = 'OP LAB' THEN mlv.subsequent_count_of_cptcode ELSE 0 END) AS opl_cptcode_coc,
        ROUND(CAST(SUM(CASE WHEN mlv.subsequent_loatype = 'OP LAB' THEN mlv.subsequent_sum_of_util_cptcode ELSE 0 END) AS NUMERIC), 2) AS opl_cptcode_util,

        SUM(CASE WHEN mlv.subsequent_loatype = 'INPATIENT' THEN mlv.subsequent_count_of_cptcode ELSE 0 END) AS inp_cptcode_coc,
        ROUND(CAST(SUM(CASE WHEN mlv.subsequent_loatype = 'INPATIENT' THEN mlv.subsequent_sum_of_util_cptcode ELSE 0 END) AS NUMERIC), 2) AS inp_cptcode_util,

        SUM(CASE WHEN mlv.subsequent_loatype = 'EMERGENCY' THEN mlv.subsequent_count_of_cptcode ELSE 0 END) AS emg_cptcode_coc,
        ROUND(CAST(SUM(CASE WHEN mlv.subsequent_loatype = 'EMERGENCY' THEN mlv.subsequent_sum_of_util_cptcode ELSE 0 END) AS NUMERIC), 2) AS emg_cptcode_util,

        -- RUV Code
        SUM(mlv.subsequent_count_of_ruvcode) AS overall_ruvcode_coc,
        ROUND(CAST(SUM(mlv.subsequent_sum_of_util_ruvcode) AS NUMERIC), 2) AS overall_ruvcode_util,

        SUM(CASE WHEN mlv.subsequent_loatype = 'OP LAB' THEN mlv.subsequent_count_of_ruvcode ELSE 0 END) AS opl_ruvcode_coc,
        ROUND(CAST(SUM(CASE WHEN mlv.subsequent_loatype = 'OP LAB' THEN mlv.subsequent_sum_of_util_ruvcode ELSE 0 END) AS NUMERIC), 2) AS opl_ruvcode_util,

        SUM(CASE WHEN mlv.subsequent_loatype = 'INPATIENT' THEN mlv.subsequent_count_of_ruvcode ELSE 0 END) AS inp_ruvcode_coc,
        ROUND(CAST(SUM(CASE WHEN mlv.subsequent_loatype = 'INPATIENT' THEN mlv.subsequent_sum_of_util_ruvcode ELSE 0 END) AS NUMERIC), 2) AS inp_ruvcode_util,

        SUM(CASE WHEN mlv.subsequent_loatype = 'EMERGENCY' THEN mlv.subsequent_count_of_ruvcode ELSE 0 END) AS emg_ruvcode_coc,
        ROUND(CAST(SUM(CASE WHEN mlv.subsequent_loatype = 'EMERGENCY' THEN mlv.subsequent_sum_of_util_ruvcode ELSE 0 END) AS NUMERIC), 2) AS emg_ruvcode_util,

        CASE 
            WHEN MAX(CASE WHEN mlv.subsequent_primaryicdcode IN (SELECT primaryicdcode FROM {{ref('end_stage_cardiometabolic_primaryicdcodes')}}) OR mlv.starting_primaryicdcode IN (SELECT primaryicdcode FROM {{ref('end_stage_cardiometabolic_primaryicdcodes')}}) THEN 1 ELSE 0 END) = 1 
            THEN 'End-Stage Cardiometabolic Disease Patient'

            WHEN MAX(CASE WHEN mlv.subsequent_primaryicdcode IN (SELECT primaryicdcode FROM {{ref('end_stage_cardiometabolic_primaryicdcodes')}}) OR mlv.starting_primaryicdcode IN (SELECT primaryicdcode FROM {{ref('end_stage_cardiometabolic_primaryicdcodes')}}) THEN 1 ELSE 0 END) = 0 
                AND MIN(mlv.starting_primaryicdgroup) = 'ESSENTIAL (PRIMARY) HYPERTENSION' 
            THEN 'Essential (Primary) Hypertension Patient Only'

            WHEN MAX(CASE WHEN mlv.subsequent_primaryicdcode IN (SELECT primaryicdcode FROM {{ref('end_stage_cardiometabolic_primaryicdcodes')}}) OR mlv.starting_primaryicdcode IN (SELECT primaryicdcode FROM {{ref('end_stage_cardiometabolic_primaryicdcodes')}}) THEN 1 ELSE 0 END) = 0 
                AND MIN(mlv.combined_starting_primaryicdgroup) = 'DIABETES MELLITUS' 
            THEN 'Diabetes Mellitus Patient Only'

            WHEN MAX(CASE WHEN mlv.subsequent_primaryicdcode IN (SELECT primaryicdcode FROM {{ref('end_stage_cardiometabolic_primaryicdcodes')}}) OR mlv.starting_primaryicdcode IN (SELECT primaryicdcode FROM {{ref('end_stage_cardiometabolic_primaryicdcodes')}}) THEN 1 ELSE 0 END) = 0 
                AND MIN(mlv.starting_primaryicdgroup) = 'DISORDERS OF LIPOPROTEIN METABOLISM AND OTHER LIPIDAEMIAS' 
            THEN 'Dyslipidaemia Patient Only'
            ELSE 'Invalid'
        END AS patient_journey_category

    FROM {{ ref('mlv') }}
    GROUP BY mlv.maskedcardno
)
SELECT 
    p.*
    ,COALESCE(l.total_lengthofstay, 0) AS total_lengthofstay
    ,COALESCE(r.count_of_rapid_readmissions, 0) AS count_of_rapid_readmissions
    ,COALESCE(r.count_of_unique_inpatient_stays, 0) AS count_of_unique_inpatient_stays
    ,COALESCE(r.count_of_rapid_cardiometabolic_readmissions, 0) AS count_of_rapid_cardiometabolic_readmissions
    ,COALESCE(r.count_of_unique_cardiometabolic_inpatient_stays, 0) AS count_of_unique_cardiometabolic_inpatient_stays
    ,COALESCE(e.count_of_non_panic_visits, 0) AS count_of_non_panic_visits
    ,COALESCE(e.count_of_panic_visits, 0) AS count_of_panic_visits
    ,COALESCE(e.count_of_unique_emergencies, 0) AS count_of_unique_emergencies

FROM patient_engine p
LEFT JOIN los_agg l ON p.maskedcardno = l.maskedcardno
LEFT JOIN readmission_agg r ON p.maskedcardno = r.maskedcardno
LEFT JOIN er_agg e ON p.maskedcardno = e.maskedcardno
