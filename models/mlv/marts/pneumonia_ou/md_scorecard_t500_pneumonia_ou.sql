
{{config(materialized = 'table')}}

{{
    md_scorecard(
        ['PNEUMONIA, ORGANISM UNSPECIFIED'],
        
        20,
        500,
        2
    ) 
}}
