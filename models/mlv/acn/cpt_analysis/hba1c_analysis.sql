{{ config(materialized='table') }}

{{ standardized_cpt_member_analysis('HbA1c', 'hba1c') }}
