{% macro md_scorecard_y24(primaryicdgroup_list, top_n_provider, top_n_physicians, more_than_n_patients, px_engine_model='px_engine_y24', icd_column='combined_starting_primaryicdgroup') %}

WITH physician_engine AS (
    SELECT
        CONCAT(starting_physiciancode, ' - ', starting_providername) AS physician_providername,
        starting_physiciancode AS physiciancode,
        starting_providername AS providername,

        STRING_AGG(DISTINCT CASE
            WHEN TRIM(combined_starting_primaryicdgroup) NOT IN (' ', '') AND combined_starting_primaryicdgroup IS NOT NULL THEN combined_starting_primaryicdgroup
        END, ', ') AS combined_starting_primaryicdgroup,

        MIN(pi.physicianname) AS physicianname,
        MIN(pi.specialization) AS specialization,
        MIN(pi.sub_specialization) AS sub_specialization,
        {% if target.type == 'bigquery' %}
        CAST(MIN(CAST(pi.is_pcc_coordinator AS INT64)) AS BOOL) AS is_pcc_coordinator,
        CAST(MIN(CAST(pi.practices_in_pcc AS INT64)) AS BOOL) AS practices_in_pcc,
        {% else %}
        MIN(pi.is_pcc_coordinator::int)::boolean AS is_pcc_coordinator,
        MIN(pi.practices_in_pcc::int)::boolean AS practices_in_pcc,
        {% endif %}

        COUNT(DISTINCT maskedcardno) AS total_unique_patient_cnt,
        COUNT(DISTINCT CASE WHEN COALESCE(total_lengthofstay, 0) > 0 THEN maskedcardno END) AS total_patient_cnt_with_stay,
        SUM(overall_count_of_claims) AS total_claim_count,
        COALESCE(SUM(total_lengthofstay), 0) AS total_patient_lengthofstay,
        SUM(overall_util) AS total_util,
        COALESCE(SUM(overall_util) / NULLIF(COUNT(DISTINCT maskedcardno), 0), 0) AS ave_12_month_util_per_patient,

        -- OP LAB
        COUNT(DISTINCT CASE WHEN opl_coc > 0 THEN maskedcardno END) AS opl_unique_px_cnt_at_least_one,
        COALESCE(CAST(COUNT(DISTINCT CASE WHEN opl_coc > 0 THEN maskedcardno END) AS NUMERIC) / NULLIF(COUNT(DISTINCT maskedcardno), 0), 0) AS opl_unique_px_count_at_least_one_pct,
        COALESCE(CAST(SUM(opl_coc) AS NUMERIC) / NULLIF(COUNT(DISTINCT CASE WHEN opl_coc > 0 THEN maskedcardno END), 0), 0) AS opl_ave_claims_per_px_at_least_one,
        SUM(opl_coc) AS opl_total_claims,
        COALESCE(CAST(SUM(opl_util) AS NUMERIC) / NULLIF(SUM(opl_coc), 0), 0) AS opl_ave_cost_per_claim_per_px_at_least_one,
        SUM(opl_util) AS opl_sum_of_util,
        COALESCE(CAST(SUM(opl_util) AS NUMERIC) / NULLIF(COUNT(DISTINCT maskedcardno), 0), 0) AS opl_ave_twelve_month_util_per_px,

        -- INPATIENT
        COUNT(DISTINCT CASE WHEN inp_coc > 0 THEN maskedcardno END) AS inp_unique_px_count_at_least_one,
        COALESCE(CAST(COUNT(DISTINCT CASE WHEN inp_coc > 0 THEN maskedcardno END) AS NUMERIC) / NULLIF(COUNT(DISTINCT maskedcardno), 0), 0) AS inp_unique_px_count_at_least_one_pct,
        COALESCE(CAST(SUM(inp_coc) AS NUMERIC) / NULLIF(COUNT(DISTINCT CASE WHEN inp_coc > 0 THEN maskedcardno END), 0), 0) AS inp_ave_claims_per_px_at_least_one,
        SUM(inp_coc) AS inp_total_claims,
        COALESCE(CAST(SUM(inp_util) AS NUMERIC) / NULLIF(SUM(inp_coc), 0), 0) AS inp_ave_cost_per_claim_per_px_at_least_one,
        SUM(inp_util) AS inp_sum_of_util,
        COALESCE(CAST(SUM(inp_util) AS NUMERIC) / NULLIF(COUNT(DISTINCT maskedcardno), 0), 0) AS inp_ave_twelve_month_util_per_px,

        -- OTHERS
        COUNT(DISTINCT CASE WHEN others_coc > 0 THEN maskedcardno END) AS others_unique_px_count_at_least_one,
        COALESCE(CAST(COUNT(DISTINCT CASE WHEN others_coc > 0 THEN maskedcardno END) AS NUMERIC) / NULLIF(COUNT(DISTINCT maskedcardno), 0), 0) AS others_unique_px_count_at_least_one_pct,
        COALESCE(CAST(SUM(others_coc) AS NUMERIC) / NULLIF(COUNT(DISTINCT CASE WHEN others_coc > 0 THEN maskedcardno END), 0), 0) AS others_ave_claims_per_px_at_least_one,
        SUM(others_coc) AS others_total_claims,
        COALESCE(CAST(SUM(others_util) AS NUMERIC) / NULLIF(SUM(others_coc), 0), 0) AS others_ave_cost_per_claim_per_px_at_least_one,
        SUM(others_util) AS others_sum_of_util,
        COALESCE(CAST(SUM(others_util) AS NUMERIC) / NULLIF(COUNT(DISTINCT maskedcardno), 0), 0) AS others_ave_twelve_month_util_per_px,

        -- PHILHEALTH & PF
        SUM(sum_philhealth) AS total_philhealth,
        COALESCE(CAST(SUM(sum_philhealth) AS NUMERIC) / NULLIF(CAST(SUM(overall_util) AS NUMERIC), 0), 0) AS percent_of_philhealth_util,
        COALESCE(CAST(SUM(sum_philhealth) AS NUMERIC) / NULLIF(CAST(COUNT(DISTINCT maskedcardno) AS NUMERIC), 0), 0) AS ave_philhealth_claim_per_patient,
        SUM(sum_professional_fees) AS total_professional_fees,
        COALESCE(CAST(SUM(sum_professional_fees) AS NUMERIC) / NULLIF(CAST(COUNT(DISTINCT maskedcardno) AS NUMERIC), 0), 0) AS ave_professional_fees_per_patient,

        -- CPT
        CAST(SUM(overall_cptcode_coc) AS NUMERIC) AS total_overall_cptcode_count,
        CAST(SUM(opl_cptcode_coc) AS NUMERIC) AS total_opl_cptcode_count,
        CAST(SUM(inp_cptcode_coc) AS NUMERIC) AS total_inp_cptcode_count,
        CAST(SUM(emg_cptcode_coc) AS NUMERIC) AS total_emg_cptcode_count,
        CAST(SUM(overall_cptcode_util) AS NUMERIC) AS total_overall_cptcode_util,
        CAST(SUM(opl_cptcode_util) AS NUMERIC) AS total_opl_cptcode_util,
        CAST(SUM(inp_cptcode_util) AS NUMERIC) AS total_inp_cptcode_util,
        CAST(SUM(emg_cptcode_util) AS NUMERIC) AS total_emg_cptcode_util,
        COALESCE(CAST(SUM(overall_cptcode_coc) / NULLIF(COUNT(DISTINCT maskedcardno), 0) AS NUMERIC), 0) AS overall_cptcode_avg_count_per_px,
        COALESCE(CAST(SUM(opl_cptcode_coc) / NULLIF(COUNT(DISTINCT maskedcardno), 0) AS NUMERIC), 0) AS opl_cptcode_avg_count_per_px,
        COALESCE(CAST(SUM(inp_cptcode_coc) / NULLIF(COUNT(DISTINCT maskedcardno), 0) AS NUMERIC), 0) AS inp_cptcode_avg_count_per_px,
        COALESCE(CAST(SUM(emg_cptcode_coc) / NULLIF(COUNT(DISTINCT maskedcardno), 0) AS NUMERIC), 0) AS emg_cptcode_avg_count_per_px,
        COALESCE(CAST(SUM(overall_cptcode_util) / NULLIF(COUNT(DISTINCT maskedcardno), 0) AS NUMERIC), 0) AS overall_cptcode_avg_util_per_px,
        COALESCE(CAST(SUM(opl_cptcode_util) / NULLIF(COUNT(DISTINCT maskedcardno), 0) AS NUMERIC), 0) AS opl_cptcode_avg_util_per_px,
        COALESCE(CAST(SUM(inp_cptcode_util) / NULLIF(COUNT(DISTINCT maskedcardno), 0) AS NUMERIC), 0) AS inp_cptcode_avg_util_per_px,
        COALESCE(CAST(SUM(emg_cptcode_util) / NULLIF(COUNT(DISTINCT maskedcardno), 0) AS NUMERIC), 0) AS emg_cptcode_avg_util_per_px,

        -- RUV
        CAST(SUM(overall_ruvcode_coc) AS NUMERIC) AS total_overall_ruvcode_count,
        CAST(SUM(opl_ruvcode_coc) AS NUMERIC) AS total_opl_ruvcode_count,
        CAST(SUM(inp_ruvcode_coc) AS NUMERIC) AS total_inp_ruvcode_count,
        CAST(SUM(emg_ruvcode_coc) AS NUMERIC) AS total_emg_ruvcode_count,
        CAST(SUM(overall_ruvcode_util) AS NUMERIC) AS total_overall_ruvcode_util,
        CAST(SUM(opl_ruvcode_util) AS NUMERIC) AS total_opl_ruvcode_util,
        CAST(SUM(inp_ruvcode_util) AS NUMERIC) AS total_inp_ruvcode_util,
        CAST(SUM(emg_ruvcode_util) AS NUMERIC) AS total_emg_ruvcode_util,
        COALESCE(CAST(SUM(overall_ruvcode_coc) / NULLIF(COUNT(DISTINCT maskedcardno), 0) AS NUMERIC), 0) AS overall_ruvcode_avg_count_per_px,
        COALESCE(CAST(SUM(opl_ruvcode_coc) / NULLIF(COUNT(DISTINCT maskedcardno), 0) AS NUMERIC), 0) AS opl_ruvcode_avg_count_per_px,
        COALESCE(CAST(SUM(inp_ruvcode_coc) / NULLIF(COUNT(DISTINCT maskedcardno), 0) AS NUMERIC), 0) AS inp_ruvcode_avg_count_per_px,
        COALESCE(CAST(SUM(emg_ruvcode_coc) / NULLIF(COUNT(DISTINCT maskedcardno), 0) AS NUMERIC), 0) AS emg_ruvcode_avg_count_per_px,
        COALESCE(CAST(SUM(overall_ruvcode_util) / NULLIF(COUNT(DISTINCT maskedcardno), 0) AS NUMERIC), 0) AS overall_ruvcode_avg_util_per_px,
        COALESCE(CAST(SUM(opl_ruvcode_util) / NULLIF(COUNT(DISTINCT maskedcardno), 0) AS NUMERIC), 0) AS opl_ruvcode_avg_util_per_px,
        COALESCE(CAST(SUM(inp_ruvcode_util) / NULLIF(COUNT(DISTINCT maskedcardno), 0) AS NUMERIC), 0) AS inp_ruvcode_avg_util_per_px,
        COALESCE(CAST(SUM(emg_ruvcode_util) / NULLIF(COUNT(DISTINCT maskedcardno), 0) AS NUMERIC), 0) AS emg_ruvcode_avg_util_per_px,

        COALESCE(SUM(CASE WHEN patient_journey_category = 'End-Stage Cardiometabolic Disease Patient' THEN 1 END), 0) AS count_of_end_stage_cardiometabolic_disease_patient,
        COALESCE(SUM(CASE WHEN patient_journey_category = 'End-Stage Cardiometabolic Disease Patient' THEN overall_util END), 0) AS sum_of_util_of_end_stage_cardiometabolic_disease_patient,
        COALESCE(SUM(CASE WHEN patient_journey_category = 'Essential (Primary) Hypertension Patient Only' THEN 1 END), 0) AS count_of_eph_patient_only,
        COALESCE(SUM(CASE WHEN patient_journey_category = 'Essential (Primary) Hypertension Patient Only' THEN overall_util END), 0) AS sum_of_util_of_eph_patient_only,
        COALESCE(SUM(CASE WHEN patient_journey_category = 'Diabetes Mellitus Patient Only' THEN 1 END), 0) AS count_of_diabetes_patient_only,
        COALESCE(SUM(CASE WHEN patient_journey_category = 'Diabetes Mellitus Patient Only' THEN overall_util END), 0) AS sum_of_util_of_diabetes_patient_only,
        COALESCE(SUM(CASE WHEN patient_journey_category = 'Dyslipidaemia Patient Only' THEN 1 END), 0) AS count_of_dyslipidaemia_patient_only,
        COALESCE(SUM(CASE WHEN patient_journey_category = 'Dyslipidaemia Patient Only' THEN overall_util END), 0) AS sum_of_util_of_dyslipidaemia_patient_only,

        COALESCE(SUM(count_of_rapid_readmissions), 0) AS count_of_rapid_readmissions,
        COALESCE(SUM(count_of_unique_inpatient_stays), 0) AS count_of_unique_inpatient_stays,
        COALESCE(SUM(count_of_rapid_cardiometabolic_readmissions), 0) AS count_of_rapid_cardiometabolic_readmissions,
        COALESCE(SUM(count_of_unique_cardiometabolic_inpatient_stays), 0) AS count_of_unique_cardiometabolic_inpatient_stays,
        COALESCE(SUM(count_of_non_panic_visits), 0) AS count_of_non_panic_visits,
        COALESCE(SUM(count_of_panic_visits), 0) AS count_of_panic_visits,
        COALESCE(SUM(count_of_unique_emergencies), 0) AS count_of_unique_emergencies,

        COALESCE(CAST(SUM(count_of_rapid_readmissions) AS NUMERIC) / NULLIF(SUM(count_of_unique_inpatient_stays), 0), 0) AS readmission_rate,
        COALESCE(CAST(SUM(count_of_rapid_cardiometabolic_readmissions) AS NUMERIC) / NULLIF(SUM(count_of_unique_cardiometabolic_inpatient_stays), 0), 0) AS cardiometabolic_readmission_rate,
        COALESCE(CAST(SUM(count_of_panic_visits) AS NUMERIC) / NULLIF(SUM(count_of_unique_emergencies), 0), 0) AS panic_visit_rate,
        COALESCE(CAST(SUM(count_of_non_panic_visits) AS NUMERIC) / NULLIF(SUM(count_of_unique_emergencies), 0), 0) AS non_panic_visit_rate,

        COALESCE(SUM(total_pcc_availment_cost), 0) AS total_pcc_availment_cost,
        COALESCE(SUM(total_pcc_availment_count), 0) AS total_pcc_availment_count,
        COALESCE(SUM(total_pcc_availment_cost) / NULLIF(COUNT(DISTINCT maskedcardno), 0), 0) AS ave_12_month_pcc_availment_cost_per_patient,
        COALESCE(SUM(total_pcc_availment_count) / NULLIF(COUNT(DISTINCT maskedcardno), 0), 0) AS ave_12_month_pcc_availment_count_per_patient

    FROM {{ ref(px_engine_model) }} pe

    LEFT JOIN (SELECT DISTINCT 
        physiciancode, 
        physicianname, 
        specialization, 
        sub_specialization,
        is_pcc_coordinator,
        practices_in_pcc
        FROM {{ ref('physicianinfo') }}) pi
    ON TRIM(UPPER(pe.starting_physiciancode)) = 
        {% if target.type == 'bigquery' %}
            CAST(pi.physiciancode AS STRING)
        {% else %}
            pi.physiciancode::TEXT
        {% endif %}

    WHERE pe.{{ icd_column }} IN (
    {% for icd in primaryicdgroup_list %}
        '{{ icd }}'{% if not loop.last %}, {% endif %}
    {% endfor %}
    )
    GROUP BY starting_physiciancode, starting_providername
)
SELECT
    physician_providername,
    physiciancode,
    providername,
    physicianname,
    specialization,
    sub_specialization,
    is_pcc_coordinator,
    practices_in_pcc,
    combined_starting_primaryicdgroup,
    
    ROUND(CAST(total_unique_patient_cnt AS NUMERIC), 2) AS total_unique_patient_cnt,
    ROUND(CAST(COALESCE(total_patient_lengthofstay, 0) AS NUMERIC), 2) AS total_patient_lengthofstay,
    ROUND(COALESCE(CAST(total_patient_lengthofstay AS NUMERIC) / NULLIF(CAST(total_patient_cnt_with_stay AS NUMERIC), 0), 0), 2) AS avg_lengthofstay_per_patient_with_stay,

    ROUND(CAST(total_claim_count AS NUMERIC), 2) AS total_claim_count,
    ROUND(CAST(total_util AS NUMERIC), 2) AS all_claims_sum_of_util,
    ROUND(CAST(ave_12_month_util_per_patient AS NUMERIC), 2) AS ave_12_month_util_per_patient,

    ROUND(CAST(opl_unique_px_cnt_at_least_one AS NUMERIC), 2) AS opl_unique_px_cnt_at_least_one,
    ROUND(CAST(opl_unique_px_count_at_least_one_pct AS NUMERIC), 2) AS opl_unique_px_count_at_least_one_pct,
    ROUND(CAST(opl_ave_claims_per_px_at_least_one AS NUMERIC), 2) AS opl_ave_claims_per_px_at_least_one,
    ROUND(CAST(opl_total_claims AS NUMERIC), 2) AS opl_total_claims,
    ROUND(CAST(opl_ave_cost_per_claim_per_px_at_least_one AS NUMERIC), 2) AS opl_ave_cost_per_claim_per_px_at_least_one,
    ROUND(CAST(opl_sum_of_util AS NUMERIC), 2) AS opl_sum_of_util,
    ROUND(CAST(opl_ave_twelve_month_util_per_px AS NUMERIC), 2) AS opl_ave_twelve_month_util_per_px,

    ROUND(CAST(inp_unique_px_count_at_least_one AS NUMERIC), 2) AS inp_unique_px_count_at_least_one,
    ROUND(CAST(inp_unique_px_count_at_least_one_pct AS NUMERIC), 2) AS inp_unique_px_count_at_least_one_pct,
    ROUND(CAST(inp_ave_claims_per_px_at_least_one AS NUMERIC), 2) AS inp_ave_claims_per_px_at_least_one,
    ROUND(CAST(inp_total_claims AS NUMERIC), 2) AS inp_total_claims,
    ROUND(CAST(inp_ave_cost_per_claim_per_px_at_least_one AS NUMERIC), 2) AS inp_ave_cost_per_claim_per_px_at_least_one,
    ROUND(CAST(inp_sum_of_util AS NUMERIC), 2) AS inp_sum_of_util,
    ROUND(CAST(inp_ave_twelve_month_util_per_px AS NUMERIC), 2) AS inp_ave_twelve_month_util_per_px,

    ROUND(CAST(others_unique_px_count_at_least_one AS NUMERIC), 2) AS others_unique_px_count_at_least_one,
    ROUND(CAST(others_unique_px_count_at_least_one_pct AS NUMERIC), 2) AS others_unique_px_count_at_least_one_pct,
    ROUND(CAST(others_ave_claims_per_px_at_least_one AS NUMERIC), 2) AS others_ave_claims_per_px_at_least_one,
    ROUND(CAST(others_total_claims AS NUMERIC), 2) AS others_total_claims,
    ROUND(CAST(others_ave_cost_per_claim_per_px_at_least_one AS NUMERIC), 2) AS others_ave_cost_per_claim_per_px_at_least_one,
    ROUND(CAST(others_sum_of_util AS NUMERIC), 2) AS others_sum_of_util,
    ROUND(CAST(others_ave_twelve_month_util_per_px AS NUMERIC), 2) AS others_ave_twelve_month_util_per_px,

    ROUND(CAST(total_professional_fees AS NUMERIC), 2) AS total_professional_fees,
    ROUND(CAST(ave_professional_fees_per_patient AS NUMERIC), 2) AS ave_professional_fees_per_patient,

    ROUND(CAST(total_philhealth AS NUMERIC), 2) AS total_philhealth,
    ROUND(CAST(percent_of_philhealth_util AS NUMERIC), 2) AS percent_of_philhealth_util,
    ROUND(CAST(ave_philhealth_claim_per_patient AS NUMERIC), 2) AS ave_philhealth_claim_per_patient,

    ROUND(CAST(total_overall_cptcode_count AS NUMERIC), 2) AS total_overall_cptcode_count,
    ROUND(CAST(total_overall_cptcode_util AS NUMERIC), 2) AS total_overall_cptcode_util,
    ROUND(CAST(overall_cptcode_avg_count_per_px AS NUMERIC), 2) AS overall_cptcode_avg_count_per_px,
    ROUND(CAST(overall_cptcode_avg_util_per_px AS NUMERIC), 2) AS overall_cptcode_avg_util_per_px,

    ROUND(COALESCE(NULLIF(CAST(count_of_end_stage_cardiometabolic_disease_patient AS NUMERIC), 0) / NULLIF(CAST(total_unique_patient_cnt AS NUMERIC), 0), 0), 2) AS percent_of_end_stage_cardiometabolic_disease_patients,
    ROUND(CAST(count_of_end_stage_cardiometabolic_disease_patient AS NUMERIC), 2) AS count_of_end_stage_cardiometabolic_disease_patient,
    ROUND(CAST(sum_of_util_of_end_stage_cardiometabolic_disease_patient AS NUMERIC), 2) AS sum_of_util_of_end_stage_cardiometabolic_disease_patient,
    ROUND(CAST(count_of_eph_patient_only AS NUMERIC), 2) AS count_of_eph_patient_only,
    ROUND(CAST(sum_of_util_of_eph_patient_only AS NUMERIC), 2) AS sum_of_util_of_eph_patient_only,
    ROUND(CAST(count_of_diabetes_patient_only AS NUMERIC), 2) AS count_of_diabetes_patient_only,
    ROUND(CAST(sum_of_util_of_diabetes_patient_only AS NUMERIC), 2) AS sum_of_util_of_diabetes_patient_only,
    ROUND(CAST(count_of_dyslipidaemia_patient_only AS NUMERIC), 2) AS count_of_dyslipidaemia_patient_only,
    ROUND(CAST(sum_of_util_of_dyslipidaemia_patient_only AS NUMERIC), 2) AS sum_of_util_of_dyslipidaemia_patient_only,

    ROUND(CAST(count_of_rapid_readmissions AS NUMERIC), 2) AS count_of_rapid_readmissions,
    ROUND(CAST(count_of_unique_inpatient_stays AS NUMERIC), 2) AS count_of_unique_inpatient_stays,
    ROUND(CAST(readmission_rate AS NUMERIC), 2) AS readmission_rate,

    ROUND(CAST(count_of_rapid_cardiometabolic_readmissions AS NUMERIC), 2) AS count_of_rapid_cardiometabolic_readmissions,
    ROUND(CAST(count_of_unique_cardiometabolic_inpatient_stays AS NUMERIC), 2) AS count_of_unique_cardiometabolic_inpatient_stays,
    ROUND(CAST(cardiometabolic_readmission_rate AS NUMERIC), 2) AS cardiometabolic_readmission_rate,

    ROUND(CAST(count_of_unique_emergencies AS NUMERIC), 2) AS count_of_unique_emergencies,        
    ROUND(CAST(count_of_panic_visits AS NUMERIC), 2) AS count_of_panic_visits,
    ROUND(CAST(panic_visit_rate AS NUMERIC), 2) AS panic_visit_rate,
    ROUND(CAST(count_of_non_panic_visits AS NUMERIC), 2) AS count_of_non_panic_visits,
    ROUND(CAST(non_panic_visit_rate AS NUMERIC), 2) AS non_panic_visit_rate,

    ROUND(CAST(total_pcc_availment_count AS NUMERIC), 2) AS total_pcc_availment_count,
    ROUND(CAST(total_pcc_availment_cost AS NUMERIC), 2) AS total_pcc_availment_cost,

    ROUND(CAST(ave_12_month_pcc_availment_cost_per_patient AS NUMERIC), 2) AS ave_12_month_pcc_availment_cost_per_patient,
    ROUND(CAST(ave_12_month_pcc_availment_count_per_patient AS NUMERIC), 2) AS ave_12_month_pcc_availment_count_per_patient

FROM physician_engine

WHERE providername IN (
    SELECT providername FROM (
        SELECT 
            starting_providername AS providername,
            SUM(overall_util) AS total_util
        FROM {{ref(px_engine_model)}}
        WHERE {{ icd_column }} IN (
        {% for icd in primaryicdgroup_list %}
            '{{ icd }}'{% if not loop.last %}, {% endif %}
        {% endfor %}
        )
        GROUP BY 1
        ORDER BY total_util DESC 
        LIMIT {{ top_n_provider }}
    )
)
AND total_unique_patient_cnt > {{ more_than_n_patients }}
ORDER BY ave_12_month_util_per_patient DESC
LIMIT {{top_n_physicians}}

{% endmacro %}
