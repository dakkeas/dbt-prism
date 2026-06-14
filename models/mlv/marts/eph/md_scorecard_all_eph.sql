
{{config(materialized = 'table')}}

{{
    md_scorecard(
        ['ESSENTIAL (PRIMARY) HYPERTENSION'],
        100000,
        1000000,
        0
    ) 
}}