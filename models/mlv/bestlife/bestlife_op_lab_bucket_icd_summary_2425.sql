{{ config(materialized = 'table') }}

with bestlife_claim_source as (
    -- Limit to the same 2024-2025 OP LAB claim universe used by bestlife_op_lab_frequency_2425.
    select
        *
    from {{ ref('bestlife_mxc_claims_2225') }}
    where source_year between 2024 and 2025
      and nullif(trim(maskedcardno), '') is not null
),

claim_rollup as (
    -- Collapse raw rows to claim grain first so claim counts and utilization are not line-inflated.
    select
        claimno,
        min(maskedcardno) as maskedcardno,
        upper(trim(min(loatype))) as loatype,
        coalesce(nullif(trim(min(primaryicdcode)), ''), 'NO_PRIMARY_ICD') as primaryicdcode,
        coalesce(nullif(trim(min(primaryicddesc)), ''), 'UNKNOWN') as primaryicddesc,
        coalesce(nullif(trim(min(primaryicdgroup)), ''), 'UNKNOWN') as primaryicdgroup,
        sum(coalesce(approved, 0)) as approved,
        sum(coalesce(billed, 0)) as billed
    from bestlife_claim_source
    group by 1
),

op_lab_claims as (
    select
        *
    from claim_rollup
    where loatype = 'OP LAB'
),

patient_op_lab_buckets as (
    select
        maskedcardno,
        count(*) as total_op_lab_claims,
        case
            when count(*) = 1 then 'Single Claim'
            when count(*) between 2 and 4 then '2-4 (Routine Testing)'
            when count(*) between 5 and 9 then '5-9 (Non-high Risk Conditions)'
            when count(*) >= 10 then '10+ (High Risk Conditions)'
        end as op_lab_claim_bucket,
        case
            when count(*) = 1 then 1
            when count(*) between 2 and 4 then 2
            when count(*) between 5 and 9 then 3
            when count(*) >= 10 then 4
            else 5
        end as bucket_order
    from op_lab_claims
    group by 1
),

bucketed_op_lab_claims as (
    select
        b.bucket_order,
        b.op_lab_claim_bucket,
        c.maskedcardno,
        c.claimno,
        c.primaryicdgroup,
        c.primaryicdcode,
        c.primaryicddesc,
        c.approved,
        c.billed
    from op_lab_claims c
    inner join patient_op_lab_buckets b
        on c.maskedcardno = b.maskedcardno
),

icd_summary as (
    select
        bucket_order,
        op_lab_claim_bucket,
        primaryicdgroup,
        primaryicdcode,
        primaryicddesc,
        count(distinct maskedcardno) as total_patients,
        count(*) as total_op_lab_claims,
        round(cast(sum(approved) as numeric), 2) as total_approved,
        round(cast(sum(billed) as numeric), 2) as total_billed
    from bucketed_op_lab_claims
    group by 1, 2, 3, 4, 5
),

bucket_totals as (
    select
        bucket_order,
        op_lab_claim_bucket,
        count(*) as bucket_op_lab_claims,
        sum(approved) as bucket_approved
    from bucketed_op_lab_claims
    group by 1, 2
),

ranked_icd_summary as (
    select
        s.*,
        round((s.total_op_lab_claims::numeric / nullif(s.total_patients::numeric, 0)), 2) as avg_claims_per_patient,
        round((s.total_approved::numeric / nullif(s.total_op_lab_claims::numeric, 0)), 2) as avg_approved_per_claim,
        round((s.total_op_lab_claims::numeric / nullif(t.bucket_op_lab_claims::numeric, 0)), 4) as pct_of_bucket_claims,
        round((s.total_approved::numeric / nullif(t.bucket_approved::numeric, 0)), 4) as pct_of_bucket_approved,
        row_number() over (
            partition by s.bucket_order, s.op_lab_claim_bucket
            order by s.total_op_lab_claims desc, s.total_approved desc, s.primaryicdgroup, s.primaryicdcode
        ) as icd_rank_in_bucket
    from icd_summary s
    inner join bucket_totals t
        on s.bucket_order = t.bucket_order
       and s.op_lab_claim_bucket = t.op_lab_claim_bucket
)

select
    bucket_order as BUCKET_ORDER,
    op_lab_claim_bucket as OP_LAB_CLAIM_BUCKET,
    primaryicdgroup as PRIMARYICDGROUP,
    primaryicdcode as PRIMARYICDCODE,
    primaryicddesc as PRIMARYICDDESC,
    total_patients as TOTAL_PATIENTS,
    total_op_lab_claims as TOTAL_OP_LAB_CLAIMS,
    total_approved as TOTAL_APPROVED,
    total_billed as TOTAL_BILLED,
    avg_claims_per_patient as AVG_CLAIMS_PER_PATIENT,
    avg_approved_per_claim as AVG_APPROVED_PER_CLAIM,
    pct_of_bucket_claims as PCT_OF_BUCKET_CLAIMS,
    pct_of_bucket_approved as PCT_OF_BUCKET_APPROVED,
    icd_rank_in_bucket as ICD_RANK_IN_BUCKET
from ranked_icd_summary
order by
    bucket_order,
    total_op_lab_claims desc,
    total_approved desc,
    primaryicdgroup,
    primaryicdcode
