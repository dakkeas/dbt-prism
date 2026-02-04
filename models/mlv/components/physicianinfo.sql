
{{config(materialized = 'table')}}
SELECT 
    pn.physiciancode,
    pn.physicianname,
    md.specialization
FROM {{ref('physiciannames')}} pn
LEFT JOIN
    {{ref('t500_md')}} md
ON pn.physiciancode = md.physiciancode
