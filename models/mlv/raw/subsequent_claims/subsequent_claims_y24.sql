{{ config(materialized = 'table') }}

-- 2024 Cohort Version: subsequent claims for first_consults_y24 within claims window 2024

WITH raw_claims_window AS (
    SELECT * FROM {{ ref('mxc_raw_claims') }} WHERE source_year = 2024
)
SELECT
    fc.maskedcardno,
    fc.starting_claimno AS starting_claimno,
    rc.claimno AS subsequent_claimno,
    ROW_NUMBER() OVER (
        PARTITION BY fc.maskedcardno
        ORDER BY 
            CASE WHEN rc.claimno = fc.starting_claimno THEN 0 ELSE 1 END,
            rc.admissiondate ASC,
            rc.claimno ASC
    ) AS claim_sequence
FROM {{ ref('first_consults_y24') }} fc
INNER JOIN raw_claims_window rc
    ON fc.maskedcardno = rc.maskedcardno
    AND rc.admissiondate >= fc.starting_admissiondate
    AND rc.admissiondate <= fc.starting_admissiondate + INTERVAL '12 months'
GROUP BY
    fc.maskedcardno,
    rc.admissiondate,
    fc.starting_claimno,
    rc.claimno
