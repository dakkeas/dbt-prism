{{ config(materialized = 'table') }}

{{
    md_scorecard_y25(
        ['CHRONIC RENAL FAILURE'],
        20,
        500,
        3,
        'px_engine_crf_y25',
        'computed_primaryicdgroup'
    )
}}
