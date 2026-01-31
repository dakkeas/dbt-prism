
{{ config(materialized='table')}}


SELECT
    s.subsequent_claimno AS claimno,
    COUNT(DISTINCT CASE 
        WHEN rc2325.physiciancode IS NOT NULL
             AND rc2325.physiciancode NOT IN ('', 'NULL','0',' ')
        THEN rc2325.physiciancode 
    END) AS total_unique_physicians,
    -- Corrected Logic: Count unique Physician Codes, not unique "1s"
    COUNT(DISTINCT CASE 
        WHEN rc2325.physiciancode IS NOT NULL
             AND rc2325.physiciancode NOT IN ('', 'NULL','0',' ')
             AND rc2325.coverageitemdesc ILIKE '%DOCTOR SERVICES%' 
        THEN rc2325.physiciancode -- <--- RETURN THE CODE, NOT 1
        ELSE NULL 
    END) AS count_of_doctor_services,

    COUNT(DISTINCT CASE 
        WHEN rc2325.physiciancode IS NOT NULL
             AND rc2325.physiciancode NOT IN ('', 'NULL','0',' ')
             AND rc2325.coverageitemdesc ILIKE '%CONSULT%' 
        THEN rc2325.physiciancode 
        ELSE NULL 
    END) AS count_of_consult_physician,

    COUNT(DISTINCT CASE 
        WHEN rc2325.physiciancode IS NOT NULL
             AND rc2325.physiciancode NOT IN ('', 'NULL','0',' ')
             AND rc2325.coverageitemdesc ILIKE '%ANESTHESIO%' 
        THEN rc2325.physiciancode 
        ELSE NULL 
    END) AS count_of_anesthesiologist,

    COUNT(DISTINCT CASE 
        WHEN rc2325.physiciancode IS NOT NULL
             AND rc2325.physiciancode NOT IN ('', 'NULL','0',' ')
             AND rc2325.coverageitemdesc ILIKE '%SURGEON%' 
        THEN rc2325.physiciancode 
        ELSE NULL 
    END) AS count_of_surgeon

FROM {{ref('subsequent_claims')}} s -- dependent on subs table
INNER JOIN raw_claims_2023_2025 rc2325
    ON s.subsequent_claimno = rc2325.claimno
GROUP BY s.subsequent_claimno