
{{config(materialized = 'table')}}

{{
    md_scorecard(
        ['PNEUMONIA MODERATE RISK'],
        
        20,
        500,
        2
    ) 
}}
