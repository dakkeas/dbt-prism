{{ config(materialized = 'table') }}

{{
    md_scorecard_y25(
        ['DIABETES MELLITUS'],
        20,
        500,
        3
    ) 
}}
