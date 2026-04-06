{{config(materialized= 'table')}}

WITH raw_claims_2023_2025 AS (
    SELECT * FROM {{ ref('mxc_raw_claims') }} WHERE source_year >= 2023
)
SELECT rc.*
FROM raw_claims_2023_2025 rc
WHERE EXISTS (
    SELECT 1
    FROM {{ ref('mlv_eph') }} c
    WHERE rc.claimno = c.subsequent_claimno
)
