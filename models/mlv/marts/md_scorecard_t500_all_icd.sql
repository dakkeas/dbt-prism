
{{config(materialized = 'table')}}

SELECT * FROM {{ ref('md_scorecard_t500_ami') }}
UNION ALL
SELECT * FROM {{ ref('md_scorecard_t500_cerebral_infarction') }}
UNION ALL
SELECT * FROM {{ ref('md_scorecard_t500_cholelithiasis') }}
UNION ALL
SELECT * FROM {{ ref('md_scorecard_t500_cihd') }}
UNION ALL
SELECT * FROM {{ ref('md_scorecard_t500_crf') }}
UNION ALL
SELECT * FROM {{ ref('md_scorecard_t500_diabetes') }}
UNION ALL
SELECT * FROM {{ ref('md_scorecard_t500_eph') }}
UNION ALL
SELECT * FROM {{ ref('md_scorecard_t500_heart_failure') }}
UNION ALL
SELECT * FROM {{ ref('md_scorecard_t500_hhd') }}
UNION ALL
SELECT * FROM {{ ref('md_scorecard_t500_lipidaemias') }}
UNION ALL
SELECT * FROM {{ ref('md_scorecard_t500_oaihd') }}
UNION ALL
SELECT * FROM {{ ref('md_scorecard_t500_ocd') }}
UNION ALL
SELECT * FROM {{ ref('md_scorecard_t500_pneumonia_mr') }}
UNION ALL
SELECT * FROM {{ ref('md_scorecard_t500_pneumonia_ou') }}
