
{{ config(materialized='table')}}


WITH first_claim_details AS (
    SELECT
        fc.maskedcardno,
        MIN(rc.claimno) AS starting_claimno,
        MIN(rc.admissiondate) AS starting_admissiondate,
        MIN(rc.dischargedate) AS starting_dischargedate,
        fc.starting_physiciancode AS starting_physiciancode,
        MIN(rc.primaryicdgroup) AS starting_primaryicdgroup,
        MIN(rc.primaryicdcode) AS starting_primaryicdcode,
        MIN(rc.primaryicddesc) AS starting_primaryicddesc,
        MIN(rc.providername) AS starting_providername,
        MIN(rc.loatype) AS starting_loatype,
        MIN(rc.coverage) AS starting_coverage,
        SUM(rc.billed) AS starting_bill,
        SUM(rc.approved) AS starting_approved,
        SUM(
            CASE
                WHEN rc.coverageitemdesc = 'PHILHEALTH' THEN ABS(rc.approved)
                ELSE 0 END
        ) AS starting_philhealth,

        -- count & sum of cptcode

        SUM(
            CASE 
                WHEN NULLIF(rc.cptcode,'') IS NOT NULL THEN 1 ELSE 0
            END
        )
        AS starting_count_of_cptcode,

        SUM(
            CASE 
                WHEN NULLIF(rc.cptcode,'') IS NOT NULL THEN rc.approved ELSE 0
            END
        )
        AS starting_sum_of_util_cptcode,


        -- count & sum of ruvcode

        SUM(
            CASE 
                WHEN NULLIF(rc.ruvcode,'') IS NOT NULL THEN 1 ELSE 0
            END
        )
        AS starting_count_of_ruvcode,

        SUM(
            CASE 
                WHEN NULLIF(rc.ruvcode,'') IS NOT NULL THEN rc.approved ELSE 0
            END
        )
        AS starting_sum_of_util_ruvcode,

        -- aggregation of cptcode & ruvcode

        STRING_AGG(DISTINCT CASE

        WHEN TRIM(rc.cptcode) NOT IN ('0', ' ', '') AND rc.cptcode IS NOT NULL THEN rc.cptcode

        END, ', ') AS starting_cptcodes,

        STRING_AGG(DISTINCT CASE

        WHEN TRIM(rc.ruvcode) NOT IN ('0', ' ', '') AND rc.ruvcode IS NOT NULL THEN rc.ruvcode

        END, ', ') AS starting_ruvcodes

    FROM
        {{ ref('first_consults')}} fc
    INNER JOIN
        raw_claims_2023_2025 rc
        ON fc.starting_claimno = rc.claimno
    GROUP BY
        fc.maskedcardno,
        fc.starting_claimno,
        fc.starting_physiciancode
),
subsequent_details AS (
    SELECT
        -- MIN(rc.lengthofstay) AS subsequent_lengthofstay,
        s.maskedcardno, 
        MIN(s.claim_sequence) AS claim_sequence,
        s.subsequent_claimno AS subsequent_claimno,
        MIN(rc.admissiondate) AS subsequent_admissiondate,
        MIN(rc.dischargedate) AS subsequent_dischargedate,
        NULLIF(MIN(rc.lengthofstay), 0) AS subsequent_lengthofstay,
        STRING_AGG(DISTINCT CASE

        WHEN TRIM(rc.physiciancode) NOT IN ('0', ' ', '') AND rc.physiciancode IS NOT NULL THEN rc.physiciancode

        END, ', ') AS subsequent_physiciancodes,
        MIN(pd.subsequent_primary_physiciancode_by_rank) AS subsequent_primary_physiciancode_by_rank,
        MIN(pd.subsequent_primary_physiciancode_by_approved_amount) AS subsequent_primary_physiciancode_by_approved_amount,
        MIN(rc.primaryicdgroup) AS subsequent_primaryicdgroup,
        MIN(rc.primaryicdcode) AS subsequent_primaryicdcode,
        MIN(rc.primaryicddesc) AS subsequent_primaryicddesc,
        MIN(rc.providername) AS subsequent_providername,
        MIN(rc.loatype) AS subsequent_loatype,
        MIN(rc.coverage) AS subsequent_coverage,
        SUM(rc.billed) AS subsequent_bill,
        SUM(rc.approved) AS subsequent_approved,
        SUM(CASE WHEN rc.coverageitemdesc = 'PHILHEALTH' THEN ABS(rc.approved) ELSE 0 END) AS subsequent_philhealth,

        SUM(
            CASE 
                WHEN NULLIF(rc.cptcode,'') IS NOT NULL THEN 1 ELSE 0
            END
        )
        AS subsequent_count_of_cptcode,

        SUM(
            CASE 
                WHEN NULLIF(rc.cptcode,'') IS NOT NULL THEN rc.approved ELSE 0
            END
        )
        AS subsequent_sum_of_util_cptcode,


        SUM(
            CASE 
                WHEN NULLIF(rc.ruvcode,'') IS NOT NULL THEN 1 ELSE 0
            END
        )
        AS subsequent_count_of_ruvcode,

        SUM(
            CASE 
                WHEN NULLIF(rc.ruvcode,'') IS NOT NULL THEN rc.approved ELSE 0
            END
        )
        AS subsequent_sum_of_util_ruvcode,

        STRING_AGG(DISTINCT CASE

        WHEN TRIM(rc.cptcode) NOT IN ('0', ' ', '') AND rc.cptcode IS NOT NULL THEN rc.cptcode

        END, ', ') AS subsequent_cptcodes,

        STRING_AGG(DISTINCT CASE

        WHEN TRIM(rc.ruvcode) NOT IN ('0', ' ', '') AND rc.ruvcode IS NOT NULL THEN rc.ruvcode

        END, ', ') AS subsequent_ruvcodes

        
    FROM
        {{ref('pre_post_subsequent_claims')}} s
    INNER JOIN
        raw_claims_2023_2025 rc ON s.subsequent_claimno = rc.claimno
    LEFT JOIN
        {{ref('prim_physician')}} pd ON s.subsequent_claimno = pd.subsequent_claimno
    GROUP BY
        s.maskedcardno, 
        s.subsequent_claimno
),

-- CUSTOM LOGICS
target_cardiometabolic_primaryicdcodes AS (
    SELECT
        primaryicdcode
    FROM {{ref('cardiometabolic_primaryicdcodes')}}
    UNION ALL
    SELECT
        primaryicdcode
    FROM {{ref('end_stage_cardiometabolic_primaryicdcodes')}}
),
flagged_as_cardiometabolic AS (
    -- Step 1 & 2: Get discharge and next admission dates per patient
    SELECT 
        maskedcardno,
        subsequent_admissiondate,
        MAX(subsequent_dischargedate) AS subsequent_dischargedate,
        -- If ANY claim on this day matches the list, flag the whole stay as 1
        MAX(CASE 
            WHEN subsequent_primaryicdcode IN (SELECT primaryicdcode FROM target_cardiometabolic_primaryicdcodes) THEN 1 
            ELSE 0 
        END) AS is_cardiometabolic_stay
    FROM subsequent_details
    WHERE subsequent_loatype = 'INPATIENT'
    GROUP BY maskedcardno, subsequent_admissiondate
),
inpatient_patient_journey AS (
    -- Step 2: Use LEAD() to look at the NEXT stay's admission and flag
    SELECT 
        *,
        LEAD(subsequent_admissiondate) OVER (
            PARTITION BY maskedcardno
            ORDER BY subsequent_admissiondate
        ) AS next_admissiondate,
        LEAD(is_cardiometabolic_stay) OVER (
            PARTITION BY maskedcardno
            ORDER BY subsequent_admissiondate
        ) AS next_stay_is_cardiometabolic
    FROM flagged_as_cardiometabolic 
),
readmission_logic AS (
    -- Step 3 & 4: Flag the readmissions
    SELECT 
        *,
        -- Date difference logic
        {% if target.type == 'bigquery' %}
            DATE_DIFF(next_admissiondate, subsequent_dischargedate, DAY) as days_to_readmit -- BigQuery syntax
        {% else %}
            (next_admissiondate - subsequent_dischargedate) as days_to_readmit -- PostgreSQL syntax
        {% endif %}
    FROM inpatient_patient_journey
),
er_inp_claims AS (
    -- Step 1: Group by patient, date, AND type. 
    -- This keeps ER and INPATIENT separate even if they happen on the same day.
    SELECT 
        maskedcardno,
        subsequent_admissiondate,
        MAX(subsequent_dischargedate) AS subsequent_dischargedate,
        subsequent_loatype
    FROM subsequent_details
    WHERE subsequent_loatype IN ('EMERGENCY', 'INPATIENT')
    GROUP BY 1, 2, 4
),
er_patient_journey AS (
    -- Step 2: Now LEAD() can see the Inpatient row following an ER row
    SELECT 
        *,
        LEAD(subsequent_loatype) OVER (
            PARTITION BY maskedcardno 
            ORDER BY subsequent_admissiondate, subsequent_loatype DESC -- ER usually comes before INPATIENT alphabetically
        ) AS next_loatype,
        LEAD(subsequent_admissiondate) OVER (
            PARTITION BY maskedcardno 
            ORDER BY subsequent_admissiondate, subsequent_loatype DESC
        ) AS next_admissiondate
    FROM er_inp_claims
),
panic_logic AS (
    -- Step 3: Check the gap
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
            ) THEN 0 -- This is a VALID admission (NOT panic)
            
            WHEN subsequent_loatype = 'EMERGENCY' THEN 1 -- Everything else is Panic
            ELSE 0 
        END AS is_panic_visit
    FROM er_patient_journey
),
merged_table AS (
    SELECT
        fc.maskedcardno,
        bl.cardno AS bl_cardno,
        fc.starting_claimno,
        fc.starting_admissiondate,
        fc.starting_dischargedate,
        fc.starting_physiciancode,
        fc.starting_primaryicdgroup,
        CASE
            WHEN fc.starting_primaryicdgroup IN ('NON-INSULIN-DEPENDENT DIABETES MELLITUS','INSULIN-DEPENDENT DIABETES MELLITUS', 'UNSPECIFIED DIABETES MELLITUS') THEN 'DIABETES MELLITUS'
            ELSE fc.starting_primaryicdgroup
        END AS combined_starting_primaryicdgroup,
        -- fc.starting_primaryicdgroup,
        
        fc.starting_primaryicdcode,
        fc.starting_primaryicddesc,
        fc.starting_providername,
        fc.starting_physiciancode || ' - ' || fc.starting_providername AS physician_providername,
        fc.starting_loatype,
        fc.starting_coverage,
        fc.starting_bill,
        fc.starting_approved,
        fc.starting_philhealth,
        s.claim_sequence,
        s.subsequent_claimno,
        s.subsequent_admissiondate,

        CASE 
            WHEN s.subsequent_loatype = 'EMERGENCY' THEN pl.is_panic_visit ELSE NULL
        END AS is_panic_visit,

        rl.next_admissiondate,
        rl.next_stay_is_cardiometabolic,
        rl.days_to_readmit,
        
        s.subsequent_dischargedate,
        s.subsequent_lengthofstay,
        s.subsequent_physiciancodes,
        s.subsequent_primary_physiciancode_by_rank,
        s.subsequent_primary_physiciancode_by_approved_amount,
        s.subsequent_primaryicdgroup,
        s.subsequent_primaryicdcode,
        CASE 
            WHEN UPPER(TRIM(s.subsequent_primaryicdcode)) IN (SELECT UPPER(TRIM(icdcode)) FROM {{ref('blp_icdcodes_v2')}}) THEN 'Y'
            ELSE 'N'
        END AS is_bestlife_icd,
        s.subsequent_primaryicddesc,
        s.subsequent_providername,
        s.subsequent_loatype,
        s.subsequent_coverage,
        s.subsequent_bill,
        s.subsequent_approved,
        s.subsequent_philhealth,
        
        -- cpt code & ruv codes

        s.subsequent_count_of_cptcode,
        s.subsequent_sum_of_util_cptcode,
        s.subsequent_count_of_ruvcode,
        s.subsequent_sum_of_util_ruvcode,
        s.subsequent_cptcodes,
        s.subsequent_ruvcodes
         
    FROM
        first_claim_details fc
    INNER JOIN
        subsequent_details s ON fc.maskedcardno = s.maskedcardno
    LEFT JOIN
        {{ref('bl_unmaskedcardno')}} bl ON bl.maskedcardno = fc.maskedcardno
    LEFT JOIN 
        readmission_logic rl ON rl.maskedcardno = fc.maskedcardno AND rl.subsequent_admissiondate = s.subsequent_admissiondate
    LEFT JOIN 
        panic_logic pl ON pl.maskedcardno = fc.maskedcardno AND pl.subsequent_admissiondate = s.subsequent_admissiondate AND pl.subsequent_loatype = s.subsequent_loatype

    ORDER BY
        fc.maskedcardno,
        s.claim_sequence
)
SELECT * FROM merged_table