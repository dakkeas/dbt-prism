
{{config(materialized = 'view')}}

WITH patient_engine AS (
    SELECT
        maskedcardno,
        MIN(bl_cardno),
        MIN(starting_providername) AS starting_providername,
        MIN(starting_physiciancode) AS starting_physiciancode,
        
        -- ALL LOA TYPES
        COUNT(DISTINCT subsequent_claimno) AS overall_count_of_claims, -- total count of claim numbers
        SUM(subsequent_approved) AS overall_util, -- total utilization
        
        -- OP LAB COUNTS & UTIL
        COUNT(DISTINCT CASE WHEN subsequent_loatype='OP LAB' THEN subsequent_claimno END) AS opl_coc, -- total count of op lab claims
        ROUND(SUM(CASE WHEN subsequent_loatype='OP LAB' THEN subsequent_approved ELSE 0 END)::numeric, 2) AS opl_util, -- total util of op lab claims
        
        -- INPATIENT COUNTS & UTIL
        COUNT(DISTINCT CASE WHEN subsequent_loatype='INPATIENT' THEN subsequent_claimno END) AS inp_coc, -- total count of inpatient claims
        ROUND(SUM(CASE WHEN subsequent_loatype='INPATIENT' THEN subsequent_approved ELSE 0 END)::numeric, 2) AS inp_util, -- total util of inpatient claims
        
        -- OTHERS (EMERGENCY/OP_CONSULT/ACU) COUNTS & UTIL
        COUNT(DISTINCT CASE WHEN subsequent_loatype IN ('EMERGENCY','OP_CONSULT','ACU') THEN subsequent_claimno END) AS others_coc, -- total count of 'others' claims
        ROUND(SUM(CASE WHEN subsequent_loatype IN ('EMERGENCY','OP_CONSULT','ACU') THEN subsequent_approved ELSE 0 END)::numeric, 2) AS others_util, -- total util of 'others' claims
        
        -- PHILHEALTH
        SUM(subsequent_philhealth) AS sum_philhealth, -- total philhealth claim from patient
        COUNT(DISTINCT CASE WHEN subsequent_philhealth > 0 THEN subsequent_claimno END) as philhealth_claim_count -- count of claims with philhealth

    FROM {{ref('combined')}}
    WHERE starting_primaryicdgroup = 'ESSENTIAL (PRIMARY) HYPERTENSION' -- just eph patients
    GROUP BY maskedcardno
)
SELECT * FROM patient_engine