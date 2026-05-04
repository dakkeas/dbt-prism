
{{config(materialized = 'table')}}

SELECT * FROM {{ref('physiciancode_with_bills')}}