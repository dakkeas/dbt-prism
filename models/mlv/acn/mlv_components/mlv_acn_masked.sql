
{{ config(materialized='table')}}

-- ACN MLV MASKED VERSION
-- Recreated from mlv.sql, adapted for ACN data
-- Source: masked_acn_2325 (with primaryicdgroup)
-- Removed: PCC logic, coverage item desc, cardiometabolic, prim_physician, bl_unmasked

WITH raw_claims AS (
    SELECT * FROM {{ ref('masked_acn_2325') }}
),

first_claim_details AS (

    SELECT
        fc.maskedcardno,
        fc.starting_claimno,
        MAX(fc.starting_admissiondate) as starting_admissiondate,
        MAX(fc.starting_physicianname) as starting_physicianname,
        MAX(fc.starting_physiciancode) as starting_physiciancode,
        MAX(fc.starting_icdcode) as starting_icdcode,
        MAX(fc.starting_providername) as starting_providername,
        MAX(fc.starting_loatype) as starting_loatype,

        MAX(rc.corpcode) AS starting_corpcode,
        MAX(rc.branchdesc) AS starting_branchdesc,
        MAX(rc.gender) AS starting_gender,
        MAX(rc.membershiptype) AS starting_membershiptype,
        MAX(rc.mainspecialization) AS starting_mainspecialization,
        SUM(rc.approved) AS starting_approved,
        MAX(rc.age) AS starting_age,
        MAX(rc.benefitid) AS starting_benefitid,
        MAX(rc.providertype) AS starting_providertype,
        MAX(rc.primaryicdgroup) AS starting_primaryicdgroup,

        -- count & sum of ruvcode
        SUM(
            CASE
                WHEN NULLIF(rc.ruvcode,'') IS NOT NULL THEN 1 ELSE 0
            END
        ) AS starting_count_of_ruvcode,

        SUM(
            CASE
                WHEN NULLIF(rc.ruvcode,'') IS NOT NULL THEN rc.approved ELSE 0
            END
        ) AS starting_sum_of_util_ruvcode,

        -- count & sum of cptcode
        SUM(
            CASE
                WHEN NULLIF(rc.cptdesc,'') IS NOT NULL THEN 1 ELSE 0
            END
        ) AS starting_count_of_cptcode,

        SUM(
            CASE
                WHEN NULLIF(rc.cptdesc,'') IS NOT NULL THEN rc.approved ELSE 0
            END
        ) AS starting_sum_of_util_cptcode,

        -- aggregation of cptdesc & ruvcode
        STRING_AGG(DISTINCT CASE
            WHEN TRIM(rc.cptdesc) NOT IN ('0', ' ', '') AND rc.cptdesc IS NOT NULL THEN rc.cptdesc
        END, ', ') AS starting_cptdescs,

        STRING_AGG(DISTINCT CASE
            WHEN TRIM(rc.ruvcode) NOT IN ('0', ' ', '') AND rc.ruvcode IS NOT NULL THEN rc.ruvcode
        END, ', ') AS starting_ruvcodes

    FROM {{ ref('first_consults_acn') }} fc
    INNER JOIN raw_claims rc
        ON fc.starting_claimno = rc.claimno
    GROUP BY
        fc.maskedcardno,
        fc.starting_claimno
),

subsequent_details AS (

    SELECT
        s.maskedcardno,
        MAX(s.claim_sequence) AS claim_sequence,
        s.subsequent_claimno,
        MAX(rc.primaryicdgroup) AS subsequent_primaryicdgroup,
        MAX(rc.icdcode) AS subsequent_icdcode,
        MAX(rc.loatype) AS subsequent_loatype,
        MAX(rc.corpcode) AS subsequent_corpcode,
        MAX(rc.branchdesc) AS subsequent_branchdesc,
        MAX(rc.gender) AS subsequent_gender,
        MAX(rc.membershiptype) AS subsequent_membershiptype,
        MAX(rc.mainspecialization) AS subsequent_mainspecialization,
        MAX(rc.admissiondate) AS subsequent_admissiondate,
        SUM(rc.approved) AS subsequent_approved,
        MAX(rc.age) AS subsequent_age,
        MAX(rc.benefitid) AS subsequent_benefitid,
        MAX(rc.providername) AS subsequent_providername,
        MAX(rc.providertype) AS subsequent_providertype,

        STRING_AGG(DISTINCT CASE
            WHEN TRIM(rc.physiciancode) NOT IN ('0', ' ', '') AND rc.physiciancode IS NOT NULL THEN rc.physiciancode
        END, ', ') AS subsequent_physiciancodes,

        MAX(rc.physicianname) AS subsequent_physicianname,

        -- count & sum of ruvcode
        SUM(
            CASE
                WHEN NULLIF(rc.ruvcode,'') IS NOT NULL THEN 1 ELSE 0
            END
        ) AS subsequent_count_of_ruvcode,

        SUM(
            CASE
                WHEN NULLIF(rc.ruvcode,'') IS NOT NULL THEN rc.approved ELSE 0
            END
        ) AS subsequent_sum_of_util_ruvcode,

        -- count & sum of cptcode
        SUM(
            CASE
                WHEN NULLIF(rc.cptdesc,'') IS NOT NULL THEN 1 ELSE 0
            END
        ) AS subsequent_count_of_cptcode,

        SUM(
            CASE
                WHEN NULLIF(rc.cptdesc,'') IS NOT NULL THEN rc.approved ELSE 0
            END
        ) AS subsequent_sum_of_util_cptcode,

        -- aggregation of cptdesc & ruvcode
        STRING_AGG(DISTINCT CASE
            WHEN TRIM(rc.cptdesc) NOT IN ('0', ' ', '') AND rc.cptdesc IS NOT NULL THEN rc.cptdesc
        END, ', ') AS subsequent_cptdescs,

        STRING_AGG(DISTINCT CASE
            WHEN TRIM(rc.ruvcode) NOT IN ('0', ' ', '') AND rc.ruvcode IS NOT NULL THEN rc.ruvcode
        END, ', ') AS subsequent_ruvcodes

    FROM {{ ref('subsequent_claims_acn') }} s
    INNER JOIN raw_claims rc
        ON s.subsequent_claimno = rc.claimno
    GROUP BY
        s.maskedcardno,
        s.subsequent_claimno
),

-- PANIC VISIT LOGIC (ER → INPATIENT within 1 day = valid admission, not panic)
er_inp_claims AS (
    SELECT
        maskedcardno,
        subsequent_admissiondate,
        subsequent_loatype
    FROM subsequent_details
    WHERE subsequent_loatype IN ('EMERGENCY', 'INPATIENT')
    GROUP BY 1, 2, 3
),

er_patient_journey AS (
    SELECT
        *,
        LEAD(subsequent_loatype) OVER (
            PARTITION BY maskedcardno
            ORDER BY subsequent_admissiondate, subsequent_loatype DESC
        ) AS next_loatype,
        LEAD(subsequent_admissiondate) OVER (
            PARTITION BY maskedcardno
            ORDER BY subsequent_admissiondate, subsequent_loatype DESC
        ) AS next_admissiondate
    FROM er_inp_claims
),

panic_logic AS (
    SELECT
        *,
        CASE
            WHEN subsequent_loatype = 'EMERGENCY'
            AND (
                next_loatype = 'INPATIENT'
                {% if target.type == 'bigquery' %}
                    AND DATE_DIFF(next_admissiondate, subsequent_admissiondate, DAY) <= 1
                {% else %}
                    AND (next_admissiondate - subsequent_admissiondate) <= 1
                {% endif %}
            ) THEN 0 -- Valid admission (NOT panic)

            WHEN subsequent_loatype = 'EMERGENCY' THEN 1 -- Panic visit
            ELSE 0
        END AS is_panic_visit
    FROM er_patient_journey
),

merged_table AS (

    SELECT

        -- =====================
        -- IDS
        -- =====================
        fc.maskedcardno,
        fc.starting_claimno,
        fc.starting_admissiondate,

        -- =====================
        -- STARTING CLAIM
        -- =====================
        fc.starting_primaryicdgroup,
        fc.starting_loatype,
        fc.starting_icdcode,
        fc.starting_providername,
        fc.starting_providertype,
        fc.starting_physicianname,
        fc.starting_physiciancode,
        fc.starting_mainspecialization,
        fc.starting_corpcode,
        fc.starting_branchdesc,
        fc.starting_membershiptype,
        fc.starting_age,
        fc.starting_gender,
        fc.starting_benefitid,
        fc.starting_approved,

        CASE
            WHEN fc.starting_primaryicdgroup IN (
                'NON-INSULIN-DEPENDENT DIABETES MELLITUS',
                'INSULIN-DEPENDENT DIABETES MELLITUS',
                'UNSPECIFIED DIABETES MELLITUS'
            )
            THEN 'DIABETES MELLITUS'
            ELSE fc.starting_primaryicdgroup
        END AS combined_starting_primaryicdgroup,

        fc.starting_count_of_cptcode,
        fc.starting_sum_of_util_cptcode,
        fc.starting_count_of_ruvcode,
        fc.starting_sum_of_util_ruvcode,
        fc.starting_cptdescs,
        fc.starting_ruvcodes,

        -- =====================
        -- SUBSEQUENT CLAIM
        -- =====================
        s.subsequent_claimno,
        s.subsequent_admissiondate,
        s.claim_sequence,


        s.subsequent_primaryicdgroup,
        s.subsequent_loatype,
        s.subsequent_icdcode,
        s.subsequent_providername,
        s.subsequent_providertype,
        s.subsequent_physiciancodes,
        s.subsequent_physicianname,
        s.subsequent_mainspecialization,
        s.subsequent_corpcode,
        s.subsequent_branchdesc,
        s.subsequent_membershiptype,
        s.subsequent_age,
        s.subsequent_gender,
        s.subsequent_benefitid,

        CASE
            WHEN s.subsequent_loatype = 'EMERGENCY' THEN pl.is_panic_visit ELSE NULL
        END AS is_panic_visit,

        s.subsequent_approved,

        -- =====================
        -- BEST LIFE LOGIC
        -- =====================
        CASE
            WHEN UPPER(TRIM(s.subsequent_icdcode))
                IN (SELECT UPPER(TRIM(icdcode)) FROM {{ ref('blp_icdcodes_v2') }})
            THEN 'Y'
            ELSE 'N'
        END AS is_bestlife_icd,

        s.subsequent_count_of_cptcode,
        s.subsequent_sum_of_util_cptcode,
        s.subsequent_count_of_ruvcode,
        s.subsequent_sum_of_util_ruvcode,
        s.subsequent_cptdescs,
        s.subsequent_ruvcodes

    FROM first_claim_details fc
    INNER JOIN subsequent_details s
        ON fc.maskedcardno = s.maskedcardno
    LEFT JOIN panic_logic pl
        ON pl.maskedcardno = fc.maskedcardno
        AND pl.subsequent_admissiondate = s.subsequent_admissiondate
        AND pl.subsequent_loatype = s.subsequent_loatype

    ORDER BY
        fc.maskedcardno,
        s.claim_sequence
)

SELECT * FROM merged_table