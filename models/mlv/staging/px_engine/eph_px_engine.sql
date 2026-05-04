
{{config(materialized = 'table')}}

SELECT
    *
FROM {{ref('px_engine')}}
WHERE starting_primaryicdgroup = 'ESSENTIAL (PRIMARY) HYPERTENSION'