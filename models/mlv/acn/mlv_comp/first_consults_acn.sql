{{ config(materialized = 'table') }}

WITH raw_claims AS (

    SELECT *
    FROM {{ ref('masked_acn_2325') }}

),

first_consult AS (

    SELECT
        rc.*,

        DENSE_RANK() OVER (
            PARTITION BY rc.maskedcardno
            ORDER BY rc.admissiondate, rc.claimno
        ) AS claim_sequence

    FROM raw_claims rc

    WHERE
        TRIM(rc.loatype) = 'CONSULT'
        AND TRIM(rc.physicianname) NOT IN ('0', '0,', '')
        AND rc.physicianname IS NOT NULL

),

aggregate_starting_claim AS (

    SELECT
        rc.maskedcardno,
        t.claimno AS starting_claimno,

        MAX(rc.admissiondate) AS starting_admissiondate,

        COALESCE(
            MAX(
                CASE
                    WHEN TRIM(rc.physicianname) NOT IN ('0', '0,', '')
                    AND rc.physicianname IS NOT NULL
                    THEN rc.physicianname
                END
            )
        ) AS starting_physicianname,
        MAX(rc.physiciancode) AS starting_physiciancode,

        MAX(rc.icdcode) AS starting_icdcode,
        MAX(rc.providername) AS starting_providername,
        MAX(rc.loatype) AS starting_loatype

    FROM (
        SELECT claimno
        FROM first_consult
        WHERE claim_sequence = 1
        GROUP BY claimno
        HAVING
            COUNT(DISTINCT physicianname) = 1
    ) t
    INNER JOIN raw_claims rc
        ON t.claimno = rc.claimno
    GROUP BY
        t.claimno,
        rc.maskedcardno
)

SELECT *
FROM aggregate_starting_claim