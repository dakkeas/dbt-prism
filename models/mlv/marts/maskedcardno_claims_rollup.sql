

SELECT
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