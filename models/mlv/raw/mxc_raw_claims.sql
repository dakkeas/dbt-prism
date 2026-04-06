
{{ config(materialized='view') }}

-- Unified view of all mxc_raw_claims source tables with consistent column types.
-- Resolves UNION type mismatches (e.g. bigint vs text across tables).
-- Target types:
--   double precision: age, lengthofstay, approved, billed
--   date: admissiondate, dischargedate
--   text: all other columns

{% set tables = [
    ('prism_2019_jan_to_jun', 2019),
    ('prism_2019_july_to_dec', 2019),
    ('prism_2020_jan_to_jun', 2020),
    ('prism_2020_july_to_dec', 2020),
    ('prism_2021_jan_to_jun', 2021),
    ('prism_2021_july_to_dec', 2021),
    ('prism_2022_jan_to_jun', 2022),
    ('prism_2022_july_to_dec', 2022),
    ('prism_2023_jan_to_jun', 2023),
    ('prism_2023_july_to_dec', 2023),
    ('prism_2024_jan_to_jun', 2024),
    ('prism_2024_july_to_dec', 2024),
    ('prism_2025_jan_to_mar', 2025)
] %}

{% for table_name, year in tables %}
SELECT
    CAST(accountype AS TEXT) AS accountype,
    CAST(corpcode AS TEXT) AS corpcode,
    CAST(corpname AS TEXT) AS corpname,
    CAST(claimno AS TEXT) AS claimno,
    CAST(maskedprincipalid AS TEXT) AS maskedprincipalid,
    CAST(maskedcardno AS TEXT) AS maskedcardno,
    CAST(membertypedesc AS TEXT) AS membertypedesc,
    CAST(relationship AS TEXT) AS relationship,
    CAST(birthdate AS TEXT) AS birthdate,
    CAST(origeffectivedate AS TEXT) AS origeffectivedate,
    CAST(effectivedate AS TEXT) AS effectivedate,
    CAST(expirydate AS TEXT) AS expirydate,
    CAST(cancellationdate AS TEXT) AS cancellationdate,
    CAST(admissiondate AS DATE) AS admissiondate,
    CAST(dischargedate AS DATE) AS dischargedate,
    CAST(lengthofstay AS DOUBLE PRECISION) AS lengthofstay,
    CAST(providercode AS TEXT) AS providercode,
    CAST(providername AS TEXT) AS providername,
    CAST(providertype AS TEXT) AS providertype,
    CAST(hospitalcategory AS TEXT) AS hospitalcategory,
    CAST(region AS TEXT) AS region,
    CAST(province AS TEXT) AS province,
    CAST(citymunicipal AS TEXT) AS citymunicipal,
    CAST(physiciancode AS TEXT) AS physiciancode,
    CAST(loatype AS TEXT) AS loatype,
    CAST(coverage AS TEXT) AS coverage,
    CAST(coverageitem AS TEXT) AS coverageitem,
    CAST(coverageitemdesc AS TEXT) AS coverageitemdesc,
    CAST(benefitid AS TEXT) AS benefitid,
    CAST(benefitdesc AS TEXT) AS benefitdesc,
    CAST(ruvcode AS TEXT) AS ruvcode,
    CAST(ruvdesc AS TEXT) AS ruvdesc,
    CAST(primaryicdcode AS TEXT) AS primaryicdcode,
    CAST(primaryicddesc AS TEXT) AS primaryicddesc,
    CAST(primaryicdgroup AS TEXT) AS primaryicdgroup,
    CAST(icdcode AS TEXT) AS icdcode,
    CAST(icddesc AS TEXT) AS icddesc,
    CAST(icdgroup AS TEXT) AS icdgroup,
    CAST(receiveddate AS TEXT) AS receiveddate,
    CAST(processeddate AS TEXT) AS processeddate,
    CAST(createdate AS TEXT) AS createdate,
    CAST(loano AS TEXT) AS loano,
    CAST(loeno AS TEXT) AS loeno,
    CAST(age AS DOUBLE PRECISION) AS age,
    CAST(gender AS TEXT) AS gender,
    CAST(fundingmgnt AS TEXT) AS fundingmgnt,
    CAST(class AS TEXT) AS class,
    CAST(benefitlimit AS TEXT) AS benefitlimit,
    CAST(actualroomtype AS TEXT) AS actualroomtype,
    CAST(actualroomtypedesc AS TEXT) AS actualroomtypedesc,
    CAST(planroomtype AS TEXT) AS planroomtype,
    CAST(planroomtypedesc AS TEXT) AS planroomtypedesc,
    CAST(cptcode AS TEXT) AS cptcode,
    CAST(cptdesc AS TEXT) AS cptdesc,
    CAST("WITH SIGNED E2E CONFORME" AS TEXT) AS "WITH SIGNED E2E CONFORME",
    CAST(pwd AS TEXT) AS pwd,
    CAST(approved AS DOUBLE PRECISION) AS approved,
    CAST(billed AS DOUBLE PRECISION) AS billed,
    CAST(loaremarks AS TEXT) AS loaremarks,
    CAST(claimsremark AS TEXT) AS claimsremark,
    CAST(physicianname AS TEXT) AS physicianname,
    CAST("Source.Name" AS TEXT) AS "Source.Name",
    {{ year }} AS source_year
FROM {{ source('mxc_raw_claims', table_name) }}
{% if not loop.last %}UNION ALL{% endif %}
{% endfor %}
