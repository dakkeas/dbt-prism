{{ config(materialized='table') }}

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
FROM {{ ref('fy2025_new_px_first_claims') }}
GROUP BY claimno
ORDER BY MAX(maskedcardno), MAX(admissiondate), claimno
