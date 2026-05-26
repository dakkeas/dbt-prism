
{{ config(materialized='table')}}

SELECT
    CONCAT(cpt_cleaned, '-', providername) AS cpt_provider,
    cpt,
    cpt_cleaned,
    providername AS provider,

    -- Is PCC flag for this CPT-Provider pairing
    CASE WHEN MAX(is_pcc) = 1 THEN 'Yes' ELSE 'No' END AS is_pcc,

    -- Overall metrics
    COALESCE(SUM(total_utilization), 0) AS total_utilization,
    COALESCE(SUM(unique_claim_count), 0) AS unique_claim_count,
    COALESCE(SUM(lineitem_count), 0) AS lineitem_count,
    COALESCE(SUM(unique_member_count), 0) AS unique_member_count,
    COALESCE(SUM(unique_doctor_count), 0) AS unique_doctor_count,
    COALESCE(ROUND(SUM(average_cost_per_claim * unique_claim_count) / NULLIF(SUM(unique_claim_count), 0), 2), 0) AS average_cost_per_claim,
    COALESCE(ROUND(SUM(average_cost_per_lineitem * lineitem_count) / NULLIF(SUM(lineitem_count), 0), 2), 0) AS average_cost_per_lineitem,
    COALESCE(ROUND(SUM(average_cost_per_member * unique_member_count) / NULLIF(SUM(unique_member_count), 0), 2), 0) AS average_cost_per_member

FROM {{ ref('cpt_icd_provider') }}
GROUP BY cpt_cleaned, cpt, providername
ORDER BY total_utilization DESC
