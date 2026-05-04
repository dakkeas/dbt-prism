{{config(materialized='table')}}

WITH accenture_claims AS (
    SELECT * FROM {{ ref('mxc_raw_claims') }} 
    WHERE source_year >= 2019
    {% if target.type == 'bigquery' %}
    AND UPPER(corpname) LIKE 'ACCENTURE%'
    {% else %}
    AND corpname ILIKE 'ACCENTURE%'
    {% endif %}
)
SELECT * FROM accenture_claims