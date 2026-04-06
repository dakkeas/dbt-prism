{{ config(materialized='table')}}


WITH raw_claims_2023_2025 AS (
    SELECT * FROM {{ ref('mxc_raw_claims') }} WHERE source_year >= 2023
),
unique_doctors_per_claim AS (
    -- Step 1: Calculate Total Approved & Primary Role per Doctor
    SELECT
        rc.claimno,
        rc.physiciancode,
        -- Sum up all money for this doctor on this claim
        SUM(rc.approved) AS total_doctor_approved,
        SUM(rc.billed) AS total_doctor_billed,
        rc.coverageitemdesc AS coverageitemdesc
        -- Assign a priority score to the doctor based on their "best" role on this claim
    FROM 
        {{ref('subsequent_claims')}} s -- dependent on subs table
    INNER JOIN
        raw_claims_2023_2025 rc
          ON rc.claimno = s.subsequent_claimno
    WHERE
        rc.physiciancode IS NOT NULL
        AND TRIM(rc.physiciancode) NOT IN ('', '0', '0,', 'NULL', ' ' )
    GROUP BY
        rc.claimno,
        rc.physiciancode,
        rc.coverageitemdesc
),
ranked AS (
    -- Step 2: Rank the Doctors
    SELECT
        u.claimno,
        u.physiciancode,
        u.coverageitemdesc,
        u.total_doctor_approved,
        u.total_doctor_billed,
        DENSE_RANK() OVER (
        PARTITION BY u.claimno 
        ORDER BY
            -- 1. Rank by Description Priority first
            CASE 
                WHEN u.coverageitemdesc ILIKE '%DOCTOR%' THEN 1
                WHEN u.coverageitemdesc ILIKE '%CONSULT%' THEN 2
                WHEN u.coverageitemdesc ILIKE '%SURGEON%' THEN 3
                WHEN u.coverageitemdesc ILIKE '%ANESTHESIO%' THEN 4
                ELSE 99 -- Force "Others" to the bottom
            END ASC
            -- 2. (Optional) Tie-breaker: If types are the same, rank by amount
    ) AS ranked_by_type,
        DENSE_RANK() OVER (
            PARTITION BY u.claimno 
            ORDER BY
            u.total_doctor_approved DESC
        ) AS ranked_by_approved
    FROM 
        unique_doctors_per_claim u
)
SELECT * FROM ranked
-- Step 2: Rank the Doctors