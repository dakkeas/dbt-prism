with source as (

    select *
    from {{ ref('seed_blhc_bp_raw') }}

),
shortlist as  (
select
    source.reference_number,
    source.final_patient_code,
    ref.patient_code_full_name,

    ref.card_number_final as maxicare_card_number, 
    cast(nullif(result_date, '') as date) as result_date,
    cast(nullif(systolic_blood_pressure, 'N/A') as numeric) as systolic_blood_pressure,
    cast(nullif(diastolic_blood_pressure, 'N/A') as numeric) as diastolic_blood_pressure,

    source,

    earliest_sbp,
    latest_sbp,
    earliest_dbp,
    latest_dbp
from source 
    LEFT JOIN {{ref('reference_member_base')}} ref on 
    ref.final_patient_code = source.final_patient_code

)
SELECT * FROM shortlist

