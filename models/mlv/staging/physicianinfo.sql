
{{config(materialized = 'table')}}

SELECT
    md.physiciancode,
    pn.physicianname,
    md.providercode AS providername,
    md.specialization
FROM {{ ref('t500_md')}} md
LEFT JOIN (SELECT DISTINCT physicianname, physiciancode FROM {{ref('physiciannames_from_seed')}}) pn
ON
    md.physiciancode = pn.physiciancode