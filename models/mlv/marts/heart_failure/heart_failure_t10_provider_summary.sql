

{{config(materialized = 'table')}}

{{
    icd_summary_per_provider(
        ['HEART FAILURE']
    ) 
}}
