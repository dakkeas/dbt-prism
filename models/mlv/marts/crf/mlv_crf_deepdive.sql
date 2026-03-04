
{{ config(materialized = 'table') }}

WITH cpt_lookup AS (
    SELECT
        TRIM(UPPER(cptcode)) AS cptcode,
        UPPER(TRIM(status_group)) AS normalized_group
    FROM {{ ref('crf_cptcodes') }}
),

-- 1. Grab claims directly from the raw table, filtering only for our target CPTs
raw_cpt_counts AS (
    SELECT 
        claimno, 
        TRIM(UPPER(cptcode)) AS cptcode, 
        STRING_AGG(cptcode, ', ') AS crf_cptcodes,
        COUNT(*) AS cpt_count
    FROM {{ source('public_data', 'raw_claims_2023_2025') }}
    WHERE TRIM(UPPER(cptcode)) IN (SELECT cptcode FROM cpt_lookup)
    GROUP BY 1, 2
),

-- 2. Attach the dialysis group category to those claims
cpt_info AS (
    SELECT 
        c.claimno, 
        c.cptcode, 
        c.cpt_count,
        c.crf_cptcodes,
        l.normalized_group
    FROM raw_cpt_counts c
    INNER JOIN cpt_lookup l 
        ON c.cptcode = l.cptcode
),

-- 3. Link back to your CRF patient base and sum the targeted counts per claim
counts AS (
    SELECT
        crf.maskedcardno,
        crf.subsequent_claimno, 
        STRING_AGG(c.crf_cptcodes, ', ') AS crf_cptcodes,
        COALESCE(SUM(CASE WHEN c.normalized_group IN ('PRE-DIALYSIS', 'PRE DIALYSIS') THEN c.cpt_count ELSE 0 END), 0) AS pre_dialysis_cptcode_count,
        COALESCE(SUM(CASE WHEN c.normalized_group IN ('ON-DIALYSIS', 'ON DIALYSIS') THEN c.cpt_count ELSE 0 END), 0) AS on_dialysis_cptcode_count
    FROM {{ ref('mlv_crf') }} crf
    LEFT JOIN cpt_info c
        ON crf.subsequent_claimno = c.claimno
    GROUP BY crf.subsequent_claimno, crf.maskedcardno
),

-- 4. Re-attach the counts to the deepdive base
deepdive AS (
    SELECT
        crf.*,
        c.crf_cptcodes,
        c.pre_dialysis_cptcode_count,
        c.on_dialysis_cptcode_count
    FROM {{ ref('mlv_crf') }} crf
    LEFT JOIN counts c
        ON crf.subsequent_claimno = c.subsequent_claimno
        AND crf.maskedcardno = c.maskedcardno
),

-- 5. Roll up patient totals (ICDs + CPTs)
dialysis_status_agg AS (
    SELECT
        dd.maskedcardno,
        SUM(dd.pre_dialysis_cptcode_count) AS sum_pre_dialysis_cptcode_count,
        SUM(dd.on_dialysis_cptcode_count) AS sum_on_dialysis_cptcode_count,
        SUM(CASE
            WHEN dd.subsequent_primaryicdcode IN ('N18.9', 'N18.8') THEN 1
            ELSE 0
        END) AS crf_only_primaryicdcode_count,
        SUM(CASE
            WHEN dd.subsequent_primaryicdcode IN ('N18.0', 'N18.5', 'Z99.2') THEN 1
            ELSE 0
        END) AS on_dialysis_primaryicdcode_count
    FROM deepdive dd
    GROUP BY dd.maskedcardno
),

-- 6. Apply the clinical hierarchy rules
dialysis_status AS (
    SELECT
        maskedcardno,
        CASE
            -- Highest severity: Check for Dialysis CPTs OR ESRD/Stage 5 ICD-10 codes
            WHEN sum_on_dialysis_cptcode_count > 0 OR on_dialysis_primaryicdcode_count > 0 THEN 'On-Dialysis'
            
            -- Mid severity: Check for Fistula prep / Vein mapping CPTs
            WHEN sum_pre_dialysis_cptcode_count > 0 THEN 'Pre-Dialysis'
            
            -- Baseline severity: No procedures, routine medical management
            ELSE 'CRF Only'
        END AS crf_category
    FROM dialysis_status_agg
)

-- 7. Final Join
SELECT
    dd.*,
    ds.crf_category
FROM deepdive dd
LEFT JOIN dialysis_status ds
    ON dd.maskedcardno = ds.maskedcardno