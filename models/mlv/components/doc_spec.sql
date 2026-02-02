{{config(materialized = 'table')}}


SELECT
    physiciancode,
    providercode,
    physicianname,
    specialization
FROM {{ref('t500_md')}}
