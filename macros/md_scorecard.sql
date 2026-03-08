{% documentation %}

md_scorecard

## Description
Generates a physician and provider scorecard with detailed metrics across multiple service categories
(outpatient lab, inpatient, others) for a specified set of ICD diagnosis groups. Metrics include
utilization, claims, patient counts, and cost analysis.

## Variables (Parameters)

- `primaryicdgroup_list` (list of strings): List of primary ICD group codes to filter physicians and claims.
  Example: ['DIABETES MELLITUS', 'ESSENTIAL (PRIMARY) HYPERTENSION']
  
- `top_n_provider` (integer): Number of top providers (by total utilization) to include in the results.
  Only physicians from these providers will be returned.
  
- `top_n_physicians` (integer): Maximum number of physicians to return in the final result.
  Results are ordered by average 12-month utilization per patient (descending).
  
- `more_than_n_patients` (integer): Minimum threshold for total unique patients per physician.
  Only physicians with at least this many unique patients during the period are included.

## Output Metrics by Category

### 1. Identifier Columns
- `physician_providername`: Concatenated physician code and provider name
- `physiciancode`: Unique physician identifier
- `providername`: Provider name
- `physicianname`: Full physician name
- `specialization`: Medical specialization/specialty

### 2. Base Patient Metrics
- `total_unique_patient_cnt`: Count of distinct patients seen by the physician

### 3. All Claims Metrics (across all service types)
- `total_claim_count`: Total number of claims submitted
- `all_claims_sum_of_util`: Total utilization (cost) across all claims
- `ave_12_month_util_per_patient`: Average utilization cost per patient over 12 months

### 4. Outpatient Lab (OPL) Metrics
- `opl_unique_px_cnt_at_least_one`: Count of patients with at least one OPL claim
- `opl_unique_px_count_at_least_one_pct`: Percentage of patients with at least one OPL claim
- `opl_ave_claims_per_px_at_least_one`: Average number of OPL claims per patient (among those with claims)
- `opl_total_claims`: Total OPL claims submitted
- `opl_ave_cost_per_claim_per_px_at_least_one`: Average cost per OPL claim (among patients with claims)
- `opl_sum_of_util`: Total OPL utilization (sum of costs)
- `opl_per_capita`: Per-capita OPL metric (% of patients × ave claims × ave cost per claim)
- `opl_ave_twelve_month_util_per_px`: Average OPL utilization per total patient population

### 5. Inpatient (INP) Metrics
- `inp_unique_px_count_at_least_one`: Count of patients with at least one inpatient claim
- `inp_unique_px_count_at_least_one_pct`: Percentage of patients with at least one inpatient claim
- `inp_ave_claims_per_px_at_least_one`: Average number of inpatient claims per patient (among those with claims)
- `inp_total_claims`: Total inpatient claims submitted
- `inp_ave_cost_per_claim_per_px_at_least_one`: Average cost per inpatient claim (among patients with claims)
- `inp_sum_of_util`: Total inpatient utilization (sum of costs)
- `inp_per_capita`: Per-capita inpatient metric (% of patients × ave claims × ave cost per claim)
- `inp_ave_twelve_month_util_per_px`: Average inpatient utilization per total patient population

### 6. Others (Other Service Categories) Metrics
- `others_unique_px_count_at_least_one`: Count of patients with at least one claim in other categories
- `others_unique_px_count_at_least_one_pct`: Percentage of patients with claims in other categories
- `others_ave_claims_per_px_at_least_one`: Average number of claims per patient (among those with claims)
- `others_total_claims`: Total claims in other categories
- `others_ave_cost_per_claim_per_px_at_least_one`: Average cost per claim (among patients with claims)
- `others_sum_of_util`: Total utilization in other categories
- `others_per_capita`: Per-capita metric for other categories (% of patients × ave claims × ave cost per claim)
- `others_ave_twelve_month_util_per_px`: Average utilization per total patient population

### 7. PhilHealth Metrics
- `total_philhealth`: Total PhilHealth benefit amounts claimed
- `ave_philhealth_claim`: Average PhilHealth benefit per patient

### 8. Procedure Code (CPT) Metrics
- `total_overall_cptcode_count`: Total count of CPT codes across all service types
- `total_overall_cptcode_util`: Total utilization associated with all CPT codes
- `overall_cptcode_avg_count_per_px`: Average number of CPT codes per patient
- `overall_cptcode_avg_util_per_px`: Average CPT code utilization per patient

### 9. RUV Code Metrics
- `total_overall_ruvcode_count`: Total count of RUV codes across all service types
- `total_overall_ruvcode_util`: Total utilization associated with all RUV codes
- `overall_ruvcode_avg_count_per_px`: Average number of RUV codes per patient
- `overall_ruvcode_avg_util_per_px`: Average RUV code utilization per patient

## Data Sources
- `px_engine`: Source for physician claim and utilization data
- `physicianinfo`: Lookup table for physician name and specialization information
- `provider_engine`: Source for provider-level aggregation

{% enddocumentation %}

{% macro md_scorecard(primaryicdgroup_list, top_n_provider, top_n_physicians, more_than_n_patients) %}


WITH physician_engine AS (
    SELECT
        -- IDENTIFIERS
        
        CONCAT(starting_physiciancode, ' - ', starting_providername) AS physician_providername,
        starting_physiciancode AS physiciancode,
        starting_providername AS providername,
        MIN(grouped_starting_primaryicdgroup) AS grouped_starting_primaryicdgroup,
        MIN(pi.physicianname) AS physicianname,
        MIN(pi.specialization) AS specialization,
        -- BASE
        COUNT(DISTINCT maskedcardno) AS total_unique_patient_cnt,
        SUM(overall_count_of_claims) AS total_claim_count,
        SUM(overall_util) AS total_util,
        SUM(overall_util) / NULLIF(COUNT(DISTINCT maskedcardno), 0) AS ave_12_month_util_per_patient,
        

        -- =============================================
        -- OP LAB METRICS
        -- =============================================
        COUNT(DISTINCT CASE WHEN opl_coc > 0 THEN maskedcardno END) AS opl_unique_px_cnt_at_least_one,

        (CAST(COUNT(DISTINCT CASE WHEN opl_coc > 0 THEN maskedcardno END) AS NUMERIC)
         / NULLIF(COUNT(DISTINCT maskedcardno), 0)
        ) AS opl_unique_px_count_at_least_one_pct,

        (CAST(SUM(opl_coc) AS NUMERIC)
         / NULLIF(COUNT(DISTINCT CASE WHEN opl_coc > 0 THEN maskedcardno END), 0)
        ) AS opl_ave_claims_per_px_at_least_one,

        SUM(opl_coc) AS opl_total_claims,

        (CAST(SUM(opl_util) AS NUMERIC)
         / NULLIF(SUM(opl_coc), 0)
        ) AS opl_ave_cost_per_claim_per_px_at_least_one,

        SUM(opl_util) AS opl_sum_of_util,

        (CAST(SUM(opl_util) AS NUMERIC)
         / NULLIF(COUNT(DISTINCT maskedcardno), 0)
        ) AS opl_ave_twelve_month_util_per_px,

        -- =============================================
        -- INPATIENT METRICS
        -- =============================================
        COUNT(DISTINCT CASE WHEN inp_coc > 0 THEN maskedcardno END) AS inp_unique_px_count_at_least_one,

        (CAST(COUNT(DISTINCT CASE WHEN inp_coc > 0 THEN maskedcardno END) AS NUMERIC)
         / NULLIF(COUNT(DISTINCT maskedcardno), 0)
        ) AS inp_unique_px_count_at_least_one_pct,

        (CAST(SUM(inp_coc) AS NUMERIC)
         / NULLIF(COUNT(DISTINCT CASE WHEN inp_coc > 0 THEN maskedcardno END), 0)
        ) AS inp_ave_claims_per_px_at_least_one,

        SUM(inp_coc) AS inp_total_claims,

        (CAST(SUM(inp_util) AS NUMERIC)
         / NULLIF(SUM(inp_coc), 0)
        ) AS inp_ave_cost_per_claim_per_px_at_least_one,

        SUM(inp_util) AS inp_sum_of_util,

        (CAST(SUM(inp_util) AS NUMERIC)
         / NULLIF(COUNT(DISTINCT maskedcardno), 0)
        ) AS inp_ave_twelve_month_util_per_px,

        -- =============================================
        -- OTHERS METRICS
        -- =============================================
        COUNT(DISTINCT CASE WHEN others_coc > 0 THEN maskedcardno END) AS others_unique_px_count_at_least_one,

        (CAST(COUNT(DISTINCT CASE WHEN others_coc > 0 THEN maskedcardno END) AS NUMERIC)
         / NULLIF(COUNT(DISTINCT maskedcardno), 0)
        ) AS others_unique_px_count_at_least_one_pct,

        (CAST(SUM(others_coc) AS NUMERIC)
         / NULLIF(COUNT(DISTINCT CASE WHEN others_coc > 0 THEN maskedcardno END), 0)
        ) AS others_ave_claims_per_px_at_least_one,

        SUM(others_coc) AS others_total_claims,

        (CAST(SUM(others_util) AS NUMERIC)
         / NULLIF(SUM(others_coc), 0)
        ) AS others_ave_cost_per_claim_per_px_at_least_one,

        SUM(others_util) AS others_sum_of_util,

        (CAST(SUM(others_util) AS NUMERIC)
         / NULLIF(COUNT(DISTINCT maskedcardno), 0)
        ) AS others_ave_twelve_month_util_per_px,

        -- =============================================
        -- PHILHEALTH METRICS
        -- =============================================
        SUM(sum_philhealth) AS total_philhealth,

        CAST(SUM(sum_philhealth) AS NUMERIC)
        / CAST(COUNT(DISTINCT maskedcardno) AS NUMERIC) AS ave_philhealth_claim,

        -- =============================================
        -- CPTCODE/RUVCODE METRICS
        -- =============================================

        -- SUM of count of CPT codes
        CAST(SUM(overall_cptcode_coc) AS NUMERIC) AS total_overall_cptcode_count,
        CAST(SUM(opl_cptcode_coc) AS NUMERIC) AS total_opl_cptcode_count,
        CAST(SUM(inp_cptcode_coc) AS NUMERIC) AS total_inp_cptcode_count,
        CAST(SUM(emg_cptcode_coc) AS NUMERIC) AS total_emg_cptcode_count,

        -- SUM of utilization of CPT codes
        CAST(SUM(overall_cptcode_util) AS NUMERIC) AS total_overall_cptcode_util,
        CAST(SUM(opl_cptcode_util) AS NUMERIC) AS total_opl_cptcode_util,
        CAST(SUM(inp_cptcode_util) AS NUMERIC) AS total_inp_cptcode_util,
        CAST(SUM(emg_cptcode_util) AS NUMERIC) AS total_emg_cptcode_util,

        -- AVG count of CPT codes per patient
        CAST(SUM(overall_cptcode_coc) / NULLIF(COUNT(DISTINCT maskedcardno), 0) AS NUMERIC) AS overall_cptcode_avg_count_per_px,
        CAST(SUM(opl_cptcode_coc) / NULLIF(COUNT(DISTINCT maskedcardno), 0) AS NUMERIC) AS opl_cptcode_avg_count_per_px,
        CAST(SUM(inp_cptcode_coc) / NULLIF(COUNT(DISTINCT maskedcardno), 0) AS NUMERIC) AS inp_cptcode_avg_count_per_px,
        CAST(SUM(emg_cptcode_coc) / NULLIF(COUNT(DISTINCT maskedcardno), 0) AS NUMERIC) AS emg_cptcode_avg_count_per_px,

        -- AVG utilization of CPT codes per patient
        CAST(SUM(overall_cptcode_util) / NULLIF(COUNT(DISTINCT maskedcardno), 0) AS NUMERIC) AS overall_cptcode_avg_util_per_px,
        CAST(SUM(opl_cptcode_util) / NULLIF(COUNT(DISTINCT maskedcardno), 0) AS NUMERIC) AS opl_cptcode_avg_util_per_px,
        CAST(SUM(inp_cptcode_util) / NULLIF(COUNT(DISTINCT maskedcardno), 0) AS NUMERIC) AS inp_cptcode_avg_util_per_px,
        CAST(SUM(emg_cptcode_util) / NULLIF(COUNT(DISTINCT maskedcardno), 0) AS NUMERIC) AS emg_cptcode_avg_util_per_px,

        -- SUM of count of RUV codes
        CAST(SUM(overall_ruvcode_coc) AS NUMERIC) AS total_overall_ruvcode_count,
        CAST(SUM(opl_ruvcode_coc) AS NUMERIC) AS total_opl_ruvcode_count,
        CAST(SUM(inp_ruvcode_coc) AS NUMERIC) AS total_inp_ruvcode_count,
        CAST(SUM(emg_ruvcode_coc) AS NUMERIC) AS total_emg_ruvcode_count,

        -- SUM of utilization of RUV codes
        CAST(SUM(overall_ruvcode_util) AS NUMERIC) AS total_overall_ruvcode_util,
        CAST(SUM(opl_ruvcode_util) AS NUMERIC) AS total_opl_ruvcode_util,
        CAST(SUM(inp_ruvcode_util) AS NUMERIC) AS total_inp_ruvcode_util,
        CAST(SUM(emg_ruvcode_util) AS NUMERIC) AS total_emg_ruvcode_util,

        -- AVG count of RUV codes per patient
        CAST(SUM(overall_ruvcode_coc) / NULLIF(COUNT(DISTINCT maskedcardno), 0) AS NUMERIC) AS overall_ruvcode_avg_count_per_px,
        CAST(SUM(opl_ruvcode_coc) / NULLIF(COUNT(DISTINCT maskedcardno), 0) AS NUMERIC) AS opl_ruvcode_avg_count_per_px,
        CAST(SUM(inp_ruvcode_coc) / NULLIF(COUNT(DISTINCT maskedcardno), 0) AS NUMERIC) AS inp_ruvcode_avg_count_per_px,
        CAST(SUM(emg_ruvcode_coc) / NULLIF(COUNT(DISTINCT maskedcardno), 0) AS NUMERIC) AS emg_ruvcode_avg_count_per_px,

        -- AVG utilization of RUV codes per patient
        CAST(SUM(overall_ruvcode_util) / NULLIF(COUNT(DISTINCT maskedcardno), 0) AS NUMERIC) AS overall_ruvcode_avg_util_per_px,
        CAST(SUM(opl_ruvcode_util) / NULLIF(COUNT(DISTINCT maskedcardno), 0) AS NUMERIC) AS opl_ruvcode_avg_util_per_px,
        CAST(SUM(inp_ruvcode_util) / NULLIF(COUNT(DISTINCT maskedcardno), 0) AS NUMERIC) AS inp_ruvcode_avg_util_per_px,
        CAST(SUM(emg_ruvcode_util) / NULLIF(COUNT(DISTINCT maskedcardno), 0) AS NUMERIC) AS emg_ruvcode_avg_util_per_px,

        COALESCE(SUM(CASE
            WHEN patient_journey_category = 'End-Stage Disease Patient' THEN 1
        END), 0) AS count_of_end_stage_disease_patient,

        COALESCE(SUM(CASE
            WHEN patient_journey_category = 'Hypertension Patient Only' THEN 1
        END), 0) AS count_of_hypertension_patient_only,

        COALESCE(SUM(CASE
            WHEN patient_journey_category = 'Diabetes Patient Only' THEN 1
        END), 0) AS count_of_diabetes_patient_only,

        COALESCE(SUM(CASE
            WHEN patient_journey_category = 'Lipidaemias Patient Only' THEN 1
        END), 0) AS count_of_lipidaemias_patient_only


    FROM {{ ref('px_engine') }} pe
    LEFT JOIN (SELECT DISTINCT physiciancode, providername, physicianname, specialization FROM {{ ref('physicianinfo') }}) pi
    ON TRIM(UPPER(pe.starting_physiciancode)) = 
        {% if target.type == 'bigquery' %}
            CAST(pi.physiciancode AS STRING)
        {% else %}
            pi.physiciancode::TEXT
        {% endif %}
    AND pe.starting_providername = pi.providername


    WHERE pe.starting_primaryicdgroup IN (
    {% for icd in primaryicdgroup_list %}
        '{{ icd }}'{% if not loop.last %}, {% endif %}
    {% endfor %}
    )
    GROUP BY starting_physiciancode, starting_providername
)
SELECT
    -- 1. IDENTIFIERS
    physician_providername,
    physiciancode,
    providername,
    physicianname,
    specialization,
    grouped_starting_primaryicdgroup,
    
    -- 2. BASE PATIENT METRICS
    total_unique_patient_cnt,
    

    -- 4. ALL CLAIMS METRICS
    total_claim_count,
    total_util AS all_claims_sum_of_util,
    ave_12_month_util_per_patient,

    -- 5. OP LAB METRICS
    opl_unique_px_cnt_at_least_one,
    opl_unique_px_count_at_least_one_pct,
    opl_ave_claims_per_px_at_least_one,
    opl_total_claims,
    opl_ave_cost_per_claim_per_px_at_least_one,
    opl_sum_of_util,

    opl_unique_px_count_at_least_one_pct * 
    opl_ave_claims_per_px_at_least_one * 
    opl_ave_cost_per_claim_per_px_at_least_one AS opl_per_capita,

    opl_ave_twelve_month_util_per_px,

    -- 6. INPATIENT METRICS
    inp_unique_px_count_at_least_one,
    inp_unique_px_count_at_least_one_pct,
    inp_ave_claims_per_px_at_least_one,
    inp_total_claims,
    inp_ave_cost_per_claim_per_px_at_least_one,
    inp_sum_of_util,

    inp_unique_px_count_at_least_one_pct * 
    inp_ave_claims_per_px_at_least_one * 
    inp_ave_cost_per_claim_per_px_at_least_one AS inp_per_capita,

    inp_ave_twelve_month_util_per_px,

    -- 7. OTHERS METRICS
    others_unique_px_count_at_least_one,
    others_unique_px_count_at_least_one_pct,
    others_ave_claims_per_px_at_least_one,
    others_total_claims,
    others_ave_cost_per_claim_per_px_at_least_one,
    others_sum_of_util,

    others_unique_px_count_at_least_one_pct * 
    others_ave_claims_per_px_at_least_one * 
    others_ave_cost_per_claim_per_px_at_least_one AS others_per_capita,

    others_ave_twelve_month_util_per_px,

    -- 8. PHILHEALTH METRICS
    total_philhealth,
    ave_philhealth_claim,

    total_overall_cptcode_count,
    total_overall_cptcode_util,
    overall_cptcode_avg_count_per_px,
    overall_cptcode_avg_util_per_px,

    
    total_overall_ruvcode_count,
    total_overall_ruvcode_util,
    overall_ruvcode_avg_count_per_px,
    overall_ruvcode_avg_util_per_px,

    COALESCE(NULLIF(CAST(count_of_end_stage_disease_patient AS NUMERIC), 0) / NULLIF(CAST(total_unique_patient_cnt AS NUMERIC), 0), 0) AS percent_of_end_stage_disease_patients,

    count_of_end_stage_disease_patient,
    count_of_hypertension_patient_only,
    count_of_diabetes_patient_only,
    count_of_lipidaemias_patient_only

FROM physician_engine

    WHERE providername IN (
        SELECT providername FROM (
            SELECT 
            starting_providername AS providername,
            SUM(total_util) AS total_util
            FROM {{ref('provider_engine')}}
            -- WHERE starting_primaryicdgroup = 'ESSENTIAL (PRIMARY) HYPERTENSION'
            WHERE starting_primaryicdgroup IN (
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