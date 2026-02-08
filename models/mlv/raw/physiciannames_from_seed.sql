{{config(materialized = 'view')}}


SELECT * FROM {{ref('physiciannames')}}
