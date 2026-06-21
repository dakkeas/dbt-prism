# Diabetes Physician Segmentation Guide

This guide explains the segmentation fields in `md_scorecard_t500_diabetes_production`.

The same production bucket rules are mirrored by the other production scorecards under `models/mlv/marts`.

## What the table represents

Each row represents one physician-provider attribution unit. The metrics summarize downstream 12-month utilization and cost outcomes for patients whose first qualifying consult was attributed to that physician.

In `dev`, the output columns use display-style names with spaces, such as `Physician Bucket` and `Efficiency Ratio`.

In `prod`, the output columns use compact PascalCase names, such as `PhysicianBucket` and `EfficiencyRatio`.

## Core segmentation columns

### Physician Bucket

`Physician Bucket` / `PhysicianBucket` assigns each physician-provider to a utilization archetype.

Current buckets:

- `Acute Escalator`
  Higher hospital-driven burden. Assigned when either:
  - inpatient prevalence percentile >= 75
  - inpatient cost percentile >= 75

- `Resource Intensive`
  High total cost without inpatient utilization being the main driver. Assigned when:
  - cost percentile >= 75
  - inpatient prevalence percentile < 75
  - and at least one of the following is >= 75 percentile:
    - CPT utilization per patient
    - others cost per patient
    - professional fees

- `Lab Overutilizer`
  High outpatient lab activity without high inpatient burden. Assigned when:
  - inpatient prevalence percentile <= 50
  - inpatient cost percentile <= 50
  - and at least one of the following is >= 75 percentile:
    - OP lab frequency
    - OP lab cost per patient

- `Minimalist`
  Very low observed follow-up or utilization. Assigned when:
  - cost percentile <= 25
  - OP lab prevalence percentile <= 25
  - total claims percentile <= 25

- `Balanced`
  Default bucket for physicians who do not match any of the patterns above.

### Volume Tier

`Volume Tier` / `VolumeTier` is based only on unique patient count.

- `High Volume`: unique patient count >= 30
- `Medium Volume`: unique patient count between 15 and 29
- `Low Volume`: unique patient count < 15

This is a volume descriptor only. It does not remove a physician from the analysis.

### Confidence Level

`Confidence Level` / `ConfidenceLevel` is directly derived from `Volume Tier`.

- `High Confidence` = `High Volume`
- `Medium Confidence` = `Medium Volume`
- `Low Confidence` = `Low Volume`

This is meant to help interpretation. A physician with fewer attributed patients may still show an extreme percentile or bucket, but the pattern should be read with more caution.

### Efficiency Ratio

`Efficiency Ratio` / `EfficiencyRatio` is calculated as:

```text
average_12_month_cost_per_patient / network_average_cost_per_patient
```

Where:

- `average_12_month_cost_per_patient` is the physician's own average 12-month cost of care per attributed patient
- `network_average_cost_per_patient` comes from `md_scorecard_network_average_by_primaryicdgroup`
- the network value is calculated across all physician-provider rows for the same primary ICD group, not only the top 500 rows shown in the production scorecard

Interpretation:

- `1.00` means the physician is exactly at the network average
- `> 1.00` means higher than network average cost per patient
- `< 1.00` means lower than network average cost per patient

## Percentiles used in the model

The segmentation uses peer percentiles calculated across the full physician set in the table, including low-volume physicians.

Relevant percentile columns:

- `Cost Percentile` / `CostPercentile`
- `Inpatient Prevalence Percentile` / `InpatientPrevalencePercentile`
- `Inpatient Cost Percentile` / `InpatientCostPercentile`
- `OP Lab Prevalence Percentile` / `OpLabPrevalencePercentile`
- `OP Lab Frequency Percentile` / `OpLabFrequencyPercentile`
- `OP Lab Cost Percentile` / `OpLabCostPercentile`
- `CPT Utilization Percentile` / `CptUtilizationPercentile`
- `Others Cost Percentile` / `OthersCostPercentile`
- `Professional Fee Percentile` / `ProfessionalFeePercentile`
- `Total Claims Percentile` / `TotalClaimsPercentile`

These are `PERCENT_RANK()`-based values scaled to 0-100 and rounded to two decimals.

## Low-volume handling

The model still includes a `Low Volume Flag` / `LowVolumeFlag`.

- `TRUE` when unique patient count < 15
- `FALSE` otherwise

This flag is informational only. Low-volume physicians are still included in:

- network average calculation
- percentile calculation
- bucket assignment

## How to navigate and filter the table

Use the identity fields first:

- `Physician Name` / `PhysicianName`
- `Physician Code` / `PhysicianCode`
- `Provider Code` / `ProviderCode`
- `Physician Provider` / `PhysicianProviderCode`
- `Sub Specialization` / `SubSpecialization`

Common filter patterns:

- To inspect one physician:
  Filter on `Physician Code` or `Physician Name`

- To review a physician across provider groupings:
  Filter on `Physician Name`, then compare `Provider Code`

- To isolate likely stable patterns:
  Filter `Confidence Level = High Confidence`

- To find outlier cost physicians:
  Sort descending by `Efficiency Ratio` or filter `Cost Percentile >= 75`

- To focus on hospitalization-heavy patterns:
  Filter `Physician Bucket = Acute Escalator`

- To focus on outpatient lab-heavy physicians without high inpatient burden:
  Filter `Physician Bucket = Lab Overutilizer`

- To find low-touch or leakage-risk patterns:
  Filter `Physician Bucket = Minimalist`

- To review complex outpatient-heavy physicians:
  Filter `Physician Bucket = Resource Intensive`

## How to read bucket summary columns

The table also carries bucket-level summary metrics on every row for convenience. These start with:

- `Physician Count By Bucket` / `PhysicianCountByBucket`
- `Bucket Average ...`
- `Bucket Minimum ...`
- `Bucket Maximum ...`

These are repeated for every physician within the same bucket so that dashboards can compare an individual physician against their archetype-level context without requiring a separate join.
