{{ config(materialized = 'table') }}

{{
    md_scorecard_y25(
        ['DISORDERS OF LIPOPROTEIN METABOLISM AND OTHER LIPIDAEMIAS'],
        20,
        500,
        3
    ) 
}}
