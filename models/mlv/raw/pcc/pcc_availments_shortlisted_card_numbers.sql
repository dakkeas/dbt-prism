{{config(materalized='table')}}

SELECT * FROM {{ref('seed_pcc_availments_shortlisted_card_numbers')}}
