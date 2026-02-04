SELECT claimno 
FROM {{ref('ocr_01211')}}
WHERE
    claimno ILIKE '%DNE%'
    OR
    claimno ILIKE '%N/A%'
    OR
    claimno ILIKE '%NA%'
    

