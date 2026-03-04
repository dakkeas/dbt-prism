{{ config(materialized = 'table')}}

SELECT
    c.*
FROM {{ref('mlv')}} c
WHERE
    c.starting_primaryicdgroup IN ('CHRONIC RENAL FAILURE')

    