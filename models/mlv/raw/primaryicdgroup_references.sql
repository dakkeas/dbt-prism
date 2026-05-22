{{config(materialized = 'table')}}

WITH primaryicdgroup_references AS (

    -- Build a clean ICD → group mapping (1 row per ICD code)
    SELECT
        primaryicdcode,
        primaryicdgroup
    FROM {{ ref('mxc_raw_claims') }}
    WHERE source_year >= 2019
    GROUP BY 1,2
)
SELECT * FROM primaryicdgroup_references