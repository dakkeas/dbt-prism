
{{config(materalized='table')}}


SELECT * FROM {{ref('seed_pcc_availments_raw_data')}}