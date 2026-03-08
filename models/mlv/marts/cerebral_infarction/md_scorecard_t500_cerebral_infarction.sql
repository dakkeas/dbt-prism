
{{config(materialized = 'table')}}

{{
    md_scorecard(
        ['CEREBRAL INFARCTION'],
        
        20,
        500,
        2
    ) 
}}
