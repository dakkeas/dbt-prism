{{config(materialized='table')}}
-- selecting all end-stage icdcodes

SELECT DISTINCT 
    primaryicdcode
    ,primaryicddesc
    ,primaryicdgroup 
FROM raw_claims_2023_2025 -- Replace with your actual table name
WHERE 
    -- Filtering to only include rows that match the codes above
    primaryicdcode LIKE 'I63%' OR 
    primaryicdcode LIKE 'I21%' OR primaryicdcode LIKE 'I22%' OR
    primaryicdcode LIKE 'I73%' OR primaryicdcode LIKE 'I702%' OR
    primaryicdcode LIKE 'I674%' OR
    primaryicdcode LIKE 'E103%' OR primaryicdcode LIKE 'E113%' OR
    primaryicdcode LIKE 'E110%' OR
    primaryicdcode LIKE 'E101%' OR primaryicdcode LIKE 'E111%' OR
    primaryicdcode LIKE 'E1062%' OR primaryicdcode LIKE 'E1162%' OR
    primaryicdcode LIKE 'I25%' OR
    primaryicdcode LIKE 'I11%' OR
    primaryicdcode LIKE 'I50%' OR
    primaryicdcode LIKE 'N18%'
union all
select DISTINCT
	r.primaryicdcode
	,r.primaryicddesc
	,r.primaryicdgroup
from raw_claims_2023_2025 r
left join {{ref('blp_icdcodes_v2')}} b on r.primaryicdcode = b.icdcode

where r.primaryicdgroup in ('CHRONIC ISCHAEMIC HEART DISEASE', 
                'HYPERTENSIVE HEART DISEASE', 
                'HEART FAILURE', 
                'CHRONIC RENAL FAILURE')
and b.icdcode is not null




