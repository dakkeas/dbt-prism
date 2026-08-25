{{ config(materialized = 'table') }}

SELECT * FROM {{ ref('eph_physician_shortlist') }}
UNION ALL
SELECT * FROM {{ ref('diabetes_physician_shortlist') }}
UNION ALL
SELECT * FROM {{ ref('lipidaemias_physician_shortlist') }}
UNION ALL
SELECT * FROM {{ ref('crf_physician_shortlist') }}
