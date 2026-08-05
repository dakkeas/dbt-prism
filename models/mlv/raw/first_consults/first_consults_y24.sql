{{ config(materialized = 'table')}}

-- 2024 Cohort Version: 2022 cool-off period, claims window 2024

WITH raw_claims_cool_off AS (
    SELECT * FROM {{ ref('mxc_raw_claims') }} WHERE source_year = 2022
),
raw_claims_window AS (
    SELECT * FROM {{ ref('mxc_raw_claims') }} WHERE source_year = 2024
),
cool_off_period AS (
    SELECT
        rc.claimno AS claimno,
        rc.physiciancode AS physiciancode,
        rc.coverageitemdesc AS coverageitemdesc,
        DENSE_RANK() OVER (PARTITION BY c.maskedcardno ORDER BY rc.admissiondate, rc.claimno) AS claim_sequence
    FROM (
        SELECT
            rc2.maskedcardno AS maskedcardno
        FROM
            raw_claims_window rc2
        LEFT JOIN
            raw_claims_cool_off rc1
        ON 
            rc1.maskedcardno = rc2.maskedcardno
        WHERE
            rc1.maskedcardno IS NULL
        GROUP BY rc2.maskedcardno
    ) c
    INNER JOIN raw_claims_window rc
    ON c.maskedcardno = rc.maskedcardno
    WHERE
        rc.primaryicdcode IN (SELECT icdcode FROM {{ref('blp_icdcodes_v2')}})
        AND rc.loatype IN ('OP LAB', 'OP_CONSULT')
),
aggregate_starting_claim AS (
    SELECT 
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
    INNER JOIN raw_claims_window rc
    ON t.claimno = rc.claimno
    GROUP BY t.claimno, rc.maskedcardno
)
SELECT * FROM aggregate_starting_claim
