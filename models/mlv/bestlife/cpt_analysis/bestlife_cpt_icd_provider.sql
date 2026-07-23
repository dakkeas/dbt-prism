{{ config(materialized = 'table') }}

with bestlife_clean as (
    select
        concat(
            upper(trim(cptdesc)), '-',
            icdcode, '-',
            upper(trim(providername))
        ) as cpt_icd_provider,

        upper(trim(providername)) as providername_clean,
        providername,

        cptdesc as cpt,
        upper(
            trim(
                {% if target.type == 'bigquery' %}
                regexp_replace(
                    replace(
                        replace(cptdesc, chr(160), ' '),
                        '·',
                        ' '
                    ),
                    r'\s+',
                    ' '
                )
                {% else %}
                regexp_replace(
                    replace(
                        replace(cptdesc, chr(160), ' '),
                        '·',
                        ' '
                    ),
                    '\s+',
                    ' ',
                    'g'
                )
                {% endif %}
            )
        ) as cpt_cleaned,
        icdcode as icd,
        max(icddesc) as icddesc,
        max(icdgroup) as icdgroup,
        max(primaryicdcode) as primaryicdcode,
        max(primaryicddesc) as primaryicddesc,
        max(primaryicdgroup) as primaryicdgroup,
        string_agg(distinct loatype, ', ' order by loatype) as loatype_list,
        string_agg(distinct member_type, ', ' order by member_type) as member_type_list,
        string_agg(distinct final_company, ', ' order by final_company) as final_company_list,
        min(source_year) as min_source_year,
        max(source_year) as max_source_year,

        sum(approved) as total_utilization,
        sum(billed) as total_billed,
        count(*) as lineitem_count,
        count(distinct claimno) as unique_claim_count,
        count(distinct maskedcardno) as unique_member_count,
        count(distinct final_patient_code) as unique_patient_code_count,
        count(distinct physicianname) as unique_doctor_count,

        round(cast(sum(approved) as numeric) / nullif(count(*), 0), 2) as average_cost_per_lineitem,
        round(cast(sum(approved) as numeric) / nullif(count(distinct claimno), 0), 2) as average_cost_per_claim,
        round(cast(sum(approved) as numeric) / nullif(count(distinct maskedcardno), 0), 2) as average_cost_per_member

    from {{ ref('bestlife_mxc_claims_2225') }} as base

    where icdcode is not null
      and icdcode not in (' ', '0', '')
      and cptdesc is not null
      and cptdesc not in (' ', '0', '')
      and providername is not null
      and providername not in (' ', '0', '')
    group by
        base.cptdesc,
        base.icdcode,
        base.providername
),

pcc_clean as (
    select distinct
        trim(upper(pccbranchname)) as pccbranchname
    from {{ ref('pcc_availments_raw_data') }}
),

cpt_standardized as (
    select distinct
        upper(
            trim(
                {% if target.type == 'bigquery' %}
                regexp_replace(
                    replace(
                        replace(cpt_cleaned, chr(160), ' '),
                        '·',
                        ' '
                    ),
                    r'\s+',
                    ' '
                )
                {% else %}
                regexp_replace(
                    replace(
                        replace(cpt_cleaned, chr(160), ' '),
                        '·',
                        ' '
                    ),
                    '\s+',
                    ' ',
                    'g'
                )
                {% endif %}
            )
        ) as cpt_cleaned,
        test_type,
        test_classification,
        cpt_cleaned_standard
    from {{ ref('cpt_standardized') }}
)

select
    bl.cpt_icd_provider,
    bl.cpt,
    bl.cpt_cleaned,
    cs.cpt_cleaned_standard,
    cs.test_type,
    cs.test_classification,
    bl.icd,
    bl.icddesc,
    bl.icdgroup,
    bl.primaryicdcode,
    bl.primaryicddesc,
    bl.primaryicdgroup,
    bl.providername,
    case
        when pcc.pccbranchname is null then 0
        else 1
    end as is_pcc,
    bl.loatype_list,
    bl.member_type_list,
    bl.final_company_list,
    bl.min_source_year,
    bl.max_source_year,
    bl.total_utilization,
    bl.total_billed,
    bl.unique_claim_count,
    bl.lineitem_count,
    bl.unique_member_count,
    bl.unique_patient_code_count,
    bl.unique_doctor_count,
    bl.average_cost_per_lineitem,
    bl.average_cost_per_claim,
    bl.average_cost_per_member
from bestlife_clean bl
left join pcc_clean pcc
    on bl.providername_clean = pcc.pccbranchname
left join cpt_standardized cs
    on bl.cpt_cleaned = cs.cpt_cleaned
where bl.total_utilization is not null
  and bl.total_utilization <> 0
order by bl.unique_claim_count desc
