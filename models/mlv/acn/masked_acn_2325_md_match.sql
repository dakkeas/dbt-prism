{{config(materialized = 'table')}}



SELECT raw.*, md.formatted_physicianname, md.final_score FROM
{{source('masked_acn_consolidated_raw_data', 'updated_masked_acn_consolidated_raw_data_fy2324_fy2425')}} raw
LEFT JOIN
{{source('md_fuzzy_from_physicianinfo','physician_name_matching_results')}} md
ON raw.physicianname = md.broken_physicianname_original
AND md.final_score >= 65