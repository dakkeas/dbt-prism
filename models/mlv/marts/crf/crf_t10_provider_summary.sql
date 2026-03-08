

{{config(materialized = 'table')}}

{{
    icd_summary_per_provider(
        ['CHRONIC RENAL FAILURE']
    ) 
}}
