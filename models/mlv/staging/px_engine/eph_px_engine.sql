
{{config(materialized = 'table')}}

SELECT
    *
FROM {{ref('px_engine')}}
WHERE combined_starting_primaryicdgroup = 'ESSENTIAL (PRIMARY) HYPERTENSION'