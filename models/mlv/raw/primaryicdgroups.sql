
{{config(materialized = 'table')}}


WITH source AS (
    SELECT * FROM {{ ref('mxc_raw_claims') }} WHERE source_year >= 2019
)
SELECT DISTINCT
    primaryicdgroup,
    primaryicddesc,
    primaryicdcode
FROM 
source


