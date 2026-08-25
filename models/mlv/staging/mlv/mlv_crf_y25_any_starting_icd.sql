{{ config(materialized = 'table') }}

WITH crf_patients AS (
    SELECT DISTINCT maskedcardno
    FROM {{ ref('mlv_crf_any_starting_icd') }}
),

crf_mlv AS (
    SELECT
        mlv.*,
        'CHRONIC RENAL FAILURE' AS computed_primaryicdgroup
    FROM {{ ref('mlv_y25') }} mlv
    INNER JOIN crf_patients cp
        ON mlv.maskedcardno = cp.maskedcardno
)

SELECT *
FROM crf_mlv
