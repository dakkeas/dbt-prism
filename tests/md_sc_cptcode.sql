-- testing whether md scorecard has the correct number of cpt code or total util




SELECT
    md.physician_providername,
    md.total_overall_cptcode_count,
    md.total_overall_ruvcode_count,
    md.total_overall_cptcode_util,
    md.total_overall_ruvcode_util,
    t.count_of_ruvcode,
    t.count_of_cptcode,
    t.util_of_cptcode,
    t.util_of_ruvcode 

FROM {{ref('md_scorecard_t500_eph')}} md
INNER JOIN (
    SELECT
        mlv.physician_providername,
        SUM(CASE 
            WHEN NULLIF(rc.cptcode, '') IS NOT NULL THEN 1
            ELSE 0
        END) count_of_cptcode,
        SUM(CASE 
            WHEN NULLIF(rc.ruvcode, '') IS NOT NULL THEN 1
            ELSE 0
        END) count_of_ruvcode,
        SUM(CASE 
            WHEN NULLIF(rc.cptcode, '') IS NOT NULL THEN rc.approved
            ELSE 0
        END) util_of_cptcode,
        SUM(CASE 
            WHEN NULLIF(rc.ruvcode, '') IS NOT NULL THEN rc.approved
            ELSE 0
        END) util_of_ruvcode
    FROM {{ref('mlv')}} mlv
    INNER JOIN raw_claims_2023_2025 rc
    ON mlv.subsequent_claimno = rc.claimno
    WHERE mlv.starting_primaryicdgroup = 'ESSENTIAL (PRIMARY) HYPERTENSION'
    GROUP BY 1
) t
ON t.physician_providername =  md.physician_providername
WHERE ROUND(t.count_of_cptcode::numeric, 1) <> ROUND(md.total_overall_cptcode_count::numeric, 1)
   OR ROUND(t.count_of_ruvcode::numeric, 1) <> ROUND(md.total_overall_ruvcode_count::numeric, 1)
   OR ROUND(t.util_of_cptcode::numeric, 1) <> ROUND(md.total_overall_cptcode_util::numeric, 1)
   OR ROUND(t.util_of_ruvcode::numeric, 1) <> ROUND(md.total_overall_ruvcode_util::numeric, 1)

