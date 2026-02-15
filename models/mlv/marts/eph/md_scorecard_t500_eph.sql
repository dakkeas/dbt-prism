
{{config(materialized = 'table')}}

{{
    md_scorecard(
        ['ESSENTIAL (PRIMARY) HYPERTENSION'],
        20,
        500,
        6
    ) 
}}