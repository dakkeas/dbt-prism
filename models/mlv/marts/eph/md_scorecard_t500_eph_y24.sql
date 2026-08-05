{{ config(materialized = 'table') }}

{{
    md_scorecard_y24(
        ['ESSENTIAL (PRIMARY) HYPERTENSION'],
        20,
        500,
        6
    ) 
}}
