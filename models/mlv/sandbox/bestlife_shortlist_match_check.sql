{{ config(materialized = 'table') }}

with bl_unmaskedcardno as (
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
        replace(cardno, ' ', '') as cardno_norm,
        activity_status,
        final_company,
        member_type,
        inactive_tagging_date,
        dropout_date,
        baseline_test_date_final
    from {{ ref('seed_bestlife_unmasked_patient_no') }}
    where nullif(trim(cardno), '') is not null
),

matched_patients as (
    -- One row per matched BestLife patient.
    -- Use patient code as the patient-level key so this check compares patient counts, not claim counts.
    select
        r.final_patient_code,
        min(r.patient_code_full_name) as patient_code_full_name,
        min(r.cardno) as cardno,
        min(b.maskedcardno) as maskedcardno,
        min(r.activity_status) as activity_status,
        min(r.final_company) as final_company,
        min(r.member_type) as member_type,
        min(r.inactive_tagging_date) as inactive_tagging_date,
        min(r.dropout_date) as dropout_date,
        min(r.baseline_test_date_final) as baseline_test_date_final,
        count(*) as match_rows
    from bl_unmaskedcardno b
    inner join reference_member_base r
        on b.cardno_norm = r.cardno_norm
    group by 1
),

claim_window_2024_2025 as (
    -- Same time window used by the frequency model.
    -- This lets the check count only patients who actually show up in the same claim slice.
    select
        *
    from {{ ref('mxc_raw_claims') }}
    where source_year between 2024 and 2025
      and nullif(trim(maskedcardno), '') is not null
),

claim_rollup as (
    -- Mirror the frequency model: roll raw rows to claim grain before filtering OP LAB.
    select
        claimno,
        min(maskedcardno) as maskedcardno,
        min(loatype) as loatype,
        nullif(trim(min(primaryicdcode)), '') as primaryicdcode
    from claim_window_2024_2025
    group by 1
),

op_lab_claims as (
    -- Same OP LAB filter used by the frequency model, but applied after claim rollup.
    select
        *
    from claim_rollup
    where upper(trim(loatype)) = 'OP LAB'
),

matched_patients_2024_2025 as (
    select distinct
        mp.*
    from matched_patients mp
    inner join op_lab_claims c
        on mp.maskedcardno = c.maskedcardno
)

select
*
from matched_patients_2024_2025
 