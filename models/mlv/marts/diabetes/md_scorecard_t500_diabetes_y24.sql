{{ config(materialized = 'table') }}

{{
    md_scorecard_y24(
        ['DIABETES MELLITUS'],
        20,
        500,
        3
    ) 
}}
