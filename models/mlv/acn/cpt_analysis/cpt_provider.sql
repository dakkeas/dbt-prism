
{{ config(materialized='table')}}

SELECT
    CONCAT(cpt_cleaned, '-', providername) AS cpt_provider,
    cpt,
    cpt_cleaned,
    providername AS provider,

    -- Is PCC flag for this CPT-Provider pairing
    CASE WHEN MAX(is_pcc) = 1 THEN 'Yes' ELSE 'No' END AS is_pcc,

    -- Overall metrics
    SUM(total_utilization) AS total_utilization,
    SUM(unique_claim_count) AS unique_claim_count,
    SUM(unique_member_count) AS unique_member_count,
    SUM(unique_doctor_count) AS unique_doctor_count,
    ROUND(SUM(average_cost_per_claim * unique_claim_count) / NULLIF(SUM(unique_claim_count), 0), 2) AS average_cost_per_claim,
    ROUND(SUM(average_cost_per_member * unique_member_count) / NULLIF(SUM(unique_member_count), 0), 2) AS average_cost_per_member

FROM dev_acn.cpt_icd_provider
GROUP BY cpt_cleaned, cpt, providername
ORDER BY total_utilization DESC;