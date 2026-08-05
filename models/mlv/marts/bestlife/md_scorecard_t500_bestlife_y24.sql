{{ config(materialized = 'table') }}

{{
    md_scorecard_y24(
        ['DIABETES MELLITUS', 'ESSENTIAL (PRIMARY) HYPERTENSION','DISORDERS OF LIPOPROTEIN METABOLISM AND OTHER LIPIDAEMIAS'],
        20,
        500,
        6
    ) 
}}
