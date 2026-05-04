
{{config(materialized = 'table')}}


WITH md_list AS (
    SELECT
        starting_physiciancode,
        starting_primaryicdgroup,
        pi.physicianname,
        starting_providername,
        maskedcardno,
        STRING_AGG(subsequent_claimno, ', ') AS subsequent_claims
    FROM 
        {{ref('mlv')}} mlv
    LEFT JOIN
        {{ref('physicianinfo')}} pi
    ON mlv.starting_physiciancode = pi.physiciancode
    WHERE 
        starting_primaryicdgroup = 'ESSENTIAL (PRIMARY) HYPERTENSION'
    GROUP BY 
        starting_physiciancode,
        starting_primaryicdgroup,
        starting_providername,
        physicianname,
        maskedcardno
)
SELECT 
    md.*,
    CASE
        WHEN mb.physiciancode IS NOT NULL THEN 'TRUE'
        ELSE 'FALSE'
    END AS has_bills
FROM md_list md
LEFT JOIN {{ref('md_with_bills')}} mb
    ON md.starting_physiciancode = mb.physiciancode


