{{config(materialized = 'table')}}

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
SELECT * FROM combined
