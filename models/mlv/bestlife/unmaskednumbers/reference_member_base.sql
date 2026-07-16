{{config(materialized = 'table')}}

with source as (

    select *
    from {{ ref('seed_reference_member_base') }}

)
select

    "Patient Code-Full Name" as patient_code_full_name,
    "Final Patient Code" as final_patient_code,
    replace("Card Number Final", ' ', '') as card_number_final, 
    cast("Processing Date - Final" as date) as processing_date_final,
    cast("Baseline Test Date - Final" as date) as baseline_test_date_final,
    cast("Dropout Date" as date) as dropout_date

from source