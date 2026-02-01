
SELECT
    og.maskedcardno,
    og.subsequent_claimno
FROM
    public.mlv_px_level_v4 og  -- Specify schema for external table
LEFT JOIN
    {{ ref('combined') }} new
ON
    og.maskedcardno = new.maskedcardno
AND
    og.subsequent_claimno = new.subsequent_claimno
WHERE 
    -- If 'new' columns are null, it means the record exists in OG but not in Combined
    new.subsequent_claimno IS NULL
    OR new.maskedcardno IS NULL