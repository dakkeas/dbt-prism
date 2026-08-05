{{ config(materialized = 'table') }}

-- Description:
-- Filters the mlv staging table to only include eligible BestLife patients.
-- Eligibility mirrors the criteria in bestlife_before_after_px_engine:
--   - Patient has a valid baseline test date (enrollment date) >= 2020-01-01
--   - Patient was active for at least 12 months after enrollment
--     (inactive_tagging_date is null or >= enrollment_date + 12 months)

WITH bestlife_unmaskedcardno AS (
    -- Normalize the BestLife card-number mapping and keep only usable masked card links.
    SELECT DISTINCT
        maskedcardno,
        REPLACE(TRIM(cardno), ' ', '') AS cardno_norm
    FROM {{ ref('bestlife_unmaskedcardno') }}
    WHERE NULLIF(TRIM(cardno), '') IS NOT NULL
      AND NULLIF(TRIM(maskedcardno), '') IS NOT NULL
),

reference_member_base AS (
    -- Prepare one BestLife seed profile per patient/card, using baseline test date as enrollment date.
    SELECT
        final_patient_code,
        REPLACE(cardno, ' ', '') AS cardno_norm,
        MIN(inactive_tagging_date) AS inactive_tagging_date,
        MIN(baseline_test_date_final) AS enrollment_date
    FROM {{ ref('seed_bestlife_unmasked_patient_no') }}
    WHERE NULLIF(TRIM(cardno), '') IS NOT NULL
      AND NULLIF(TRIM(final_patient_code), '') IS NOT NULL
    GROUP BY 1, 2
),

bestlife_patient_cards AS (
    -- Match BestLife seed patients to MXC masked card numbers through normalized card number.
    SELECT DISTINCT
        r.final_patient_code,
        r.enrollment_date,
        r.inactive_tagging_date,
        b.maskedcardno
    FROM reference_member_base r
    INNER JOIN bestlife_unmaskedcardno b
        ON r.cardno_norm = b.cardno_norm
),

eligible_patients AS (
    -- Apply eligibility filters: valid enrollment date and at least 12 months of active status.
    SELECT DISTINCT
        maskedcardno
    FROM bestlife_patient_cards
    WHERE enrollment_date IS NOT NULL
      AND enrollment_date >= DATE '2020-01-01'
      AND (
          inactive_tagging_date IS NULL
          {% if target.type == 'bigquery' %}
              OR inactive_tagging_date >= enrollment_date + INTERVAL 12 MONTH
          {% else %}
              OR inactive_tagging_date >= enrollment_date + INTERVAL '12 months'
          {% endif %}
      )
),

bestlife_mlv AS (
    SELECT
        mlv.*
    FROM {{ ref('mlv') }} mlv
    INNER JOIN eligible_patients ep
        ON mlv.maskedcardno = ep.maskedcardno
)

SELECT *
FROM bestlife_mlv
