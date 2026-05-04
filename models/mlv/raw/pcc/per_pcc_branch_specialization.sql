{{config(materalized='table')}}

SELECT * FROM {{ref('seed_per_pcc_branch_specialization')}}