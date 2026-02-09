
{{ config(materialized = 'table')}}

SELECT
    c.*
FROM {{ref('mlv')}} c
WHERE
    c.starting_primaryicdgroup = 'NON-INSULIN-DEPENDENT DIABETES MELLITUS'