
-- Use the `ref` function to select from other models

select * from {{ ref('blp_icdcodes_v2') }}
