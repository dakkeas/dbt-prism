
{{config(materialized = 'table')}}

{{
    md_scorecard(
        ['HEART FAILURE'],
        
        20,
        500,
        2
    ) 
}}
