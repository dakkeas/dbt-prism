{{config(materialized= 'table')}}


SELECT rc.*
FROM raw_claims_2023_2025 rc
WHERE EXISTS (
    SELECT 1
    FROM {{ ref('mlv_eph') }} c
    WHERE rc.claimno = c.subsequent_claimno
)
