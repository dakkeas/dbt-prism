{{config(materialized= 'table')}}

WITH combined AS (
    SELECT * FROM {{ ref('MMC_ocr_raw') }}
    UNION ALL
    SELECT * FROM {{ ref('TMC_ocr_raw') }}
    UNION ALL
    SELECT * FROM {{ ref('TMCFV_ocr_raw') }}
    UNION ALL
    SELECT * FROM {{ ref('MDH_ocr_raw') }}
    UNION ALL
    SELECT * FROM {{ ref('CW_ocr_raw') }}
    UNION ALL
    SELECT * FROM {{ ref('CGH_ocr_raw') }}
    UNION ALL
    SELECT * FROM {{ ref('AHMC_ocr_raw') }}
)
SELECT
    c.item_name,
    c.item_name_simple_clean,
    c.item_name_hard_clean,
    ABS(c.item_quantity) AS item_quantity,
    ABS(c.item_unit_gross_price) AS item_unit_gross_price,
    CASE 
        WHEN c.total_price IS NULL THEN 
            ABS(c.item_unit_gross_price * c.item_quantity)
        ELSE 
            ABS(c.total_price)
    END AS total_price,

    CASE 
        WHEN c.claimno ILIKE 'DNE' OR c.claimno ILIKE '%N/A%' OR c.claimno ILIKE '%NA%' THEN  
        NULL
        ELSE
        c.claimno
    END AS claimno,
    mlv.physician_providercode AS starting_physician_providercode,
    mlv.maskedcardno AS maskedcardno,
    CASE 
        WHEN c.physiciancode ILIKE 'DNE' OR c.physiciancode ILIKE '%N/A' OR c.physiciancode ILIKE 'NA' THEN  
        NULL
        ELSE
        c.physiciancode
    END AS subsequent_physician_providercode,
    SPLIT_PART(c.physiciancode, ' - ', 1) AS physiciancode,
    SPLIT_PART(c.physiciancode, ' - ', 2) AS providername,
    c.loe_folder,
    c.source_file,
    c.file_name,
    c.icdcode
FROM combined c
LEFT JOIN {{ref('mlv_eph')}} mlv
ON c.claimno = mlv.subsequent_claimno
WHERE
    c.item_name_hard_clean IS NOT NULL AND c.item_name_hard_clean <> ''
    AND c.item_name_simple_clean IS NOT NULL AND c.item_name_simple_clean <> ''
    AND c.item_unit_gross_price IS NOT NULL
    AND c.item_quantity IS NOT NULL
    AND c.claimno IS NOT NULL AND c.claimno <> ''
    AND c.physiciancode IS NOT NULL AND c.physiciancode <> ''

