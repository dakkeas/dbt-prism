
{{config(materialized = 'table')}}

{{
    md_scorecard(
        ['HYPERTENSIVE HEART DISEASE'],
        
        20,
        500,
        2
    ) 
}}
