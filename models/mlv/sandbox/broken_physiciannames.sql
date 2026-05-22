
{{config(materialized = 'table')}}

SELECT DISTINCT physicianname
FROM {{ ref('masked_acn_consolidated_raw_data_fy2324_fy2425') }}
WHERE physicianname IS NOT NULL