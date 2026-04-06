{{config(materialized = 'table') }}

WITH raw_claims_2023_2025 AS (
    SELECT * FROM {{ ref('mxc_raw_claims') }} WHERE source_year >= 2023
),
base_claims AS (
    SELECT
        fc.maskedcardno,
        fc.starting_claimno,
        fc.starting_admissiondate,
        rc2325.claimno AS subsequent_claimno,
        rc2325.admissiondate AS subsequent_admissiondate,
        CASE
            WHEN rc2325.claimno = fc.starting_claimno THEN 0
            WHEN rc2325.admissiondate < fc.starting_admissiondate 
                 OR (rc2325.admissiondate = fc.starting_admissiondate AND rc2325.claimno < fc.starting_claimno) 
                 THEN -1 -- PRE
            ELSE 1 -- POST
        END AS claim_type
    FROM {{ref('end_stage_diseases_first_consults')}} fc
    INNER JOIN raw_claims_2023_2025 rc2325
        ON fc.maskedcardno = rc2325.maskedcardno
        AND (
            (rc2325.admissiondate >= fc.starting_admissiondate - INTERVAL '12 months'
            AND rc2325.admissiondate <= fc.starting_admissiondate + INTERVAL '12 months')
            OR rc2325.claimno = fc.starting_claimno
        )
    GROUP BY
        fc.maskedcardno,
        fc.starting_claimno,
        fc.starting_admissiondate,
        rc2325.claimno,
        rc2325.admissiondate
)
SELECT
    maskedcardno,
    starting_claimno,
    subsequent_claimno,
    CASE
        WHEN claim_type = 0 THEN 0
        WHEN claim_type = -1 THEN 
            -1 * ROW_NUMBER() OVER (
                PARTITION BY maskedcardno, claim_type 
                ORDER BY subsequent_admissiondate DESC, subsequent_claimno DESC
            )
        WHEN claim_type = 1 THEN 
            ROW_NUMBER() OVER (
                PARTITION BY maskedcardno, claim_type 
                ORDER BY subsequent_admissiondate ASC, subsequent_claimno ASC
            )
    END AS claim_sequence
FROM base_claims
