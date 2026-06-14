{% macro env_alias(dev_name, prod_name) -%}
    {% if target.name | lower == 'dev' %}
        {{ adapter.quote(dev_name) }}
    {% else %}
        {{ adapter.quote(prod_name) }}
    {% endif %}
{%- endmacro %}
