
{{ config(materialized = 'table')}}

SELECT
    c.*
FROM {{ref('mlv')}} c
WHERE
    c.starting_primaryicdgroup IN ('NON-INSULIN-DEPENDENT DIABETES MELLITUS','INSULIN-DEPENDENT DIABETES MELLITUS')

    