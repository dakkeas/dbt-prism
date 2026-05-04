
{{config(materialized = 'table')}}

SELECT
    pn.physiciancode,
    pn.physicianname,
    md.specialization,
    md.sub_specialization,
    md.is_coordinator AS is_pcc_coordinator,
    md.practices_in_pcc
FROM {{ref('unique_physiciannames')}} pn
LEFT JOIN {{ref('pcc_physician_codes')}} md
ON pn.physiciancode = md.physiciancode
GROUP BY 1,2,3,4,5,6
