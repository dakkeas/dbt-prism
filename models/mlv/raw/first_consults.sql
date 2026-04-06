
{{ config(materialized = 'table')}} -- creates a table

-- VETTING VERSION: Uses mxc_raw_claims source tables instead of raw_claims_2023_2025 / raw_claims_2022
-- Purpose: to check dataset integrity

WITH raw_claims_2022 AS (
    SELECT * FROM {{ ref('mxc_raw_claims') }} WHERE source_year = 2022
),
raw_claims_2023_2025 AS (
    SELECT * FROM {{ ref('mxc_raw_claims') }} WHERE source_year >= 2023
),
cool_off_period AS ( -- produces unique patients
    SELECT
        rc.claimno AS claimno,
        rc.physiciancode AS physiciancode,
        rc.coverageitemdesc AS coverageitemdesc,
        DENSE_RANK() OVER (PARTITION BY c.maskedcardno ORDER BY rc.admissiondate, rc.claimno) -- counter on each row (grouped by maskedcardno) by admissiondate, claimno
        AS claim_sequence
        FROM  (
            SELECT
                rc2.maskedcardno AS maskedcardno
            FROM
                raw_claims_2023_2025 rc2
            LEFT JOIN -- selects claims from 2023 - 2025 data
                raw_claims_2022 rc1
            ON 
                rc1.maskedcardno = rc2.maskedcardno -- gets rows from left table + matching rows from right table
            WHERE
                rc1.maskedcardno IS NULL -- for maskedcardno that are in 2022 but not in 2023 (meaning there are no claims in 2022)
                -- since there wouldnt be any maskedcardno rows in 2022
            GROUP BY rc2.maskedcardno -- ensures no duplicates  
        ) c
        INNER JOIN raw_claims_2023_2025 rc -- joining with raw
        ON c.maskedcardno = rc.maskedcardno
        WHERE
            rc.primaryicdcode IN (SELECT icdcode FROM {{ref('blp_icdcodes_v2')}}) -- primaryicdcode has to be in best life  
            AND rc.loatype IN ('OP LAB', 'OP_CONSULT') -- has to be the ff loatypes
),
aggregate_starting_claim AS (
    -- aggregating by into a single row 
    SELECT 
        -- aggregate into claim number
        rc.maskedcardno,
        t.claimno AS starting_claimno,
        MIN(rc.admissiondate) AS starting_admissiondate, 
        MIN(rc.dischargedate) AS starting_dischargedate, 

        COALESCE(
            MAX(CASE
                WHEN UPPER(rc.coverageitemdesc) LIKE '%DOCTOR%' 
                AND TRIM(rc.physiciancode) NOT IN ('0', '0,', '')
                AND rc.physiciancode IS NOT NULL
                THEN rc.physiciancode
            END),
            MAX(CASE
                WHEN UPPER(rc.coverageitemdesc) LIKE '%CONSULT%' 
                AND TRIM(rc.physiciancode) NOT IN ('0', '0,', '')
                AND rc.physiciancode IS NOT NULL
                THEN rc.physiciancode
            END),
            MAX(CASE
                WHEN TRIM(rc.physiciancode) NOT IN ('0', '0,', '')
                AND rc.physiciancode IS NOT NULL
                THEN rc.physiciancode
            END)
        ) AS starting_physiciancode,        

        MIN(rc.primaryicdcode) AS starting_primaryicdcode,
        MIN(rc.primaryicdgroup) AS starting_primaryicdgroup,
        MIN(rc.providername) AS starting_providername,
        MIN(rc.loatype) AS starting_loatype
    FROM (
        -- selects first consults only from cool off table that has a single doctor services doctor OR a single doctor. 
        SELECT claimno FROM cool_off_period WHERE claim_sequence = 1
        AND TRIM(physiciancode) NOT IN ('0', '0,', '')
        AND physiciancode IS NOT NULL
        GROUP BY claimno
        HAVING
            COUNT(DISTINCT physiciancode) = 1
            OR COUNT(DISTINCT CASE 
            WHEN coverageitemdesc = 'DOCTOR SERVICES' THEN physiciancode 
            END) = 1
    ) t
    INNER JOIN raw_claims_2023_2025 rc
    ON t.claimno = rc.claimno
    GROUP BY t.claimno, rc.maskedcardno
)
SELECT * FROM aggregate_starting_claim
