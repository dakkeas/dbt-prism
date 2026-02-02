{{ config(materialized = 'table')}}

SELECT
    c.*
FROM {{ref('combined')}} c
WHERE
    c.starting_primaryicdgroup = 'ESSENTIAL (PRIMARY) HYPERTENSION'