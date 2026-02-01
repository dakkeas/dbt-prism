
SELECT
    c.subsequent_claimno,
    c.subsequent_primary_physiciancode_by_rank,
    p.subsequent_primary_physiciancode_by_rank AS expected_rank_code
FROM {{ ref('combined') }} AS c
LEFT JOIN {{ ref('prim_doctor') }} AS p
  ON c.subsequent_claimno = p.subsequent_claimno
WHERE
    -- Use IS DISTINCT FROM to catch mismatches even if one side is NULL
    c.subsequent_primary_physiciancode_by_rank IS DISTINCT FROM p.subsequent_primary_physiciancode_by_rank
    OR 
    c.subsequent_primary_physiciancode_by_approved_amount IS DISTINCT FROM p.subsequent_primary_physiciancode_by_approved_amount