# Scorecard Data-Flow Charts

Charts reflect current dbt model and macro dependencies. Arrows show transformation order; dashed arrows show reference/enrichment inputs.

## 1. MD scorecards — Diabetes, EPH, Dyslipidaemias

```mermaid
flowchart LR
  claims[(MXC claims\n2019–2025)] --> raw[mxc_raw_claims\nunion + type casts]
  raw --> fc[first_consults\nfirst eligible consult\nphysician/provider attribution]
  raw --> sc[subsequent_claims\n12-month journey window]
  fc --> mlv[mlv\nstarting + subsequent claim detail]
  sc --> mlv
  icd[(ICD reference seeds)] -. disease groups .-> mlv
  pcc[(PCC data)] -. patient PCC metrics .-> mlv
  cpt[(CPT / RUV fields)] -. procedure metrics .-> mlv
  mlv --> px[px_engine\npatient-level aggregation]
  physician[(physicianinfo)] -. names + specialty + PCC flags .-> agg
  px --> agg[md_scorecard macro\nphysician/provider aggregation]
  agg --> filt[Disease filter\nDIABETES / EPH / DYSLIPIDAEMIAS]
  filt --> prov[Top 20 providers\nby total utilization]
  prov --> vol[Patient threshold\n> 3 patients]
  vol --> top500[Top 500 physician-provider rows\nranked by 12-month cost/patient]
  top500 --> prod[Production scorecard\nvolume tier + confidence\npeer percentiles + network average\nphysician bucket + potential savings]
  px --> metrics[Metrics\nOP Lab / inpatient / others\nclaims + utilization\nCPT + PhilHealth + professional fees\nLOS + readmission + panic visits]
  metrics --> agg
```

## 2. CRF MD scorecard — separate path

```mermaid
flowchart LR
  raw[mxc_raw_claims] --> base[Shared MLV journey\nfirst_consults → subsequent_claims → mlv]
  base --> cohort[mlv_crf_any_starting_icd\npatient qualifies if CRF appears\nin starting OR subsequent ICD group]
  cohort --> retain[Retain all journey rows\nfull 12-month patient experience]
  retain --> crfpx[CRF patient engine\nutilization + service buckets\nCPT/RUV + PhilHealth/PF\nLOS + readmission + panic visits\npatient journey category]
  icd[(ICD references)] -. CRF + end-stage codes .-> cohort
  pcc[(PCC data)] -. PCC cost/count .-> crfpx
  physician[(physicianinfo)] -. physician enrichment .-> crfagg
  crfpx --> crfagg[Custom CRF scorecard aggregation\nprovider ranking + physician/provider metrics]
  crfagg --> crftop[Top 20 providers\npatient threshold > 3]
  crftop --> crf500[Top 500 CRF physician-provider rows]
  crf500 --> crfprod[CRF production scorecard\nvolume/confidence + percentiles\nnetwork comparison + bucket\npotential savings]
  retain --> y24[mlv_crf_y24_any_starting_icd\n→ px_engine_crf_y24]
  retain --> y25[mlv_crf_y25_any_starting_icd\n→ px_engine_crf_y25]
  y24 --> sc24[md_scorecard_t500_crf_y24]
  y25 --> sc25[md_scorecard_t500_crf_y25]
  sc24 --> delta[md_scorecard_delta_crf\njoin physician code + provider\ncalculate 2025 − 2024]
  sc25 --> delta
  delta --> shortlist[crf_physician_shortlist]
  cohort --> provider[crf_t10_provider_summary\ncustom CRF provider summary]
```

## 3. Top provider scorecards

```mermaid
flowchart LR
  raw[mxc_raw_claims] --> journey[Shared journey\nfirst_consults → subsequent_claims → mlv]
  icd[(ICD reference seeds)] -. disease filter .-> journey
  journey --> disease[Disease-specific MLV rows\nDiabetes / EPH / Dyslipidaemias / CRF]
  disease --> rank[Aggregate approved utilization\nby starting provider]
  rank --> top10[Rank descending\nselect top 10 providers]
  top10 --> topmetrics[Top-provider metrics\npatients + claims\napproved utilization\naverage utilization\nOP consult / OP Lab / inpatient\nemergency / ACU / dental]
  topmetrics --> compare[Compare against\nALL OTHER PROVIDERS]
  compare --> output[Top provider scorecard output\nshare of total patients\nshare of claims\nshare of utilization\nclaims and utilization per patient]
  disease --> crfbranch{CRF?}
  crfbranch -->|Yes| crf[crf_t10_provider_summary\ncustom CRF logic from\nmlv_crf_any_starting_icd]
  crf --> output
  crfbranch -->|No| macro[icd_summary_per_provider macro\nDiabetes / EPH / Dyslipidaemias]
  macro --> output
  shared[(icd_summary)] -. total disease denominators .-> macro
  shared -. total disease denominators .-> crf
```

## 4. Delta MD scorecards — 2024 vs 2025

```mermaid
flowchart LR
  raw[(MXC claims)] --> y24base[2024 path\nsource_year = 2024]
  raw --> y25base[2025 path\nsource_year = 2025]
  y24base --> fc24[first_consults_y24]
  y25base --> fc25[first_consults_y25]
  fc24 --> sc24[subsequent_claims_y24]
  fc25 --> sc25[subsequent_claims_y25]
  sc24 --> mlv24[mlv_y24]
  sc25 --> mlv25[mlv_y25]
  mlv24 --> px24[px_engine_y24]
  mlv25 --> px25[px_engine_y25]
  crf24[CRF override:\nmlv_crf_y24_any_starting_icd\npx_engine_crf_y24] -. CRF only .-> px24
  crf25[CRF override:\nmlv_crf_y25_any_starting_icd\npx_engine_crf_y25] -. CRF only .-> px25
  px24 --> sc24out[md_scorecard_t500_*_y24\nMD scorecard macro]
  px25 --> sc25out[md_scorecard_t500_*_y25\nMD scorecard macro]
  sc24out --> join[Join on\nphysician code + provider name]
  sc25out --> join
  join --> calc[Delta calculation\n2025 value − 2024 value]
  calc --> measures[Delta measures\npatients + claims + utilization\nOP Lab / inpatient / others\nPhilHealth + professional fees\nCPT + readmission + panic visits\nLOS + PCC]
  measures --> disease[Delta outputs\nCRF / Diabetes / EPH / Dyslipidaemias]
  disease --> shortlist[Disease physician shortlist]
  disease --> drivers[Main delta analysis\nranked change drivers]
```

## Model map

| Chart | Primary dbt models/macros |
|---|---|
| MD scorecards | `mxc_raw_claims`, `first_consults`, `subsequent_claims`, `mlv`, `px_engine`, `md_scorecard`, production scorecard models |
| CRF MD scorecard | `mlv_crf_any_starting_icd`, `px_engine_crf_y24`, `px_engine_crf_y25`, `md_scorecard_t500_crf_any_starting_icd`, CRF production model |
| Top provider scorecards | `icd_summary_per_provider`, `crf_t10_provider_summary`, disease `*_t10_provider_summary` models |
| Delta MD scorecards | year-specific `mlv`, `px_engine`, `md_scorecard_t500_*_y24`, `md_scorecard_t500_*_y25`, `md_scorecard_delta_*` |
