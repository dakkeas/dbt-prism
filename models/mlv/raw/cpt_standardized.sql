
{{ config(materialized='table') }}

SELECT * FROM {{ref("acn_cpt_info_standardized")}}
