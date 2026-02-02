{{config(materialized= 'table')}}


SELECT rc.*
FROM raw_claims_2023_2025 rc
WHERE EXISTS (
    SELECT 1
    FROM {{ ref('eph_combined') }} c
    WHERE rc.claimno = c.subsequent_claimno
)
