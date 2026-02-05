
{{config(materialized = 'view')}}

SELECT
    md.physiciancode,
    pn.physicianname,
    md.providercode AS providername,
    md.specialization
FROM {{ ref('t500_md')}} md
LEFT JOIN (SELECT DISTINCT physicianname, physiciancode FROM {{ref('physiciannames')}}) pn
ON
    md.physiciancode = pn.physiciancode