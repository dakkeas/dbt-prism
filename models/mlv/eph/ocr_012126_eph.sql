{{config(materialized = 'table')}}


select 
    -- md.claimno,
    -- d.claimno,
    md.physician_providercode,
    d.physiciancode
from 
    dev_mlv.ocr_012126 d
left join
    dev_mlv.md_scorecard_t500 md
ON
    md.physician_providercode = d.physiciancode
WHERE md.physician_providercode IS NULL


