

{% macro icd_summary_per_provider(primaryicdgroup_list) %}
WITH t10_list AS (
    -- grabs top 10 providers in total util for specified ICD group
    SELECT
        starting_providername
        ,sum(subsequent_approved)
        
    FROM {{ref('mlv')}}

    WHERE grouped_starting_primaryicdgroup IN (
    {% for icd in primaryicdgroup_list %}
        '{{ icd }}'{% if not loop.last %}, {% endif %}
        {% endfor %}
    )

    GROUP BY 1
    ORDER BY 2 desc -- order by total util, top 10
    LIMIT 10
)
SELECT
    m.starting_providername
    ,sum(m.subsequent_approved) as total_util
    ,CAST(sum(m.subsequent_approved) AS NUMERIC) / MAX(s.total_util) as percent_of_total_util
    ,avg(m.subsequent_approved) as avg_util
    ,count(distinct m.maskedcardno) as total_patients
    ,CAST(count(distinct m.maskedcardno) AS NUMERIC) / MAX(s.total_patients) as percent_of_total_patients
    ,count(distinct m.subsequent_claimno) as total_claims
    ,CAST(count(distinct m.subsequent_claimno) AS NUMERIC) / MAX(s.total_claims) as percent_of_total_claims

    ,CAST(count(distinct m.subsequent_claimno) AS NUMERIC) / NULLIF(count(distinct m.maskedcardno), 0) as avg_claims_per_patient


        -- claims breakdown in total
    ,COALESCE(count(distinct case when m.subsequent_loatype = 'OP LAB' then m.subsequent_claimno end), 0) as total_op_lab_claims
    ,CAST(COALESCE(count(distinct case when m.subsequent_loatype = 'OP LAB' then m.subsequent_claimno end), 0) AS NUMERIC) / NULLIF(count(distinct m.subsequent_claimno), 0) as percent_of_total_op_lab_claims
    ,COALESCE(count(distinct case when m.subsequent_loatype = 'OP_CONSULT' then m.subsequent_claimno end), 0) as total_op_consult_claims
    ,CAST(COALESCE(count(distinct case when m.subsequent_loatype = 'OP_CONSULT' then m.subsequent_claimno end), 0) AS NUMERIC) / NULLIF(count(distinct m.subsequent_claimno), 0) as percent_of_total_op_consult_claims
    ,COALESCE(count(distinct case when m.subsequent_loatype = 'INPATIENT' then m.subsequent_claimno end), 0) as total_inpatient_claims
    ,CAST(COALESCE(count(distinct case when m.subsequent_loatype = 'INPATIENT' then m.subsequent_claimno end), 0) AS NUMERIC) / NULLIF(count(distinct m.subsequent_claimno), 0) as percent_of_total_inpatient_claims
    ,COALESCE(count(distinct case when m.subsequent_loatype = 'EMERGENCY' then m.subsequent_claimno end), 0) as total_emergency_claims
    ,CAST(COALESCE(count(distinct case when m.subsequent_loatype = 'EMERGENCY' then m.subsequent_claimno end), 0) AS NUMERIC) / NULLIF(count(distinct m.subsequent_claimno), 0) as percent_of_total_emergency_claims
    ,COALESCE(count(distinct case when m.subsequent_loatype = 'ACU' then m.subsequent_claimno end), 0) as total_acu_claims
    ,CAST(COALESCE(count(distinct case when m.subsequent_loatype = 'ACU' then m.subsequent_claimno end), 0) AS NUMERIC) / NULLIF(count(distinct m.subsequent_claimno), 0) as percent_of_total_acu_claims
    ,COALESCE(count(distinct case when m.subsequent_loatype = 'DENTAL' then m.subsequent_claimno end), 0) as total_dental_claims
    ,CAST(COALESCE(count(distinct case when m.subsequent_loatype = 'DENTAL' then m.subsequent_claimno end), 0) AS NUMERIC) / NULLIF(count(distinct m.subsequent_claimno), 0) as percent_of_total_dental_claims

    -- claims breakdown in avg count per patient
    ,COALESCE(CAST(count(distinct case when m.subsequent_loatype = 'OP_CONSULT' then m.subsequent_claimno end) AS NUMERIC) / NULLIF(count(distinct m.maskedcardno), 0), 0) as avg_op_consult_claims_per_patient
    ,COALESCE(CAST(count(distinct case when m.subsequent_loatype = 'OP LAB' then m.subsequent_claimno end) AS NUMERIC) / NULLIF(count(distinct m.maskedcardno), 0), 0) as avg_op_lab_claims_per_patient
    ,COALESCE(CAST(count(distinct case when m.subsequent_loatype = 'INPATIENT' then m.subsequent_claimno end) AS NUMERIC) / NULLIF(count(distinct m.maskedcardno), 0), 0) as avg_inpatient_claims_per_patient
    ,COALESCE(CAST(count(distinct case when m.subsequent_loatype = 'EMERGENCY' then m.subsequent_claimno end) AS NUMERIC) / NULLIF(count(distinct m.maskedcardno), 0), 0) as avg_emergency_claims_per_patient
    ,COALESCE(CAST(count(distinct case when m.subsequent_loatype = 'ACU' then m.subsequent_claimno end) AS NUMERIC) / NULLIF(count(distinct m.maskedcardno), 0), 0) as avg_acu_claims_per_patient
    ,COALESCE(CAST(count(distinct case when m.subsequent_loatype = 'DENTAL' then m.subsequent_claimno end) AS NUMERIC) / NULLIF(count(distinct m.maskedcardno), 0), 0) as avg_dental_claims_per_patient

    -- util breakdown in total
    ,COALESCE(sum(case when m.subsequent_loatype = 'OP LAB' then m.subsequent_approved end), 0) as total_op_lab_util
    ,CAST(COALESCE(sum(case when m.subsequent_loatype = 'OP LAB' then m.subsequent_approved end), 0) AS NUMERIC) / NULLIF(sum(m.subsequent_approved), 0) as percent_of_total_op_lab_util
    ,COALESCE(sum(case when m.subsequent_loatype = 'OP_CONSULT' then m.subsequent_approved end), 0) as total_op_consult_util
    ,CAST(COALESCE(sum(case when m.subsequent_loatype = 'OP_CONSULT' then m.subsequent_approved end), 0) AS NUMERIC) / NULLIF(sum(m.subsequent_approved), 0) as percent_of_total_op_consult_util
    ,COALESCE(sum(case when m.subsequent_loatype = 'INPATIENT' then m.subsequent_approved end), 0) as total_inpatient_util
    ,CAST(COALESCE(sum(case when m.subsequent_loatype = 'INPATIENT' then m.subsequent_approved end), 0) AS NUMERIC) / NULLIF(sum(m.subsequent_approved), 0) as percent_of_total_inpatient_util
    ,COALESCE(sum(case when m.subsequent_loatype = 'EMERGENCY' then m.subsequent_approved end), 0) as total_emergency_util
    ,CAST(COALESCE(sum(case when m.subsequent_loatype = 'EMERGENCY' then m.subsequent_approved end), 0) AS NUMERIC) / NULLIF(sum(m.subsequent_approved), 0) as percent_of_total_emergency_util
    ,COALESCE(sum(case when m.subsequent_loatype = 'ACU' then m.subsequent_approved end), 0) as total_acu_util
    ,CAST(COALESCE(sum(case when m.subsequent_loatype = 'ACU' then m.subsequent_approved end), 0) AS NUMERIC) / NULLIF(sum(m.subsequent_approved), 0) as percent_of_total_acu_util
    ,COALESCE(sum(case when m.subsequent_loatype = 'DENTAL' then m.subsequent_approved end), 0) as total_dental_util
    ,CAST(COALESCE(sum(case when m.subsequent_loatype = 'DENTAL' then m.subsequent_approved end), 0) AS NUMERIC) / NULLIF(sum(m.subsequent_approved), 0) as percent_of_total_dental_util

    -- util breakdown in avg util per patient
    ,COALESCE(CAST(sum(case when m.subsequent_loatype = 'OP_CONSULT' then m.subsequent_approved end) AS NUMERIC) / NULLIF(count(distinct m.maskedcardno), 0), 0) as avg_op_consult_util_per_patient
    ,COALESCE(CAST(sum(case when m.subsequent_loatype = 'OP LAB' then m.subsequent_approved end) AS NUMERIC) / NULLIF(count(distinct m.maskedcardno), 0), 0) as avg_op_lab_util_per_patient
    ,COALESCE(CAST(sum(case when m.subsequent_loatype = 'INPATIENT' then m.subsequent_approved end) AS NUMERIC) / NULLIF(count(distinct m.maskedcardno), 0), 0) as avg_inpatient_util_per_patient
    ,COALESCE(CAST(sum(case when m.subsequent_loatype = 'EMERGENCY' then m.subsequent_approved end) AS NUMERIC) / NULLIF(count(distinct m.maskedcardno), 0), 0) as avg_emergency_util_per_patient
    ,COALESCE(CAST(sum(case when m.subsequent_loatype = 'ACU' then m.subsequent_approved end) AS NUMERIC) / NULLIF(count(distinct m.maskedcardno), 0), 0) as avg_acu_util_per_patient
    ,COALESCE(CAST(sum(case when m.subsequent_loatype = 'DENTAL' then m.subsequent_approved end) AS NUMERIC) / NULLIF(count(distinct m.maskedcardno), 0), 0) as avg_dental_util_per_patient


FROM {{ref('mlv')}} m
LEFT JOIN {{ref('icd_summary')}} s
ON m.grouped_starting_primaryicdgroup = s.grouped_starting_primaryicdgroup
WHERE
    m.starting_providername IN (SELECT starting_providername from t10_list)
    and
    m.grouped_starting_primaryicdgroup IN (
        {% for icd in primaryicdgroup_list %}
        '{{ icd }}'{% if not loop.last %}, {% endif %}
        {% endfor %}
    
    )
GROUP BY 1

UNION ALL

SELECT
    'ALL OTHER PROVIDERS' as starting_providername
    ,sum(m.subsequent_approved) as total_util
    ,CAST(sum(m.subsequent_approved) AS NUMERIC) / MAX(s.total_util) as percent_of_total_util
    ,avg(m.subsequent_approved) as avg_util
    ,count(distinct m.maskedcardno) as total_patients
    ,CAST(count(distinct m.maskedcardno) AS NUMERIC) / MAX(s.total_patients) as percent_of_total_patients
    ,count(distinct m.subsequent_claimno) as total_claims
    ,CAST(count(distinct m.subsequent_claimno) AS NUMERIC) / MAX(s.total_claims) as percent_of_total_claims

    ,CAST(count(distinct m.subsequent_claimno) AS NUMERIC) / NULLIF(count(distinct m.maskedcardno), 0) as avg_claims_per_patient


        -- claims breakdown in total
    ,COALESCE(count(distinct case when m.subsequent_loatype = 'OP LAB' then m.subsequent_claimno end), 0) as total_op_lab_claims
    ,CAST(COALESCE(count(distinct case when m.subsequent_loatype = 'OP LAB' then m.subsequent_claimno end), 0) AS NUMERIC) / NULLIF(count(distinct m.subsequent_claimno), 0) as percent_of_total_op_lab_claims
    ,COALESCE(count(distinct case when m.subsequent_loatype = 'OP_CONSULT' then m.subsequent_claimno end), 0) as total_op_consult_claims
    ,CAST(COALESCE(count(distinct case when m.subsequent_loatype = 'OP_CONSULT' then m.subsequent_claimno end), 0) AS NUMERIC) / NULLIF(count(distinct m.subsequent_claimno), 0) as percent_of_total_op_consult_claims
    ,COALESCE(count(distinct case when m.subsequent_loatype = 'INPATIENT' then m.subsequent_claimno end), 0) as total_inpatient_claims
    ,CAST(COALESCE(count(distinct case when m.subsequent_loatype = 'INPATIENT' then m.subsequent_claimno end), 0) AS NUMERIC) / NULLIF(count(distinct m.subsequent_claimno), 0) as percent_of_total_inpatient_claims
    ,COALESCE(count(distinct case when m.subsequent_loatype = 'EMERGENCY' then m.subsequent_claimno end), 0) as total_emergency_claims
    ,CAST(COALESCE(count(distinct case when m.subsequent_loatype = 'EMERGENCY' then m.subsequent_claimno end), 0) AS NUMERIC) / NULLIF(count(distinct m.subsequent_claimno), 0) as percent_of_total_emergency_claims
    ,COALESCE(count(distinct case when m.subsequent_loatype = 'ACU' then m.subsequent_claimno end), 0) as total_acu_claims
    ,CAST(COALESCE(count(distinct case when m.subsequent_loatype = 'ACU' then m.subsequent_claimno end), 0) AS NUMERIC) / NULLIF(count(distinct m.subsequent_claimno), 0) as percent_of_total_acu_claims
    ,COALESCE(count(distinct case when m.subsequent_loatype = 'DENTAL' then m.subsequent_claimno end), 0) as total_dental_claims
    ,CAST(COALESCE(count(distinct case when m.subsequent_loatype = 'DENTAL' then m.subsequent_claimno end), 0) AS NUMERIC) / NULLIF(count(distinct m.subsequent_claimno), 0) as percent_of_total_dental_claims

    -- claims breakdown in avg count per patient
    ,COALESCE(CAST(count(distinct case when m.subsequent_loatype = 'OP_CONSULT' then m.subsequent_claimno end) AS NUMERIC) / NULLIF(count(distinct m.maskedcardno), 0), 0) as avg_op_consult_claims_per_patient
    ,COALESCE(CAST(count(distinct case when m.subsequent_loatype = 'OP LAB' then m.subsequent_claimno end) AS NUMERIC) / NULLIF(count(distinct m.maskedcardno), 0), 0) as avg_op_lab_claims_per_patient
    ,COALESCE(CAST(count(distinct case when m.subsequent_loatype = 'INPATIENT' then m.subsequent_claimno end) AS NUMERIC) / NULLIF(count(distinct m.maskedcardno), 0), 0) as avg_inpatient_claims_per_patient
    ,COALESCE(CAST(count(distinct case when m.subsequent_loatype = 'EMERGENCY' then m.subsequent_claimno end) AS NUMERIC) / NULLIF(count(distinct m.maskedcardno), 0), 0) as avg_emergency_claims_per_patient
    ,COALESCE(CAST(count(distinct case when m.subsequent_loatype = 'ACU' then m.subsequent_claimno end) AS NUMERIC) / NULLIF(count(distinct m.maskedcardno), 0), 0) as avg_acu_claims_per_patient
    ,COALESCE(CAST(count(distinct case when m.subsequent_loatype = 'DENTAL' then m.subsequent_claimno end) AS NUMERIC) / NULLIF(count(distinct m.maskedcardno), 0), 0) as avg_dental_claims_per_patient

    -- util breakdown in total
    ,COALESCE(sum(case when m.subsequent_loatype = 'OP LAB' then m.subsequent_approved end), 0) as total_op_lab_util
    ,CAST(COALESCE(sum(case when m.subsequent_loatype = 'OP LAB' then m.subsequent_approved end), 0) AS NUMERIC) / NULLIF(sum(m.subsequent_approved), 0) as percent_of_total_op_lab_util
    ,COALESCE(sum(case when m.subsequent_loatype = 'OP_CONSULT' then m.subsequent_approved end), 0) as total_op_consult_util
    ,CAST(COALESCE(sum(case when m.subsequent_loatype = 'OP_CONSULT' then m.subsequent_approved end), 0) AS NUMERIC) / NULLIF(sum(m.subsequent_approved), 0) as percent_of_total_op_consult_util
    ,COALESCE(sum(case when m.subsequent_loatype = 'INPATIENT' then m.subsequent_approved end), 0) as total_inpatient_util
    ,CAST(COALESCE(sum(case when m.subsequent_loatype = 'INPATIENT' then m.subsequent_approved end), 0) AS NUMERIC) / NULLIF(sum(m.subsequent_approved), 0) as percent_of_total_inpatient_util
    ,COALESCE(sum(case when m.subsequent_loatype = 'EMERGENCY' then m.subsequent_approved end), 0) as total_emergency_util
    ,CAST(COALESCE(sum(case when m.subsequent_loatype = 'EMERGENCY' then m.subsequent_approved end), 0) AS NUMERIC) / NULLIF(sum(m.subsequent_approved), 0) as percent_of_total_emergency_util
    ,COALESCE(sum(case when m.subsequent_loatype = 'ACU' then m.subsequent_approved end), 0) as total_acu_util
    ,CAST(COALESCE(sum(case when m.subsequent_loatype = 'ACU' then m.subsequent_approved end), 0) AS NUMERIC) / NULLIF(sum(m.subsequent_approved), 0) as percent_of_total_acu_util
    ,COALESCE(sum(case when m.subsequent_loatype = 'DENTAL' then m.subsequent_approved end), 0) as total_dental_util
    ,CAST(COALESCE(sum(case when m.subsequent_loatype = 'DENTAL' then m.subsequent_approved end), 0) AS NUMERIC) / NULLIF(sum(m.subsequent_approved), 0) as percent_of_total_dental_util

    -- util breakdown in avg util per patient
    ,COALESCE(CAST(sum(case when m.subsequent_loatype = 'OP_CONSULT' then m.subsequent_approved end) AS NUMERIC) / NULLIF(count(distinct m.maskedcardno), 0), 0) as avg_op_consult_util_per_patient
    ,COALESCE(CAST(sum(case when m.subsequent_loatype = 'OP LAB' then m.subsequent_approved end) AS NUMERIC) / NULLIF(count(distinct m.maskedcardno), 0), 0) as avg_op_lab_util_per_patient
    ,COALESCE(CAST(sum(case when m.subsequent_loatype = 'INPATIENT' then m.subsequent_approved end) AS NUMERIC) / NULLIF(count(distinct m.maskedcardno), 0), 0) as avg_inpatient_util_per_patient
    ,COALESCE(CAST(sum(case when m.subsequent_loatype = 'EMERGENCY' then m.subsequent_approved end) AS NUMERIC) / NULLIF(count(distinct m.maskedcardno), 0), 0) as avg_emergency_util_per_patient
    ,COALESCE(CAST(sum(case when m.subsequent_loatype = 'ACU' then m.subsequent_approved end) AS NUMERIC) / NULLIF(count(distinct m.maskedcardno), 0), 0) as avg_acu_util_per_patient
    ,COALESCE(CAST(sum(case when m.subsequent_loatype = 'DENTAL' then m.subsequent_approved end) AS NUMERIC) / NULLIF(count(distinct m.maskedcardno), 0), 0) as avg_dental_util_per_patient


FROM {{ref('mlv')}} m
LEFT JOIN {{ref('icd_summary')}} s
ON m.grouped_starting_primaryicdgroup = s.grouped_starting_primaryicdgroup

WHERE
    m.starting_providername NOT IN (SELECT starting_providername from t10_list)
    and
    m.grouped_starting_primaryicdgroup IN (
        {% for icd in primaryicdgroup_list %}
        '{{ icd }}'{% if not loop.last %}, {% endif %}
        {% endfor %}
    
    )

ORDER BY total_util desc

{% endmacro %}