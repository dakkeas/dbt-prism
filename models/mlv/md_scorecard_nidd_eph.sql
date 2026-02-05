{{config(materialized = 'table')}}



SELECT * FROM {{ ref('md_scorecard_t500_eph') }}
UNION 
SELECT * FROM {{ ref('md_scorecard_t500_nidd') }}