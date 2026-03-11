{{config(materialized='table')}}

select * from {{ref('cardiometabolic_primaryicdcodes_csv')}}
