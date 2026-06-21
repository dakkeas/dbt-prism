{{config(materialized = 'table')}}

{{
    md_scorecard(
        ['CHRONIC RENAL FAILURE'],
        10000,
        500,
        3
    ) 
}}
