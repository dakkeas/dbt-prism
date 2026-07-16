with source as (

    select *
    from {{ ref('seed_blhc_labs_raw') }}

),
shortlist as  (
    select
        source.reference_number,
        source.final_patient_code,
        ref.patient_code_full_name,
        ref.card_number_final as maxicare_card_number, 
        cast(nullif(result_date, '') as date) as result_date,
        list_of_tests,
        cast(
            nullif(
                regexp_replace(
                    regexp_replace(hba1c_ngsp, '[^0-9\.]', '', 'g'),
                    '\.+',
                    '.',
                    'g'
                ),
                ''
            ) as numeric
        ) as hba1c_ngsp,

        cast(
            nullif(
                regexp_replace(
                    regexp_replace(glucose_fastingfbs_mgdl, '[^0-9\.]', '', 'g'),
                    '\.+',
                    '.',
                    'g'
                ),
                ''
            ) as numeric
        ) as glucose_fastingfbs_mgdl,

        cast(
            nullif(
                regexp_replace(
                    regexp_replace(creatinine_mgdl, '[^0-9\.]', '', 'g'),
                    '\.+',
                    '.',
                    'g'
                ),
                ''
            ) as numeric
        ) as creatinine_mgdl,

        cast(
            nullif(
                regexp_replace(
                    regexp_replace(ldl_cholesterol_mgdl, '[^0-9\.]', '', 'g'),
                    '\.+',
                    '.',
                    'g'
                ),
                ''
            ) as numeric
        ) as ldl_cholesterol_mgdl,
        record_url,
        earliest_hba1c,
        latest_hba1c,
        earliest_lipid_profile,
        latest_lipid_profile,
        earliest_fbs,
        latest_fbs
    from source
    LEFT JOIN {{ref('reference_member_base')}} ref on 
    ref.final_patient_code = source.final_patient_code
)
SELECT * FROM shortlist

