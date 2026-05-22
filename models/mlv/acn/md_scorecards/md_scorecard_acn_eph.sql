
{{config(materialized = 'table')}}

{{
    md_scorecard_acn(
        ['ESSENTIAL (PRIMARY) HYPERTENSION'],
        10000000,
        10000000,
        0
    ) 
}}
