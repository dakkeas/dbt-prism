{{ config(materialized = 'table') }}

WITH classified AS (
    SELECT
        'DIABETES MELLITUS' AS icd_group,
        CASE
            WHEN rank_y24 <= 100
                AND rank_y25 <= 100
                AND ABS(rank_change) <= 100
                THEN 'REPEAT HIGH UTIL'
            WHEN rank_change < -100
                THEN 'DROPPED >100 RANK'
            WHEN rank_change > 100
                THEN 'JUMPED >100 RANK'
        END AS bucket,
        *
    FROM {{ ref('md_scorecard_delta_diabetes') }}
),
ranked AS (
    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY bucket
            ORDER BY
                CASE WHEN bucket = 'REPEAT HIGH UTIL' THEN rank_y25 END ASC NULLS LAST,
                CASE WHEN bucket = 'DROPPED >100 RANK' THEN rank_change END ASC NULLS LAST,
                CASE WHEN bucket = 'JUMPED >100 RANK' THEN rank_change END DESC NULLS LAST,
                COALESCE(y25_ave_12_month_util_per_patient, 0) DESC,
                physiciancode
        ) AS shortlist_rank
    FROM classified
    WHERE bucket IS NOT NULL
),
with_driver AS (
    SELECT
        *,
        CONCAT_WS(
            ' | ',
            CASE
                WHEN COALESCE(delta_inp_sum_of_util, 0) <> 0
                    THEN 'Inpatient Util: ' || {{ format_currency('delta_inp_sum_of_util') }}
            END,
            CASE
                WHEN COALESCE(delta_opl_sum_of_util, 0) <> 0
                    THEN 'OP Lab Util: ' || {{ format_currency('delta_opl_sum_of_util') }}
            END,
            CASE
                WHEN COALESCE(delta_total_cpt_util, 0) <> 0
                    THEN 'CPT Util: ' || {{ format_currency('delta_total_cpt_util') }}
            END,
            CASE
                WHEN COALESCE(delta_others_sum_of_util, 0) <> 0
                    THEN 'Others Util: ' || {{ format_currency('delta_others_sum_of_util') }}
            END
        ) AS driver_summary
    FROM ranked
)
SELECT
    icd_group,
    bucket,
    shortlist_rank,
    physiciancode AS physician_code,
    physicianname AS physician_name,
    providername AS provider_name,
    specialization,
    sub_specialization,

    rank_y24,
    rank_y25,
    rank_change,

    y24_total_unique_patient_cnt,
    y25_total_unique_patient_cnt,
    delta_total_unique_patient_cnt,

    y24_all_claims_sum_of_util AS y24_total_util,
    y25_all_claims_sum_of_util AS y25_total_util,
    delta_all_claims_sum_of_util AS delta_total_util,

    y24_ave_12_month_util_per_patient AS y24_util_per_patient,
    y25_ave_12_month_util_per_patient AS y25_util_per_patient,
    delta_ave_12_month_util_per_patient AS delta_util_per_patient,

    y24_inp_sum_of_util AS y24_inpatient_util,
    y25_inp_sum_of_util AS y25_inpatient_util,
    delta_inp_sum_of_util AS delta_inpatient_util,

    y24_opl_sum_of_util AS y24_op_lab_util,
    y25_opl_sum_of_util AS y25_op_lab_util,
    delta_opl_sum_of_util AS delta_op_lab_util,

    y24_total_cpt_util AS y24_cpt_util,
    y25_total_cpt_util AS y25_cpt_util,
    delta_total_cpt_util AS delta_cpt_util,

    y24_others_sum_of_util AS y24_others_util,
    y25_others_sum_of_util AS y25_others_util,
    delta_others_sum_of_util AS delta_others_util,

    driver_summary,
    CONCAT(
        'Rank ', rank_y24, ' to ', rank_y25,
        ': Util/Pt ', {{ format_currency('y24_ave_12_month_util_per_patient') }},
        ' to ', {{ format_currency('y25_ave_12_month_util_per_patient') }},
        ' (', {{ format_currency('delta_ave_12_month_util_per_patient') }}, ')',
        ' across ', y24_total_unique_patient_cnt, ' to ', y25_total_unique_patient_cnt,
        ' patients; driven by ', COALESCE(driver_summary, 'no utilization-component change')
    ) AS report_summary
FROM with_driver
WHERE shortlist_rank <= 5
ORDER BY bucket, shortlist_rank

