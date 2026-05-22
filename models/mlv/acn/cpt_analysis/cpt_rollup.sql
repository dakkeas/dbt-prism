
{{ config(materialized='table')}}


SELECT
    cpt_cleaned,

    -- Overall metrics
    SUM(total_utilization) AS total_utilization,
    SUM(unique_claim_count) AS unique_claim_count,
    SUM(unique_member_count) AS unique_member_count,
    SUM(unique_doctor_count) AS unique_doctor_count,
    ROUND(SUM(average_cost_per_claim * unique_claim_count) / NULLIF(SUM(unique_claim_count), 0), 2) AS average_cost_per_claim,
    ROUND(SUM(average_cost_per_member * unique_member_count) / NULLIF(SUM(unique_member_count), 0), 2) AS average_cost_per_member,

    -- Non-PCC metrics
    SUM(CASE WHEN is_pcc = 0 THEN total_utilization END) AS non_pcc_total_utilization,
    SUM(CASE WHEN is_pcc = 0 THEN lineitem_count END) AS non_pcc_lineitem_count,
    SUM(CASE WHEN is_pcc = 0 THEN unique_claim_count END) AS non_pcc_unique_claim_count,
    SUM(CASE WHEN is_pcc = 0 THEN unique_member_count END) AS non_pcc_unique_member_count,
    SUM(CASE WHEN is_pcc = 0 THEN unique_doctor_count END) AS non_pcc_unique_doctor_count,
    ROUND(SUM(CASE WHEN is_pcc = 0 THEN average_cost_per_claim * unique_claim_count END) / NULLIF(SUM(CASE WHEN is_pcc = 0 THEN unique_claim_count END), 0), 2) AS non_pcc_average_cost_per_claim,
    ROUND(SUM(CASE WHEN is_pcc = 0 THEN average_cost_per_member * unique_member_count END) / NULLIF(SUM(CASE WHEN is_pcc = 0 THEN unique_member_count END), 0), 2) AS non_pcc_average_cost_per_member,

    -- Non-PCC most/cheapest expensive provider
    MAX(CASE WHEN is_pcc = 0 THEN providername END) FILTER (
        WHERE is_pcc = 0 AND average_cost_per_claim = (
            SELECT MAX(i.average_cost_per_claim) FROM dev_acn.cpt_icd_provider i WHERE i.cpt_cleaned = o.cpt_cleaned AND i.is_pcc = 0
        )
    ) AS non_pcc_most_expensive_provider,

    MAX(CASE WHEN is_pcc = 0 THEN average_cost_per_claim END) AS non_pcc_cost_of_most_expensive_provider,

    MIN(CASE WHEN is_pcc = 0 THEN providername END) FILTER (
        WHERE is_pcc = 0 AND average_cost_per_claim = (
            SELECT MIN(i.average_cost_per_claim) FROM dev_acn.cpt_icd_provider i WHERE i.cpt_cleaned = o.cpt_cleaned AND i.is_pcc = 0
        )
    ) AS non_pcc_cheapest_provider,

    MIN(CASE WHEN is_pcc = 0 THEN average_cost_per_claim END) AS non_pcc_cost_of_cheapest_provider,

    -- PCC metrics
    CASE WHEN MAX(is_pcc) = 1 THEN 'Yes' ELSE 'No' END AS pcc_test_available,

    SUM(CASE WHEN is_pcc = 1 THEN total_utilization END) AS pcc_total_utilization,
    SUM(CASE WHEN is_pcc = 1 THEN lineitem_count END) AS pcc_lineitem_count,
    SUM(CASE WHEN is_pcc = 1 THEN unique_claim_count END) AS pcc_unique_claim_count,
    SUM(CASE WHEN is_pcc = 1 THEN unique_member_count END) AS pcc_unique_member_count,
    SUM(CASE WHEN is_pcc = 1 THEN unique_doctor_count END) AS pcc_unique_doctor_count,

    ROUND(SUM(CASE WHEN is_pcc = 1 THEN average_cost_per_claim * unique_claim_count END) / NULLIF(SUM(CASE WHEN is_pcc = 1 THEN unique_claim_count END), 0), 2) AS pcc_average_cost_per_claim,
    ROUND(SUM(CASE WHEN is_pcc = 1 THEN average_cost_per_member * unique_member_count END) / NULLIF(SUM(CASE WHEN is_pcc = 1 THEN unique_member_count END), 0), 2) AS pcc_average_cost_per_member,
    STRING_AGG(CASE WHEN is_pcc = 1 THEN providername END, ', ' ORDER BY providername) AS pcc_branches_available

FROM dev_acn.cpt_icd_provider o
GROUP BY cpt_cleaned
ORDER BY total_utilization DESC