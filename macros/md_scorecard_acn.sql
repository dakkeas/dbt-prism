{% macro md_scorecard_acn(primaryicdgroup_list, top_n_provider, top_n_physicians, more_than_n_patients) %}

WITH physician_engine AS (
    SELECT
        -- IDENTIFIERS
        -- COALESCE(md.formatted_physicianname, pe.starting_physicianname) AS physicianname,
        pe.starting_physicianname as physicianname,
        MAX(pe.starting_physiciancode) AS physiciancode,
        pe.starting_providername AS providername,
        -- CONCAT(COALESCE(md.formatted_physicianname, pe.starting_physicianname), ' - ', pe.starting_providername) AS physician_providername,
        CONCAT(pe.starting_physicianname, ' - ', pe.starting_providername) AS physician_providername,
        pe.starting_mainspecialization AS main_specialization,
        -- STRING_AGG(DISTINCT CASE
        --     WHEN TRIM(pe.starting_mainspecialization) NOT IN (' ', '') AND pe.starting_mainspecialization IS NOT NULL THEN pe.starting_mainspecialization
        -- END, ', ') AS main_specializations,

        STRING_AGG(DISTINCT CASE
            WHEN TRIM(pe.combined_starting_primaryicdgroup) NOT IN (' ', '') AND pe.combined_starting_primaryicdgroup IS NOT NULL THEN pe.combined_starting_primaryicdgroup
        END, ', ') AS combined_starting_primaryicdgroup,



        -- BASE METRICS
        COUNT(DISTINCT pe.maskedcardno) AS total_unique_patient_cnt,
        SUM(pe.overall_count_of_claims) AS total_claim_count,
        SUM(pe.overall_util) AS total_util,
        COALESCE(SUM(pe.overall_util) / NULLIF(COUNT(DISTINCT pe.maskedcardno), 0), 0) AS ave_12_month_util_per_patient,

        {% set loatypes = [
            ('ACU', 'acu'), 
            ('CONSULT', 'consult'), 
            ('Corporate Clinic', 'corporate_clinic'), 
            ('DENTAL', 'dental'), 
            ('EMERGENCY', 'emergency'), 
            ('INPATIENT', 'inpatient'), 
            ('Medgrocer', 'medgrocer'), 
            ('PROCEDURE', 'procedure'), 
            ('VIDEO CALL', 'video_call'), 
            ('VOICE CALL', 'voice_call'), 
            ('Zennya (Home Care)', 'zennya_home_care')
        ] %}
        
        {% for l, l_slug in loatypes %}
        -- =============================================
        -- {{ l | upper }} METRICS
        -- =============================================
        COUNT(DISTINCT CASE WHEN pe.{{ l_slug }}_coc > 0 THEN pe.maskedcardno END) AS {{ l_slug }}_unique_px_count_at_least_one,
        
        COALESCE(
            CAST(COUNT(DISTINCT CASE WHEN pe.{{ l_slug }}_coc > 0 THEN pe.maskedcardno END) AS NUMERIC)
            / NULLIF(COUNT(DISTINCT pe.maskedcardno), 0)
        , 0) AS {{ l_slug }}_unique_px_count_at_least_one_pct,

        COALESCE(
            CAST(SUM(pe.{{ l_slug }}_coc) AS NUMERIC)
            / NULLIF(COUNT(DISTINCT CASE WHEN pe.{{ l_slug }}_coc > 0 THEN pe.maskedcardno END), 0)
        , 0) AS {{ l_slug }}_ave_claims_per_px_at_least_one,

        SUM(pe.{{ l_slug }}_coc) AS {{ l_slug }}_total_claims,

        COALESCE(
            CAST(SUM(pe.{{ l_slug }}_util) AS NUMERIC)
            / NULLIF(SUM(pe.{{ l_slug }}_coc), 0)
        , 0) AS {{ l_slug }}_ave_cost_per_claim_per_px_at_least_one,

        SUM(pe.{{ l_slug }}_util) AS {{ l_slug }}_sum_of_util,

        COALESCE(
            CAST(SUM(pe.{{ l_slug }}_util) AS NUMERIC)
            / NULLIF(COUNT(DISTINCT pe.maskedcardno), 0)
        , 0) AS {{ l_slug }}_ave_twelve_month_util_per_px,
        {% endfor %}

        -- Journey Metrics
        COALESCE(SUM(CASE WHEN pe.patient_journey_category = 'End-Stage Cardiometabolic Disease Patient' THEN 1 END), 0) AS count_of_end_stage_cardiometabolic_disease_patient,
        COALESCE(SUM(CASE WHEN pe.patient_journey_category = 'End-Stage Cardiometabolic Disease Patient' THEN pe.overall_util END), 0) AS sum_of_util_of_end_stage_cardiometabolic_disease_patient,

        COALESCE(SUM(CASE WHEN pe.patient_journey_category = 'Essential (Primary) Hypertension Patient Only' THEN 1 END), 0) AS count_of_eph_patient_only,
        COALESCE(SUM(CASE WHEN pe.patient_journey_category = 'Essential (Primary) Hypertension Patient Only' THEN pe.overall_util END), 0) AS sum_of_util_of_eph_patient_only,

        COALESCE(SUM(CASE WHEN pe.patient_journey_category = 'Diabetes Mellitus Patient Only' THEN 1 END), 0) AS count_of_diabetes_patient_only,
        COALESCE(SUM(CASE WHEN pe.patient_journey_category = 'Diabetes Mellitus Patient Only' THEN pe.overall_util END), 0) AS sum_of_util_of_diabetes_patient_only,

        COALESCE(SUM(CASE WHEN pe.patient_journey_category = 'Dyslipidaemia Patient Only' THEN 1 END), 0) AS count_of_dyslipidaemia_patient_only,
        COALESCE(SUM(CASE WHEN pe.patient_journey_category = 'Dyslipidaemia Patient Only' THEN pe.overall_util END), 0) AS sum_of_util_of_dyslipidaemia_patient_only,

        -- ER METRICS
        COALESCE(SUM(pe.count_of_unique_emergencies), 0) AS count_of_unique_emergencies,
        COALESCE(SUM(pe.count_of_panic_visits), 0) AS count_of_panic_visits,
        COALESCE(CAST(SUM(pe.count_of_panic_visits) AS NUMERIC) / NULLIF(SUM(pe.count_of_unique_emergencies), 0), 0) AS panic_visit_rate,

        COALESCE(SUM(pe.count_of_non_panic_visits), 0) AS count_of_non_panic_visits,
        COALESCE(CAST(SUM(pe.count_of_non_panic_visits) AS NUMERIC) / NULLIF(SUM(pe.count_of_unique_emergencies), 0), 0) AS non_panic_visit_rate

    FROM {{ ref('px_engine_acn') }} pe

    -- LEFT JOIN {{ source('md_fuzzy_from_physicianinfo', 'physician_name_matching_results') }} md
    --     ON pe.starting_physicianname = md.broken_physicianname_original
    --     AND md.final_score >= 65

    WHERE pe.combined_starting_primaryicdgroup IN (
        {% for icd in primaryicdgroup_list %}
            '{{ icd }}'{% if not loop.last %}, {% endif %}
        {% endfor %}
    )

    GROUP BY 
        -- COALESCE(md.formatted_physicianname, pe.starting_physicianname),
        pe.starting_physicianname,
        pe.starting_providername,
        pe.starting_mainspecialization
)

SELECT
    physician_providername,
    physicianname,
    providername,
    main_specialization,
    combined_starting_primaryicdgroup,
    
    total_unique_patient_cnt,
    total_claim_count,
    total_util AS all_claims_sum_of_util,
    ave_12_month_util_per_patient,

    {% for l, l_slug in loatypes %}
    {{ l_slug }}_unique_px_count_at_least_one,
    {{ l_slug }}_unique_px_count_at_least_one_pct,
    {{ l_slug }}_ave_claims_per_px_at_least_one,
    {{ l_slug }}_total_claims,
    {{ l_slug }}_ave_cost_per_claim_per_px_at_least_one,
    {{ l_slug }}_sum_of_util,
    {{ l_slug }}_ave_twelve_month_util_per_px,
    {% endfor %}

    COALESCE(NULLIF(CAST(count_of_end_stage_cardiometabolic_disease_patient AS NUMERIC), 0) / NULLIF(CAST(total_unique_patient_cnt AS NUMERIC), 0), 0) AS percent_of_end_stage_cardiometabolic_disease_patients,
    count_of_end_stage_cardiometabolic_disease_patient,
    sum_of_util_of_end_stage_cardiometabolic_disease_patient,

    count_of_eph_patient_only,
    sum_of_util_of_eph_patient_only,

    count_of_diabetes_patient_only,
    sum_of_util_of_diabetes_patient_only,

    count_of_dyslipidaemia_patient_only,
    sum_of_util_of_dyslipidaemia_patient_only,

    count_of_unique_emergencies,
    count_of_panic_visits,
    panic_visit_rate,
    count_of_non_panic_visits,
    non_panic_visit_rate

FROM physician_engine

	WHERE providername IN (
	    SELECT providername FROM (
	        SELECT 
	            starting_providername AS providername,
	            SUM(overall_util) AS total_util
	        FROM {{ ref('px_engine_acn') }}
	        WHERE combined_starting_primaryicdgroup IN (
            {% for icd in primaryicdgroup_list %}
                '{{ icd }}'{% if not loop.last %}, {% endif %}
            {% endfor %}
        )
	        GROUP BY 1
	        ORDER BY total_util DESC 
	        LIMIT {{ top_n_provider }}
	    ) provider_totals
	)
	AND total_unique_patient_cnt > {{ more_than_n_patients }}
	ORDER BY ave_12_month_util_per_patient DESC
	LIMIT {{ top_n_physicians }}

{% endmacro %}
