
{{config(materialized = 'table')}}

{{
    md_scorecard(
        ['OTHER ACUTE ISCHAEMIC HEART DISEASES'],
        
        20,
        500,
        2
    ) 
}}
