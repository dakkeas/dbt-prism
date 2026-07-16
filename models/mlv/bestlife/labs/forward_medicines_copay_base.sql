{{ config(materialized = 'table') }}

select *
from {{ ref('forward_medicines_copay') }}
