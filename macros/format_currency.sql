{% macro format_currency(value) -%}
    {%- if target.type == 'bigquery' -%}
        FORMAT("₱%'.2f", COALESCE(CAST({{ value }} AS FLOAT64), 0.0))
    {%- else -%}
        '₱' || TO_CHAR(COALESCE({{ value }}, 0), 'FM999,999,990.00')
    {%- endif -%}
{%- endmacro %}
