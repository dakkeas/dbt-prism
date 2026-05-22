-- models/staging/stg_acn_raw.sql

select *
from {{ source('masked_acn_consolidated_raw_data', 'masked_acn_consolidated_raw_data_fy2324_fy2425') }}