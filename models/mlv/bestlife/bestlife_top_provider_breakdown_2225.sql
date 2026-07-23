{{ config(materialized = 'table') }}

with bestlife_claim_source as (
    select
        *
    from {{ ref('bestlife_mxc_claims_2225') }}
    where nullif(trim(maskedcardno), '') is not null
      and nullif(trim(claimno), '') is not null
),

claim_rollup as (
    -- Collapse raw rows to claim grain first so provider utilization and claim counts are not line-inflated.
    select
        claimno,
        min(maskedcardno) as maskedcardno,
        nullif(trim(min(providercode)), '') as providercode,
        coalesce(nullif(trim(min(providername)), ''), 'UNKNOWN PROVIDER') as providername,
        min(providertype) as providertype,
        min(region) as region,
        min(province) as province,
        min(citymunicipal) as citymunicipal,
        min(source_year) as source_year,
        upper(trim(min(loatype))) as loatype,
        sum(coalesce(approved, 0)) as approved,
        sum(coalesce(billed, 0)) as billed
    from bestlife_claim_source
    group by 1
),

classified_claims as (
    select
        *,
        case
            when loatype = 'OP LAB' then 'OP LAB'
            when loatype = 'INPATIENT' then 'INPATIENT'
            else 'OTHERS'
        end as loatype_bucket
    from claim_rollup
),

provider_rollup as (
    select
        providername,
        providercode,
        min(providertype) as providertype,
        min(region) as region,
        min(province) as province,
        min(citymunicipal) as citymunicipal,
        count(distinct maskedcardno) as total_bestlife_members,
        count(*) as total_claims,
        round(cast(sum(approved) as numeric), 2) as total_util,
        round(cast(sum(billed) as numeric), 2) as total_billed,
        count(*) filter (where loatype_bucket = 'OP LAB') as op_lab_claims,
        round(cast(sum(case when loatype_bucket = 'OP LAB' then approved else 0 end) as numeric), 2) as op_lab_util,
        count(*) filter (where loatype_bucket = 'INPATIENT') as inpatient_claims,
        round(cast(sum(case when loatype_bucket = 'INPATIENT' then approved else 0 end) as numeric), 2) as inpatient_util,
        count(*) filter (where loatype_bucket = 'OTHERS') as others_claims,
        round(cast(sum(case when loatype_bucket = 'OTHERS' then approved else 0 end) as numeric), 2) as others_util
    from classified_claims
    group by 1, 2
),

ranked_provider_rollup as (
    select
        *,
        dense_rank() over (order by total_util desc, total_claims desc, providername, providercode) as provider_util_rank,
        round((total_claims::numeric / nullif(total_bestlife_members::numeric, 0)), 2) as avg_claims_per_member,
        round((total_util::numeric / nullif(total_claims::numeric, 0)), 2) as avg_util_per_claim,
        round((total_util::numeric / nullif(total_bestlife_members::numeric, 0)), 2) as avg_util_per_member,
        round((op_lab_claims::numeric / nullif(total_claims::numeric, 0)), 4) as op_lab_claim_pct,
        round((op_lab_util::numeric / nullif(total_util::numeric, 0)), 4) as op_lab_util_pct,
        round((inpatient_claims::numeric / nullif(total_claims::numeric, 0)), 4) as inpatient_claim_pct,
        round((inpatient_util::numeric / nullif(total_util::numeric, 0)), 4) as inpatient_util_pct,
        round((others_claims::numeric / nullif(total_claims::numeric, 0)), 4) as others_claim_pct,
        round((others_util::numeric / nullif(total_util::numeric, 0)), 4) as others_util_pct
    from provider_rollup
)

select
    provider_util_rank as PROVIDER_UTIL_RANK,
    providername as PROVIDERNAME,
    providercode as PROVIDERCODE,
    providertype as PROVIDERTYPE,
    region as REGION,
    province as PROVINCE,
    citymunicipal as CITYMUNICIPAL,
    total_bestlife_members as TOTAL_BESTLIFE_MEMBERS,
    total_claims as TOTAL_CLAIMS,
    total_util as TOTAL_UTIL,
    total_billed as TOTAL_BILLED,
    avg_claims_per_member as AVG_CLAIMS_PER_MEMBER,
    avg_util_per_claim as AVG_UTIL_PER_CLAIM,
    avg_util_per_member as AVG_UTIL_PER_MEMBER,
    op_lab_claims as OP_LAB_CLAIMS,
    op_lab_util as OP_LAB_UTIL,
    op_lab_claim_pct as OP_LAB_CLAIM_PCT,
    op_lab_util_pct as OP_LAB_UTIL_PCT,
    inpatient_claims as INPATIENT_CLAIMS,
    inpatient_util as INPATIENT_UTIL,
    inpatient_claim_pct as INPATIENT_CLAIM_PCT,
    inpatient_util_pct as INPATIENT_UTIL_PCT,
    others_claims as OTHERS_CLAIMS,
    others_util as OTHERS_UTIL,
    others_claim_pct as OTHERS_CLAIM_PCT,
    others_util_pct as OTHERS_UTIL_PCT
from ranked_provider_rollup
order by
    provider_util_rank,
    total_util desc,
    total_claims desc,
    providername
