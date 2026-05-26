{{ config(materialized='table') }}

WITH procedure_claim_lines AS (
    -- filtering by lab claims
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

fy2024_lab_members AS (
    -- pulling all members who had lab claims in fy2024
    SELECT DISTINCT
        maskedcardno
    FROM procedure_claim_lines
    WHERE admissiondate < DATE '2024-08-31'
),

eligible_fy2025_claims AS (
    -- pulling only FY2025 claims from members who did not have lab claims in FY2024
    SELECT DISTINCT
        pcl.maskedcardno,
        pcl.claimno,
        pcl.admissiondate
    FROM procedure_claim_lines pcl
    WHERE pcl.admissiondate >= DATE '2024-08-31'
      AND NOT EXISTS (
          SELECT 1
          FROM fy2024_lab_members f24
          WHERE f24.maskedcardno = pcl.maskedcardno
      )
),

first_fy2025_claim_ids AS (
    -- pulling the earliest claim for each member from the eligible claims
    SELECT DISTINCT
        maskedcardno,
        claimno,
        admissiondate
    FROM (
        SELECT
            maskedcardno,
            claimno,
            admissiondate,
            DENSE_RANK() OVER (
                PARTITION BY maskedcardno
                ORDER BY admissiondate, claimno
            ) AS claim_sequence
        FROM eligible_fy2025_claims
    ) ranked_claims
    WHERE claim_sequence = 1
),

first_fy2025_claim_lines AS (
    SELECT
        pcl.*
    FROM procedure_claim_lines pcl
    INNER JOIN first_fy2025_claim_ids f
        ON pcl.maskedcardno = f.maskedcardno
       AND pcl.claimno = f.claimno
       AND pcl.admissiondate = f.admissiondate
)
SELECT

    MAX(maskedcardno) AS maskedcardno,
    MAX(loatype) AS loatype,
    claimno,
    MAX(admissiondate) AS admissiondate,
    MAX(icdcode) AS icdcode,
    MAX(ruvcode) AS ruvcode,
    STRING_AGG(DISTINCT cptdesc, ', ' ORDER BY cptdesc) AS cptdesc,
    MAX(primaryicddesc) AS primaryicddesc,
    MAX(primaryicdgroup) AS primaryicdgroup,
    MAX(physicianname) AS physicianname,
    MAX(physiciancode) AS physiciancode,
    MAX(mainspecialization) AS mainspecialization,
    MAX(age) AS age,
    MAX(gender) AS gender,
    MAX(corpcode) AS corpcode,
    MAX(branchdesc) AS branchdesc,
    MAX(membershiptype) AS membershiptype,
    MAX(benefitid) AS benefitid,
    COALESCE(SUM(approved), 0) AS approved
FROM first_fy2025_claim_lines
GROUP BY claimno
ORDER BY maskedcardno, admissiondate, claimno


