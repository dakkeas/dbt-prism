{{ config(materialized = 'table')}}

WITH eph_mlv AS (
    SELECT
        c.*
    FROM {{ref('mlv')}} c
    WHERE
        c.starting_primaryicdgroup = 'ESSENTIAL (PRIMARY) HYPERTENSION'
)
SELECT
    CASE
        WHEN cb.claimno IS NOT NULL THEN 'TRUE'
        ELSE 'FALSE'
    END AS has_bills,
    mlv.*
FROM eph_mlv mlv
LEFT JOIN {{ref("claims_with_bills")}} cb
ON mlv.subsequent_claimno = cb.claimno