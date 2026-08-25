{{ config(materialized = 'table') }}

{{
    md_scorecard_y24(
        ['CHRONIC RENAL FAILURE'],
        20,
        500,
        3,
        'px_engine_crf_y24',
        'computed_primaryicdgroup'
    )
}}
