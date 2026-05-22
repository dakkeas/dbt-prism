{{ config(materialized = 'table') }}

SELECT
    combined_starting_primaryicdgroup
    ,sum(subsequent_approved) as total_util
    ,avg(subsequent_approved) as avg_util
    ,count(distinct maskedcardno) as total_patients
    ,count(distinct subsequent_claimno) as total_claims
    ,CAST(count(distinct subsequent_claimno) AS NUMERIC) / NULLIF(count(distinct maskedcardno), 0) as avg_claims_per_patient

    -- claims breakdown in total
    ,COALESCE(count(distinct case when subsequent_loatype = 'ACU' then subsequent_claimno end), 0) as total_acu_claims
    ,COALESCE(count(distinct case when subsequent_loatype = 'CONSULT' then subsequent_claimno end), 0) as total_consult_claims
    ,COALESCE(count(distinct case when subsequent_loatype = 'Corporate Clinic' then subsequent_claimno end), 0) as total_corporate_clinic_claims
    ,COALESCE(count(distinct case when subsequent_loatype = 'DENTAL' then subsequent_claimno end), 0) as total_dental_claims
    ,COALESCE(count(distinct case when subsequent_loatype = 'EMERGENCY' then subsequent_claimno end), 0) as total_emergency_claims
    ,COALESCE(count(distinct case when subsequent_loatype = 'INPATIENT' then subsequent_claimno end), 0) as total_inpatient_claims
    ,COALESCE(count(distinct case when subsequent_loatype = 'Medgrocer' then subsequent_claimno end), 0) as total_medgrocer_claims
    ,COALESCE(count(distinct case when subsequent_loatype = 'PROCEDURE' then subsequent_claimno end), 0) as total_procedure_claims
    ,COALESCE(count(distinct case when subsequent_loatype = 'VIDEO CALL' then subsequent_claimno end), 0) as total_video_call_claims
    ,COALESCE(count(distinct case when subsequent_loatype = 'VOICE CALL' then subsequent_claimno end), 0) as total_voice_call_claims
    ,COALESCE(count(distinct case when subsequent_loatype = 'Zennya (Home Care)' then subsequent_claimno end), 0) as total_zennya_home_care_claims

    -- claims breakdown in avg count per patient
    ,COALESCE(CAST(count(distinct case when subsequent_loatype = 'ACU' then subsequent_claimno end) AS NUMERIC) / NULLIF(count(distinct maskedcardno), 0), 0) as avg_acu_claims_per_patient
    ,COALESCE(CAST(count(distinct case when subsequent_loatype = 'CONSULT' then subsequent_claimno end) AS NUMERIC) / NULLIF(count(distinct maskedcardno), 0), 0) as avg_consult_claims_per_patient
    ,COALESCE(CAST(count(distinct case when subsequent_loatype = 'Corporate Clinic' then subsequent_claimno end) AS NUMERIC) / NULLIF(count(distinct maskedcardno), 0), 0) as avg_corporate_clinic_claims_per_patient
    ,COALESCE(CAST(count(distinct case when subsequent_loatype = 'DENTAL' then subsequent_claimno end) AS NUMERIC) / NULLIF(count(distinct maskedcardno), 0), 0) as avg_dental_claims_per_patient
    ,COALESCE(CAST(count(distinct case when subsequent_loatype = 'EMERGENCY' then subsequent_claimno end) AS NUMERIC) / NULLIF(count(distinct maskedcardno), 0), 0) as avg_emergency_claims_per_patient
    ,COALESCE(CAST(count(distinct case when subsequent_loatype = 'INPATIENT' then subsequent_claimno end) AS NUMERIC) / NULLIF(count(distinct maskedcardno), 0), 0) as avg_inpatient_claims_per_patient
    ,COALESCE(CAST(count(distinct case when subsequent_loatype = 'Medgrocer' then subsequent_claimno end) AS NUMERIC) / NULLIF(count(distinct maskedcardno), 0), 0) as avg_medgrocer_claims_per_patient
    ,COALESCE(CAST(count(distinct case when subsequent_loatype = 'PROCEDURE' then subsequent_claimno end) AS NUMERIC) / NULLIF(count(distinct maskedcardno), 0), 0) as avg_procedure_claims_per_patient
    ,COALESCE(CAST(count(distinct case when subsequent_loatype = 'VIDEO CALL' then subsequent_claimno end) AS NUMERIC) / NULLIF(count(distinct maskedcardno), 0), 0) as avg_video_call_claims_per_patient
    ,COALESCE(CAST(count(distinct case when subsequent_loatype = 'VOICE CALL' then subsequent_claimno end) AS NUMERIC) / NULLIF(count(distinct maskedcardno), 0), 0) as avg_voice_call_claims_per_patient
    ,COALESCE(CAST(count(distinct case when subsequent_loatype = 'Zennya (Home Care)' then subsequent_claimno end) AS NUMERIC) / NULLIF(count(distinct maskedcardno), 0), 0) as avg_zennya_home_care_claims_per_patient

    -- util breakdown in total
    ,COALESCE(sum(case when subsequent_loatype = 'ACU' then subsequent_approved end), 0) as total_acu_util
    ,COALESCE(sum(case when subsequent_loatype = 'CONSULT' then subsequent_approved end), 0) as total_consult_util
    ,COALESCE(sum(case when subsequent_loatype = 'Corporate Clinic' then subsequent_approved end), 0) as total_corporate_clinic_util
    ,COALESCE(sum(case when subsequent_loatype = 'DENTAL' then subsequent_approved end), 0) as total_dental_util
    ,COALESCE(sum(case when subsequent_loatype = 'EMERGENCY' then subsequent_approved end), 0) as total_emergency_util
    ,COALESCE(sum(case when subsequent_loatype = 'INPATIENT' then subsequent_approved end), 0) as total_inpatient_util
    ,COALESCE(sum(case when subsequent_loatype = 'Medgrocer' then subsequent_approved end), 0) as total_medgrocer_util
    ,COALESCE(sum(case when subsequent_loatype = 'PROCEDURE' then subsequent_approved end), 0) as total_procedure_util
    ,COALESCE(sum(case when subsequent_loatype = 'VIDEO CALL' then subsequent_approved end), 0) as total_video_call_util
    ,COALESCE(sum(case when subsequent_loatype = 'VOICE CALL' then subsequent_approved end), 0) as total_voice_call_util
    ,COALESCE(sum(case when subsequent_loatype = 'Zennya (Home Care)' then subsequent_approved end), 0) as total_zennya_home_care_util

    -- util breakdown in avg util per patient
    ,COALESCE(CAST(sum(case when subsequent_loatype = 'ACU' then subsequent_approved end) AS NUMERIC) / NULLIF(count(distinct maskedcardno), 0), 0) as avg_acu_util_per_patient
    ,COALESCE(CAST(sum(case when subsequent_loatype = 'CONSULT' then subsequent_approved end) AS NUMERIC) / NULLIF(count(distinct maskedcardno), 0), 0) as avg_consult_util_per_patient
    ,COALESCE(CAST(sum(case when subsequent_loatype = 'Corporate Clinic' then subsequent_approved end) AS NUMERIC) / NULLIF(count(distinct maskedcardno), 0), 0) as avg_corporate_clinic_util_per_patient
    ,COALESCE(CAST(sum(case when subsequent_loatype = 'DENTAL' then subsequent_approved end) AS NUMERIC) / NULLIF(count(distinct maskedcardno), 0), 0) as avg_dental_util_per_patient
    ,COALESCE(CAST(sum(case when subsequent_loatype = 'EMERGENCY' then subsequent_approved end) AS NUMERIC) / NULLIF(count(distinct maskedcardno), 0), 0) as avg_emergency_util_per_patient
    ,COALESCE(CAST(sum(case when subsequent_loatype = 'INPATIENT' then subsequent_approved end) AS NUMERIC) / NULLIF(count(distinct maskedcardno), 0), 0) as avg_inpatient_util_per_patient
    ,COALESCE(CAST(sum(case when subsequent_loatype = 'Medgrocer' then subsequent_approved end) AS NUMERIC) / NULLIF(count(distinct maskedcardno), 0), 0) as avg_medgrocer_util_per_patient
    ,COALESCE(CAST(sum(case when subsequent_loatype = 'PROCEDURE' then subsequent_approved end) AS NUMERIC) / NULLIF(count(distinct maskedcardno), 0), 0) as avg_procedure_util_per_patient
    ,COALESCE(CAST(sum(case when subsequent_loatype = 'VIDEO CALL' then subsequent_approved end) AS NUMERIC) / NULLIF(count(distinct maskedcardno), 0), 0) as avg_video_call_util_per_patient
    ,COALESCE(CAST(sum(case when subsequent_loatype = 'VOICE CALL' then subsequent_approved end) AS NUMERIC) / NULLIF(count(distinct maskedcardno), 0), 0) as avg_voice_call_util_per_patient
    ,COALESCE(CAST(sum(case when subsequent_loatype = 'Zennya (Home Care)' then subsequent_approved end) AS NUMERIC) / NULLIF(count(distinct maskedcardno), 0), 0) as avg_zennya_home_care_util_per_patient

FROM {{ ref('mlv_acn_masked') }}
GROUP BY 1
ORDER BY total_util desc, total_patients desc
