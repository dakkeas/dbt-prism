
{{config(materialized = 'table')}}

{{
    md_scorecard(
        ['OTHER CEREBROVASCULAR DISEASES'],
        
        20,
        500,
        2
    ) 
}}
