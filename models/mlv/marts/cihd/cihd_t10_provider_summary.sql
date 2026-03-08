

{{config(materialized = 'table')}}

{{
    icd_summary_per_provider(
        ['CHRONIC ISCHAEMIC HEART DISEASE']
    ) 
}}
