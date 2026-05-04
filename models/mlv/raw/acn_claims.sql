{{config(materialized='table')}}

WITH accenture_claims AS (
    SELECT * FROM {{ ref('mxc_raw_claims') }} 
    WHERE source_year >= 2019
    AND corpname ILIKE 'ACCENTURE%'
)
SELECT * FROM accenture_claims