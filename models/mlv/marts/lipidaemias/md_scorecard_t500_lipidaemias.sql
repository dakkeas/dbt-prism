
{{config(materialized = 'table')}}

{{
    md_scorecard(
        ['DISORDERS OF LIPOPROTEIN METABOLISM AND OTHER LIPIDAEMIAS'],
        20,
        500,
        6
    ) 
}}