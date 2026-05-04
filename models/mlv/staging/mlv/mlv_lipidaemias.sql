
{{config(materialized = 'table')}}

SELECT
    c.*
FROM {{ref('mlv')}} c
WHERE
    c.starting_primaryicdgroup IN ('DISORDERS OF LIPOPROTEIN METABOLISM AND OTHER LIPIDAEMIAS')
