{{ config(materialized='table')}}


WITH acn_clean AS (
    SELECT
        CONCAT(
            UPPER(TRIM(cptdesc)), '-',
            icdcode, '-',
            UPPER(TRIM(providername)), '-',
            UPPER(TRIM(membershiptype))
        ) AS cpt_icd_provider,

        UPPER(TRIM(providername)) AS providername_clean,
        providername,
        UPPER(TRIM(membershiptype)) AS membershiptype,

        cptdesc AS cpt,
        UPPER(TRIM(cptdesc)) AS cpt_cleaned,
        icdcode AS icd,
        MAX(primaryicdgroup) AS primaryicdgroup,
        MAX(primaryicddesc) AS primaryicddesc,

        SUM(approved) AS total_utilization,
        COUNT(*) AS lineitem_count,
        COUNT(DISTINCT claimno) AS unique_claim_count,
        COUNT(DISTINCT maskedcardno) AS unique_member_count,
        COUNT(DISTINCT physicianname) AS unique_doctor_count,

        ROUND(CAST(SUM(approved) AS NUMERIC) / NULLIF(COUNT(*), 0), 2) AS average_cost_per_lineitem,
        ROUND(CAST(SUM(approved) AS NUMERIC) / NULLIF(COUNT(DISTINCT claimno), 0), 2) AS average_cost_per_claim,
        ROUND(CAST(SUM(approved) AS NUMERIC) / NULLIF(COUNT(DISTINCT maskedcardno), 0), 2) AS average_cost_per_member

    FROM {{ ref('masked_acn_2325') }}

    WHERE loatype = 'PROCEDURE'
      AND icdcode IS NOT NULL
      AND icdcode NOT IN (' ', '0', '')
      AND cptdesc IS NOT NULL
      AND cptdesc NOT IN (' ', '0', '')
      AND providername IS NOT NULL
      AND providername NOT IN (' ', '0', '')
      AND admissiondate >= DATE '2024-09-01'

    GROUP BY
        cptdesc,
        icdcode,
        providername,
        UPPER(TRIM(membershiptype))
),

pcc_clean AS (
    SELECT DISTINCT
        TRIM(UPPER(pccbranchname)) AS pccbranchname  
    FROM {{ ref('pcc_availments_raw_data') }}
),
cpt_standardized AS (
    SELECT DISTINCT
        cpt_cleaned,
        test_type,
        test_classification,
        cpt_cleaned_standard
    FROM {{ ref('cpt_standardized') }}
)
SELECT
    acn.cpt_icd_provider,
    acn.cpt,
    acn.cpt_cleaned,
    cs.cpt_cleaned_standard,
    cs.test_type,
    cs.test_classification,
    acn.icd,
    acn.primaryicddesc,
    acn.primaryicdgroup,
    acn.providername,
    acn.membershiptype,
    CASE
        WHEN pcc.pccbranchname IS NULL THEN 0
        ELSE 1
    END AS is_pcc,


    acn.total_utilization,
    acn.unique_claim_count,
    acn.lineitem_count,
    acn.unique_member_count,
    acn.unique_doctor_count,
    acn.average_cost_per_lineitem,
    acn.average_cost_per_claim,
    acn.average_cost_per_member

FROM acn_clean acn

LEFT JOIN pcc_clean pcc
    ON acn.providername_clean = pcc.pccbranchname  
LEFT JOIN cpt_standardized cs
    ON acn.cpt_cleaned = cs.cpt_cleaned
WHERE total_utilization IS NOT NULL
AND total_utilization <> 0

ORDER BY acn.unique_claim_count DESC
