
-- VETTING VERSION: Uses vetting_prim_physician instead of prim_physician
-- Purpose: to check dataset integrity

SELECT
    c.subsequent_claimno,
    c.subsequent_primary_physiciancode_by_rank,
    p.subsequent_primary_physiciancode_by_rank AS expected_rank_code
FROM {{ ref('vetting_mlv') }} AS c
LEFT JOIN {{ ref('vetting_prim_physician') }} AS p
  ON c.subsequent_claimno = p.subsequent_claimno
WHERE
    -- Use IS DISTINCT FROM to catch mismatches even if one side is NULL
    c.subsequent_primary_physiciancode_by_rank IS DISTINCT FROM p.subsequent_primary_physiciancode_by_rank
    OR 
    c.subsequent_primary_physiciancode_by_approved_amount IS DISTINCT FROM p.subsequent_primary_physiciancode_by_approved_amount
