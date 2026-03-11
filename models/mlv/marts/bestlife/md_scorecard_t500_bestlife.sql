
{{config(materialized = 'table')}}

{{
    md_scorecard(
        ['DIABETES MELLITUS', 'ESSENTIAL (PRIMARY) HYPERTENSION','DISORDERS OF LIPOPROTEIN METABOLISM AND OTHER LIPIDAEMIAS'],
        20,
        500,
        6
    ) 
}}
