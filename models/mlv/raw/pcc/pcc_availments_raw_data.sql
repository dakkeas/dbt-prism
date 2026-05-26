{{ config(materialized='table') }}

SELECT
    card_number,
    transaction_id,
    availment_type,
    icd_code,
    icd_description,
    pcc_branch_name AS pccbranchname,
    physiciancode,
    physicianname,
    service_price,
    availment_date
FROM {{ ref('seed_pcc_availments_raw_data') }}