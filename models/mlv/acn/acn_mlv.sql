
{{ config(materialized='table')}}


SELECT * FROM {{ref('mlv')}}
{% if target.type == 'bigquery' %}
WHERE UPPER(starting_corpname) LIKE 'ACCENTURE%'
{% else %}
WHERE starting_corpname ILIKE 'ACCENTURE%'
{% endif %}
