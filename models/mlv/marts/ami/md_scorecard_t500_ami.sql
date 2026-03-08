
{{config(materialized = 'table')}}

{{
    md_scorecard(
        ['ACUTE MYOCARDIAL INFARCTION'],
        
        20,
        500,
        2
    ) 
}}
