{{ config(materialized = 'table') }}

{{
    md_scorecard_y24(
        ['DISORDERS OF LIPOPROTEIN METABOLISM AND OTHER LIPIDAEMIAS'],
        20,
        500,
        3
    ) 
}}
