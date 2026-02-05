{{config(materialized = 'view')}}


SELECT
    starting_primaryicdgroup,
    starting_providername,
    COUNT(DISTINCT maskedcardno) AS count_of_patients,
    SUM(overall_util) AS total_util
FROM {{ref('px_engine')}}
GROUP BY 1,2
ORDER BY 1,2,4
