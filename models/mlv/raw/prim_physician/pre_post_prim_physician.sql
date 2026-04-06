
{{ config(materialized='view')}}

-- VETTING VERSION: Uses mxc_raw_claims source tables instead of raw_claims_2023_2025
-- Purpose: to check dataset integrity

WITH raw_claims_2023_2025 AS (
    SELECT * FROM {{ ref('mxc_raw_claims') }} WHERE source_year >= 2023
),
-- CREATE TABLE mlv_primary_doctor_per_claim_01272026 AS
base_data AS (
    -- 1. Deduplication & Standardization (1 Pass)
    -- We group by claim and doctor to remove duplicate lines immediately.
    SELECT
        rc.claimno,
        rc.physiciancode,
        SUM(rc.approved) AS total_approved,
        -- Normalize the role descriptions early to make the next steps cleaner
        CASE 
            WHEN rc.coverageitemdesc ILIKE '%DOCTOR%' THEN 'DOCTOR SERVICES'
            WHEN rc.coverageitemdesc ILIKE '%CONSULT%' THEN 'CONSULT/ATTENDING PHYSICIAN'
            WHEN rc.coverageitemdesc ILIKE '%SURGEON%' THEN 'SURGEON'
            WHEN rc.coverageitemdesc ILIKE '%ANESTHESIO%' THEN 'ANESTHESIOLOGIST'
            ELSE 'OTHER'
        END AS role_type
    FROM raw_claims_2023_2025 rc
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
    -- 2. Add Money Rankings (Window Function)
    -- We need this to identify the top earner later
    SELECT 
        *,
        DENSE_RANK() OVER (PARTITION BY claimno ORDER BY total_approved DESC) as rank_money
    FROM base_data
),
claim_stats AS (
    -- 3. Pivot: Calculate Counts AND Candidate Codes in one go
    SELECT
        claimno,
        -- A. Calculate Counts per Type
        COUNT(DISTINCT CASE WHEN role_type ILIKE '%DOCTOR%' THEN physiciancode END) as cnt_doc,
        COUNT(DISTINCT CASE WHEN role_type ILIKE '%CONSULT%' THEN physiciancode END) as cnt_consult,
        COUNT(DISTINCT CASE WHEN role_type ILIKE '%SURGEON%' THEN physiciancode END) as cnt_surgeon,
        COUNT(DISTINCT CASE WHEN role_type ILIKE '%ANESTHESIO%' THEN physiciancode END) as cnt_anesth,
        COUNT(DISTINCT physiciancode) as total_docs,

        -- B. Pre-fetch the "Candidate Code" for each type
        -- If Count=1, MAX() grabs the specific code. If Count>1, we don't use this column anyway.
        MAX(CASE WHEN role_type ILIKE '%DOCTOR%' THEN physiciancode END) as prim_doc,
        MAX(CASE WHEN role_type ILIKE '%CONSULT%' THEN physiciancode END) as prim_consult,
        MAX(CASE WHEN role_type ILIKE '%SURGEON%' THEN physiciancode END) as prim_surgeon,
        MAX(CASE WHEN role_type ILIKE '%ANESTHESIO%' THEN physiciancode END) as prim_anesth,

        -- C. Pre-calculate Money Logic
        COUNT(DISTINCT CASE WHEN rank_money = 1 THEN physiciancode END) as cnt_top_approved_docs,
        MAX(CASE WHEN rank_money = 1 THEN physiciancode END) as prim_top_approved
    FROM ranked_data
    GROUP BY claimno
)
-- 4. Final Selection (Simple Left Join, extremely fast)
SELECT
    s.subsequent_claimno,
    
    -- LOGIC 1: BY RANK (Waterfall)
    CASE 
        -- Priority 1: Doctor Services
        WHEN stats.cnt_doc = 1 THEN stats.prim_doc
        
        -- Priority 2: Consults (Wins if Doc Svc is missing/multiple AND Consult is exactly 1)
        WHEN COALESCE(stats.cnt_doc, 0) != 1 AND stats.cnt_consult = 1 
            THEN stats.prim_consult
            
        -- Priority 3: Surgeon
        WHEN COALESCE(stats.cnt_doc, 0) != 1 AND COALESCE(stats.cnt_consult, 0) != 1 AND stats.cnt_surgeon = 1 
            THEN stats.prim_surgeon
            
        -- Priority 4: Anesthesiologist
        WHEN COALESCE(stats.cnt_doc, 0) != 1 AND COALESCE(stats.cnt_consult, 0) != 1 AND COALESCE(stats.cnt_surgeon, 0) != 1 AND stats.cnt_anesth = 1 
            THEN stats.prim_anesth

        -- Fallbacks
        WHEN COALESCE(stats.total_docs, 0) = 0 THEN 'NO PRIMARY DOCTOR'
        ELSE 'NO PRIMARY DOCTOR'
    END AS subsequent_primary_physiciancode_by_rank,

    -- LOGIC 2: BY APPROVED AMOUNT
    CASE 
        WHEN stats.cnt_top_approved_docs = 1 THEN stats.prim_top_approved
        WHEN COALESCE(stats.total_docs, 0) = 0 THEN 'NO PRIMARY DOCTOR'
        ELSE 'NO PRIMARY DOCTOR'
    END AS subsequent_primary_physiciancode_by_approved_amount

FROM {{ref('pre_post_subsequent_claims')}} s
LEFT JOIN claim_stats stats ON s.subsequent_claimno = stats.claimno

