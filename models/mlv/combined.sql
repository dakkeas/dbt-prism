
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
                WHEN rc.coverageitemdesc = 'PHILHEALTH' THEN rc.approved
                ELSE 0 END
        ) AS starting_philhealth
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
        s.maskedcardno, 
        MIN(s.claim_sequence) AS claim_sequence,
        s.subsequent_claimno AS subsequent_claimno,
        MIN(rc.admissiondate) AS subsequent_admissiondate,
        MIN(rc.dischargedate) AS subsequent_dischargedate,
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
        SUM(CASE WHEN rc.coverageitemdesc = 'PHILHEALTH' THEN rc.approved ELSE 0 END) AS subsequent_philhealth
    FROM
        {{ref('subsequent_claims')}} s
    INNER JOIN
        raw_claims_2023_2025 rc ON s.subsequent_claimno = rc.claimno
    LEFT JOIN
        {{ref('prim_doctor')}} pd ON s.subsequent_claimno = pd.subsequent_claimno
    GROUP BY
        s.maskedcardno, 
        s.subsequent_claimno
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
        fc.starting_primaryicdcode,
        fc.starting_primaryicddesc,
        fc.starting_providername,
        fc.starting_loatype,
        fc.starting_coverage,
        fc.starting_bill,
        fc.starting_approved,
        fc.starting_philhealth,
        s.claim_sequence,
        s.subsequent_claimno,
        s.subsequent_admissiondate,
        s.subsequent_dischargedate,
        s.subsequent_physiciancodes,
        s.subsequent_primary_physiciancode_by_rank,
        s.subsequent_primary_physiciancode_by_approved_amount,
        s.subsequent_primaryicdgroup,
        s.subsequent_primaryicdcode,
        CASE 
            WHEN UPPER(TRIM(s.subsequent_primaryicdcode)) IN (SELECT UPPER(TRIM(icdcode)) FROM blp_icdcodes_v2) THEN 'Y'
            ELSE 'N'
        END AS is_bestlife_icd,
        s.subsequent_primaryicddesc,
        s.subsequent_providername,
        s.subsequent_loatype,
        s.subsequent_coverage,
        s.subsequent_bill,
        s.subsequent_approved,
        s.subsequent_philhealth
    FROM
        first_claim_details fc
    INNER JOIN
        subsequent_details s ON fc.maskedcardno = s.maskedcardno
    LEFT JOIN
        {{ref('bl_unmaskedcardno')}} bl ON bl.maskedcardno = fc.maskedcardno
    ORDER BY
        fc.maskedcardno,
        s.claim_sequence
)
SELECT * FROM merged_table