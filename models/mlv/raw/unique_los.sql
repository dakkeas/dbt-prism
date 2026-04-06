{{ config(materialized='table') }}

-- model to get the unique length of stay per patient as there can be multiple INP claims on the same
-- adissiondate, but have differeing dischargedates. 

WITH ranked_claims AS (
    SELECT
        maskedcardno,
        subsequent_admissiondate,
        subsequent_claimno,
        subsequent_lengthofstay,
        -- Rank to find the claim with the furthest discharge date
        ROW_NUMBER() OVER (
            PARTITION BY maskedcardno, subsequent_admissiondate
            ORDER BY subsequent_dischargedate DESC, subsequent_lengthofstay DESC, subsequent_claimno ASC
        ) as rn
    FROM {{ ref('pre_post_mlv') }}
    WHERE subsequent_loatype = 'INPATIENT'
)

SELECT
    maskedcardno,
    subsequent_admissiondate,
    subsequent_claimno AS max_los_claimno,
    subsequent_lengthofstay AS max_lengthofstay
FROM ranked_claims
WHERE rn = 1