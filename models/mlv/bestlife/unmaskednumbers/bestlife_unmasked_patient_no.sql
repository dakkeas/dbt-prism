{{ config(materialized = 'table') }}

select *
from {{ ref('seed_bestlife_unmasked_patient_no') }}
