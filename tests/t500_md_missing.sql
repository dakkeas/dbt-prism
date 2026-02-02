
SELECT
    md1.physiciancode,
FROM
    {{ ref('md_scorecard_t500') }} md1
LEFT JOIN
    {{ ref('t500_md') }} md2
WHERE
    md2.physiciancode IS NULL