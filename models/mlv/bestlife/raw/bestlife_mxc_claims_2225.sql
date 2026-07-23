{{ config(materialized = 'table') }}

with bestlife_unmaskedcardno as (
    select distinct
        maskedcardno,
        replace(cardno, ' ', '') as cardno_norm
    from {{ ref('bl_unmaskedcardno') }}
    where nullif(trim(cardno), '') is not null
),

reference_member_base as (
    select
        replace(cardno, ' ', '') as cardno_norm,
        string_agg(distinct patient_code_full_name, ', ' order by patient_code_full_name) as patient_code_full_name,
        string_agg(distinct final_patient_code, ', ' order by final_patient_code) as final_patient_code,
        string_agg(distinct cardno, ', ' order by cardno) as cardno,
        string_agg(distinct activity_status, ', ' order by activity_status) as activity_status,
        string_agg(distinct final_company, ', ' order by final_company) as final_company,
        string_agg(distinct member_type, ', ' order by member_type) as member_type,
        string_agg(distinct inactive_tagging_date::text, ', ' order by inactive_tagging_date::text) as inactive_tagging_date,
        string_agg(distinct dropout_date::text, ', ' order by dropout_date::text) as dropout_date,
        string_agg(distinct baseline_test_date_final::text, ', ' order by baseline_test_date_final::text) as baseline_test_date_final
    from {{ ref('seed_bestlife_unmasked_patient_no') }}
    where nullif(trim(cardno), '') is not null
    group by 1
),

matched_bestlife_patients as (
    -- Collapse to one BestLife profile per masked card so the raw claim grain is not multiplied.
    select
        b.maskedcardno,
        string_agg(distinct r.patient_code_full_name, ', ' order by r.patient_code_full_name) as patient_code_full_name,
        string_agg(distinct r.final_patient_code, ', ' order by r.final_patient_code) as final_patient_code,
        string_agg(distinct r.cardno, ', ' order by r.cardno) as cardno,
        string_agg(distinct r.activity_status, ', ' order by r.activity_status) as activity_status,
        string_agg(distinct r.final_company, ', ' order by r.final_company) as final_company,
        string_agg(distinct r.member_type, ', ' order by r.member_type) as member_type,
        string_agg(distinct r.inactive_tagging_date, ', ' order by r.inactive_tagging_date) as inactive_tagging_date,
        string_agg(distinct r.dropout_date, ', ' order by r.dropout_date) as dropout_date,
        string_agg(distinct r.baseline_test_date_final, ', ' order by r.baseline_test_date_final) as baseline_test_date_final
    from bestlife_unmaskedcardno b
    inner join reference_member_base r
        on b.cardno_norm = r.cardno_norm
    where nullif(trim(b.maskedcardno), '') is not null
    group by 1
),

mxc_2022_2025 as (
    select
        *
    from {{ ref('mxc_raw_claims') }}
    where source_year between 2022 and 2025
      and nullif(trim(maskedcardno), '') is not null
)

select
    c.*,
    p.patient_code_full_name,
    p.final_patient_code,
    p.cardno,
    p.activity_status,
    p.final_company,
    p.member_type,
    p.inactive_tagging_date,
    p.dropout_date,
    p.baseline_test_date_final
from mxc_2022_2025 c
inner join matched_bestlife_patients p
    on c.maskedcardno = p.maskedcardno
