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
    mlv.maskedcardno AS maskedcardno,

    mlv.physician_providername AS starting_physician_providername, -- used to link to t500 scorecard

    CASE 
        WHEN c.physiciancode ILIKE 'DNE' OR c.physiciancode ILIKE '%N/A' OR c.physiciancode ILIKE 'NA' THEN  
        NULL
        ELSE
        c.physiciancode
    END AS subsequent_physician_providername,

    SPLIT_PART(c.physiciancode, ' - ', 1) AS subsequent_physiciancode,
    SPLIT_PART(c.physiciancode, ' - ', 2) AS subsequent_providername,

    CASE 
        WHEN c.claimno ILIKE 'DNE' OR c.claimno ILIKE '%N/A%' OR c.claimno ILIKE '%NA%' THEN  
        'N/A'
        ELSE
        c.claimno
    END AS file_claimno, -- claim numbers from ABBY/source file

    mlv.subsequent_claimno AS subsequent_claimno,

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

    c.icdcode

FROM combined c
LEFT JOIN {{ref('mlv_eph')}} mlv
ON c.claimno = mlv.subsequent_claimno
