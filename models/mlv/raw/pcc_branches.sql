
{{config(materialized='table')}}

SELECT DISTINCT
    a.providername,
    a.providertype,
    p.pcc_branch_name

FROm {{ref('masked_acn_2325')}} a

JOIN {{ref('pcc_availments_raw_data')}} p
    ON LOWER(TRIM(a.providername)) = LOWER(TRIM(p.pcc_branch_name))
ORDER BY a.providername
