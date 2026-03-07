

{{config(materialized = 'table')}}

{{
    md_scorecard_crf_deepdive(
        ['NON-INSULIN-DEPENDENT DIABETES MELLITUS', 'INSULIN-DEPENDENT DIABETES MELLITUS', 'ESSENTIAL (PRIMARY) HYPERTENSION', 'CHRONIC RENAL FAILURE', 'UNSPECIFIED DIABETES MELLITUS'],
        20, 
        500, 
        7 
    ) 
}}

-- list of starting_primaryicdgroup
-- top n providers
-- top n physicians
-- more than n patients











