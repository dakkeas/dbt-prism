

SELECT
    c.maskedcardno
FROM {{ref('mlv')}} c
LEFT JOIN
    {{ref('bl_unmaskedcardno')}} b
ON c.maskedcardno = b.maskedcardno
WHERE
    b.maskedcardno IS NULL
    AND --checking whether there are missing maskedcardno in unmasked csv
    c.starting_primaryicdgroup = 'ESSENTIAL (PRIMARY) HYPERTENSION'
    