
{{ config(materialized='table')}}

-- UNION ALL of all physician names and physician codes from all claimss
-- Grabs unique combinations of physiciancode + physicianname for references

WITH raw_unioned AS (
    SELECT physicianname, physiciancode FROM {{source('mxc_raw_claims', 'prism_2019_jan_to_jun')}}
    UNION ALL
    SELECT physicianname, physiciancode FROM {{source('mxc_raw_claims', 'prism_2019_july_to_dec')}}
    UNION ALL
    SELECT physicianname, physiciancode FROM {{source('mxc_raw_claims', 'prism_2020_jan_to_jun')}}
    UNION ALL
    SELECT physicianname, physiciancode FROM {{source('mxc_raw_claims', 'prism_2020_july_to_dec')}}
    UNION ALL
    SELECT physicianname, physiciancode FROM {{source('mxc_raw_claims', 'prism_2021_jan_to_jun')}}
    UNION ALL
    SELECT physicianname, physiciancode FROM {{source('mxc_raw_claims', 'prism_2021_july_to_dec')}}
    UNION ALL
    SELECT physicianname, physiciancode FROM {{source('mxc_raw_claims', 'prism_2022_jan_to_jun')}}
    UNION ALL
    SELECT physicianname, physiciancode FROM {{source('mxc_raw_claims', 'prism_2022_july_to_dec')}}
    UNION ALL
    SELECT physicianname, physiciancode FROM {{source('mxc_raw_claims', 'prism_2023_jan_to_jun')}}
    UNION ALL
    SELECT physicianname, physiciancode FROM {{source('mxc_raw_claims', 'prism_2023_july_to_dec')}}
),
-- Cast the column so it behaves as text downstream
casted_data AS (
    SELECT
        physicianname,
        CAST(physiciancode AS TEXT) AS physiciancode
        -- NOTE: You can also use physiciancode::text if your database supports it
    FROM raw_unioned
)
-- Filter and grab the unique combinations
SELECT DISTINCT
    physicianname,
    physiciancode
FROM casted_data
WHERE
    physicianname IS NOT NULL
    AND physiciancode IS NOT NULL
    AND physicianname <> ''
    AND physiciancode <> '' -- This is now 100% safe because physiciancode is text!
