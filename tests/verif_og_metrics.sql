SELECT
    og.maskedcardno,
    og.subsequent_claimno,
    og.starting_physiciancode AS og_physiciancode,
    new.starting_physiciancode AS new_physiciancode,
    og.starting_approved AS og_approved,
    new.starting_approved AS new_approved,
    og.starting_bill AS og_bill,
    new.starting_bill AS new_bill,
    og.starting_philhealth AS og_philhealth,
    new.starting_philhealth AS new_philhealth
FROM
    public.mlv_px_level_v4 AS og  -- Added schema name
LEFT JOIN
    {{ ref('mlv') }} AS new
ON
    og.maskedcardno = new.maskedcardno
    AND og.subsequent_claimno = new.subsequent_claimno
WHERE
    -- Row missing in new table
    new.subsequent_claimno IS NULL
    OR new.maskedcardno IS NULL
    -- Or mismatch in starting_physiciancode (handling potential NULLs)
    OR og.starting_physiciancode IS DISTINCT FROM new.starting_physiciancode
    -- Or mismatch in numeric columns
    OR ROUND(og.starting_approved::numeric, 2) != ROUND(new.starting_approved::numeric, 2)
    OR ROUND(og.starting_bill::numeric, 2) != ROUND(new.starting_bill::numeric, 2)
    OR ROUND(og.starting_philhealth::numeric, 2) != ROUND(new.starting_philhealth::numeric, 2)