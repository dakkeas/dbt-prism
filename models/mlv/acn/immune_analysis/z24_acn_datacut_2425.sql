
{{ config(materialized='table') }}

WITH patient_pool AS (

    SELECT DISTINCT
        maskedcardno
    FROM {{ source('acn_raw_data', 'masked_acn_raw_2425') }}
    WHERE icdcode = 'Z24.2'

),

prism_claims AS (
    SELECT icdcode, icddesc FROM {{ source('mxc_raw_claims', 'prism_2019_jan_to_jun') }}
    UNION ALL
    SELECT icdcode, icddesc FROM {{ source('mxc_raw_claims', 'prism_2019_july_to_dec') }}
    UNION ALL
    SELECT icdcode, icddesc FROM {{ source('mxc_raw_claims', 'prism_2020_jan_to_jun') }}
    UNION ALL
    SELECT icdcode, icddesc FROM {{ source('mxc_raw_claims', 'prism_2020_july_to_dec') }}
    UNION ALL
    SELECT icdcode, icddesc FROM {{ source('mxc_raw_claims', 'prism_2021_jan_to_jun') }}
    UNION ALL
    SELECT icdcode, icddesc FROM {{ source('mxc_raw_claims', 'prism_2021_july_to_dec') }}
    UNION ALL
    SELECT icdcode, icddesc FROM {{ source('mxc_raw_claims', 'prism_2022_jan_to_jun') }}
    UNION ALL
    SELECT icdcode, icddesc FROM {{ source('mxc_raw_claims', 'prism_2022_july_to_dec') }}
    UNION ALL
    SELECT icdcode, icddesc FROM {{ source('mxc_raw_claims', 'prism_2023_jan_to_jun') }}
    UNION ALL
    SELECT icdcode, icddesc FROM {{ source('mxc_raw_claims', 'prism_2023_july_to_dec') }}
    UNION ALL
    SELECT icdcode, icddesc FROM {{ source('mxc_raw_claims', 'prism_2024_jan_to_jun') }}
    UNION ALL
    SELECT icdcode, icddesc FROM {{ source('mxc_raw_claims', 'prism_2024_july_to_dec') }}
    UNION ALL
    SELECT icdcode, icddesc FROM {{ source('mxc_raw_claims', 'prism_2025_jan_to_mar') }}
),

icd_mapping AS (
    SELECT 
        icdcode, 
        MAX(icddesc) AS icddesc
    FROM prism_claims
    WHERE icdcode IS NOT NULL
    GROUP BY icdcode
)

SELECT
    raw.*,
    map.icddesc
FROM {{ source('acn_raw_data', 'masked_acn_raw_2425') }} raw
INNER JOIN patient_pool pp
    ON pp.maskedcardno = raw.maskedcardno
LEFT JOIN icd_mapping map
    ON raw.icdcode = map.icdcode