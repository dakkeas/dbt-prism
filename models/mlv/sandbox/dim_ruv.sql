
{{config(materialized = 'table')}}

WITH from_2023_2025 AS (
    SELECT DISTINCT
        ruvcode::text,
        ruvdesc::text
    FROM raw_claims_2023_2025
    WHERE 
        (NULLIF(ruvcode, '') IS NOT NULL) 
        OR 
        (NULLIF(ruvdesc, '') IS NOT NULL)
),
from_2022 AS (
    SELECT DISTINCT
        ruvcode::text,
        ruvdesc::text
    FROM raw_claims_2022
    WHERE 
        (NULLIF(ruvcode, '') IS NOT NULL) 
        OR 
        (NULLIF(ruvdesc, '') IS NOT NULL)
)
SELECT * FROM from_2023_2025
UNION -- This removes duplicates found in both CTEs
SELECT * FROM from_2022

