
{{ config(materialized='table')}}


SELECT * FROM {{ref('mlv')}}
WHERE starting_corpname ILIKE 'ACCENTURE%'
