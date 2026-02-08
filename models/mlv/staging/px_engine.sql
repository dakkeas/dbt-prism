{{config(materialized = 'view')}}

WITH patient_engine AS (
    SELECT
        maskedcardno,
        MIN(bl_cardno) as bl_cardno,
        MIN(starting_providername) AS starting_providername,
        MIN(starting_physiciancode) AS starting_physiciancode,
        MIN(starting_primaryicdgroup) AS starting_primaryicdgroup,
        
        COUNT(DISTINCT subsequent_claimno) AS overall_count_of_claims,
        SUM(subsequent_approved) AS overall_util,
        
        -- OP LAB
        COUNT(DISTINCT CASE WHEN subsequent_loatype='OP LAB' THEN subsequent_claimno END) AS opl_coc,
        ROUND(CAST(SUM(CASE WHEN subsequent_loatype='OP LAB' THEN subsequent_approved ELSE 0 END) AS NUMERIC), 2) AS opl_util,
        
        -- INPATIENT
        COUNT(DISTINCT CASE WHEN subsequent_loatype='INPATIENT' THEN subsequent_claimno END) AS inp_coc,
        ROUND(CAST(SUM(CASE WHEN subsequent_loatype='INPATIENT' THEN subsequent_approved ELSE 0 END) AS NUMERIC), 2) AS inp_util,
        
        -- OTHERS
        COUNT(DISTINCT CASE WHEN subsequent_loatype IN ('EMERGENCY','OP_CONSULT','ACU') THEN subsequent_claimno END) AS others_coc,
        ROUND(CAST(SUM(CASE WHEN subsequent_loatype IN ('EMERGENCY','OP_CONSULT','ACU') THEN subsequent_approved ELSE 0 END) AS NUMERIC), 2) AS others_util,
        
        SUM(subsequent_philhealth) AS sum_philhealth,
        COUNT(DISTINCT CASE WHEN subsequent_philhealth > 0 THEN subsequent_claimno END) as philhealth_claim_count

    FROM {{ref('mlv')}}
    GROUP BY maskedcardno
)
SELECT * FROM patient_engine