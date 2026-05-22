{{ config(materialized = 'table') }}

WITH raw_claims AS (

    SELECT *
    FROM {{ ref('masked_acn_2325') }}
)

SELECT
    fc.maskedcardno,
    fc.starting_claimno AS starting_claimno,
    rc.claimno AS subsequent_claimno,

    ROW_NUMBER() OVER (
        PARTITION BY fc.maskedcardno
        ORDER BY
            CASE
                WHEN rc.claimno = fc.starting_claimno THEN 0
                ELSE 1
            END,
            rc.admissiondate ASC,
            rc.claimno ASC
    ) AS claim_sequence

FROM {{ ref('first_consults_acn') }} fc

INNER JOIN raw_claims rc
    ON fc.maskedcardno = rc.maskedcardno
    AND rc.admissiondate >= fc.starting_admissiondate
    AND rc.admissiondate <= {{ dateadd('month', 12, 'fc.starting_admissiondate') }}

GROUP BY
    fc.maskedcardno,
    rc.admissiondate,
    fc.starting_claimno,
    rc.claimno