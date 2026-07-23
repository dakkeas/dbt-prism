{{ config(materialized = 'table') }}

with bestlife_claim_source as (
    -- Limit to the 2024-2025 MXC window before any claim-level aggregation.
    select
        *
    from {{ ref('bestlife_mxc_claims_2225') }}
    where source_year between 2024 and 2025
      and nullif(trim(maskedcardno), '') is not null
),

claim_rollup as (
    -- Collapse raw rows to claim grain first so utilization is counted once per claim.
    select
        claimno,
        min(maskedcardno) as maskedcardno,
        min(patient_code_full_name) as patient_code_full_name,
        min(final_patient_code) as final_patient_code,
        min(cardno) as cardno,
        min(activity_status) as activity_status,
        min(final_company) as final_company,
        min(member_type) as member_type,
        min(inactive_tagging_date) as inactive_tagging_date,
        min(dropout_date) as dropout_date,
        min(baseline_test_date_final) as baseline_test_date_final,
        min(membertypedesc) as membertypedesc,
        min(source_year) as source_year,
        min(loatype) as loatype,
        upper(trim(min(primaryicdcode))) as primaryicdcode_norm,
        nullif(trim(min(primaryicdcode)), '') as primaryicdcode,
        min(primaryicddesc) as primaryicddesc,
        min(primaryicdgroup) as primaryicdgroup,
        sum(coalesce(approved, 0)) as approved,
        sum(coalesce(billed, 0)) as billed
    from bestlife_claim_source
    group by 1
),

bestlife_icds as (
    -- Exact BestLife ICD lookup: used to split OP LAB claims into BestLife vs non-BestLife.
    select
        upper(trim(icdcode)) as icdcode_norm,
        min(trim(icdcode)) as icdcode,
        min(description) as bestlife_icd_description,
        min(final_tagging) as bestlife_final_tagging
    from {{ ref('blp_icdcodes_v2') }}
    where nullif(trim(icdcode), '') is not null
    group by 1
),

op_lab_claims as (
    -- Keep OP LAB only after claim rollup, then attach BestLife ICD metadata when there is a match.
    select
        cr.claimno,
        cr.maskedcardno,
        cr.patient_code_full_name,
        cr.final_patient_code,
        cr.cardno,
        cr.activity_status,
        cr.final_company,
        cr.member_type,
        cr.inactive_tagging_date,
        cr.dropout_date,
        cr.baseline_test_date_final,
        cr.membertypedesc,
        cr.source_year,
        cr.loatype,
        cr.primaryicdcode,
        cr.primaryicdcode_norm,
        cr.primaryicddesc,
        cr.primaryicdgroup,
        cr.approved,
        cr.billed,
        b.icdcode as bestlife_icd_code,
        b.bestlife_icd_description,
        b.bestlife_final_tagging
    from claim_rollup cr
    left join bestlife_icds b
        on cr.primaryicdcode_norm = b.icdcode_norm
    where upper(trim(cr.loatype)) = 'OP LAB'
),

patient_op_lab as (
    -- Final grain: one row per patient.
    -- Count total OP LAB claims, then split counts/approved amounts by BestLife match status.
    select
        maskedcardno,
        min(membertypedesc) as membertypedesc,
        count(*) as total_op_lab_claims,
        count(*) filter (where bestlife_icd_code is not null) as bestlife_op_lab_claims,
        count(*) filter (where bestlife_icd_code is null) as non_bestlife_op_lab_claims,
        sum(approved) as total_approved,
        sum(case when bestlife_icd_code is not null then approved else 0 end) as bestlife_approved,
        sum(case when bestlife_icd_code is null then approved else 0 end) as non_bestlife_approved,
        string_agg(distinct coalesce(primaryicdcode, primaryicdcode_norm), ', ' order by coalesce(primaryicdcode, primaryicdcode_norm)) as primaryicdcodes,
        string_agg(distinct coalesce(primaryicdgroup, 'UNKNOWN'), ', ' order by coalesce(primaryicdgroup, 'UNKNOWN')) as primaryicdgroups,
        string_agg(distinct coalesce(bestlife_icd_code, 'NON_BESTLIFE'), ', ' order by coalesce(bestlife_icd_code, 'NON_BESTLIFE')) as op_lab_icd_bucket_list,
        string_agg(distinct coalesce(bestlife_icd_description, 'NON_BESTLIFE'), ', ' order by coalesce(bestlife_icd_description, 'NON_BESTLIFE')) as op_lab_icd_description_list
    from op_lab_claims
    group by 1
),

patient_profile as (
    -- Profile columns are attached by the canonical raw BestLife claims model.
    select
        maskedcardno,
        string_agg(distinct patient_code_full_name, ', ' order by patient_code_full_name) as patient_code_full_name,
        string_agg(distinct final_patient_code, ', ' order by final_patient_code) as final_patient_code,
        string_agg(distinct cardno, ', ' order by cardno) as cardno,
        string_agg(distinct activity_status, ', ' order by activity_status) as activity_status,
        string_agg(distinct final_company, ', ' order by final_company) as final_company,
        string_agg(distinct member_type, ', ' order by member_type) as member_type,
        string_agg(distinct inactive_tagging_date::text, ', ' order by inactive_tagging_date::text) as inactive_tagging_date,
        string_agg(distinct dropout_date::text, ', ' order by dropout_date::text) as dropout_date,
        string_agg(distinct baseline_test_date_final::text, ', ' order by baseline_test_date_final::text) as baseline_test_date_final
    from claim_rollup
    group by 1
),

bucketed_patients as (
    -- Bucket assignment is based on total OP LAB utilization per patient across 2024-2025.
    select
        maskedcardno,
        membertypedesc,
        total_op_lab_claims,
        bestlife_op_lab_claims,
        non_bestlife_op_lab_claims,
        total_approved,
        bestlife_approved,
        non_bestlife_approved,
        primaryicdcodes,
        primaryicdgroups,
        op_lab_icd_bucket_list,
        op_lab_icd_description_list,
        case
            when total_op_lab_claims = 1 then 'Single Claim'
            when total_op_lab_claims between 2 and 4 then '2-4 (Routine Testing)'
            when total_op_lab_claims between 5 and 9 then '5-9 (Non-high Risk Conditions)'
            when total_op_lab_claims >= 10 then '10+ (High Risk Conditions)'
        end as op_lab_claim_bucket
    from patient_op_lab
)

select
    -- Production-style uppercase output columns at the end of the model.
    bp.maskedcardno as MASKEDCARDNO,
    pp.patient_code_full_name as PATIENT_CODE_FULL_NAME,
    pp.final_patient_code as FINAL_PATIENT_CODE,
    pp.cardno as CARDNO,
    pp.activity_status as ACTIVITY_STATUS,
    pp.final_company as FINAL_COMPANY,
    pp.member_type as MEMBER_TYPE,
    pp.inactive_tagging_date as INACTIVE_TAGGING_DATE,
    pp.dropout_date as DROPOUT_DATE,
    pp.baseline_test_date_final as BASELINE_TEST_DATE_FINAL,
    bp.membertypedesc as MEMBERTYPEDESC,
    bp.primaryicdcodes as PRIMARYICDCODES,
    bp.primaryicdgroups as PRIMARYICDGROUPS,
    bp.op_lab_claim_bucket as OP_LAB_CLAIM_BUCKET,
    bp.total_op_lab_claims as TOTAL_OP_LAB_CLAIMS,
    bp.bestlife_op_lab_claims as BESTLIFE_OP_LAB_CLAIMS,
    bp.non_bestlife_op_lab_claims as NON_BESTLIFE_OP_LAB_CLAIMS,
    bp.total_approved as TOTAL_APPROVED,
    bp.bestlife_approved as BESTLIFE_APPROVED,
    bp.non_bestlife_approved as NON_BESTLIFE_APPROVED
from bucketed_patients bp
left join patient_profile pp
    on bp.maskedcardno = pp.maskedcardno
order by
    case bp.op_lab_claim_bucket
        when 'Single Claim' then 1
        when '2-4 (Routine Testing)' then 2
        when '5-9 (Non-high Risk Conditions)' then 3
        when '10+ (High Risk Conditions)' then 4
        else 5
    end,
    bp.total_op_lab_claims desc,
    bp.maskedcardno
