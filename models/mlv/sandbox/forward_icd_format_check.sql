{{ config(materialized = 'table') }}

with raw_claims as (
    select
        claimno,
        primaryicdcode,
        upper(trim(primaryicdcode)) as primaryicdcode_norm
    from {{ ref('mxc_raw_claims') }}
    where source_year between 2022 and 2025
      and nullif(trim(primaryicdcode), '') is not null
),

forward_icds as (
    select distinct
        trim(icd_code) as icd_code,
        upper(trim(icd_code)) as icd_code_norm
    from {{ ref('forward_medicines_copay') }}
    where nullif(trim(icd_code), '') is not null
),

matched as (
    select
        f.icd_code,
        f.icd_code_norm,
        count(distinct r.claimno) as total_claims,
        count(distinct case when r.primaryicdcode_norm = f.icd_code_norm then r.claimno end) as exact_claims,
        count(distinct case when r.primaryicdcode ilike f.icd_code then r.claimno end) as ilike_claims,
        count(distinct case when replace(r.primaryicdcode_norm, '.0', '') = replace(f.icd_code_norm, '.0', '') then r.claimno end) as stripped_dot_zero_claims,
        min(case when r.primaryicdcode_norm = f.icd_code_norm then r.primaryicdcode end) as sample_exact_primaryicdcode,
        min(case when r.primaryicdcode ilike f.icd_code then r.primaryicdcode end) as sample_ilike_primaryicdcode,
        min(case when replace(r.primaryicdcode_norm, '.0', '') = replace(f.icd_code_norm, '.0', '') then r.primaryicdcode end) as sample_stripped_primaryicdcode
    from forward_icds f
    left join raw_claims r
        on (
            r.primaryicdcode_norm = f.icd_code_norm
            or r.primaryicdcode ilike f.icd_code
            or replace(r.primaryicdcode_norm, '.0', '') = replace(f.icd_code_norm, '.0', '')
        )
    group by
        f.icd_code,
        f.icd_code_norm
)

select
    icd_code,
    icd_code_norm,
    total_claims,
    exact_claims,
    ilike_claims,
    stripped_dot_zero_claims,
    sample_exact_primaryicdcode,
    sample_ilike_primaryicdcode,
    sample_stripped_primaryicdcode
from matched
order by
    total_claims desc,
    icd_code
