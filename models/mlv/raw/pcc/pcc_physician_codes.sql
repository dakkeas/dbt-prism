{{config(materalized='table')}}

SELECT * FROM {{ref('seed_pcc_physician_codes')}}