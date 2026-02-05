
{{config(materialized = 'table')}}

SELECT
    c.*
FROM {{ref('mlv')}} c
WHERE
    c.starting_primaryicdgroup IN ('ESSENTIAL (PRIMARY) HYPERTENSION','NON-INSULIN-DEPENDENT DIABETES MELLITUS')