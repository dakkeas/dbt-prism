
{{ config(materialized='table') }}

WITH non_pcc_ranked AS (
    SELECT
        cpt_cleaned,
        providername,
        average_cost_per_lineitem,
        ROW_NUMBER() OVER (PARTITION BY cpt_cleaned ORDER BY average_cost_per_lineitem DESC) AS rank_most_expensive,
        ROW_NUMBER() OVER (PARTITION BY cpt_cleaned ORDER BY average_cost_per_lineitem ASC) AS rank_cheapest
    FROM {{ ref('cpt_icd_provider') }}
    WHERE is_pcc = 0
),

most_expensive AS (
    SELECT cpt_cleaned, providername AS provider, average_cost_per_lineitem AS cost
    FROM non_pcc_ranked
    WHERE rank_most_expensive = 1
),

cheapest AS (
    SELECT cpt_cleaned, providername AS provider, average_cost_per_lineitem  AS cost
    FROM non_pcc_ranked
    WHERE rank_cheapest = 1
),

pcc_branches AS (
    SELECT
        cpt_cleaned,
        STRING_AGG(DISTINCT providername, ', ' ORDER BY providername) AS pcc_branches_available
    FROM {{ ref('cpt_icd_provider') }}
    WHERE is_pcc = 1
    GROUP BY cpt_cleaned
)

SELECT
    o.cpt_cleaned,
    -- Overall metrics
    COALESCE(SUM(o.total_utilization), 0) AS total_utilization,

    COALESCE(SUM(o.unique_claim_count), 0) AS unique_claim_count,
    COALESCE(SUM(o.lineitem_count), 0) AS lineitem_count,

    COALESCE(SUM(o.unique_member_count), 0) AS unique_member_count,
    COALESCE(SUM(o.unique_doctor_count), 0) AS unique_doctor_count,

    COALESCE(ROUND(CAST(SUM(o.average_cost_per_claim * o.unique_claim_count) AS NUMERIC) / NULLIF(SUM(o.unique_claim_count), 0), 2), 0) AS average_cost_per_claim,
    COALESCE(ROUND(CAST(SUM(o.average_cost_per_lineitem * o.lineitem_count) AS NUMERIC) / NULLIF(SUM(o.lineitem_count), 0), 2), 0) AS average_cost_per_lineitem,

    COALESCE(ROUND(CAST(SUM(o.average_cost_per_member * o.unique_member_count) AS NUMERIC) / NULLIF(SUM(o.unique_member_count), 0), 2), 0) AS average_cost_per_member,
    -- Non-PCC metrics
    COALESCE(SUM(CASE WHEN o.is_pcc = 0 THEN o.total_utilization ELSE 0 END), 0) AS non_pcc_total_utilization,

    COALESCE(SUM(CASE WHEN o.is_pcc = 0 THEN o.lineitem_count ELSE 0 END), 0) AS non_pcc_lineitem_count,
    COALESCE(SUM(CASE WHEN o.is_pcc = 0 THEN o.unique_claim_count ELSE 0 END), 0) AS non_pcc_unique_claim_count,

    COALESCE(SUM(CASE WHEN o.is_pcc = 0 THEN o.unique_member_count ELSE 0 END), 0) AS non_pcc_unique_member_count,
    COALESCE(SUM(CASE WHEN o.is_pcc = 0 THEN o.unique_doctor_count ELSE 0 END), 0) AS non_pcc_unique_doctor_count,

    COALESCE(ROUND(CAST(SUM(CASE WHEN o.is_pcc = 0 THEN o.average_cost_per_claim * o.unique_claim_count ELSE 0 END) AS NUMERIC) / NULLIF(SUM(CASE WHEN o.is_pcc = 0 THEN o.unique_claim_count ELSE 0 END), 0), 2), 0) AS non_pcc_average_cost_per_claim,
    COALESCE(ROUND(CAST(SUM(CASE WHEN o.is_pcc = 0 THEN o.average_cost_per_lineitem * o.lineitem_count ELSE 0 END) AS NUMERIC) / NULLIF(SUM(CASE WHEN o.is_pcc = 0 THEN o.lineitem_count ELSE 0 END), 0), 2), 0) AS non_pcc_average_cost_per_lineitem,

    COALESCE(ROUND(CAST(SUM(CASE WHEN o.is_pcc = 0 THEN o.average_cost_per_member * o.unique_member_count ELSE 0 END) AS NUMERIC) / NULLIF(SUM(CASE WHEN o.is_pcc = 0 THEN o.unique_member_count ELSE 0 END), 0), 2), 0) AS non_pcc_average_cost_per_member,
    -- Non-PCC most/cheapest provider
    me.provider AS non_pcc_most_expensive_provider,
    COALESCE(me.cost, 0) AS non_pcc_cost_of_most_expensive_provider,
    ch.provider AS non_pcc_cheapest_provider,
    COALESCE(ch.cost, 0) AS non_pcc_cost_of_cheapest_provider,
    -- PCC metrics
    CASE WHEN MAX(o.is_pcc) = 1 THEN 'Yes' ELSE 'No' END AS pcc_test_available,
    COALESCE(SUM(CASE WHEN o.is_pcc = 1 THEN o.total_utilization ELSE 0 END), 0) AS pcc_total_utilization,
    COALESCE(SUM(CASE WHEN o.is_pcc = 1 THEN o.lineitem_count ELSE 0 END), 0) AS pcc_lineitem_count,
    COALESCE(SUM(CASE WHEN o.is_pcc = 1 THEN o.unique_claim_count ELSE 0 END), 0) AS pcc_unique_claim_count,
    COALESCE(SUM(CASE WHEN o.is_pcc = 1 THEN o.unique_member_count ELSE 0 END), 0) AS pcc_unique_member_count,
    COALESCE(SUM(CASE WHEN o.is_pcc = 1 THEN o.unique_doctor_count ELSE 0 END), 0) AS pcc_unique_doctor_count,
    COALESCE(ROUND(CAST(SUM(CASE WHEN o.is_pcc = 1 THEN o.average_cost_per_claim * o.unique_claim_count ELSE 0 END) AS NUMERIC) / NULLIF(SUM(CASE WHEN o.is_pcc = 1 THEN o.unique_claim_count ELSE 0 END), 0), 2), 0) AS pcc_average_cost_per_claim,
    COALESCE(ROUND(CAST(SUM(CASE WHEN o.is_pcc = 1 THEN o.average_cost_per_lineitem * o.lineitem_count ELSE 0 END) AS NUMERIC) / NULLIF(SUM(CASE WHEN o.is_pcc = 1 THEN o.lineitem_count ELSE 0 END), 0), 2), 0) AS pcc_average_cost_per_lineitem,

    COALESCE(ROUND(CAST(SUM(CASE WHEN o.is_pcc = 1 THEN o.average_cost_per_member * o.unique_member_count ELSE 0 END) AS NUMERIC) / NULLIF(SUM(CASE WHEN o.is_pcc = 1 THEN o.unique_member_count ELSE 0 END), 0), 2), 0) AS pcc_average_cost_per_member,
    pb.pcc_branches_available

FROM {{ ref('cpt_icd_provider') }} o
LEFT JOIN most_expensive me ON me.cpt_cleaned = o.cpt_cleaned
LEFT JOIN cheapest ch ON ch.cpt_cleaned = o.cpt_cleaned
LEFT JOIN pcc_branches pb ON pb.cpt_cleaned = o.cpt_cleaned
GROUP BY o.cpt_cleaned, me.provider, me.cost, ch.provider, ch.cost, pb.pcc_branches_available
ORDER BY total_utilization DESC
