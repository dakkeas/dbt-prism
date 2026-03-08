

{{config(materialized = 'table')}}

{{
    icd_summary_per_provider(
        ['ACUTE MYOCARDIAL INFARCTION']
    ) 
}}
