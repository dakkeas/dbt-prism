
{{config(materialized = 'table')}}

{{
    md_scorecard_v2(
        ['ESSENTIAL (PRIMARY) HYPERTENSION'],
        20,
        500,
        6
    ) 
}}