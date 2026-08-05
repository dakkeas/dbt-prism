{{ config(materialized = 'view') }}

with bestlife_unmaskedcardno as (
    select
        maskedcardno,
        replace(trim(cardno), ' ', '') as cardno_norm
    from {{ ref('bestlife_unmaskedcardno') }}
    where nullif(trim(cardno), '') is not null
),

reference_member_base as (
    select
        final_patient_code,
        replace(cardno, ' ', '') as cardno_norm
    from {{ ref('seed_bestlife_unmasked_patient_no') }}
    where nullif(trim(cardno), '') is not null
),

matched as (
    select
        b.maskedcardno,
        count(*) as match_count
    from bestlife_unmaskedcardno b
    inner join reference_member_base r
        on b.cardno_norm = r.cardno_norm
    group by 1
)

select
    maskedcardno,
    match_count
from matched
order by
    match_count desc,
    maskedcardno
