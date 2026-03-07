


{{config(materialized = 'table')}}

{{
    icd_summary_per_provider(
        ['DISORDERS OF LIPOPROTEIN METABOLISM AND OTHER LIPIDAEMIAS']
    ) 
}}

