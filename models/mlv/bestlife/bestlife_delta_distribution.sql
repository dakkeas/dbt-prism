{{ config(materialized = 'table') }}

-- BestLife Delta Distribution Model
-- Unpivots key metrics from bestlife_before_after_px_engine and calculates statistical distributions of patient-level deltas overall.
--
-- Calculations & Transformations Context:
-- 1. patient_level_unpivoted: Unpivots columns from the base model so that each patient-metric combination has its own row.
--    This standardizes the inputs (before_val, after_val, delta_val) into a single processing schema.
-- 2. final: Aggregates across all patients per metric to calculate descriptive statistics:
--    - Count and percentage of patients showing a decrease (delta < 0), no change (delta = 0), or increase (delta > 0).
--    - Average values for pre-enrollment ('before'), post-enrollment ('after'), and average of the individual deltas.
--    - Standard dispersion metrics: minimum, maximum, and standard deviation of deltas.
--    - Quantiles (25th, 50th/median, 75th percentiles) to assess skewness and distribution of the impact.

with source_data as (
    select * from {{ ref('bestlife_before_after_px_engine') }}
),

patient_level_unpivoted as (
    select
        final_patient_code,
        'overall_utilization_amount' as metric_name,
        before_overall_util as before_val,
        after_overall_util as after_val,
        delta_overall_util as delta_val
    from source_data
    union all
    select
        final_patient_code,
        'overall_claim_count' as metric_name,
        before_overall_count_of_claims as before_val,
        after_overall_count_of_claims as after_val,
        delta_overall_count_of_claims as delta_val
    from source_data
    union all
    select
        final_patient_code,
        'outpatient_lab_utilization_amount' as metric_name,
        before_opl_util as before_val,
        after_opl_util as after_val,
        delta_opl_util as delta_val
    from source_data
    union all
    select
        final_patient_code,
        'outpatient_lab_claim_count' as metric_name,
        before_opl_coc as before_val,
        after_opl_coc as after_val,
        delta_opl_coc as delta_val
    from source_data
    union all
    select
        final_patient_code,
        'inpatient_utilization_amount' as metric_name,
        before_inp_util as before_val,
        after_inp_util as after_val,
        delta_inp_util as delta_val
    from source_data
    union all
    select
        final_patient_code,
        'inpatient_claim_count' as metric_name,
        before_inp_coc as before_val,
        after_inp_coc as after_val,
        delta_inp_coc as delta_val
    from source_data
    union all
    select
        final_patient_code,
        'other_utilization_amount' as metric_name,
        before_others_util as before_val,
        after_others_util as after_val,
        delta_others_util as delta_val
    from source_data
    union all
    select
        final_patient_code,
        'other_claim_count' as metric_name,
        before_others_coc as before_val,
        after_others_coc as after_val,
        delta_others_coc as delta_val
    from source_data
    union all
    select
        final_patient_code,
        'total_length_of_stay_days' as metric_name,
        before_total_lengthofstay as before_val,
        after_total_lengthofstay as after_val,
        delta_total_lengthofstay as delta_val
    from source_data
    union all
    select
        final_patient_code,
        'panic_visit_count' as metric_name,
        before_count_of_panic_visits as before_val,
        after_count_of_panic_visits as after_val,
        delta_count_of_panic_visits as delta_val
    from source_data
    union all
    select
        final_patient_code,
        'unique_emergency_visit_count' as metric_name,
        before_count_of_unique_emergencies as before_val,
        after_count_of_unique_emergencies as after_val,
        delta_count_of_unique_emergencies as delta_val
    from source_data
    union all
    select
        final_patient_code,
        'rapid_readmission_count' as metric_name,
        before_count_of_rapid_readmissions as before_val,
        after_count_of_rapid_readmissions as after_val,
        delta_count_of_rapid_readmissions as delta_val
    from source_data
    union all
    select
        final_patient_code,
        'unique_inpatient_stay_count' as metric_name,
        before_count_of_unique_inpatient_stays as before_val,
        after_count_of_unique_inpatient_stays as after_val,
        delta_count_of_unique_inpatient_stays as delta_val
    from source_data
    union all
    select
        final_patient_code,
        'unique_cardiometabolic_inpatient_stay_count' as metric_name,
        before_count_of_unique_cardiometabolic_inpatient_stays as before_val,
        after_count_of_unique_cardiometabolic_inpatient_stays as after_val,
        delta_count_of_unique_cardiometabolic_inpatient_stays as delta_val
    from source_data
    union all
    select
        final_patient_code,
        'rapid_cardiometabolic_readmission_count' as metric_name,
        before_count_of_rapid_cardiometabolic_readmissions as before_val,
        after_count_of_rapid_cardiometabolic_readmissions as after_val,
        delta_count_of_rapid_cardiometabolic_readmissions as delta_val
    from source_data
    union all
    select
        final_patient_code,
        'non_panic_visit_count' as metric_name,
        before_count_of_non_panic_visits as before_val,
        after_count_of_non_panic_visits as after_val,
        delta_count_of_non_panic_visits as delta_val
    from source_data
    union all
    select
        final_patient_code,
        'professional_fee_amount' as metric_name,
        before_sum_professional_fees as before_val,
        after_sum_professional_fees as after_val,
        delta_sum_professional_fees as delta_val
    from source_data
    union all
    select
        final_patient_code,
        'philhealth_benefit_amount' as metric_name,
        before_sum_philhealth as before_val,
        after_sum_philhealth as after_val,
        delta_sum_philhealth as delta_val
    from source_data
),

final as (
    select
        metric_name,
        count(distinct final_patient_code) as total_patient_count,
        
        -- Patients Decreased: Number of patients whose metric value went down in the 'after' period (delta < 0).
        -- For cost, panic visits, or inpatient stays, a decrease is generally a positive clinical/financial outcome.
        count(distinct case when delta_val < 0 then final_patient_code end) as decreased_patient_count,
        round(
            cast(count(distinct case when delta_val < 0 then final_patient_code end) as numeric) 
            / nullif(cast(count(distinct final_patient_code) as numeric), 0),
            4
        ) as decreased_patient_pct,

        -- Patients No Change: Number of patients whose metric value remained identical (delta = 0).
        -- This includes patients who had zero utilization/claims in both pre and post periods.
        count(distinct case when delta_val = 0 then final_patient_code end) as no_change_patient_count,
        round(
            cast(count(distinct case when delta_val = 0 then final_patient_code end) as numeric) 
            / nullif(cast(count(distinct final_patient_code) as numeric), 0),
            4
        ) as no_change_patient_pct,

        -- Patients Increased: Number of patients whose metric value rose in the 'after' period (delta > 0).
        count(distinct case when delta_val > 0 then final_patient_code end) as increased_patient_count,
        round(
            cast(count(distinct case when delta_val > 0 then final_patient_code end) as numeric) 
            / nullif(cast(count(distinct final_patient_code) as numeric), 0),
            4
        ) as increased_patient_pct,

        round(cast(avg(before_val) as numeric), 2) as avg_before_val,
        round(cast(avg(after_val) as numeric), 2) as avg_after_val,
        round(cast(avg(delta_val) as numeric), 2) as avg_delta_val,
        round(
            cast(avg(after_val) - avg(before_val) as numeric) / nullif(cast(avg(before_val) as numeric), 0),
            4
        ) as pct_change_avg,

        round(cast(min(delta_val) as numeric), 2) as min_delta_val,
        round(cast(max(delta_val) as numeric), 2) as max_delta_val,
        round(cast(stddev(delta_val) as numeric), 2) as stddev_delta_val,

        {% if target.type == 'bigquery' %}
            round(cast(approx_quantiles(delta_val, 100)[offset(25)] as numeric), 2) as p25_delta_val,
            round(cast(approx_quantiles(delta_val, 100)[offset(50)] as numeric), 2) as p50_delta_val,
            round(cast(approx_quantiles(delta_val, 100)[offset(75)] as numeric), 2) as p75_delta_val
        {% else %}
            round(cast(percentile_cont(0.25) within group (order by delta_val) as numeric), 2) as p25_delta_val,
            round(cast(percentile_cont(0.50) within group (order by delta_val) as numeric), 2) as p50_delta_val,
            round(cast(percentile_cont(0.75) within group (order by delta_val) as numeric), 2) as p75_delta_val
        {% endif %}
    from patient_level_unpivoted
    group by 1
)

select *
from final
order by metric_name
