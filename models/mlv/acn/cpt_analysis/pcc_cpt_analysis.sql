{{ config(materialized='table') }}

WITH pcc_branches AS (
    SELECT DISTINCT
        TRIM(UPPER(pccbranchname)) AS pccbranchname
    FROM {{ ref('pcc_availments_raw_data') }}
),

acn_clean AS (
    SELECT
        maskedcardno,
        claimno,
        admissiondate,
        providername,
        UPPER(TRIM(providername)) AS providername_clean,
        physicianname,
        membershiptype,
        cptdesc AS cpt,
        approved,
        UPPER(
            TRIM(
                {% if target.type == 'bigquery' %}
                REGEXP_REPLACE(
                    REPLACE(
                        REPLACE(cptdesc, CHR(160), ' '),
                        '·',
                        ' '
                    ),
                    r'\s+',
                    ' '
                )
                {% else %}
                REGEXP_REPLACE(
                    REPLACE(
                        REPLACE(cptdesc, CHR(160), ' '),
                        '·',
                        ' '
                    ),
                    '\s+',
                    ' ',
                    'g'
                )
                {% endif %}
            )
        ) AS cpt_cleaned
    FROM {{ ref('masked_acn_2325') }}
    WHERE cptdesc IS NOT NULL
      AND cptdesc NOT IN (' ', '0', '')
      AND providername IS NOT NULL
      AND providername NOT IN (' ', '0', '')
      AND admissiondate >= DATE '2024-09-01'
),

acn_with_pcc_flag AS (
    SELECT
        acn.*,
        CASE
            WHEN pcc.pccbranchname IS NULL THEN 0
            ELSE 1
        END AS is_pcc
    FROM acn_clean acn
    LEFT JOIN pcc_branches pcc
        ON acn.providername_clean = pcc.pccbranchname
),

cpt_standardized AS (
    SELECT DISTINCT
        UPPER(
            TRIM(
                {% if target.type == 'bigquery' %}
                REGEXP_REPLACE(
                    REPLACE(
                        REPLACE(cpt_cleaned, CHR(160), ' '),
                        '·',
                        ' '
                    ),
                    r'\s+',
                    ' '
                )
                {% else %}
                REGEXP_REPLACE(
                    REPLACE(
                        REPLACE(cpt_cleaned, CHR(160), ' '),
                        '·',
                        ' '
                    ),
                    '\s+',
                    ' ',
                    'g'
                )
                {% endif %}
            )
        ) AS cpt_cleaned,
        cpt_cleaned_standard,
        test_type,
        test_classification
    FROM {{ ref('cpt_standardized') }}
    WHERE UPPER(test_classification) LIKE '%CLINIC+%'
       OR UPPER(test_classification) LIKE '%PCC+%'
),

pcc_totals AS (
    SELECT
        COALESCE(SUM(CASE WHEN is_pcc = 1 THEN approved ELSE 0 END), 0) AS whole_pcc_total_utilization,
        COALESCE(COUNT(CASE WHEN is_pcc = 1 THEN 1 END), 0) AS whole_pcc_lineitem_count,
        COALESCE(COUNT(DISTINCT CASE WHEN is_pcc = 1 THEN claimno END), 0) AS whole_pcc_claim_count,
        COALESCE(COUNT(DISTINCT CASE WHEN is_pcc = 1 THEN maskedcardno END), 0) AS whole_pcc_member_count
    FROM acn_with_pcc_flag
),

eligible_cpt_lineitems AS (
    SELECT
        acn.maskedcardno,
        acn.claimno,
        acn.providername,
        acn.physicianname,
        acn.membershiptype,
        acn.cpt,
        acn.approved,
        acn.is_pcc,
        cs.cpt_cleaned_standard,
        cs.test_type,
        cs.test_classification
    FROM acn_with_pcc_flag acn
    INNER JOIN cpt_standardized cs
        ON acn.cpt_cleaned = cs.cpt_cleaned
)

SELECT
    e.cpt AS cpt_original,
    STRING_AGG(DISTINCT e.cpt_cleaned_standard, ', ' ORDER BY e.cpt_cleaned_standard) AS cpt_standardized_list,
    MAX(e.test_type) AS test_type,
    MAX(e.test_classification) AS test_classification,

    COALESCE(SUM(e.approved), 0) AS total_utilization,
    COUNT(*) AS lineitem_count,
    COUNT(DISTINCT e.claimno) AS claim_count,
    COUNT(DISTINCT e.maskedcardno) AS member_count,
    COUNT(DISTINCT e.providername) AS provider_count,
    COUNT(DISTINCT e.physicianname) AS physician_count,
    COALESCE(ROUND(CAST(SUM(e.approved) AS NUMERIC) / NULLIF(COUNT(*), 0), 2), 0) AS average_utilization_per_lineitem,
    COALESCE(ROUND(CAST(SUM(e.approved) AS NUMERIC) / NULLIF(COUNT(DISTINCT e.claimno), 0), 2), 0) AS average_utilization_per_claim,
    COALESCE(ROUND(CAST(SUM(e.approved) AS NUMERIC) / NULLIF(COUNT(DISTINCT e.maskedcardno), 0), 2), 0) AS average_utilization_per_member,

    COALESCE(SUM(CASE WHEN e.is_pcc = 1 THEN e.approved ELSE 0 END), 0) AS pcc_total_utilization,
    COUNT(CASE WHEN e.is_pcc = 1 THEN 1 END) AS pcc_lineitem_count,
    COUNT(DISTINCT CASE WHEN e.is_pcc = 1 THEN e.claimno END) AS pcc_claim_count,
    COUNT(DISTINCT CASE WHEN e.is_pcc = 1 THEN e.maskedcardno END) AS pcc_member_count,
    COUNT(DISTINCT CASE WHEN e.is_pcc = 1 THEN e.providername END) AS pcc_provider_count,

    COALESCE(SUM(CASE WHEN e.is_pcc = 0 THEN e.approved ELSE 0 END), 0) AS non_pcc_total_utilization,
    COUNT(CASE WHEN e.is_pcc = 0 THEN 1 END) AS non_pcc_lineitem_count,
    COUNT(DISTINCT CASE WHEN e.is_pcc = 0 THEN e.claimno END) AS non_pcc_claim_count,
    COUNT(DISTINCT CASE WHEN e.is_pcc = 0 THEN e.maskedcardno END) AS non_pcc_member_count,

    COALESCE(
        ROUND(
            CAST(SUM(CASE WHEN e.is_pcc = 1 THEN e.approved ELSE 0 END) AS NUMERIC)
            / NULLIF(CAST(SUM(e.approved) AS NUMERIC), 0),
            4
        ),
        0
    ) AS pcc_capture_rate_of_cpt_utilization,
    COALESCE(
        ROUND(
            CAST(COUNT(DISTINCT CASE WHEN e.is_pcc = 1 THEN e.claimno END) AS NUMERIC)
            / NULLIF(CAST(COUNT(DISTINCT e.claimno) AS NUMERIC), 0),
            4
        ),
        0
    ) AS pcc_capture_rate_of_cpt_claims,

    COALESCE(
        ROUND(
            CAST(SUM(CASE WHEN e.is_pcc = 1 THEN e.approved ELSE 0 END) AS NUMERIC)
            / NULLIF(CAST(MAX(p.whole_pcc_total_utilization) AS NUMERIC), 0),
            4
        ),
        0
    ) AS share_of_whole_pcc_utilization,
    COALESCE(
        ROUND(
            CAST(COUNT(DISTINCT CASE WHEN e.is_pcc = 1 THEN e.claimno END) AS NUMERIC)
            / NULLIF(CAST(MAX(p.whole_pcc_claim_count) AS NUMERIC), 0),
            4
        ),
        0
    ) AS share_of_whole_pcc_claims,
    COALESCE(
        ROUND(
            CAST(COUNT(CASE WHEN e.is_pcc = 1 THEN 1 END) AS NUMERIC)
            / NULLIF(CAST(MAX(p.whole_pcc_lineitem_count) AS NUMERIC), 0),
            4
        ),
        0
    ) AS share_of_whole_pcc_lineitems,

    MAX(p.whole_pcc_total_utilization) AS whole_pcc_total_utilization,
    MAX(p.whole_pcc_claim_count) AS whole_pcc_claim_count,
    MAX(p.whole_pcc_lineitem_count) AS whole_pcc_lineitem_count,
    MAX(p.whole_pcc_member_count) AS whole_pcc_member_count
FROM eligible_cpt_lineitems e
CROSS JOIN pcc_totals p
GROUP BY e.cpt
ORDER BY total_utilization DESC
