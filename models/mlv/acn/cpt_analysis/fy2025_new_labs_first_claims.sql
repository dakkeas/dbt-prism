{{ config(materialized='table') }}

WITH procedure_claim_lines AS (
    SELECT
        claimno,
        corpcode,
        branchdesc,
        admissiondate,
        gender,
        membershiptype,
        mainspecialization,
        loatype,
        icdcode,
        approved,
        age,
        benefitid,
        ruvcode,
        cptdesc,
        physicianname,
        physiciancode,
        maskedcardno,
        primaryicddesc,
        primaryicdgroup
    FROM {{ ref('masked_acn_2325') }}
    WHERE maskedcardno IS NOT NULL
      AND admissiondate >= DATE '2023-08-31'
      AND admissiondate < DATE '2025-09-01'
      AND TRIM(loatype) = 'PROCEDURE'
),

procedure_claims AS (
    SELECT
        claimno,
        MAX(corpcode) AS corpcode,
        MAX(branchdesc) AS branchdesc,
        MAX(admissiondate) AS admissiondate,
        MAX(gender) AS gender,
        MAX(membershiptype) AS membershiptype,
        MAX(mainspecialization) AS mainspecialization,
        MAX(loatype) AS loatype,
        MAX(icdcode) AS icdcode,
        SUM(approved) AS approved,
        MAX(age) AS age,
        MAX(benefitid) AS benefitid,
        MAX(ruvcode) AS ruvcode,
        STRING_AGG(DISTINCT cptdesc, ', ' ORDER BY cptdesc) AS cptdesc,
        MAX(physicianname) AS physicianname,
        MAX(physiciancode) AS physiciancode,
        MAX(maskedcardno) AS maskedcardno,
        MAX(primaryicddesc) AS primaryicddesc,
        MAX(primaryicdgroup) AS primaryicdgroup
    FROM procedure_claim_lines
    GROUP BY claimno
),

fy2024_lab_members AS (
    SELECT DISTINCT
        maskedcardno
    FROM procedure_claims
    WHERE admissiondate < DATE '2024-08-31'
),

ranked_fy2025_lab_claims AS (
    SELECT
        pc.*,
        ROW_NUMBER() OVER (
            PARTITION BY pc.maskedcardno
            ORDER BY pc.admissiondate, pc.claimno
        ) AS claim_sequence
    FROM procedure_claims pc
    WHERE pc.admissiondate >= DATE '2024-08-31'
      AND NOT EXISTS (
          SELECT 1
          FROM fy2024_lab_members f24
          WHERE f24.maskedcardno = pc.maskedcardno
      )
)

SELECT
    *
FROM ranked_fy2025_lab_claims
WHERE claim_sequence = 1
ORDER BY maskedcardno, admissiondate, claimno
