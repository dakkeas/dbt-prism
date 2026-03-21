{{config(materialized = 'table') }}


SELECT
    fc.maskedcardno,
    fc.starting_claimno AS starting_claimno, -- starting claim number
    rc2325.claimno AS subsequent_claimno, -- subsequent claim number
    ROW_NUMBER() OVER (
        PARTITION BY fc.maskedcardno
        ORDER BY 
            CASE WHEN rc2325.claimno = fc.starting_claimno THEN 0 ELSE 1 END,  -- first consult always first
            rc2325.admissiondate ASC,
            rc2325.claimno ASC
    ) AS claim_sequence
FROM {{ref('first_consults')}} fc
INNER JOIN raw_claims_2023_2025 rc2325
    ON fc.maskedcardno = rc2325.maskedcardno
    AND (
        (rc2325.admissiondate >= fc.starting_admissiondate - INTERVAL '12 months'
         AND rc2325.admissiondate <= fc.starting_admissiondate + INTERVAL '12 months')
        OR rc2325.claimno = fc.starting_claimno
    )
GROUP BY
    fc.maskedcardno,
    rc2325.admissiondate,
    fc.starting_claimno,
    rc2325.claimno