

{{ config(materialized = 'table')}}





SELECT
    COUNT(maskedcardno) AS total_patients,
    COUNT(CASE WHEN crf_category = 'Non CRF Patient' THEN 1 END) AS non_crf_patients,
    COUNT(CASE WHEN crf_category = 'On-Dialysis' THEN 1 END) AS on_dialysis_patients,
    COUNT(CASE WHEN crf_category = 'Pre-Dialysis' THEN 1 END) AS pre_dialysis_patients,
    COUNT(CASE WHEN crf_category = 'CRF Only' THEN 1 END) AS crf_only_patients
FROM {{ref('mlv_crf_deepdive')}}
GROUP BY crf_category