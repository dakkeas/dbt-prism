
{{config(materialized = 'table')}}

{{
    md_scorecard(
        ['CHRONIC ISCHAEMIC HEART DISEASE'],
        
        20,
        500,
        2
    ) 
}}
