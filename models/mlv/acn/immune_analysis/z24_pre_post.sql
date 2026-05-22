{{ config(materialized='table') }}

WITH raw_data AS (
    SELECT *
    FROM {{ ref('z24_acn_datacut_2425') }}
),

base_data AS (
    SELECT
        maskedcardno,
        claimno,
        MIN(admissiondate) AS admissiondate,
        MIN(corpcode) AS corpcode,
        MIN(branchdesc) AS branchdesc,
        MIN(gender) AS gender,
        MIN(membershiptype) AS membershiptype,
        MIN(mainspecialization) AS mainspecialization,
        MIN(loatype) AS loatype,
        MIN(icdcode) AS icdcode,
        MIN(icddesc) AS icddesc,
        MIN(age) AS age,
        MIN(benefitid) AS benefitid,
        MIN(ruvcode) AS ruvcode,
        SUM(approved) AS approved,
        STRING_AGG(DISTINCT cptdesc, ', ') AS cptdescs,
        MAX(CASE 
            WHEN UPPER(icdcode) LIKE 'W53%'
              OR UPPER(icdcode) LIKE 'W54%'
              OR UPPER(icdcode) LIKE 'W55%'
              OR UPPER(icdcode) = 'Z20.3'
              OR UPPER(icdcode) = 'Z24.2'
            THEN 1 ELSE 0 END) AS is_target_icd
    FROM raw_data
    GROUP BY maskedcardno, claimno
),

index_claims_raw AS (
    SELECT 
        maskedcardno,
        claimno AS index_claimno,
        admissiondate AS index_date,
        ROW_NUMBER() OVER (PARTITION BY maskedcardno ORDER BY admissiondate ASC, claimno ASC) AS rn
    FROM base_data
    WHERE is_target_icd = 1
),

index_claims AS (
    SELECT 
        maskedcardno, 
        index_claimno, 
        index_date
    FROM index_claims_raw
    WHERE rn = 1
),

sequenced_claims AS (
    SELECT
        b.*,
        f.index_date,
        f.index_claimno,
        CASE 
            WHEN b.claimno = f.index_claimno THEN 0
            WHEN b.admissiondate < f.index_date OR (b.admissiondate = f.index_date AND b.claimno < f.index_claimno) THEN
                -1 * ROW_NUMBER() OVER (
                    PARTITION BY b.maskedcardno, CASE WHEN b.admissiondate < f.index_date OR (b.admissiondate = f.index_date AND b.claimno < f.index_claimno) THEN 1 ELSE 0 END
                    ORDER BY b.admissiondate DESC, b.claimno DESC
                )
            WHEN b.admissiondate > f.index_date OR (b.admissiondate = f.index_date AND b.claimno > f.index_claimno) THEN
                ROW_NUMBER() OVER (
                    PARTITION BY b.maskedcardno, CASE WHEN b.admissiondate > f.index_date OR (b.admissiondate = f.index_date AND b.claimno > f.index_claimno) THEN 1 ELSE 0 END
                    ORDER BY b.admissiondate ASC, b.claimno ASC
                )
        END AS claim_sequence
    FROM base_data b
    LEFT JOIN index_claims f
        ON b.maskedcardno = f.maskedcardno
)

SELECT
    *,
    
    {% if target.type == 'bigquery' %}

        DATE_DIFF(CAST(admissiondate AS DATE), CAST(index_date AS DATE), MONTH) AS relative_month_bucket,
        DATE_DIFF(CAST(admissiondate AS DATE), CAST(index_date AS DATE), WEEK) AS relative_week_bucket,

        -- 12-month pre/post bucket
        CASE 
            WHEN DATE_DIFF(CAST(admissiondate AS DATE), CAST(index_date AS DATE), MONTH) BETWEEN -12 AND -1 THEN -1
            WHEN DATE_DIFF(CAST(admissiondate AS DATE), CAST(index_date AS DATE), MONTH) = 0 THEN 0
            WHEN DATE_DIFF(CAST(admissiondate AS DATE), CAST(index_date AS DATE), MONTH) BETWEEN 1 AND 12 THEN 1
            ELSE NULL
        END AS relative_12month_bucket

    {% else %}

        CAST((EXTRACT(YEAR FROM admissiondate) - EXTRACT(YEAR FROM index_date)) * 12 + 
        (EXTRACT(MONTH FROM admissiondate) - EXTRACT(MONTH FROM index_date)) AS INTEGER) AS relative_month_bucket,
        CAST(FLOOR((CAST(admissiondate AS DATE) - CAST(index_date AS DATE)) / 7.0) AS INTEGER) AS relative_week_bucket,

        -- 12-month pre/post bucket
        CASE 
            WHEN ((EXTRACT(YEAR FROM admissiondate) - EXTRACT(YEAR FROM index_date)) * 12 + 
                (EXTRACT(MONTH FROM admissiondate) - EXTRACT(MONTH FROM index_date))) BETWEEN -12 AND -1 THEN -1
            WHEN ((EXTRACT(YEAR FROM admissiondate) - EXTRACT(YEAR FROM index_date)) * 12 + 
                (EXTRACT(MONTH FROM admissiondate) - EXTRACT(MONTH FROM index_date))) = 0 THEN 0
            WHEN ((EXTRACT(YEAR FROM admissiondate) - EXTRACT(YEAR FROM index_date)) * 12 + 
                (EXTRACT(MONTH FROM admissiondate) - EXTRACT(MONTH FROM index_date))) BETWEEN 1 AND 12 THEN 1
            ELSE NULL
        END AS relative_12month_bucket

    {% endif %}

FROM sequenced_claims
