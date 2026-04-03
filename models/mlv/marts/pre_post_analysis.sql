{{ config(materialized='table') }}

WITH base_data AS (
    SELECT *
    FROM {{ ref('pre_post_mlv') }}
)

SELECT
    base_data.*,

    -- Adjusted length of stay logic for overlapping inpatient claims
    CASE 
        WHEN base_data.subsequent_loatype = 'INPATIENT' THEN
            CASE 
                WHEN ul.max_los_claimno IS NOT NULL THEN base_data.subsequent_lengthofstay
                ELSE 0
            END
        ELSE base_data.subsequent_lengthofstay
    END AS adjusted_lengthofstay,
    
    -- Calculate relative month bucket where first consult month = 0
    {% if target.type == 'bigquery' %}

        DATE_DIFF(CAST(base_data.subsequent_admissiondate AS DATE), CAST(base_data.starting_admissiondate AS DATE), MONTH) AS relative_month_bucket,
        DATE_DIFF(CAST(base_data.subsequent_admissiondate AS DATE), CAST(base_data.starting_admissiondate AS DATE), WEEK) AS relative_week_bucket,

        -- 12-month pre/post bucket
        CASE 
            WHEN DATE_DIFF(CAST(base_data.subsequent_admissiondate AS DATE), CAST(base_data.starting_admissiondate AS DATE), MONTH) BETWEEN -12 AND -1 THEN -1
            WHEN DATE_DIFF(CAST(base_data.subsequent_admissiondate AS DATE), CAST(base_data.starting_admissiondate AS DATE), MONTH) = 0 THEN 0
            WHEN DATE_DIFF(CAST(base_data.subsequent_admissiondate AS DATE), CAST(base_data.starting_admissiondate AS DATE), MONTH) BETWEEN 1 AND 12 THEN 1
            ELSE NULL
        END AS relative_12month_bucket

    {% else %}
            CAST((EXTRACT(YEAR FROM base_data.subsequent_admissiondate) - EXTRACT(YEAR FROM base_data.starting_admissiondate)) * 12 + 
            (EXTRACT(MONTH FROM base_data.subsequent_admissiondate) - EXTRACT(MONTH FROM base_data.starting_admissiondate)) AS INTEGER) AS relative_month_bucket,
            CAST(FLOOR((CAST(base_data.subsequent_admissiondate AS DATE) - CAST(base_data.starting_admissiondate AS DATE)) / 7.0) AS INTEGER) AS relative_week_bucket,

            -- 12-month pre/post bucket
            CASE 
                WHEN ((EXTRACT(YEAR FROM base_data.subsequent_admissiondate) - EXTRACT(YEAR FROM base_data.starting_admissiondate)) * 12 + 
                    (EXTRACT(MONTH FROM base_data.subsequent_admissiondate) - EXTRACT(MONTH FROM base_data.starting_admissiondate))) BETWEEN -12 AND -1 THEN -1
                WHEN ((EXTRACT(YEAR FROM base_data.subsequent_admissiondate) - EXTRACT(YEAR FROM base_data.starting_admissiondate)) * 12 + 
                    (EXTRACT(MONTH FROM base_data.subsequent_admissiondate) - EXTRACT(MONTH FROM base_data.starting_admissiondate))) = 0 THEN 0
                WHEN ((EXTRACT(YEAR FROM base_data.subsequent_admissiondate) - EXTRACT(YEAR FROM base_data.starting_admissiondate)) * 12 + 
                    (EXTRACT(MONTH FROM base_data.subsequent_admissiondate) - EXTRACT(MONTH FROM base_data.starting_admissiondate))) BETWEEN 1 AND 12 THEN 1
                ELSE NULL
            END AS relative_12month_bucket

    {% endif %}
    
FROM base_data
LEFT JOIN {{ ref('unique_los') }} ul
   ON base_data.subsequent_claimno = ul.max_los_claimno