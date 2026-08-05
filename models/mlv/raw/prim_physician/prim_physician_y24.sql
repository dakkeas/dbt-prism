{{ config(materialized='table')}}

-- 2024 Cohort Version: primary physician per subsequent claim for y24

WITH raw_claims_window AS (
    SELECT * FROM {{ ref('mxc_raw_claims') }} WHERE source_year = 2024
),
base_data AS (
    SELECT
        rc.claimno,
        rc.physiciancode,
        SUM(rc.approved) AS total_approved,
        CASE 
            WHEN rc.coverageitemdesc ILIKE '%DOCTOR%' THEN 'DOCTOR SERVICES'
            WHEN rc.coverageitemdesc ILIKE '%CONSULT%' THEN 'CONSULT/ATTENDING PHYSICIAN'
            WHEN rc.coverageitemdesc ILIKE '%SURGEON%' THEN 'SURGEON'
            WHEN rc.coverageitemdesc ILIKE '%ANESTHESIO%' THEN 'ANESTHESIOLOGIST'
            ELSE 'OTHER'
        END AS role_type
    FROM raw_claims_window rc
    WHERE rc.physiciancode IS NOT NULL 
      AND TRIM(rc.physiciancode) NOT IN ('', '0', '0,', 'NULL', ' ')
    GROUP BY rc.claimno, rc.physiciancode, 
        CASE 
            WHEN rc.coverageitemdesc ILIKE '%DOCTOR%' THEN 'DOCTOR SERVICES'
            WHEN rc.coverageitemdesc ILIKE '%CONSULT%' THEN 'CONSULT/ATTENDING PHYSICIAN'
            WHEN rc.coverageitemdesc ILIKE '%SURGEON%' THEN 'SURGEON'
            WHEN rc.coverageitemdesc ILIKE '%ANESTHESIO%' THEN 'ANESTHESIOLOGIST'
            ELSE 'OTHER'
        END
),
ranked_data AS (
    SELECT 
        *,
        DENSE_RANK() OVER (PARTITION BY claimno ORDER BY total_approved DESC) as rank_money
    FROM base_data
),
claim_stats AS (
    SELECT
        claimno,
        COUNT(DISTINCT CASE WHEN role_type ILIKE '%DOCTOR%' THEN physiciancode END) as cnt_doc,
        COUNT(DISTINCT CASE WHEN role_type ILIKE '%CONSULT%' THEN physiciancode END) as cnt_consult,
        COUNT(DISTINCT CASE WHEN role_type ILIKE '%SURGEON%' THEN physiciancode END) as cnt_surgeon,
        COUNT(DISTINCT CASE WHEN role_type ILIKE '%ANESTHESIO%' THEN physiciancode END) as cnt_anesth,
        COUNT(DISTINCT physiciancode) as total_docs,

        MAX(CASE WHEN role_type ILIKE '%DOCTOR%' THEN physiciancode END) as prim_doc,
        MAX(CASE WHEN role_type ILIKE '%CONSULT%' THEN physiciancode END) as prim_consult,
        MAX(CASE WHEN role_type ILIKE '%SURGEON%' THEN physiciancode END) as prim_surgeon,
        MAX(CASE WHEN role_type ILIKE '%ANESTHESIO%' THEN physiciancode END) as prim_anesth,

        COUNT(DISTINCT CASE WHEN rank_money = 1 THEN physiciancode END) as cnt_top_approved_docs,
        MAX(CASE WHEN rank_money = 1 THEN physiciancode END) as prim_top_approved
    FROM ranked_data
    GROUP BY claimno
)
SELECT
    s.subsequent_claimno,
    
    CASE 
        WHEN stats.cnt_doc = 1 THEN stats.prim_doc
        WHEN COALESCE(stats.cnt_doc, 0) != 1 AND stats.cnt_consult = 1 THEN stats.prim_consult
        WHEN COALESCE(stats.cnt_doc, 0) != 1 AND COALESCE(stats.cnt_consult, 0) != 1 AND stats.cnt_surgeon = 1 THEN stats.prim_surgeon
        WHEN COALESCE(stats.cnt_doc, 0) != 1 AND COALESCE(stats.cnt_consult, 0) != 1 AND COALESCE(stats.cnt_surgeon, 0) != 1 AND stats.cnt_anesth = 1 THEN stats.prim_anesth
        ELSE 'NO PRIMARY DOCTOR'
    END AS subsequent_primary_physiciancode_by_rank,

    CASE 
        WHEN stats.cnt_top_approved_docs = 1 THEN stats.prim_top_approved
        ELSE 'NO PRIMARY DOCTOR'
    END AS subsequent_primary_physiciancode_by_approved_amount

FROM {{ ref('subsequent_claims_y24') }} s
LEFT JOIN claim_stats stats ON s.subsequent_claimno = stats.claimno
