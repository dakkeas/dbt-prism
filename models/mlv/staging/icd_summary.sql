
{{ config(materialized = 'table') }}



SELECT
    combined_starting_primaryicdgroup
    ,sum(subsequent_approved) as total_util
    ,avg(subsequent_approved) as avg_util
    ,count(distinct maskedcardno) as total_patients
    ,count(distinct subsequent_claimno) as total_claims
    ,CAST(count(distinct subsequent_claimno) AS NUMERIC) / NULLIF(count(distinct maskedcardno), 0) as avg_claims_per_patient

    -- claims breakdown in total
    ,COALESCE(count(distinct case when subsequent_loatype = 'OP LAB' then subsequent_claimno end), 0) as total_op_lab_claims
    ,COALESCE(count(distinct case when subsequent_loatype = 'OP_CONSULT' then subsequent_claimno end), 0) as total_op_consult_claims
    ,COALESCE(count(distinct case when subsequent_loatype = 'INPATIENT' then subsequent_claimno end), 0) as total_inpatient_claims
    ,COALESCE(count(distinct case when subsequent_loatype = 'EMERGENCY' then subsequent_claimno end), 0) as total_emergency_claims
    ,COALESCE(count(distinct case when subsequent_loatype = 'ACU' then subsequent_claimno end), 0) as total_acu_claims
    ,COALESCE(count(distinct case when subsequent_loatype = 'DENTAL' then subsequent_claimno end), 0) as total_dental_claims

    -- claims breakdown in avg count per patient
    ,COALESCE(CAST(count(distinct case when subsequent_loatype = 'OP_CONSULT' then subsequent_claimno end) AS NUMERIC) / NULLIF(count(distinct maskedcardno), 0), 0) as avg_op_consult_claims_per_patient
    ,COALESCE(CAST(count(distinct case when subsequent_loatype = 'OP LAB' then subsequent_claimno end) AS NUMERIC) / NULLIF(count(distinct maskedcardno), 0), 0) as avg_op_lab_claims_per_patient
    ,COALESCE(CAST(count(distinct case when subsequent_loatype = 'INPATIENT' then subsequent_claimno end) AS NUMERIC) / NULLIF(count(distinct maskedcardno), 0), 0) as avg_inpatient_claims_per_patient
    ,COALESCE(CAST(count(distinct case when subsequent_loatype = 'EMERGENCY' then subsequent_claimno end) AS NUMERIC) / NULLIF(count(distinct maskedcardno), 0), 0) as avg_emergency_claims_per_patient
    ,COALESCE(CAST(count(distinct case when subsequent_loatype = 'ACU' then subsequent_claimno end) AS NUMERIC) / NULLIF(count(distinct maskedcardno), 0), 0) as avg_acu_claims_per_patient
    ,COALESCE(CAST(count(distinct case when subsequent_loatype = 'DENTAL' then subsequent_claimno end) AS NUMERIC) / NULLIF(count(distinct maskedcardno), 0), 0) as avg_dental_claims_per_patient

    -- util breakdown in total
    ,COALESCE(sum(case when subsequent_loatype = 'OP LAB' then subsequent_approved end), 0) as total_op_lab_util
    ,COALESCE(sum(case when subsequent_loatype = 'OP_CONSULT' then subsequent_approved end), 0) as total_op_consult_util
    ,COALESCE(sum(case when subsequent_loatype = 'INPATIENT' then subsequent_approved end), 0) as total_inpatient_util
    ,COALESCE(sum(case when subsequent_loatype = 'EMERGENCY' then subsequent_approved end), 0) as total_emergency_util
    ,COALESCE(sum(case when subsequent_loatype = 'ACU' then subsequent_approved end), 0) as total_acu_util
    ,COALESCE(sum(case when subsequent_loatype = 'DENTAL' then subsequent_approved end), 0) as total_dental_util

    -- util breakdown in avg util per patient
    ,COALESCE(CAST(sum(case when subsequent_loatype = 'OP_CONSULT' then subsequent_approved end) AS NUMERIC) / NULLIF(count(distinct maskedcardno), 0), 0) as avg_op_consult_util_per_patient
    ,COALESCE(CAST(sum(case when subsequent_loatype = 'OP LAB' then subsequent_approved end) AS NUMERIC) / NULLIF(count(distinct maskedcardno), 0), 0) as avg_op_lab_util_per_patient
    ,COALESCE(CAST(sum(case when subsequent_loatype = 'INPATIENT' then subsequent_approved end) AS NUMERIC) / NULLIF(count(distinct maskedcardno), 0), 0) as avg_inpatient_util_per_patient
    ,COALESCE(CAST(sum(case when subsequent_loatype = 'EMERGENCY' then subsequent_approved end) AS NUMERIC) / NULLIF(count(distinct maskedcardno), 0), 0) as avg_emergency_util_per_patient
    ,COALESCE(CAST(sum(case when subsequent_loatype = 'ACU' then subsequent_approved end) AS NUMERIC) / NULLIF(count(distinct maskedcardno), 0), 0) as avg_acu_util_per_patient
    ,COALESCE(CAST(sum(case when subsequent_loatype = 'DENTAL' then subsequent_approved end) AS NUMERIC) / NULLIF(count(distinct maskedcardno), 0), 0) as avg_dental_util_per_patient

FROM {{ ref('mlv') }}
GROUP BY 1
ORDER BY total_util desc, total_patients desc




