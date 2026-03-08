
{{config(materialized = 'table')}}

{{
    icd_summary_per_provider(
        ['NON-INSULIN-DEPENDENT DIABETES MELLITUS', 'INSULIN-DEPENDENT DIABETES MELLITUS', 'UNSPECIFIED DIABETES MELLITUS'],
    ) 
}}







