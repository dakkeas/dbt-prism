{{ config(materialized = 'table') }}

-- Description:
-- This CRF-specific MLV cohort keeps patients whose starting ICD can be any
-- primary ICD group, as long as the patient has CHRONIC RENAL FAILURE as the
-- primary ICD group on either the first consult or any subsequent consult in
-- the MLV journey. All MLV rows for those patients are retained so downstream
-- scorecards measure the full patient journey after cohort assignment.

WITH crf_patients AS (
    SELECT DISTINCT
        maskedcardno
    FROM {{ ref('mlv') }}
    WHERE starting_primaryicdgroup = 'CHRONIC RENAL FAILURE'
        OR subsequent_primaryicdgroup = 'CHRONIC RENAL FAILURE'
),

crf_mlv AS (
    SELECT
        'CHRONIC RENAL FAILURE' AS computed_primaryicdgroup,
        mlv.*
    FROM {{ ref('mlv') }} mlv
    INNER JOIN crf_patients cp
        ON mlv.maskedcardno = cp.maskedcardno
)

SELECT *
FROM crf_mlv
