{% macro create_yearly_claims(start_year, end_year) %}

{% set schema = "mxc_raw_claims" %} --schema

{% for year in range(start_year, end_year + 1) %}

    {% set next_year = year + 1 %}
    {% set table_name = schema ~ ".acn_claims_" ~ year %}

    {% do run_query("DROP TABLE IF EXISTS " ~ table_name) %}

    {% set sql %}
        CREATE TABLE {{ table_name }} AS
        SELECT *
        FROM {{ ref('acn_claims') }}
        WHERE admissiondate >= '{{ year }}-01-01'
          AND admissiondate < '{{ next_year }}-01-01';
    {% endset %}

    {% do run_query(sql) %}

    {% do run_query("
        CREATE INDEX IF NOT EXISTS idx_" ~ year ~ "_maskedcardno 
        ON " ~ table_name ~ " (maskedcardno)
    ") %}

    {% do run_query("
        CREATE INDEX IF NOT EXISTS idx_" ~ year ~ "_admissiondate 
        ON " ~ table_name ~ " (admissiondate)
    ") %}

{% endfor %}

{% endmacro %}