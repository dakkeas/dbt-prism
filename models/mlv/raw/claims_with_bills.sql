
{{config(materialized = 'table') }}

SELECT * FROM {{ref('source_claims_with_bills')}}