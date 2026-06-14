{% macro standardized_cpt_member_analysis(standardized_cpt_names, metric_prefix='standardized_cpt') %}
{% if standardized_cpt_names is string %}
    {% set cpt_name_list = [standardized_cpt_names] %}
{% else %}
    {% set cpt_name_list = standardized_cpt_names %}
{% endif %}

WITH acn_clean AS (
    SELECT
        maskedcardno,
        claimno,
        admissiondate,
        providername,
        physicianname,
        membershiptype,
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
    WHERE maskedcardno IS NOT NULL
      AND cptdesc IS NOT NULL
      AND cptdesc NOT IN (' ', '0', '')
      AND admissiondate >= DATE '2024-09-01'
      AND admissiondate < DATE '2025-09-01'
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
        cpt_cleaned_standard
    FROM {{ ref('cpt_standardized') }}
    WHERE cpt_cleaned_standard IN (
        {% for cpt_name in cpt_name_list %}
        '{{ cpt_name | replace("'", "''") }}'{% if not loop.last %}, {% endif %}
        {% endfor %}
    )
),

member_cpt AS (
    SELECT
        acn.maskedcardno,
        cs.cpt_cleaned_standard AS cpt_standardized,
        COUNT(*) AS {{ metric_prefix }}_cpt_count,
        COUNT(DISTINCT acn.claimno) AS {{ metric_prefix }}_claim_count,
        COUNT(DISTINCT acn.admissiondate) AS {{ metric_prefix }}_service_date_count,
        COUNT(DISTINCT acn.providername) AS unique_{{ metric_prefix }}_provider_count,
        COUNT(DISTINCT acn.physicianname) AS unique_{{ metric_prefix }}_physician_count,
        SUM(CASE WHEN UPPER(TRIM(acn.membershiptype)) = 'PRINCIPAL' THEN 1 ELSE 0 END) AS principal_{{ metric_prefix }}_cpt_count,
        SUM(CASE WHEN UPPER(TRIM(acn.membershiptype)) = 'DEPENDENT' THEN 1 ELSE 0 END) AS dependent_{{ metric_prefix }}_cpt_count,
        COALESCE(SUM(CASE WHEN UPPER(TRIM(acn.membershiptype)) = 'PRINCIPAL' THEN acn.approved ELSE 0 END), 0) AS principal_{{ metric_prefix }}_utilization,
        COALESCE(SUM(CASE WHEN UPPER(TRIM(acn.membershiptype)) = 'DEPENDENT' THEN acn.approved ELSE 0 END), 0) AS dependent_{{ metric_prefix }}_utilization,
        COALESCE(SUM(acn.approved), 0) AS total_utilization,
        COALESCE(MIN(acn.approved), 0) AS minimum_{{ metric_prefix }}_lineitem_utilization,
        COALESCE(MAX(acn.approved), 0) AS maximum_{{ metric_prefix }}_lineitem_utilization
    FROM acn_clean acn
    INNER JOIN cpt_standardized cs
        ON acn.cpt_cleaned = cs.cpt_cleaned
    GROUP BY 1, 2
)

SELECT
    cpt_standardized,
    {{ metric_prefix }}_cpt_count AS {{ metric_prefix }}_frequency,
    COUNT(*) AS patient_count,
    SUM({{ metric_prefix }}_claim_count) AS total_{{ metric_prefix }}_claim_count,
    SUM({{ metric_prefix }}_service_date_count) AS total_{{ metric_prefix }}_service_date_count,
    SUM(unique_{{ metric_prefix }}_provider_count) AS total_unique_{{ metric_prefix }}_provider_count,
    SUM(unique_{{ metric_prefix }}_physician_count) AS total_unique_{{ metric_prefix }}_physician_count,
    SUM(principal_{{ metric_prefix }}_cpt_count) AS total_principal_{{ metric_prefix }}_cpt_count,
    SUM(dependent_{{ metric_prefix }}_cpt_count) AS total_dependent_{{ metric_prefix }}_cpt_count,
    SUM(principal_{{ metric_prefix }}_utilization) AS total_principal_{{ metric_prefix }}_utilization,
    SUM(dependent_{{ metric_prefix }}_utilization) AS total_dependent_{{ metric_prefix }}_utilization,
    SUM(total_utilization) AS total_utilization,
    COALESCE(ROUND(CAST(SUM(total_utilization) AS NUMERIC) / NULLIF(SUM({{ metric_prefix }}_cpt_count), 0), 2), 0) AS average_utilization_per_{{ metric_prefix }}_cpt,
    COALESCE(ROUND(CAST(SUM(total_utilization) AS NUMERIC) / NULLIF(COUNT(*), 0), 2), 0) AS average_utilization_per_patient,
    COALESCE(MIN(minimum_{{ metric_prefix }}_lineitem_utilization), 0) AS minimum_{{ metric_prefix }}_lineitem_utilization,
    COALESCE(MAX(maximum_{{ metric_prefix }}_lineitem_utilization), 0) AS maximum_{{ metric_prefix }}_lineitem_utilization
FROM member_cpt
GROUP BY 1, 2
ORDER BY 1, 2
{% endmacro %}
