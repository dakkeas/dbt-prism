
{{config(materialized = 'table')}}

{{
    icd_summary_per_provider_acn(
        ['ESSENTIAL (PRIMARY) HYPERTENSION'],
    ) 
}}






