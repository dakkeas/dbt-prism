{{ config(materialized = 'table') }}

WITH physician_provider_metrics AS (
    SELECT
        combined_starting_primaryicdgroup AS primaryicdgroup,
        CONCAT(starting_physiciancode, ' - ', starting_providername) AS physician_providername,
        starting_physiciancode AS physiciancode,
        starting_providername AS providername,
        COUNT(DISTINCT maskedcardno) AS unique_patient_count,
        SUM(overall_count_of_claims) AS total_claims,
        SUM(overall_util) AS total_12_month_cost_of_care,
        COALESCE(
            CAST(SUM(overall_util) AS NUMERIC)
            / NULLIF(CAST(COUNT(DISTINCT maskedcardno) AS NUMERIC), 0),
            0
        ) AS average_12_month_cost_per_patient
    FROM {{ ref('px_engine') }}
    WHERE combined_starting_primaryicdgroup IS NOT NULL
        AND TRIM(combined_starting_primaryicdgroup) NOT IN ('', ' ')
    GROUP BY
        combined_starting_primaryicdgroup,
        starting_physiciancode,
        starting_providername
),

icd_rollup AS (
    SELECT
        combined_starting_primaryicdgroup AS primaryicdgroup,
        COUNT(DISTINCT maskedcardno) AS unique_patient_count,
        SUM(overall_count_of_claims) AS total_claims,
        SUM(overall_util) AS total_12_month_cost_of_care
    FROM {{ ref('px_engine') }}
    WHERE combined_starting_primaryicdgroup IS NOT NULL
        AND TRIM(combined_starting_primaryicdgroup) NOT IN ('', ' ')
    GROUP BY combined_starting_primaryicdgroup
)

SELECT
    ppm.primaryicdgroup,
    ROUND(CAST(AVG(ppm.average_12_month_cost_per_patient) AS NUMERIC), 2) AS network_average_cost_per_patient,
    COUNT(*) AS physician_provider_count,
    ROUND(CAST(ir.unique_patient_count AS NUMERIC), 2) AS unique_patient_count,
    ROUND(CAST(ir.total_claims AS NUMERIC), 2) AS total_claims,
    ROUND(CAST(ir.total_12_month_cost_of_care AS NUMERIC), 2) AS total_12_month_cost_of_care
FROM physician_provider_metrics ppm
LEFT JOIN icd_rollup ir
    ON ppm.primaryicdgroup = ir.primaryicdgroup
GROUP BY
    ppm.primaryicdgroup,
    ir.unique_patient_count,
    ir.total_claims,
    ir.total_12_month_cost_of_care
