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
        DATE_DIFF(CAST(base_data.subsequent_admissiondate AS DATE), CAST(base_data.starting_admissiondate AS DATE), WEEK) AS relative_week_bucket
    {% else %}
        CAST((EXTRACT(YEAR FROM CAST(base_data.subsequent_admissiondate AS DATE)) - EXTRACT(YEAR FROM CAST(base_data.starting_admissiondate AS DATE))) * 12 + 
             (EXTRACT(MONTH FROM CAST(base_data.subsequent_admissiondate AS DATE)) - EXTRACT(MONTH FROM CAST(base_data.starting_admissiondate AS DATE))) AS INTEGER) AS relative_month_bucket,
        CAST(FLOOR((CAST(base_data.subsequent_admissiondate AS DATE) - CAST(base_data.starting_admissiondate AS DATE)) / 7.0) AS INTEGER) AS relative_week_bucket
    {% endif %}
FROM base_data
LEFT JOIN {{ ref('unique_los') }} ul
   ON base_data.subsequent_claimno = ul.max_los_claimno