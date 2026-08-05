{{ config(materialized = 'table') }}

{{
    md_scorecard_y25(
        ['ESSENTIAL (PRIMARY) HYPERTENSION'],
        20,
        500,
        6
    ) 
}}
