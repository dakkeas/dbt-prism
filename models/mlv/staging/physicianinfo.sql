
{{config(materialized = 'table')}}


SELECT
    pn.physiciancode,
    pn.physicianname,
    md.providercode AS providername,
    md.specialization
FROM {{ref('unique_physiciannames')}} pn
LEFT JOIN {{ref('t500_md')}} md
ON
    md.physiciancode = pn.physiciancode
GROUP BY 1,2,3,4


