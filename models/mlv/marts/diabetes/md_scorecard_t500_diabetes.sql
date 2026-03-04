
{{config(materialized = 'table')}}

{{
    md_scorecard(
        ['NON-INSULIN-DEPENDENT DIABETES MELLITUS', 'INSULIN-DEPENDENT DIABETES MELLITUS'],
        20,
        500,
        2
    ) 
}}