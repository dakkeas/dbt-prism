{{ config(materialized='table') }}

WITH non_pcc_ranked AS (
    SELECT
        cpt_cleaned_standard,
        icd,
        providername,
        average_cost_per_lineitem,
        ROW_NUMBER() OVER (PARTITION BY cpt_cleaned_standard, icd ORDER BY average_cost_per_lineitem DESC) AS rank_most_expensive,
        ROW_NUMBER() OVER (PARTITION BY cpt_cleaned_standard, icd ORDER BY average_cost_per_lineitem ASC) AS rank_cheapest
    FROM {{ ref('cpt_icd_provider') }}
    WHERE is_pcc = 0
    --   AND cpt_cleaned_standard IS NOT NULL
),

most_expensive AS (
    SELECT
        cpt_cleaned_standard,
        icd,
        providername AS provider,
        average_cost_per_lineitem AS cost
    FROM non_pcc_ranked
    WHERE rank_most_expensive = 1
),

cheapest AS (
    SELECT
        cpt_cleaned_standard,
        icd,
        providername AS provider,
        average_cost_per_lineitem AS cost
    FROM non_pcc_ranked
    WHERE rank_cheapest = 1
),

pcc_branches AS (
    SELECT
        cpt_cleaned_standard,
        icd,
        STRING_AGG(DISTINCT providername, ', ' ORDER BY providername) AS pcc_branches_available
    FROM {{ ref('cpt_icd_provider') }}
    WHERE is_pcc = 1
    --   AND cpt_cleaned_standard IS NOT NULL
    GROUP BY cpt_cleaned_standard, icd
)

SELECT
    CONCAT(o.cpt_cleaned_standard, '-', o.icd) AS cpt_standardized_icd,
    STRING_AGG(DISTINCT o.cpt, ', ' ORDER BY o.cpt) AS cpt,
    STRING_AGG(DISTINCT o.cpt_cleaned, ', ' ORDER BY o.cpt_cleaned) AS cpt_original,
    o.cpt_cleaned_standard AS cpt_standardized,
    MAX(o.test_type) AS test_type,
    MAX(o.test_classification) AS test_classification,
    o.icd,
    MAX(o.primaryicddesc) AS primaryicddesc,
    MAX(o.primaryicdgroup) AS primaryicdgroup,

    -- Is PCC flag for this CPT-ICD pairing
    CASE WHEN MAX(o.is_pcc) = 1 THEN 'Yes' ELSE 'No' END AS is_pcc,

    -- Overall metrics
    COALESCE(SUM(o.total_utilization), 0) AS total_utilization,
    COALESCE(SUM(o.lineitem_count), 0) AS lineitem_count,
    COALESCE(SUM(o.unique_claim_count), 0) AS unique_claim_count,
    COALESCE(SUM(o.unique_member_count), 0) AS unique_member_count,
    COALESCE(SUM(o.unique_doctor_count), 0) AS unique_doctor_count,
    COALESCE(ROUND(CAST(SUM(o.average_cost_per_claim * o.unique_claim_count) AS NUMERIC) / NULLIF(SUM(o.unique_claim_count), 0), 2), 0) AS average_cost_per_claim,
    COALESCE(ROUND(CAST(SUM(o.average_cost_per_lineitem * o.lineitem_count) AS NUMERIC) / NULLIF(SUM(o.lineitem_count), 0), 2), 0) AS average_cost_per_lineitem,
    COALESCE(ROUND(CAST(SUM(o.average_cost_per_member * o.unique_member_count) AS NUMERIC) / NULLIF(SUM(o.unique_member_count), 0), 2), 0) AS average_cost_per_member,

    -- Non-PCC metrics
    COALESCE(SUM(CASE WHEN o.is_pcc = 0 THEN o.total_utilization ELSE 0 END), 0) AS non_pcc_total_utilization,
    COALESCE(SUM(CASE WHEN o.is_pcc = 0 THEN o.lineitem_count ELSE 0 END), 0) AS non_pcc_lineitem_count,
    COALESCE(SUM(CASE WHEN o.is_pcc = 0 THEN o.unique_claim_count ELSE 0 END), 0) AS non_pcc_unique_claim_count,
    COALESCE(SUM(CASE WHEN o.is_pcc = 0 AND o.membershiptype = 'PRINCIPAL' THEN o.total_utilization ELSE 0 END), 0) AS non_pcc_principal_total_utilization,
    COALESCE(SUM(CASE WHEN o.is_pcc = 0 AND o.membershiptype = 'PRINCIPAL' THEN o.lineitem_count ELSE 0 END), 0) AS non_pcc_principal_lineitem_count,
    COALESCE(SUM(CASE WHEN o.is_pcc = 0 AND o.membershiptype = 'PRINCIPAL' THEN o.unique_claim_count ELSE 0 END), 0) AS non_pcc_principal_unique_claim_count,
    COALESCE(ROUND(CAST(SUM(CASE WHEN o.is_pcc = 0 AND o.membershiptype = 'PRINCIPAL' THEN o.average_cost_per_lineitem * o.lineitem_count ELSE 0 END) AS NUMERIC) / NULLIF(SUM(CASE WHEN o.is_pcc = 0 AND o.membershiptype = 'PRINCIPAL' THEN o.lineitem_count ELSE 0 END), 0), 2), 0) AS non_pcc_principal_average_cost_per_lineitem,
    COALESCE(SUM(CASE WHEN o.is_pcc = 0 AND o.membershiptype = 'DEPENDENT' THEN o.total_utilization ELSE 0 END), 0) AS non_pcc_dependent_total_utilization,
    COALESCE(SUM(CASE WHEN o.is_pcc = 0 AND o.membershiptype = 'DEPENDENT' THEN o.lineitem_count ELSE 0 END), 0) AS non_pcc_dependent_lineitem_count,
    COALESCE(SUM(CASE WHEN o.is_pcc = 0 AND o.membershiptype = 'DEPENDENT' THEN o.unique_claim_count ELSE 0 END), 0) AS non_pcc_dependent_unique_claim_count,
    COALESCE(ROUND(CAST(SUM(CASE WHEN o.is_pcc = 0 AND o.membershiptype = 'DEPENDENT' THEN o.average_cost_per_lineitem * o.lineitem_count ELSE 0 END) AS NUMERIC) / NULLIF(SUM(CASE WHEN o.is_pcc = 0 AND o.membershiptype = 'DEPENDENT' THEN o.lineitem_count ELSE 0 END), 0), 2), 0) AS non_pcc_dependent_average_cost_per_lineitem,
    COALESCE(SUM(CASE WHEN o.is_pcc = 0 THEN o.unique_member_count ELSE 0 END), 0) AS non_pcc_unique_member_count,
    COALESCE(SUM(CASE WHEN o.is_pcc = 0 THEN o.unique_doctor_count ELSE 0 END), 0) AS non_pcc_unique_doctor_count,
    COALESCE(ROUND(CAST(SUM(CASE WHEN o.is_pcc = 0 THEN o.average_cost_per_claim * o.unique_claim_count ELSE 0 END) AS NUMERIC) / NULLIF(SUM(CASE WHEN o.is_pcc = 0 THEN o.unique_claim_count ELSE 0 END), 0), 2), 0) AS non_pcc_average_cost_per_claim,
    COALESCE(ROUND(CAST(SUM(CASE WHEN o.is_pcc = 0 THEN o.average_cost_per_lineitem * o.lineitem_count ELSE 0 END) AS NUMERIC) / NULLIF(SUM(CASE WHEN o.is_pcc = 0 THEN o.lineitem_count ELSE 0 END), 0), 2), 0) AS non_pcc_average_cost_per_lineitem,
    COALESCE(ROUND(CAST(SUM(CASE WHEN o.is_pcc = 0 THEN o.average_cost_per_member * o.unique_member_count ELSE 0 END) AS NUMERIC) / NULLIF(SUM(CASE WHEN o.is_pcc = 0 THEN o.unique_member_count ELSE 0 END), 0), 2), 0) AS non_pcc_average_cost_per_member,
    MAX(me.provider) AS non_pcc_most_expensive_provider,
    COALESCE(MAX(me.cost), 0) AS non_pcc_cost_of_most_expensive_provider,
    MAX(ch.provider) AS non_pcc_cheapest_provider,
    COALESCE(MAX(ch.cost), 0) AS non_pcc_cost_of_cheapest_provider,

    -- PCC metrics
    CASE WHEN MAX(o.is_pcc) = 1 THEN 'Yes' ELSE 'No' END AS pcc_test_available,
    COALESCE(SUM(CASE WHEN o.is_pcc = 1 THEN o.total_utilization ELSE 0 END), 0) AS pcc_total_utilization,
    COALESCE(SUM(CASE WHEN o.is_pcc = 1 THEN o.lineitem_count ELSE 0 END), 0) AS pcc_lineitem_count,
    COALESCE(SUM(CASE WHEN o.is_pcc = 1 THEN o.unique_claim_count ELSE 0 END), 0) AS pcc_unique_claim_count,
    COALESCE(SUM(CASE WHEN o.is_pcc = 1 AND o.membershiptype = 'PRINCIPAL' THEN o.total_utilization ELSE 0 END), 0) AS pcc_principal_total_utilization,
    COALESCE(SUM(CASE WHEN o.is_pcc = 1 AND o.membershiptype = 'PRINCIPAL' THEN o.lineitem_count ELSE 0 END), 0) AS pcc_principal_lineitem_count,
    COALESCE(SUM(CASE WHEN o.is_pcc = 1 AND o.membershiptype = 'PRINCIPAL' THEN o.unique_claim_count ELSE 0 END), 0) AS pcc_principal_unique_claim_count,
    COALESCE(ROUND(CAST(SUM(CASE WHEN o.is_pcc = 1 AND o.membershiptype = 'PRINCIPAL' THEN o.average_cost_per_lineitem * o.lineitem_count ELSE 0 END) AS NUMERIC) / NULLIF(SUM(CASE WHEN o.is_pcc = 1 AND o.membershiptype = 'PRINCIPAL' THEN o.lineitem_count ELSE 0 END), 0), 2), 0) AS pcc_principal_average_cost_per_lineitem,
    COALESCE(SUM(CASE WHEN o.is_pcc = 1 AND o.membershiptype = 'DEPENDENT' THEN o.total_utilization ELSE 0 END), 0) AS pcc_dependent_total_utilization,
    COALESCE(SUM(CASE WHEN o.is_pcc = 1 AND o.membershiptype = 'DEPENDENT' THEN o.lineitem_count ELSE 0 END), 0) AS pcc_dependent_lineitem_count,
    COALESCE(SUM(CASE WHEN o.is_pcc = 1 AND o.membershiptype = 'DEPENDENT' THEN o.unique_claim_count ELSE 0 END), 0) AS pcc_dependent_unique_claim_count,
    COALESCE(ROUND(CAST(SUM(CASE WHEN o.is_pcc = 1 AND o.membershiptype = 'DEPENDENT' THEN o.average_cost_per_lineitem * o.lineitem_count ELSE 0 END) AS NUMERIC) / NULLIF(SUM(CASE WHEN o.is_pcc = 1 AND o.membershiptype = 'DEPENDENT' THEN o.lineitem_count ELSE 0 END), 0), 2), 0) AS pcc_dependent_average_cost_per_lineitem,
    COALESCE(SUM(CASE WHEN o.is_pcc = 1 THEN o.unique_member_count ELSE 0 END), 0) AS pcc_unique_member_count,
    COALESCE(SUM(CASE WHEN o.is_pcc = 1 THEN o.unique_doctor_count ELSE 0 END), 0) AS pcc_unique_doctor_count,
    COALESCE(ROUND(CAST(SUM(CASE WHEN o.is_pcc = 1 THEN o.average_cost_per_claim * o.unique_claim_count ELSE 0 END) AS NUMERIC) / NULLIF(SUM(CASE WHEN o.is_pcc = 1 THEN o.unique_claim_count ELSE 0 END), 0), 2), 0) AS pcc_average_cost_per_claim,
    COALESCE(ROUND(CAST(SUM(CASE WHEN o.is_pcc = 1 THEN o.average_cost_per_lineitem * o.lineitem_count ELSE 0 END) AS NUMERIC) / NULLIF(SUM(CASE WHEN o.is_pcc = 1 THEN o.lineitem_count ELSE 0 END), 0), 2), 0) AS pcc_average_cost_per_lineitem,
    COALESCE(ROUND(CAST(SUM(CASE WHEN o.is_pcc = 1 THEN o.average_cost_per_member * o.unique_member_count ELSE 0 END) AS NUMERIC) / NULLIF(SUM(CASE WHEN o.is_pcc = 1 THEN o.unique_member_count ELSE 0 END), 0), 2), 0) AS pcc_average_cost_per_member,
    MAX(pb.pcc_branches_available) AS pcc_branches_available

FROM {{ ref('cpt_icd_provider') }} o
LEFT JOIN most_expensive me
    ON me.cpt_cleaned_standard = o.cpt_cleaned_standard
    AND me.icd = o.icd
LEFT JOIN cheapest ch
    ON ch.cpt_cleaned_standard = o.cpt_cleaned_standard
    AND ch.icd = o.icd
LEFT JOIN pcc_branches pb
    ON pb.cpt_cleaned_standard = o.cpt_cleaned_standard
    AND pb.icd = o.icd
-- WHERE o.cpt_cleaned_standard IS NOT NULL
GROUP BY
    o.cpt_cleaned_standard,
    o.icd
ORDER BY total_utilization DESC
