
{{ config(materialized='table') }}

WITH unique_admissions AS (
    -- CONTEXT: There can be different claim numbers with the same admissiondate yet have different dischargedates
    -- each of these claims may have different lengthofstays thus baloooning the los count. This only grabs the greatest lengthofstay
    SELECT
        maskedcardno,
        subsequent_admissiondate,
        MAX(subsequent_loatype) AS subsequent_loatype,
        MAX(subsequent_lengthofstay) AS max_lengthofstay,
        MAX(days_to_readmit) AS days_to_readmit,
        MAX(next_stay_is_cardio_metabolic) AS next_stay_is_cardio_metabolic

    FROM {{ ref('mlv') }}
    WHERE subsequent_loatype = 'INPATIENT'
    GROUP BY maskedcardno, subsequent_admissiondate
),
los_agg AS (
    SELECT 
        -- sums only the max lengthofstay per unique admissiondates
        maskedcardno,
        SUM(max_lengthofstay) AS total_lengthofstay
    FROM unique_admissions
    GROUP BY maskedcardno
),
patient_engine AS 
    SELECT
        mlv.maskedcardno,
        MIN(mlv.bl_cardno) AS bl_cardno,
        MIN(mlv.starting_providername) AS starting_providername,
        MIN(mlv.starting_physiciancode) AS starting_physiciancode,
        MIN(mlv.starting_primaryicdgroup) AS starting_primaryicdgroup,
        MIN(mlv.combined_starting_primaryicdgroup) AS combined_starting_primaryicdgroup,
        
        COUNT(DISTINCT mlv.subsequent_claimno) AS overall_count_of_claims,
        SUM(mlv.subsequent_approved) AS overall_util,
        MAX(l.total_lengthofstay) AS total_lengthofstay, -- sums only the max lengthofstay per admissiondate

        -- readmission rates
        SUM(CASE 
            WHEN ua.subsequent_loatype = 'INPATIENT' AND l.days_to_readmit <= 30 THEN 1 ELSE 0
            END
        ) AS count_of_rapid_readmissions,


        

        SUM(CASE 
            WHEN ua.subsequent_loatype = 'INPATIENT' AND
             ua.days_to_readmit <= 30 AND 
             ua.days_to_readmit IS NOT NULL AND
             ua.next_stay_is_cardio_metabolic = 1 THEN 1 ELSE 0
            END
        ) AS count_of_rapid_cardiometabolic_readmissions,

        -- panic logic



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
        CAST(SUM(ABS(mlv.subsequent_philhealth))) AS NUMERIC / CAST(SUM(mlv.subsequent_approved) AS NUMERIC) AS percent_of_philhealth_util,
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
            WHEN MAX(CASE WHEN mlv.subsequent_primaryicdgroup IN 
                (SELECT primaryicdcode FROM {{ref('end_stage_cardiometabolic_primaryicdcodes')}}) THEN 1 ELSE 0 END) = 1 
            THEN 'End-Stage Cardiometabolic Disease Patient'

            WHEN MAX(CASE WHEN mlv.subsequent_primaryicdgroup IN 
                (SELECT primaryicdcode FROM {{ref('end_stage_cardiometabolic_primaryicdcodes')}}) THEN 1 ELSE 0 END) = 0 
                AND MIN(mlv.starting_primaryicdgroup) = 'ESSENTIAL (PRIMARY) HYPERTENSION' 
            THEN 'Essential (Primary) Hypertension Patient Only'

            WHEN MAX(CASE WHEN mlv.subsequent_primaryicdgroup IN 
                (SELECT primaryicdcode FROM {{ref('end_stage_cardiometabolic_primaryicdcodes')}}) THEN 1 ELSE 0 END) = 0 
                AND MIN(mlv.combined_starting_primaryicdgroup) = 'DIABETES MELLITUS' 
            THEN 'Diabetes Mellitus Patient Only'

            WHEN MAX(CASE WHEN mlv.subsequent_primaryicdgroup IN 
                (SELECT primaryicdcode FROM {{ref('end_stage_cardiometabolic_primaryicdcodes')}}) THEN 1 ELSE 0 END) = 0 
                AND MIN(mlv.starting_primaryicdgroup) = 'DISORDERS OF LIPOPROTEIN METABOLISM AND OTHER LIPIDAEMIAS' 
            THEN 'Dyslipidaemia Patient Only'
            ELSE 'Invalid'
        END AS patient_journey_category
    FROM {{ ref('mlv') }}
    LEFT JOIN los_agg l ON mlv.maskedcardno = l.maskedcardno
    LEFT JOIN unique_admissions ua ON mlv.maskedcardno = ua.maskedcardno AND mlv.subsequent_admissiondate = ua.subsequent_admissiondate
    GROUP BY mlv.maskedcardno


SELECT * FROM patient_engine
