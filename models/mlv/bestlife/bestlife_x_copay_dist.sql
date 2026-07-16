{{ config(materialized = 'table') }}

with raw_claims_2022_2025 as (
    select *
    from {{ ref('mxc_raw_claims') }}
    where source_year >= 2022
),

claim_rollup as (
    select
        claimno,
        upper(trim(primaryicdcode)) as primaryicdcode_norm,
        nullif(trim(primaryicdcode), '') as primaryicdcode,
        min(primaryicddesc) as primaryicddesc,
        min(primaryicdgroup) as primaryicdgroup,
        min(maskedcardno) as maskedcardno,
        sum(coalesce(approved, 0)) as approved,
        sum(coalesce(billed, 0)) as billed
    from raw_claims_2022_2025
    group by 1, 2, 3
),

bestlife_icds as (
    select
        upper(trim(icdcode)) as icdcode_norm,
        min(description) as bestlife_description,
        min(final_tagging) as bestlife_final_tagging
    from {{ ref('blp_icdcodes_v2') }}
    where nullif(trim(icdcode), '') is not null
    group by 1
),

forward_icds as (
    select
        upper(trim(icd_code)) as icdcode_norm,
        min(trim(icd_code)) as icdcode,
        min(icd_description) as forward_icd_description,
        min(category) as forward_category
    from {{ ref('forward_medicines_copay') }}
    where nullif(trim(icd_code), '') is not null
    group by 1
),

forward_icd_matches as (
    select
        cr.claimno,
        f.icdcode_norm,
        f.icdcode,
        f.forward_icd_description,
        f.forward_category,
        row_number() over (
            partition by cr.claimno
            order by
                case when cr.primaryicdcode_norm = f.icdcode_norm then 0 else 1 end,
                length(f.icdcode_norm) desc,
                f.icdcode_norm
        ) as rn
    from claim_rollup cr
    join forward_icds f
        on cr.primaryicdcode_norm ilike f.icdcode_norm || '%'
    -- Forward ICDs are category-level codes, so prefix matching captures child ICDs.
),

classified_claims as (
    select
        cr.claimno,
        cr.maskedcardno,
        cr.primaryicdcode_norm,
        cr.primaryicdcode,
        cr.primaryicddesc,
        cr.primaryicdgroup,
        cr.approved,
        cr.billed,
        case
            when b.icdcode_norm is not null then 'BESTLIFE'
            when f.icdcode_norm is not null then 'FORWARD MEDS CO-PAY'
            else 'OTHER'
        end as icd_bucket,
        case
            when b.icdcode_norm is not null and f.icdcode_norm is not null then 'Y'
            else 'N'
        end as is_bestlife_forward_overlap,
        coalesce(b.icdcode_norm, f.icdcode_norm, cr.primaryicdcode) as icd_code,
        coalesce(b.bestlife_description, f.forward_icd_description, cr.primaryicddesc) as icd_description,
        coalesce(b.bestlife_final_tagging, f.forward_category, 'other') as icd_category,
        b.bestlife_final_tagging
    from claim_rollup cr
    left join bestlife_icds b
        on cr.primaryicdcode_norm = b.icdcode_norm
    left join forward_icd_matches f
        on cr.claimno = f.claimno
       and f.rn = 1
),

bucket_rollup as (
    select
        icd_bucket,
        is_bestlife_forward_overlap,
        icd_code,
        icd_description,
        icd_category,
        bestlife_final_tagging,
        count(*) as total_claims,
        count(distinct maskedcardno) as total_patients,
        sum(approved) as total_util,
        sum(billed) as total_billed,
        avg(approved) as avg_claim_util
    from classified_claims
    group by
        icd_bucket,
        is_bestlife_forward_overlap,
        icd_code,
        icd_description,
        icd_category,
        bestlife_final_tagging
),

totals as (
    select
        count(*) as grand_total_claims,
        count(distinct maskedcardno) as grand_total_patients,
        sum(approved) as grand_total_util
    from classified_claims
)

select
    b.icd_bucket as ICD_BUCKET,
    b.is_bestlife_forward_overlap as IS_BESTLIFE_FORWARD_OVERLAP,
    b.icd_code as ICD_CODE,
    b.icd_description as ICD_DESCRIPTION,
    b.icd_category as ICD_CATEGORY,
    b.total_claims,
    b.total_patients,
    round((b.total_claims::numeric / nullif(b.total_patients::numeric, 0)), 2) as avg_claims_per_patient,
    b.total_util,
    round((b.total_util::numeric / nullif(b.total_claims::numeric, 0)), 2) as avg_util_per_claim,
    round((b.total_util::numeric / nullif(b.total_patients::numeric, 0)), 2) as avg_util_per_patient,
    round((b.total_billed::numeric / nullif(b.total_claims::numeric, 0)), 2) as avg_billed_per_claim,
    round((b.total_billed::numeric / nullif(b.total_patients::numeric, 0)), 2) as avg_billed_per_patient,
    round((b.total_claims::numeric / nullif(t.grand_total_claims::numeric, 0)), 4) as pct_of_total_claims,
    round((b.total_util::numeric / nullif(t.grand_total_util::numeric, 0)), 4) as pct_of_total_util
from bucket_rollup b
cross join totals t
order by
    b.total_util desc,
    b.total_claims desc,
    b.icd_code
