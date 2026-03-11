
{{config(materialized = 'table')}}

{{
    md_scorecard(
        ['DIABETES MELLITUS'],
        100000000,
        100000000,
        6
    ) 
}}
