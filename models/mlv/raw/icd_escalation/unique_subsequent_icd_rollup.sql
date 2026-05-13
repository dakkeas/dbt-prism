{{config(materialized = 'table')}}

WITH source AS (
    SELECT *
    FROM {{ ref('mlv') }}
)

SELECT
    combined_starting_primaryicdgroup,
    subsequent_primaryicdgroup AS subsequent_primaryicdgroup,
    subsequent_primaryicdcode AS subsequent_primaryicdcode,
    -- STRING_AGG(DISTINCT subsequent_primaryicdgroup, ', ') AS subsequent_icd_list,
    COUNT(DISTINCT maskedcardno) AS patient_count,
    COUNT(DISTINCT subsequent_claimno) AS claim_count,
    SUM(subsequent_approved) AS total_util,
    SUM(subsequent_approved) / NULLIF(COUNT(DISTINCT maskedcardno), 0) AS avg_util_per_patient,
    SUM(CASE WHEN subsequent_loatype = 'OP LAB' THEN subsequent_approved ELSE 0 END) AS total_op_lab,
    SUM(CASE WHEN subsequent_loatype = 'INPATIENT' THEN subsequent_approved ELSE 0 END) AS total_inpatient,
    SUM(CASE WHEN subsequent_loatype = 'EMERGENCY' THEN subsequent_approved ELSE 0 END) AS total_er,
    SUM(CASE WHEN subsequent_loatype = 'OP_CONSULT' THEN subsequent_approved ELSE 0 END) AS total_op_consult,
    SUM(CASE WHEN subsequent_loatype = 'ACU' THEN subsequent_approved ELSE 0 END) AS total_acu
FROM source
GROUP BY
    combined_starting_primaryicdgroup,
    subsequent_primaryicdgroup,
    subsequent_primaryicdcode
ORDER BY combined_starting_primaryicdgroup, patient_count DESC