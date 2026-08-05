{{ config(materialized = 'table') }}

-- Table transformations:
-- 1. Identify eligible BestLife patients and enrollment windows.
-- 2. Pull MXC claims into before/after periods around enrollment.
-- 3. Roll raw claim rows to claim grain before calculating PX-style metrics.
-- 4. Aggregate period metrics, then output before, after, delta, and safe percent-change columns.

with bestlife_unmaskedcardno as (
    -- Normalize the BestLife card-number mapping and keep only usable masked card links.
    select distinct
        maskedcardno,
        replace(trim(cardno), ' ', '') as cardno_norm
    from {{ ref('bestlife_unmaskedcardno') }}
    where nullif(trim(cardno), '') is not null
      and nullif(trim(maskedcardno), '') is not null
),

reference_member_base as (
    -- Prepare one BestLife seed profile per patient/card, using baseline test date as enrollment date.
    select
        final_patient_code,
        replace(cardno, ' ', '') as cardno_norm,
        string_agg(distinct patient_code_full_name, ', ') as patient_code_full_name,
        string_agg(distinct cardno, ', ' order by cardno) as cardnos,
        string_agg(distinct activity_status, ', ' order by activity_status) as activity_status,
        string_agg(distinct final_company, ', ' order by final_company) as final_company,
        string_agg(distinct member_type, ', ' order by member_type) as member_type,
        min(inactive_tagging_date) as inactive_tagging_date,
        min(dropout_date) as dropout_date,
        min(baseline_test_date_final) as enrollment_date
    from {{ ref('seed_bestlife_unmasked_patient_no') }}
    where nullif(trim(cardno), '') is not null
      and nullif(trim(final_patient_code), '') is not null
    group by 1, 2
),

bestlife_patient_cards as (
    -- Match BestLife seed patients to MXC masked card numbers through normalized card number.
    select distinct
        r.final_patient_code,
        r.patient_code_full_name,
        r.cardnos,
        r.activity_status,
        r.final_company,
        r.member_type,
        r.inactive_tagging_date,
        r.dropout_date,
        r.enrollment_date,
        b.maskedcardno
    from reference_member_base r
    inner join bestlife_unmaskedcardno b
        on r.cardno_norm = b.cardno_norm
),

eligible_patients as (
    -- Collapse matched cards to patient grain and apply before-window and inactive-date eligibility.
    select
        final_patient_code,
        string_agg(distinct patient_code_full_name, ', ') as patient_code_full_name,
        string_agg(distinct maskedcardno, ', ' order by maskedcardno) as maskedcardnos,
        string_agg(distinct cardnos, ', ' order by cardnos) as cardnos,
        string_agg(distinct activity_status, ', ' order by activity_status) as activity_status,
        string_agg(distinct final_company, ', ' order by final_company) as final_company,
        string_agg(distinct member_type, ', ' order by member_type) as member_type,
        min(inactive_tagging_date) as inactive_tagging_date,
        min(dropout_date) as dropout_date,
        min(enrollment_date) as enrollment_date,
        {% if target.type == 'bigquery' %}
            min(enrollment_date) - interval 12 month as before_period_start,
            min(enrollment_date) as before_period_end,
            min(enrollment_date) as after_period_start,
            min(enrollment_date) + interval 12 month as after_period_end
        {% else %}
            min(enrollment_date) - interval '12 months' as before_period_start,
            min(enrollment_date) as before_period_end,
            min(enrollment_date) as after_period_start,
            min(enrollment_date) + interval '12 months' as after_period_end
        {% endif %}
    from bestlife_patient_cards
    group by 1
    having min(enrollment_date) is not null
       and min(enrollment_date) >= date '2020-01-01'
       and (
            min(inactive_tagging_date) is null
            {% if target.type == 'bigquery' %}
                or min(inactive_tagging_date) >= min(enrollment_date) + interval 12 month
            {% else %}
                or min(inactive_tagging_date) >= min(enrollment_date) + interval '12 months'
            {% endif %}
       )
),

eligible_patient_cards as (
    -- Re-expand eligible patients to their masked card numbers for claim joins.
    select distinct
        ep.final_patient_code,
        ep.enrollment_date,
        ep.before_period_start,
        ep.after_period_end,
        bpc.maskedcardno
    from eligible_patients ep
    inner join bestlife_patient_cards bpc
        on ep.final_patient_code = bpc.final_patient_code
),

mxc_claims as (
    -- Limit MXC source claims to the available 2019-2025 claim universe with valid admission dates.
    select *
    from {{ ref('mxc_raw_claims') }}
    where source_year between 2019 and 2025
      and nullif(trim(maskedcardno), '') is not null
      and admissiondate is not null
),

period_claim_rows as (
    -- Attach eligible patient claims to the 12-month before or after enrollment window.
    -- Enrollment-day claims belong to the after period.
    select
        epc.final_patient_code,
        case
            {% if target.type == 'bigquery' %}
                when c.admissiondate >= epc.enrollment_date - interval 12 month
                 and c.admissiondate < epc.enrollment_date
                    then 'before'
                when c.admissiondate >= epc.enrollment_date
                 and c.admissiondate <= epc.enrollment_date + interval 12 month
                    then 'after'
            {% else %}
                when c.admissiondate >= epc.enrollment_date - interval '12 months'
                 and c.admissiondate < epc.enrollment_date
                    then 'before'
                when c.admissiondate >= epc.enrollment_date
                 and c.admissiondate <= epc.enrollment_date + interval '12 months'
                    then 'after'
            {% endif %}
        end as period,
        c.*
    from eligible_patient_cards epc
    inner join mxc_claims c
        on epc.maskedcardno = c.maskedcardno
        {% if target.type == 'bigquery' %}
           and c.admissiondate >= epc.enrollment_date - interval 12 month
           and c.admissiondate <= epc.enrollment_date + interval 12 month
        {% else %}
           and c.admissiondate >= epc.enrollment_date - interval '12 months'
           and c.admissiondate <= epc.enrollment_date + interval '12 months'
        {% endif %}
),

claim_rollup as (
    -- Roll raw MXC claim lines to claim grain so utilization and claim counts are not line-inflated.
    select
        final_patient_code,
        period,
        claimno,
        min(maskedcardno) as maskedcardno,
        min(corpname) as corpname,
        min(membertypedesc) as membertypedesc,
        min(relationship) as relationship,
        min(admissiondate) as admissiondate,
        max(dischargedate) as dischargedate,
        nullif(min(lengthofstay), 0) as lengthofstay,
        min(providername) as providername,
        min(physiciancode) as physiciancode,
        min(primaryicdgroup) as primaryicdgroup,
        nullif(trim(min(primaryicdcode)), '') as primaryicdcode,
        min(primaryicddesc) as primaryicddesc,
        min(loatype) as loatype,
        min(coverage) as coverage,
        sum(coalesce(billed, 0)) as billed,
        sum(coalesce(approved, 0)) as approved,
        sum(case when coverageitemdesc = 'PHILHEALTH' then abs(coalesce(approved, 0)) else 0 end) as philhealth,
        sum(
            case
                when coverageitemdesc in (
                    'SURGEON',
                    'CONSULT/ATTENDING PHYSICIAN',
                    'DOCTOR SERVICES',
                    'ANESTHESIOLOGIST'
                )
                    then abs(coalesce(approved, 0))
                else 0
            end
        ) as professional_fees,
        sum(case when nullif(cptcode, '') is not null then 1 else 0 end) as count_of_cptcode,
        sum(case when nullif(cptcode, '') is not null then coalesce(approved, 0) else 0 end) as sum_of_util_cptcode,
        sum(case when nullif(ruvcode, '') is not null then 1 else 0 end) as count_of_ruvcode,
        sum(case when nullif(ruvcode, '') is not null then coalesce(approved, 0) else 0 end) as sum_of_util_ruvcode
    from period_claim_rows
    where period is not null
    group by 1, 2, 3
),

target_cardiometabolic_primaryicdcodes as (
    -- Combine cardiometabolic ICD reference lists used for readmission classification.
    select primaryicdcode
    from {{ ref('cardiometabolic_primaryicdcodes') }}
    union distinct
    select primaryicdcode
    from {{ ref('end_stage_cardiometabolic_primaryicdcodes') }}
),

unique_admissions as (
    -- Reduce ER/inpatient claims to unique patient-period-date-type encounters.
    select
        final_patient_code,
        period,
        admissiondate,
        loatype,
        coalesce(max(lengthofstay), 0) as max_lengthofstay,
        max(dischargedate) as dischargedate,
        max(
            case
                when primaryicdcode in (
                    select primaryicdcode
                    from target_cardiometabolic_primaryicdcodes
                )
                    then 1
                else 0
            end
        ) as is_cardiometabolic_stay
    from claim_rollup
    where loatype in ('INPATIENT', 'EMERGENCY')
    group by 1, 2, 3, 4
),

inpatient_journey as (
    -- Order inpatient encounters within each period to identify the next inpatient stay.
    select
        *,
        lead(admissiondate) over (
            partition by final_patient_code, period
            order by admissiondate
        ) as next_admissiondate,
        lead(is_cardiometabolic_stay) over (
            partition by final_patient_code, period
            order by admissiondate
        ) as next_stay_is_cardiometabolic
    from unique_admissions
    where loatype = 'INPATIENT'
),

readmission_logic as (
    select
        *,
        {% if target.type == 'bigquery' %}
            date_diff(next_admissiondate, dischargedate, day) as days_to_readmit
        {% else %}
            (next_admissiondate - dischargedate) as days_to_readmit
        {% endif %}
    from inpatient_journey
),

er_patient_journey as (
    select
        *,
        lead(loatype) over (
            partition by final_patient_code, period
            order by admissiondate, loatype desc
        ) as next_loatype,
        lead(admissiondate) over (
            partition by final_patient_code, period
            order by admissiondate, loatype desc
        ) as next_admissiondate
    from unique_admissions
),

panic_logic as (
    select
        final_patient_code,
        period,
        admissiondate,
        case
            when loatype = 'EMERGENCY'
             and next_loatype = 'INPATIENT'
             {% if target.type == 'bigquery' %}
             and date_diff(next_admissiondate, admissiondate, day) <= 1
             {% else %}
             and (next_admissiondate - admissiondate) <= 1
             {% endif %}
                then 0
            when loatype = 'EMERGENCY' then 1
            else 0
        end as is_panic_visit
    from er_patient_journey
    where loatype = 'EMERGENCY'
),

claim_metrics as (
    select
        final_patient_code,
        period,
        count(distinct claimno) as overall_count_of_claims,
        round(cast(sum(approved) as numeric), 2) as overall_util,
        count(distinct case when loatype = 'OP LAB' then claimno end) as opl_coc,
        round(cast(sum(case when loatype = 'OP LAB' then approved else 0 end) as numeric), 2) as opl_util,
        count(distinct case when loatype = 'INPATIENT' then claimno end) as inp_coc,
        round(cast(sum(case when loatype = 'INPATIENT' then approved else 0 end) as numeric), 2) as inp_util,
        count(distinct case when loatype in ('EMERGENCY', 'OP_CONSULT', 'ACU') then claimno end) as others_coc,
        round(cast(sum(case when loatype in ('EMERGENCY', 'OP_CONSULT', 'ACU') then approved else 0 end) as numeric), 2) as others_util,
        round(cast(sum(abs(philhealth)) as numeric), 2) as sum_philhealth,
        round(cast(sum(abs(professional_fees)) as numeric), 2) as sum_professional_fees,
        cast(sum(abs(philhealth)) as numeric) / nullif(cast(sum(approved) as numeric), 0) as percent_of_philhealth_util,
        count(distinct case when philhealth > 0 then claimno end) as philhealth_claim_count,
        sum(count_of_cptcode) as overall_cptcode_coc,
        round(cast(sum(sum_of_util_cptcode) as numeric), 2) as overall_cptcode_util,
        sum(case when loatype = 'OP LAB' then count_of_cptcode else 0 end) as opl_cptcode_coc,
        round(cast(sum(case when loatype = 'OP LAB' then sum_of_util_cptcode else 0 end) as numeric), 2) as opl_cptcode_util,
        sum(case when loatype = 'INPATIENT' then count_of_cptcode else 0 end) as inp_cptcode_coc,
        round(cast(sum(case when loatype = 'INPATIENT' then sum_of_util_cptcode else 0 end) as numeric), 2) as inp_cptcode_util,
        sum(case when loatype = 'EMERGENCY' then count_of_cptcode else 0 end) as emg_cptcode_coc,
        round(cast(sum(case when loatype = 'EMERGENCY' then sum_of_util_cptcode else 0 end) as numeric), 2) as emg_cptcode_util,
        sum(count_of_ruvcode) as overall_ruvcode_coc,
        round(cast(sum(sum_of_util_ruvcode) as numeric), 2) as overall_ruvcode_util,
        sum(case when loatype = 'OP LAB' then count_of_ruvcode else 0 end) as opl_ruvcode_coc,
        round(cast(sum(case when loatype = 'OP LAB' then sum_of_util_ruvcode else 0 end) as numeric), 2) as opl_ruvcode_util,
        sum(case when loatype = 'INPATIENT' then count_of_ruvcode else 0 end) as inp_ruvcode_coc,
        round(cast(sum(case when loatype = 'INPATIENT' then sum_of_util_ruvcode else 0 end) as numeric), 2) as inp_ruvcode_util,
        sum(case when loatype = 'EMERGENCY' then count_of_ruvcode else 0 end) as emg_ruvcode_coc,
        round(cast(sum(case when loatype = 'EMERGENCY' then sum_of_util_ruvcode else 0 end) as numeric), 2) as emg_ruvcode_util
    from claim_rollup
    group by 1, 2
),

los_metrics as (
    select
        final_patient_code,
        period,
        coalesce(sum(max_lengthofstay), 0) as total_lengthofstay
    from unique_admissions
    where loatype = 'INPATIENT'
    group by 1, 2
),

readmission_metrics as (
    select
        final_patient_code,
        period,
        coalesce(sum(case when days_to_readmit <= 30 and days_to_readmit is not null then 1 else 0 end), 0) as count_of_rapid_readmissions,
        coalesce(count(*), 0) as count_of_unique_inpatient_stays,
        coalesce(
            sum(
                case
                    when days_to_readmit <= 30
                     and days_to_readmit is not null
                     and next_stay_is_cardiometabolic = 1
                        then 1
                    else 0
                end
            ),
            0
        ) as count_of_rapid_cardiometabolic_readmissions,
        coalesce(count(case when next_stay_is_cardiometabolic = 1 then 1 end), 0) as count_of_unique_cardiometabolic_inpatient_stays
    from readmission_logic
    group by 1, 2
),

er_metrics as (
    select
        final_patient_code,
        period,
        coalesce(count(case when is_panic_visit = 1 then 1 end), 0) as count_of_panic_visits,
        coalesce(count(case when is_panic_visit = 0 then 1 end), 0) as count_of_non_panic_visits,
        coalesce(count(*), 0) as count_of_unique_emergencies
    from panic_logic
    group by 1, 2
),

period_metrics as (
    select
        cm.final_patient_code,
        cm.period,
        cm.overall_count_of_claims,
        cm.overall_util,
        cm.opl_coc,
        cm.opl_util,
        cm.inp_coc,
        cm.inp_util,
        cm.others_coc,
        cm.others_util,
        cm.sum_philhealth,
        cm.sum_professional_fees,
        cm.percent_of_philhealth_util,
        cm.philhealth_claim_count,
        cm.overall_cptcode_coc,
        cm.overall_cptcode_util,
        cm.opl_cptcode_coc,
        cm.opl_cptcode_util,
        cm.inp_cptcode_coc,
        cm.inp_cptcode_util,
        cm.emg_cptcode_coc,
        cm.emg_cptcode_util,
        cm.overall_ruvcode_coc,
        cm.overall_ruvcode_util,
        cm.opl_ruvcode_coc,
        cm.opl_ruvcode_util,
        cm.inp_ruvcode_coc,
        cm.inp_ruvcode_util,
        cm.emg_ruvcode_coc,
        cm.emg_ruvcode_util,
        coalesce(lm.total_lengthofstay, 0) as total_lengthofstay,
        coalesce(rm.count_of_rapid_readmissions, 0) as count_of_rapid_readmissions,
        coalesce(rm.count_of_unique_inpatient_stays, 0) as count_of_unique_inpatient_stays,
        coalesce(rm.count_of_rapid_cardiometabolic_readmissions, 0) as count_of_rapid_cardiometabolic_readmissions,
        coalesce(rm.count_of_unique_cardiometabolic_inpatient_stays, 0) as count_of_unique_cardiometabolic_inpatient_stays,
        coalesce(em.count_of_non_panic_visits, 0) as count_of_non_panic_visits,
        coalesce(em.count_of_panic_visits, 0) as count_of_panic_visits,
        coalesce(em.count_of_unique_emergencies, 0) as count_of_unique_emergencies
    from claim_metrics cm
    left join los_metrics lm
        on cm.final_patient_code = lm.final_patient_code
       and cm.period = lm.period
    left join readmission_metrics rm
        on cm.final_patient_code = rm.final_patient_code
       and cm.period = rm.period
    left join er_metrics em
        on cm.final_patient_code = em.final_patient_code
       and cm.period = em.period
),

final as (
    select
        ep.final_patient_code,
        ep.patient_code_full_name,
        ep.maskedcardnos,
        ep.cardnos,
        ep.activity_status,
        ep.final_company,
        ep.member_type,
        ep.enrollment_date,
        ep.inactive_tagging_date,
        ep.dropout_date,
        ep.before_period_start,
        ep.before_period_end,
        ep.after_period_start,
        ep.after_period_end,

        coalesce(b.overall_count_of_claims, 0) as before_overall_count_of_claims,
        coalesce(a.overall_count_of_claims, 0) as after_overall_count_of_claims,
        coalesce(a.overall_count_of_claims, 0) - coalesce(b.overall_count_of_claims, 0) as delta_overall_count_of_claims,
        cast(coalesce(a.overall_count_of_claims, 0) - coalesce(b.overall_count_of_claims, 0) as numeric) / nullif(cast(coalesce(b.overall_count_of_claims, 0) as numeric), 0) as pct_change_overall_count_of_claims,

        coalesce(b.overall_util, 0) as before_overall_util,
        coalesce(a.overall_util, 0) as after_overall_util,
        coalesce(a.overall_util, 0) - coalesce(b.overall_util, 0) as delta_overall_util,
        (coalesce(a.overall_util, 0) - coalesce(b.overall_util, 0)) / nullif(coalesce(b.overall_util, 0), 0) as pct_change_overall_util,

        coalesce(b.opl_coc, 0) as before_opl_coc,
        coalesce(a.opl_coc, 0) as after_opl_coc,
        coalesce(a.opl_coc, 0) - coalesce(b.opl_coc, 0) as delta_opl_coc,
        cast(coalesce(a.opl_coc, 0) - coalesce(b.opl_coc, 0) as numeric) / nullif(cast(coalesce(b.opl_coc, 0) as numeric), 0) as pct_change_opl_coc,

        coalesce(b.opl_util, 0) as before_opl_util,
        coalesce(a.opl_util, 0) as after_opl_util,
        coalesce(a.opl_util, 0) - coalesce(b.opl_util, 0) as delta_opl_util,
        (coalesce(a.opl_util, 0) - coalesce(b.opl_util, 0)) / nullif(coalesce(b.opl_util, 0), 0) as pct_change_opl_util,

        coalesce(b.inp_coc, 0) as before_inp_coc,
        coalesce(a.inp_coc, 0) as after_inp_coc,
        coalesce(a.inp_coc, 0) - coalesce(b.inp_coc, 0) as delta_inp_coc,
        cast(coalesce(a.inp_coc, 0) - coalesce(b.inp_coc, 0) as numeric) / nullif(cast(coalesce(b.inp_coc, 0) as numeric), 0) as pct_change_inp_coc,

        coalesce(b.inp_util, 0) as before_inp_util,
        coalesce(a.inp_util, 0) as after_inp_util,
        coalesce(a.inp_util, 0) - coalesce(b.inp_util, 0) as delta_inp_util,
        (coalesce(a.inp_util, 0) - coalesce(b.inp_util, 0)) / nullif(coalesce(b.inp_util, 0), 0) as pct_change_inp_util,

        coalesce(b.others_coc, 0) as before_others_coc,
        coalesce(a.others_coc, 0) as after_others_coc,
        coalesce(a.others_coc, 0) - coalesce(b.others_coc, 0) as delta_others_coc,
        cast(coalesce(a.others_coc, 0) - coalesce(b.others_coc, 0) as numeric) / nullif(cast(coalesce(b.others_coc, 0) as numeric), 0) as pct_change_others_coc,

        coalesce(b.others_util, 0) as before_others_util,
        coalesce(a.others_util, 0) as after_others_util,
        coalesce(a.others_util, 0) - coalesce(b.others_util, 0) as delta_others_util,
        (coalesce(a.others_util, 0) - coalesce(b.others_util, 0)) / nullif(coalesce(b.others_util, 0), 0) as pct_change_others_util,

        coalesce(b.sum_philhealth, 0) as before_sum_philhealth,
        coalesce(a.sum_philhealth, 0) as after_sum_philhealth,
        coalesce(a.sum_philhealth, 0) - coalesce(b.sum_philhealth, 0) as delta_sum_philhealth,
        (coalesce(a.sum_philhealth, 0) - coalesce(b.sum_philhealth, 0)) / nullif(coalesce(b.sum_philhealth, 0), 0) as pct_change_sum_philhealth,

        coalesce(b.sum_professional_fees, 0) as before_sum_professional_fees,
        coalesce(a.sum_professional_fees, 0) as after_sum_professional_fees,
        coalesce(a.sum_professional_fees, 0) - coalesce(b.sum_professional_fees, 0) as delta_sum_professional_fees,
        (coalesce(a.sum_professional_fees, 0) - coalesce(b.sum_professional_fees, 0)) / nullif(coalesce(b.sum_professional_fees, 0), 0) as pct_change_sum_professional_fees,

        b.percent_of_philhealth_util as before_percent_of_philhealth_util,
        a.percent_of_philhealth_util as after_percent_of_philhealth_util,
        a.percent_of_philhealth_util - b.percent_of_philhealth_util as delta_percent_of_philhealth_util,

        coalesce(b.philhealth_claim_count, 0) as before_philhealth_claim_count,
        coalesce(a.philhealth_claim_count, 0) as after_philhealth_claim_count,
        coalesce(a.philhealth_claim_count, 0) - coalesce(b.philhealth_claim_count, 0) as delta_philhealth_claim_count,
        cast(coalesce(a.philhealth_claim_count, 0) - coalesce(b.philhealth_claim_count, 0) as numeric) / nullif(cast(coalesce(b.philhealth_claim_count, 0) as numeric), 0) as pct_change_philhealth_claim_count,

        coalesce(b.overall_cptcode_coc, 0) as before_overall_cptcode_coc,
        coalesce(a.overall_cptcode_coc, 0) as after_overall_cptcode_coc,
        coalesce(a.overall_cptcode_coc, 0) - coalesce(b.overall_cptcode_coc, 0) as delta_overall_cptcode_coc,
        cast(coalesce(a.overall_cptcode_coc, 0) - coalesce(b.overall_cptcode_coc, 0) as numeric) / nullif(cast(coalesce(b.overall_cptcode_coc, 0) as numeric), 0) as pct_change_overall_cptcode_coc,

        coalesce(b.overall_cptcode_util, 0) as before_overall_cptcode_util,
        coalesce(a.overall_cptcode_util, 0) as after_overall_cptcode_util,
        coalesce(a.overall_cptcode_util, 0) - coalesce(b.overall_cptcode_util, 0) as delta_overall_cptcode_util,
        (coalesce(a.overall_cptcode_util, 0) - coalesce(b.overall_cptcode_util, 0)) / nullif(coalesce(b.overall_cptcode_util, 0), 0) as pct_change_overall_cptcode_util,

        coalesce(b.opl_cptcode_coc, 0) as before_opl_cptcode_coc,
        coalesce(a.opl_cptcode_coc, 0) as after_opl_cptcode_coc,
        coalesce(a.opl_cptcode_coc, 0) - coalesce(b.opl_cptcode_coc, 0) as delta_opl_cptcode_coc,

        coalesce(b.opl_cptcode_util, 0) as before_opl_cptcode_util,
        coalesce(a.opl_cptcode_util, 0) as after_opl_cptcode_util,
        coalesce(a.opl_cptcode_util, 0) - coalesce(b.opl_cptcode_util, 0) as delta_opl_cptcode_util,

        coalesce(b.inp_cptcode_coc, 0) as before_inp_cptcode_coc,
        coalesce(a.inp_cptcode_coc, 0) as after_inp_cptcode_coc,
        coalesce(a.inp_cptcode_coc, 0) - coalesce(b.inp_cptcode_coc, 0) as delta_inp_cptcode_coc,

        coalesce(b.inp_cptcode_util, 0) as before_inp_cptcode_util,
        coalesce(a.inp_cptcode_util, 0) as after_inp_cptcode_util,
        coalesce(a.inp_cptcode_util, 0) - coalesce(b.inp_cptcode_util, 0) as delta_inp_cptcode_util,

        coalesce(b.emg_cptcode_coc, 0) as before_emg_cptcode_coc,
        coalesce(a.emg_cptcode_coc, 0) as after_emg_cptcode_coc,
        coalesce(a.emg_cptcode_coc, 0) - coalesce(b.emg_cptcode_coc, 0) as delta_emg_cptcode_coc,

        coalesce(b.emg_cptcode_util, 0) as before_emg_cptcode_util,
        coalesce(a.emg_cptcode_util, 0) as after_emg_cptcode_util,
        coalesce(a.emg_cptcode_util, 0) - coalesce(b.emg_cptcode_util, 0) as delta_emg_cptcode_util,

        coalesce(b.overall_ruvcode_coc, 0) as before_overall_ruvcode_coc,
        coalesce(a.overall_ruvcode_coc, 0) as after_overall_ruvcode_coc,
        coalesce(a.overall_ruvcode_coc, 0) - coalesce(b.overall_ruvcode_coc, 0) as delta_overall_ruvcode_coc,

        coalesce(b.overall_ruvcode_util, 0) as before_overall_ruvcode_util,
        coalesce(a.overall_ruvcode_util, 0) as after_overall_ruvcode_util,
        coalesce(a.overall_ruvcode_util, 0) - coalesce(b.overall_ruvcode_util, 0) as delta_overall_ruvcode_util,

        coalesce(b.opl_ruvcode_coc, 0) as before_opl_ruvcode_coc,
        coalesce(a.opl_ruvcode_coc, 0) as after_opl_ruvcode_coc,
        coalesce(a.opl_ruvcode_coc, 0) - coalesce(b.opl_ruvcode_coc, 0) as delta_opl_ruvcode_coc,

        coalesce(b.opl_ruvcode_util, 0) as before_opl_ruvcode_util,
        coalesce(a.opl_ruvcode_util, 0) as after_opl_ruvcode_util,
        coalesce(a.opl_ruvcode_util, 0) - coalesce(b.opl_ruvcode_util, 0) as delta_opl_ruvcode_util,

        coalesce(b.inp_ruvcode_coc, 0) as before_inp_ruvcode_coc,
        coalesce(a.inp_ruvcode_coc, 0) as after_inp_ruvcode_coc,
        coalesce(a.inp_ruvcode_coc, 0) - coalesce(b.inp_ruvcode_coc, 0) as delta_inp_ruvcode_coc,

        coalesce(b.inp_ruvcode_util, 0) as before_inp_ruvcode_util,
        coalesce(a.inp_ruvcode_util, 0) as after_inp_ruvcode_util,
        coalesce(a.inp_ruvcode_util, 0) - coalesce(b.inp_ruvcode_util, 0) as delta_inp_ruvcode_util,

        coalesce(b.emg_ruvcode_coc, 0) as before_emg_ruvcode_coc,
        coalesce(a.emg_ruvcode_coc, 0) as after_emg_ruvcode_coc,
        coalesce(a.emg_ruvcode_coc, 0) - coalesce(b.emg_ruvcode_coc, 0) as delta_emg_ruvcode_coc,

        coalesce(b.emg_ruvcode_util, 0) as before_emg_ruvcode_util,
        coalesce(a.emg_ruvcode_util, 0) as after_emg_ruvcode_util,
        coalesce(a.emg_ruvcode_util, 0) - coalesce(b.emg_ruvcode_util, 0) as delta_emg_ruvcode_util,

        coalesce(b.total_lengthofstay, 0) as before_total_lengthofstay,
        coalesce(a.total_lengthofstay, 0) as after_total_lengthofstay,
        coalesce(a.total_lengthofstay, 0) - coalesce(b.total_lengthofstay, 0) as delta_total_lengthofstay,

        coalesce(b.count_of_rapid_readmissions, 0) as before_count_of_rapid_readmissions,
        coalesce(a.count_of_rapid_readmissions, 0) as after_count_of_rapid_readmissions,
        coalesce(a.count_of_rapid_readmissions, 0) - coalesce(b.count_of_rapid_readmissions, 0) as delta_count_of_rapid_readmissions,

        coalesce(b.count_of_unique_inpatient_stays, 0) as before_count_of_unique_inpatient_stays,
        coalesce(a.count_of_unique_inpatient_stays, 0) as after_count_of_unique_inpatient_stays,
        coalesce(a.count_of_unique_inpatient_stays, 0) - coalesce(b.count_of_unique_inpatient_stays, 0) as delta_count_of_unique_inpatient_stays,

        coalesce(b.count_of_rapid_cardiometabolic_readmissions, 0) as before_count_of_rapid_cardiometabolic_readmissions,
        coalesce(a.count_of_rapid_cardiometabolic_readmissions, 0) as after_count_of_rapid_cardiometabolic_readmissions,
        coalesce(a.count_of_rapid_cardiometabolic_readmissions, 0) - coalesce(b.count_of_rapid_cardiometabolic_readmissions, 0) as delta_count_of_rapid_cardiometabolic_readmissions,

        coalesce(b.count_of_unique_cardiometabolic_inpatient_stays, 0) as before_count_of_unique_cardiometabolic_inpatient_stays,
        coalesce(a.count_of_unique_cardiometabolic_inpatient_stays, 0) as after_count_of_unique_cardiometabolic_inpatient_stays,
        coalesce(a.count_of_unique_cardiometabolic_inpatient_stays, 0) - coalesce(b.count_of_unique_cardiometabolic_inpatient_stays, 0) as delta_count_of_unique_cardiometabolic_inpatient_stays,

        coalesce(b.count_of_non_panic_visits, 0) as before_count_of_non_panic_visits,
        coalesce(a.count_of_non_panic_visits, 0) as after_count_of_non_panic_visits,
        coalesce(a.count_of_non_panic_visits, 0) - coalesce(b.count_of_non_panic_visits, 0) as delta_count_of_non_panic_visits,

        coalesce(b.count_of_panic_visits, 0) as before_count_of_panic_visits,
        coalesce(a.count_of_panic_visits, 0) as after_count_of_panic_visits,
        coalesce(a.count_of_panic_visits, 0) - coalesce(b.count_of_panic_visits, 0) as delta_count_of_panic_visits,

        coalesce(b.count_of_unique_emergencies, 0) as before_count_of_unique_emergencies,
        coalesce(a.count_of_unique_emergencies, 0) as after_count_of_unique_emergencies,
        coalesce(a.count_of_unique_emergencies, 0) - coalesce(b.count_of_unique_emergencies, 0) as delta_count_of_unique_emergencies
    from eligible_patients ep
    left join period_metrics b
        on ep.final_patient_code = b.final_patient_code
       and b.period = 'before'
    left join period_metrics a
        on ep.final_patient_code = a.final_patient_code
       and a.period = 'after'
)

select *
from final
order by enrollment_date, final_patient_code
