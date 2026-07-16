{{ config(materialized = 'table') }}

with bestlife_unmaskedcardno as (
    select
        maskedcardno,
        replace(cardno, ' ', '') as cardno_norm
    from {{ ref('bl_unmaskedcardno') }}
    where nullif(trim(cardno), '') is not null
),

reference_member_base as (
    select
        patient_code_full_name,
        final_patient_code,
        cardno,
        replace(cardno, ' ', '') as cardno_norm
        ,activity_status
        ,final_company
        ,member_type
        ,inactive_tagging_date
        ,dropout_date
        ,baseline_test_date_final
    from {{ ref('seed_bestlife_unmasked_patient_no') }}
    where nullif(trim(cardno), '') is not null
),

matched_bestlife_patients as (
    -- BestLife patient list comes from normalized card-number overlap.
    -- Keep distinct maskedcardno so downstream claim joins stay one-to-many, not many-to-many.
    select distinct
        b.maskedcardno,
        r.patient_code_full_name,
        r.final_patient_code,
        r.cardno,
        r.activity_status,
        r.final_company,
        r.member_type,
        r.inactive_tagging_date,
        r.dropout_date,
        r.baseline_test_date_final
    from bestlife_unmaskedcardno b
    inner join reference_member_base r
        on b.cardno_norm = r.cardno_norm
),

mxc_2024_2025 as (
    -- Limit to the 2024-2025 MXC window before any claim-level aggregation.
    select
        *
    from {{ ref('mxc_raw_claims') }}
    where source_year between 2024 and 2025
      and nullif(trim(maskedcardno), '') is not null
),

bestlife_claim_source as (
    -- Keep only claims for matched BestLife patients.
    select
        c.*
    from mxc_2024_2025 c
    inner join matched_bestlife_patients p
        on c.maskedcardno = p.maskedcardno
),

claim_rollup as (
    -- Collapse raw rows to claim grain first so utilization is counted once per claim.
    select
        claimno,
        min(maskedcardno) as maskedcardno,
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
    -- One seed row per matched patient. This is joined at the end so claim aggregation stays unchanged.
    select distinct
        maskedcardno,
        patient_code_full_name,
        final_patient_code,
        cardno,
        activity_status,
        final_company,
        member_type,
        inactive_tagging_date,
        dropout_date,
        baseline_test_date_final
    from matched_bestlife_patients
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
            when total_op_lab_claims between 1 and 2 then 'Routine (1-2)'
            when total_op_lab_claims between 3 and 5 then 'Occasional Bucket (3-5)'
            when total_op_lab_claims between 6 and 10 then 'Chronic Monitoring (6-10)'
            when total_op_lab_claims between 11 and 20 then 'High Frequency (11-20)'
            when total_op_lab_claims >= 21 then 'Extreme Flyers (>20)'
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
        when 'Routine' then 1
        when 'Occasional Bucket' then 2
        when 'Chronic Monitoring' then 3
        when 'High Frequency' then 4
        when 'Extreme Flyers' then 5
        else 6
    end,
    bp.total_op_lab_claims desc,
    bp.maskedcardno
