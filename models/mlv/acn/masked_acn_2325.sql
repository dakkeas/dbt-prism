
{{ config(materialized='table')}}

WITH primaryicdgroup_references AS (
    SELECT * FROM {{ ref('primaryicdgroup_references') }}
),

masked_acn_source AS (

    SELECT *
    FROM {{ source('masked_acn_consolidated_raw_data', 'updated_masked_acn_consolidated_raw_data_fy2324_fy2425') }}

)

SELECT
    m.*,
    r.primaryicddesc,
    r.primaryicdgroup
FROM masked_acn_source m
LEFT JOIN primaryicdgroup_references r
    ON m.icdcode = r.primaryicdcode