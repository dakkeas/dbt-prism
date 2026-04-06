
{{config(materialized = 'table')}}

WITH raw_claims_2023_2025 AS (
    SELECT * FROM {{ ref('mxc_raw_claims') }} WHERE source_year >= 2023
),
raw_claims_2022 AS (
    SELECT * FROM {{ ref('mxc_raw_claims') }} WHERE source_year = 2022
),
from_2023_2025 AS (
    SELECT DISTINCT
        cptcode::text,
        cptdesc::text
    FROM raw_claims_2023_2025
    WHERE 
        (NULLIF(cptcode, '') IS NOT NULL) 
        OR 
        (NULLIF(cptdesc, '') IS NOT NULL)
),
from_2022 AS (
    SELECT DISTINCT
        cptcode::text,
        cptdesc::text
    FROM raw_claims_2022
    WHERE 
        (NULLIF(cptcode, '') IS NOT NULL) 
        OR 
        (NULLIF(cptdesc, '') IS NOT NULL)
)
SELECT * FROM from_2023_2025
UNION -- This removes duplicates found in both CTEs
SELECT * FROM from_2022
