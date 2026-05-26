{{ config(materialized='table') }}

SELECT
    primaryicdgroup,

    COALESCE(SUM(total_utilization), 0) AS total_utilization,
    COALESCE(SUM(lineitem_count), 0) AS lineitem_count,
    COALESCE(SUM(unique_claim_count), 0) AS claim_count,
    COALESCE(SUM(unique_member_count), 0) AS member_count,

    COALESCE(COUNT(DISTINCT providername), 0) AS unique_provider_count,
    COALESCE(SUM(unique_doctor_count), 0) AS unique_doctor_count

FROM {{ ref('cpt_icd_provider') }}
GROUP BY primaryicdgroup
ORDER BY total_utilization DESC

