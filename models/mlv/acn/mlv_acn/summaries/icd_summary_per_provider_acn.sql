{{ config(materialized = 'table') }}

SELECT
    m.combined_starting_primaryicdgroup
    ,m.starting_providername
    ,sum(m.subsequent_approved) as total_util
    ,CAST(sum(m.subsequent_approved) AS NUMERIC) / MAX(s.total_util) as percent_of_total_util
    ,avg(m.subsequent_approved) as avg_util
    ,count(distinct m.maskedcardno) as total_patients
    ,CAST(count(distinct m.maskedcardno) AS NUMERIC) / MAX(s.total_patients) as percent_of_total_patients
    ,count(distinct m.subsequent_claimno) as total_claims
    ,CAST(count(distinct m.subsequent_claimno) AS NUMERIC) / MAX(s.total_claims) as percent_of_total_claims

    ,CAST(count(distinct m.subsequent_claimno) AS NUMERIC) / NULLIF(count(distinct m.maskedcardno), 0) as avg_claims_per_patient

    -- claims breakdown in total
    ,COALESCE(count(distinct case when m.subsequent_loatype = 'ACU' then m.subsequent_claimno end), 0) as total_acu_claims
    ,CAST(COALESCE(count(distinct case when m.subsequent_loatype = 'ACU' then m.subsequent_claimno end), 0) AS NUMERIC) / NULLIF(count(distinct m.subsequent_claimno), 0) as percent_of_total_acu_claims
    ,COALESCE(count(distinct case when m.subsequent_loatype = 'CONSULT' then m.subsequent_claimno end), 0) as total_consult_claims
    ,CAST(COALESCE(count(distinct case when m.subsequent_loatype = 'CONSULT' then m.subsequent_claimno end), 0) AS NUMERIC) / NULLIF(count(distinct m.subsequent_claimno), 0) as percent_of_total_consult_claims
    ,COALESCE(count(distinct case when m.subsequent_loatype = 'Corporate Clinic' then m.subsequent_claimno end), 0) as total_corporate_clinic_claims
    ,CAST(COALESCE(count(distinct case when m.subsequent_loatype = 'Corporate Clinic' then m.subsequent_claimno end), 0) AS NUMERIC) / NULLIF(count(distinct m.subsequent_claimno), 0) as percent_of_total_corporate_clinic_claims
    ,COALESCE(count(distinct case when m.subsequent_loatype = 'DENTAL' then m.subsequent_claimno end), 0) as total_dental_claims
    ,CAST(COALESCE(count(distinct case when m.subsequent_loatype = 'DENTAL' then m.subsequent_claimno end), 0) AS NUMERIC) / NULLIF(count(distinct m.subsequent_claimno), 0) as percent_of_total_dental_claims
    ,COALESCE(count(distinct case when m.subsequent_loatype = 'EMERGENCY' then m.subsequent_claimno end), 0) as total_emergency_claims
    ,CAST(COALESCE(count(distinct case when m.subsequent_loatype = 'EMERGENCY' then m.subsequent_claimno end), 0) AS NUMERIC) / NULLIF(count(distinct m.subsequent_claimno), 0) as percent_of_total_emergency_claims
    ,COALESCE(count(distinct case when m.subsequent_loatype = 'INPATIENT' then m.subsequent_claimno end), 0) as total_inpatient_claims
    ,CAST(COALESCE(count(distinct case when m.subsequent_loatype = 'INPATIENT' then m.subsequent_claimno end), 0) AS NUMERIC) / NULLIF(count(distinct m.subsequent_claimno), 0) as percent_of_total_inpatient_claims
    ,COALESCE(count(distinct case when m.subsequent_loatype = 'Medgrocer' then m.subsequent_claimno end), 0) as total_medgrocer_claims
    ,CAST(COALESCE(count(distinct case when m.subsequent_loatype = 'Medgrocer' then m.subsequent_claimno end), 0) AS NUMERIC) / NULLIF(count(distinct m.subsequent_claimno), 0) as percent_of_total_medgrocer_claims
    ,COALESCE(count(distinct case when m.subsequent_loatype = 'PROCEDURE' then m.subsequent_claimno end), 0) as total_procedure_claims
    ,CAST(COALESCE(count(distinct case when m.subsequent_loatype = 'PROCEDURE' then m.subsequent_claimno end), 0) AS NUMERIC) / NULLIF(count(distinct m.subsequent_claimno), 0) as percent_of_total_procedure_claims
    ,COALESCE(count(distinct case when m.subsequent_loatype = 'VIDEO CALL' then m.subsequent_claimno end), 0) as total_video_call_claims
    ,CAST(COALESCE(count(distinct case when m.subsequent_loatype = 'VIDEO CALL' then m.subsequent_claimno end), 0) AS NUMERIC) / NULLIF(count(distinct m.subsequent_claimno), 0) as percent_of_total_video_call_claims
    ,COALESCE(count(distinct case when m.subsequent_loatype = 'VOICE CALL' then m.subsequent_claimno end), 0) as total_voice_call_claims
    ,CAST(COALESCE(count(distinct case when m.subsequent_loatype = 'VOICE CALL' then m.subsequent_claimno end), 0) AS NUMERIC) / NULLIF(count(distinct m.subsequent_claimno), 0) as percent_of_total_voice_call_claims
    ,COALESCE(count(distinct case when m.subsequent_loatype = 'Zennya (Home Care)' then m.subsequent_claimno end), 0) as total_zennya_home_care_claims
    ,CAST(COALESCE(count(distinct case when m.subsequent_loatype = 'Zennya (Home Care)' then m.subsequent_claimno end), 0) AS NUMERIC) / NULLIF(count(distinct m.subsequent_claimno), 0) as percent_of_total_zennya_home_care_claims

    -- claims breakdown in avg count per patient
    ,COALESCE(CAST(count(distinct case when m.subsequent_loatype = 'ACU' then m.subsequent_claimno end) AS NUMERIC) / NULLIF(count(distinct m.maskedcardno), 0), 0) as avg_acu_claims_per_patient
    ,COALESCE(CAST(count(distinct case when m.subsequent_loatype = 'CONSULT' then m.subsequent_claimno end) AS NUMERIC) / NULLIF(count(distinct m.maskedcardno), 0), 0) as avg_consult_claims_per_patient
    ,COALESCE(CAST(count(distinct case when m.subsequent_loatype = 'Corporate Clinic' then m.subsequent_claimno end) AS NUMERIC) / NULLIF(count(distinct m.maskedcardno), 0), 0) as avg_corporate_clinic_claims_per_patient
    ,COALESCE(CAST(count(distinct case when m.subsequent_loatype = 'DENTAL' then m.subsequent_claimno end) AS NUMERIC) / NULLIF(count(distinct m.maskedcardno), 0), 0) as avg_dental_claims_per_patient
    ,COALESCE(CAST(count(distinct case when m.subsequent_loatype = 'EMERGENCY' then m.subsequent_claimno end) AS NUMERIC) / NULLIF(count(distinct m.maskedcardno), 0), 0) as avg_emergency_claims_per_patient
    ,COALESCE(CAST(count(distinct case when m.subsequent_loatype = 'INPATIENT' then m.subsequent_claimno end) AS NUMERIC) / NULLIF(count(distinct m.maskedcardno), 0), 0) as avg_inpatient_claims_per_patient
    ,COALESCE(CAST(count(distinct case when m.subsequent_loatype = 'Medgrocer' then m.subsequent_claimno end) AS NUMERIC) / NULLIF(count(distinct m.maskedcardno), 0), 0) as avg_medgrocer_claims_per_patient
    ,COALESCE(CAST(count(distinct case when m.subsequent_loatype = 'PROCEDURE' then m.subsequent_claimno end) AS NUMERIC) / NULLIF(count(distinct m.maskedcardno), 0), 0) as avg_procedure_claims_per_patient
    ,COALESCE(CAST(count(distinct case when m.subsequent_loatype = 'VIDEO CALL' then m.subsequent_claimno end) AS NUMERIC) / NULLIF(count(distinct m.maskedcardno), 0), 0) as avg_video_call_claims_per_patient
    ,COALESCE(CAST(count(distinct case when m.subsequent_loatype = 'VOICE CALL' then m.subsequent_claimno end) AS NUMERIC) / NULLIF(count(distinct m.maskedcardno), 0), 0) as avg_voice_call_claims_per_patient
    ,COALESCE(CAST(count(distinct case when m.subsequent_loatype = 'Zennya (Home Care)' then m.subsequent_claimno end) AS NUMERIC) / NULLIF(count(distinct m.maskedcardno), 0), 0) as avg_zennya_home_care_claims_per_patient

    -- util breakdown in total
    ,COALESCE(sum(case when m.subsequent_loatype = 'ACU' then m.subsequent_approved end), 0) as total_acu_util
    ,CAST(COALESCE(sum(case when m.subsequent_loatype = 'ACU' then m.subsequent_approved end), 0) AS NUMERIC) / NULLIF(sum(m.subsequent_approved), 0) as percent_of_total_acu_util
    ,COALESCE(sum(case when m.subsequent_loatype = 'CONSULT' then m.subsequent_approved end), 0) as total_consult_util
    ,CAST(COALESCE(sum(case when m.subsequent_loatype = 'CONSULT' then m.subsequent_approved end), 0) AS NUMERIC) / NULLIF(sum(m.subsequent_approved), 0) as percent_of_total_consult_util
    ,COALESCE(sum(case when m.subsequent_loatype = 'Corporate Clinic' then m.subsequent_approved end), 0) as total_corporate_clinic_util
    ,CAST(COALESCE(sum(case when m.subsequent_loatype = 'Corporate Clinic' then m.subsequent_approved end), 0) AS NUMERIC) / NULLIF(sum(m.subsequent_approved), 0) as percent_of_total_corporate_clinic_util
    ,COALESCE(sum(case when m.subsequent_loatype = 'DENTAL' then m.subsequent_approved end), 0) as total_dental_util
    ,CAST(COALESCE(sum(case when m.subsequent_loatype = 'DENTAL' then m.subsequent_approved end), 0) AS NUMERIC) / NULLIF(sum(m.subsequent_approved), 0) as percent_of_total_dental_util
    ,COALESCE(sum(case when m.subsequent_loatype = 'EMERGENCY' then m.subsequent_approved end), 0) as total_emergency_util
    ,CAST(COALESCE(sum(case when m.subsequent_loatype = 'EMERGENCY' then m.subsequent_approved end), 0) AS NUMERIC) / NULLIF(sum(m.subsequent_approved), 0) as percent_of_total_emergency_util
    ,COALESCE(sum(case when m.subsequent_loatype = 'INPATIENT' then m.subsequent_approved end), 0) as total_inpatient_util
    ,CAST(COALESCE(sum(case when m.subsequent_loatype = 'INPATIENT' then m.subsequent_approved end), 0) AS NUMERIC) / NULLIF(sum(m.subsequent_approved), 0) as percent_of_total_inpatient_util
    ,COALESCE(sum(case when m.subsequent_loatype = 'Medgrocer' then m.subsequent_approved end), 0) as total_medgrocer_util
    ,CAST(COALESCE(sum(case when m.subsequent_loatype = 'Medgrocer' then m.subsequent_approved end), 0) AS NUMERIC) / NULLIF(sum(m.subsequent_approved), 0) as percent_of_total_medgrocer_util
    ,COALESCE(sum(case when m.subsequent_loatype = 'PROCEDURE' then m.subsequent_approved end), 0) as total_procedure_util
    ,CAST(COALESCE(sum(case when m.subsequent_loatype = 'PROCEDURE' then m.subsequent_approved end), 0) AS NUMERIC) / NULLIF(sum(m.subsequent_approved), 0) as percent_of_total_procedure_util
    ,COALESCE(sum(case when m.subsequent_loatype = 'VIDEO CALL' then m.subsequent_approved end), 0) as total_video_call_util
    ,CAST(COALESCE(sum(case when m.subsequent_loatype = 'VIDEO CALL' then m.subsequent_approved end), 0) AS NUMERIC) / NULLIF(sum(m.subsequent_approved), 0) as percent_of_total_video_call_util
    ,COALESCE(sum(case when m.subsequent_loatype = 'VOICE CALL' then m.subsequent_approved end), 0) as total_voice_call_util
    ,CAST(COALESCE(sum(case when m.subsequent_loatype = 'VOICE CALL' then m.subsequent_approved end), 0) AS NUMERIC) / NULLIF(sum(m.subsequent_approved), 0) as percent_of_total_voice_call_util
    ,COALESCE(sum(case when m.subsequent_loatype = 'Zennya (Home Care)' then m.subsequent_approved end), 0) as total_zennya_home_care_util
    ,CAST(COALESCE(sum(case when m.subsequent_loatype = 'Zennya (Home Care)' then m.subsequent_approved end), 0) AS NUMERIC) / NULLIF(sum(m.subsequent_approved), 0) as percent_of_total_zennya_home_care_util

    -- util breakdown in avg util per patient
    ,COALESCE(CAST(sum(case when m.subsequent_loatype = 'ACU' then m.subsequent_approved end) AS NUMERIC) / NULLIF(count(distinct m.maskedcardno), 0), 0) as avg_acu_util_per_patient
    ,COALESCE(CAST(sum(case when m.subsequent_loatype = 'CONSULT' then m.subsequent_approved end) AS NUMERIC) / NULLIF(count(distinct m.maskedcardno), 0), 0) as avg_consult_util_per_patient
    ,COALESCE(CAST(sum(case when m.subsequent_loatype = 'Corporate Clinic' then m.subsequent_approved end) AS NUMERIC) / NULLIF(count(distinct m.maskedcardno), 0), 0) as avg_corporate_clinic_util_per_patient
    ,COALESCE(CAST(sum(case when m.subsequent_loatype = 'DENTAL' then m.subsequent_approved end) AS NUMERIC) / NULLIF(count(distinct m.maskedcardno), 0), 0) as avg_dental_util_per_patient
    ,COALESCE(CAST(sum(case when m.subsequent_loatype = 'EMERGENCY' then m.subsequent_approved end) AS NUMERIC) / NULLIF(count(distinct m.maskedcardno), 0), 0) as avg_emergency_util_per_patient
    ,COALESCE(CAST(sum(case when m.subsequent_loatype = 'INPATIENT' then m.subsequent_approved end) AS NUMERIC) / NULLIF(count(distinct m.maskedcardno), 0), 0) as avg_inpatient_util_per_patient
    ,COALESCE(CAST(sum(case when m.subsequent_loatype = 'Medgrocer' then m.subsequent_approved end) AS NUMERIC) / NULLIF(count(distinct m.maskedcardno), 0), 0) as avg_medgrocer_util_per_patient
    ,COALESCE(CAST(sum(case when m.subsequent_loatype = 'PROCEDURE' then m.subsequent_approved end) AS NUMERIC) / NULLIF(count(distinct m.maskedcardno), 0), 0) as avg_procedure_util_per_patient
    ,COALESCE(CAST(sum(case when m.subsequent_loatype = 'VIDEO CALL' then m.subsequent_approved end) AS NUMERIC) / NULLIF(count(distinct m.maskedcardno), 0), 0) as avg_video_call_util_per_patient
    ,COALESCE(CAST(sum(case when m.subsequent_loatype = 'VOICE CALL' then m.subsequent_approved end) AS NUMERIC) / NULLIF(count(distinct m.maskedcardno), 0), 0) as avg_voice_call_util_per_patient
    ,COALESCE(CAST(sum(case when m.subsequent_loatype = 'Zennya (Home Care)' then m.subsequent_approved end) AS NUMERIC) / NULLIF(count(distinct m.maskedcardno), 0), 0) as avg_zennya_home_care_util_per_patient

FROM {{ ref('mlv_acn_masked') }} m
LEFT JOIN {{ ref('icd_summary_acn') }} s
    ON m.combined_starting_primaryicdgroup = s.combined_starting_primaryicdgroup
GROUP BY 1, 2
ORDER BY combined_starting_primaryicdgroup, total_util DESC
