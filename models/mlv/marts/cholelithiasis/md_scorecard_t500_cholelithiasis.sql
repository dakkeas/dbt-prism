
{{config(materialized = 'table')}}

{{
    md_scorecard(
        ['CHOLELITHIASIS'],
        
        20,
        500,
        2
    ) 
}}
