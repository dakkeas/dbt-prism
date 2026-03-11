
{{config(materialized = 'table')}}

{{
    md_scorecard(
        ['DIABETES MELLITUS'],
        20,
        500,
        3
    ) 
}}