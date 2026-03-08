
{{ config(materialized='table') }}

WITH patient_engine AS (
    SELECT
        maskedcardno,
        MIN(bl_cardno) AS bl_cardno,
        MIN(starting_providername) AS starting_providername,
        MIN(starting_physiciancode) AS starting_physiciancode,
        MIN(starting_primaryicdgroup) AS starting_primaryicdgroup,
        MIN(grouped_starting_primaryicdgroup) AS grouped_starting_primaryicdgroup,
        
        COUNT(DISTINCT subsequent_claimno) AS overall_count_of_claims,
        SUM(subsequent_approved) AS overall_util,

        -- OP LAB
        COUNT(DISTINCT CASE WHEN subsequent_loatype = 'OP LAB' THEN subsequent_claimno END) AS opl_coc,
        ROUND(CAST(SUM(CASE WHEN subsequent_loatype = 'OP LAB' THEN subsequent_approved ELSE 0 END) AS NUMERIC), 2) AS opl_util,

        -- INPATIENT
        COUNT(DISTINCT CASE WHEN subsequent_loatype = 'INPATIENT' THEN subsequent_claimno END) AS inp_coc,
        ROUND(CAST(SUM(CASE WHEN subsequent_loatype = 'INPATIENT' THEN subsequent_approved ELSE 0 END) AS NUMERIC), 2) AS inp_util,

        -- OTHERS
        COUNT(DISTINCT CASE WHEN subsequent_loatype IN ('EMERGENCY','OP_CONSULT','ACU') THEN subsequent_claimno END) AS others_coc,
        ROUND(CAST(SUM(CASE WHEN subsequent_loatype IN ('EMERGENCY','OP_CONSULT','ACU') THEN subsequent_approved ELSE 0 END) AS NUMERIC), 2) AS others_util,

        -- PhilHealth
        SUM(ABS(subsequent_philhealth)) AS sum_philhealth,
        COUNT(DISTINCT CASE WHEN subsequent_philhealth > 0 THEN subsequent_claimno END) AS philhealth_claim_count,

        -- CPT Code
        SUM(subsequent_count_of_cptcode) AS overall_cptcode_coc,
        ROUND(CAST(SUM(subsequent_sum_of_util_cptcode) AS NUMERIC), 2) AS overall_cptcode_util,

        SUM(CASE WHEN subsequent_loatype = 'OP LAB' THEN subsequent_count_of_cptcode ELSE 0 END) AS opl_cptcode_coc,
        ROUND(CAST(SUM(CASE WHEN subsequent_loatype = 'OP LAB' THEN subsequent_sum_of_util_cptcode ELSE 0 END) AS NUMERIC), 2) AS opl_cptcode_util,

        SUM(CASE WHEN subsequent_loatype = 'INPATIENT' THEN subsequent_count_of_cptcode ELSE 0 END) AS inp_cptcode_coc,
        ROUND(CAST(SUM(CASE WHEN subsequent_loatype = 'INPATIENT' THEN subsequent_sum_of_util_cptcode ELSE 0 END) AS NUMERIC), 2) AS inp_cptcode_util,

        SUM(CASE WHEN subsequent_loatype = 'EMERGENCY' THEN subsequent_count_of_cptcode ELSE 0 END) AS emg_cptcode_coc,
        ROUND(CAST(SUM(CASE WHEN subsequent_loatype = 'EMERGENCY' THEN subsequent_sum_of_util_cptcode ELSE 0 END) AS NUMERIC), 2) AS emg_cptcode_util,

        -- RUV Code
        SUM(subsequent_count_of_ruvcode) AS overall_ruvcode_coc,
        ROUND(CAST(SUM(subsequent_sum_of_util_ruvcode) AS NUMERIC), 2) AS overall_ruvcode_util,

        SUM(CASE WHEN subsequent_loatype = 'OP LAB' THEN subsequent_count_of_ruvcode ELSE 0 END) AS opl_ruvcode_coc,
        ROUND(CAST(SUM(CASE WHEN subsequent_loatype = 'OP LAB' THEN subsequent_sum_of_util_ruvcode ELSE 0 END) AS NUMERIC), 2) AS opl_ruvcode_util,

        SUM(CASE WHEN subsequent_loatype = 'INPATIENT' THEN subsequent_count_of_ruvcode ELSE 0 END) AS inp_ruvcode_coc,
        ROUND(CAST(SUM(CASE WHEN subsequent_loatype = 'INPATIENT' THEN subsequent_sum_of_util_ruvcode ELSE 0 END) AS NUMERIC), 2) AS inp_ruvcode_util,

        SUM(CASE WHEN subsequent_loatype = 'EMERGENCY' THEN subsequent_count_of_ruvcode ELSE 0 END) AS emg_ruvcode_coc,
        ROUND(CAST(SUM(CASE WHEN subsequent_loatype = 'EMERGENCY' THEN subsequent_sum_of_util_ruvcode ELSE 0 END) AS NUMERIC), 2) AS emg_ruvcode_util,

        CASE 
            WHEN MAX(CASE WHEN subsequent_primaryicdgroup IN 
                ('CHRONIC ISCHAEMIC HEART DISEASE', 
                'HYPERTENSIVE HEART DISEASE', 
                'HEART FAILURE', 
                'CHRONIC RENAL FAILURE') THEN 1 ELSE 0 END) = 1 
            THEN 'End-Stage Disease Patient'

            WHEN MAX(CASE WHEN subsequent_primaryicdgroup IN 
                ('CHRONIC ISCHAEMIC HEART DISEASE', 
                'HYPERTENSIVE HEART DISEASE', 
                'HEART FAILURE', 
                'CHRONIC RENAL FAILURE') THEN 1 ELSE 0 END) = 0 
                AND MIN(starting_primaryicdgroup) = 'ESSENTIAL (PRIMARY) HYPERTENSION' 
            THEN 'Hypertension Patient Only'

            WHEN MAX(CASE WHEN subsequent_primaryicdgroup IN 
                ('CHRONIC ISCHAEMIC HEART DISEASE', 
                'HYPERTENSIVE HEART DISEASE', 
                'HEART FAILURE', 
                'CHRONIC RENAL FAILURE') THEN 1 ELSE 0 END) = 0 
                AND MIN(grouped_starting_primaryicdgroup) = 'DIABETES' 
            THEN 'Diabetes Patient Only'

            WHEN MAX(CASE WHEN subsequent_primaryicdgroup IN 
                ('CHRONIC ISCHAEMIC HEART DISEASE', 
                'HYPERTENSIVE HEART DISEASE', 
                'HEART FAILURE', 
                'CHRONIC RENAL FAILURE') THEN 1 ELSE 0 END) = 0 
                AND MIN(starting_primaryicdgroup) = 'DISORDERS OF LIPOPROTEIN METABOLISM AND OTHER LIPIDAEMIAS' 
            THEN 'Lipidaemias Patient Only'
        END AS patient_journey_category




    FROM {{ ref('mlv') }}
    GROUP BY maskedcardno
)

SELECT * FROM patient_engine
