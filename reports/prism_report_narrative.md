# PRISM Report

## Executive Summary

PRISM is a claims intelligence framework designed to translate raw healthcare utilization data into physician-, provider-, disease-, and program-level insights. The framework brings together MXC claims history, BestLife program membership data, physician reference data, provider metadata, diagnosis groupings, procedure information, PhilHealth components, professional fee components, and longitudinal patient journey logic. Its purpose is to support more consistent measurement of healthcare utilization, identify drivers of cost and care intensity, and provide a repeatable basis for physician and provider scorecards.

This report summarizes the current analytical structure of PRISM and explains how its scorecards should be interpreted. The core reporting logic is built around patient attribution, first-consult identification, subsequent claims tracking, utilization rollups, claim type classification, year-over-year comparison, and disease-specific filtering. The framework does not treat a claim as an isolated transaction only. Instead, it follows the patient through a claims journey and uses that journey to understand how physicians, providers, and disease cohorts are associated with downstream utilization.

The report is intended to accompany dashboards, tables, and extracts that contain the actual counts, rankings, and utilization values. The narrative sections below are written so data tables can be inserted under each topic without changing the structure of the report. Where figures are required, placeholders may be replaced with actual values from the corresponding PRISM marts.

At a strategic level, PRISM helps answer four major questions. First, which disease cohorts represent the most meaningful concentration of medical utilization? Second, which providers and physicians are associated with higher patient volume, higher total utilization, or higher per-patient cost? Third, how do care patterns differ across outpatient lab, inpatient, and other claim categories? Fourth, how do physician rankings and utilization patterns change between 2024 and 2025?

The disease-specific scorecards focus on chronic renal failure, diabetes mellitus, essential primary hypertension, and dyslipidaemias. These conditions were selected because they are high-relevance cardiometabolic cohorts, are frequently represented in longitudinal utilization patterns, and can be evaluated through both cost and clinical outcome indicators. The BestLife analysis is presented separately because its attribution logic relies on program enrollment and baseline test dates, allowing before-versus-after comparisons around a defined intervention point.

Overall, PRISM should be read as a measurement and prioritization tool. It does not, by itself, determine clinical appropriateness or physician performance in isolation. Instead, it provides structured evidence that can support deeper review, provider engagement, care management planning, and targeted analysis of high-cost or high-risk patient groups.

## Chapter 1: Background & Strategic Context

### 1.1 The PRISM Initiative

PRISM was developed to create a more reliable view of healthcare utilization across member populations, providers, physicians, and disease cohorts. Healthcare claims data is often broad, noisy, and transaction-heavy. A single patient journey may appear across many claim rows, multiple claim types, repeated provider encounters, multiple physicians, procedure line items, PhilHealth offsets, and professional fee components. PRISM addresses this by standardizing claims into analytical layers that can be reviewed at patient, claim, physician, provider, disease, and program levels.

The initiative is built around the idea that utilization should be interpreted in context. A high-cost physician or provider may be serving a more complex patient mix. A high inpatient share may reflect severity, access issues, delayed intervention, referral pattern, or care coordination gaps. A rising year-over-year rank may reflect volume growth, changes in case mix, or increased concentration of members under a provider. PRISM structures the data so these possibilities can be investigated instead of collapsed into a single unqualified number.

PRISM also supports repeatability. Once raw claims are standardized and the patient journey logic is defined, the same scorecard methodology can be applied across multiple disease groups. This allows chronic renal failure, diabetes mellitus, essential primary hypertension, and dyslipidaemias to be assessed using consistent metric definitions while still preserving disease-specific filters. The same framework can also be extended to additional cohorts if new ICD groupings or program definitions are added.

The initiative is especially useful for three types of decision-making. For management, PRISM identifies where utilization is concentrated and where further review may have the greatest impact. For network and provider strategy, it highlights providers and physicians with meaningful patient volume, high utilization intensity, or notable year-over-year shifts. For clinical and care management teams, it surfaces patient journey indicators such as readmissions, cardiometabolic readmissions, emergency visits, and potential panic visits.

### 1.2 Report Scope & Coverage Period

This report covers the PRISM claims architecture and the current scorecard framework. The claims foundation includes MXC claims tables from 2019 through 2025, with the main disease and MLV scoring logic focused on recent patient journeys beginning in 2023 and the year-over-year physician comparison focused on 2024 and 2025. The BestLife program analysis uses MXC claims from 2022 through 2025 for the matched BestLife population, with a separate before-versus-after design based on each patient's baseline test or enrollment date.

The report is descriptive rather than numerical. It explains what each section measures, how cohorts are constructed, how metrics should be interpreted, and where tables or charts should be inserted. Actual values, rankings, deltas, percentages, and utilization figures should be added from the finalized PRISM marts after data validation.

The covered analytical components include raw claims consolidation, BestLife patient matching, first-consult attribution, subsequent-claim tracking, provider rollups, physician scorecards, disease-specific scorecards, and 2024 to 2025 rank deltas. The report does not include ACN-specific reporting except where ACN is referenced as an excluded or separate data domain. For the PRISM claims source used here, only PRISM raw claims tables are in scope.

### 1.3 Target Audience

This report is intended for executive, analytics, clinical, care management, and network stakeholders who need a shared interpretation of PRISM outputs. Executives can use the report to understand overall utilization patterns and identify priority areas for intervention. Analytics teams can use it as documentation for metric definitions, attribution logic, and data architecture. Clinical and care management teams can use it to interpret disease-specific scorecards and patient journey outcomes. Network teams can use it to review provider concentration, physician segmentation, and year-over-year changes in utilization ranking.

The report assumes that readers may not be familiar with the underlying dbt models or raw claims structure. For that reason, each section explains the business meaning of the logic rather than only naming technical fields. Where relevant, the report distinguishes between claim-level indicators, patient-level indicators, physician-level indicators, provider-level indicators, and cohort-level indicators.

## Chapter 2: Data Architecture & Attribution Methodology

### 2.1 Data Sources

The PRISM framework synthesizes data from multiple master sources. These sources are transformed through dbt into standardized intermediate models and final marts. The architecture is designed to preserve raw claims detail while producing stable reporting tables for downstream analysis.

MXC Claims Data is the primary repository for inpatient, outpatient, emergency, and other claims. The raw PRISM tables are consolidated across semiannual and annual source tables into a unified `mxc_raw_claims` model. The unified model standardizes column types across years, tags each row with a source year, and allows downstream models to query one consistent claims view instead of multiple raw tables. This is the foundation for physician scorecards, provider analysis, disease cohorts, patient journeys, and BestLife utilization measurement.

The core claim fields include patient identifiers, claim numbers, admission and discharge dates, length of stay, provider identifiers, provider names, provider type, physician codes, claim type or LOA type, coverage, coverage item descriptions, ICD codes, ICD descriptions, ICD groups, CPT codes, RUV codes, billed amounts, approved amounts, PhilHealth line items, professional fee line items, and member metadata. These fields are used differently depending on reporting grain. Claim counts are usually evaluated after collapsing raw line items to claim grain, while utilization and component costs are summed from approved amounts.

BestLife Program Seed Data provides the program-specific member registry. It includes patient identifiers, card numbers, patient names or codes, activity status, company, member type, inactive tagging date, dropout date, and baseline test date. PRISM uses the BestLife seed data to identify program participants and to define enrollment timing. For before-versus-after analysis, the baseline test date acts as the anchor date for comparing pre-enrollment and post-enrollment utilization.

BestLife patient matching relies on a separate masked-card mapping. Since claims data uses masked card numbers while program seed data uses card numbers, PRISM normalizes card numbers and joins them to masked card numbers. This creates a matched BestLife population that can be connected back to MXC claims without exposing unmasked claims identifiers in the analytical models.

Physician reference data is used to enrich scorecards with physician names, specialization, sub-specialization, PCC coordinator flags, and PCC practice indicators. This enrichment allows scorecards to move beyond coded identifiers and support segmentation by role, specialty, and care setting.

Provider and PCC-related datasets add additional context around provider identity, branch availability, PCC utilization, and provider-level aggregation. These datasets are particularly useful when comparing hospital or clinic patterns, evaluating top provider breakdowns, and distinguishing physician behavior from provider setting effects.

ICD and disease reference tables define the clinical cohorts used in disease-specific scorecards. These references allow PRISM to filter patients and claims into chronic renal failure, diabetes mellitus, essential primary hypertension, dyslipidaemias, and other cardiometabolic groupings. Disease-specific scorecards depend on these definitions being maintained consistently.

### 2.2 Patient Attribution Logic

PRISM attribution begins by identifying the relevant patient cohort, then assigning the patient journey to physicians and providers using first-consult and subsequent-claim logic. This approach separates cohort entry from downstream utilization. A patient is first placed into a cohort based on a qualifying first consult or disease-relevant claim. After the patient enters the cohort, subsequent claims are tracked to evaluate utilization, care patterns, readmissions, emergency activity, and procedure use.

The first-consult logic identifies the starting claim for a patient within the relevant disease or reporting window. The starting claim captures the initial physician, provider, admission date, diagnosis group, diagnosis code, claim type, billed amount, approved amount, PhilHealth component, professional fee component, CPT codes, and RUV codes. This starting point is important because it defines the physician and provider context for the scorecard.

Subsequent claims are then attached to the patient journey after the starting claim. These subsequent claims provide the basis for measuring downstream utilization. The model captures later admission dates, discharge dates, length of stay, subsequent providers, subsequent claim types, subsequent approved amounts, subsequent PhilHealth amounts, subsequent professional fees, and procedure-related utilization. This lets PRISM evaluate what happens after the initial disease-relevant encounter.

For physician attribution, PRISM uses physician code and provider name together as the primary scorecard identity. This helps distinguish the same physician across provider contexts and avoids over-collapsing performance when a physician practices across multiple facilities. Physician reference data is joined afterward to add physician name and specialization.

For subsequent-claim physician attribution, PRISM includes logic to identify a primary physician by rank or by approved amount. This is necessary because claims may include multiple physician codes on the same claim. Ranking logic helps identify the physician most strongly associated with the claim when multiple physicians are present.

Provider attribution is handled separately through provider rollups. Provider analyses collapse raw claim rows to claim grain and then aggregate by provider name and provider code. This is useful because provider-level utilization can be driven by facility type, case mix, patient routing, geographic concentration, and the kinds of services delivered at that site.

BestLife attribution follows a different path because enrollment timing matters. PRISM first matches BestLife members to masked card numbers, collapses members to patient grain, applies eligibility checks, and defines before and after windows around the enrollment date. Claims before enrollment and claims after enrollment are then compared using aligned 12-month windows. Enrollment-day claims are treated as part of the after period.

### 2.3 Data Quality Notes

The PRISM framework includes several safeguards to reduce avoidable distortion in reporting outputs. Raw claims tables are unioned through a standardized model so that field types remain consistent across source years. Numeric fields such as approved amount, billed amount, age, and length of stay are cast into numeric types. Admission and discharge dates are cast into date types. Text fields are cast consistently so the unioned model can serve as a stable base layer.

Claim-grain aggregation is important because MXC raw data may contain multiple rows per claim due to coverage items, procedure codes, or line-item components. Provider rollups and some BestLife metrics collapse rows to claim grain before calculating claim counts and provider utilization. This avoids inflating claim counts by treating every line item as a separate claim.

Null and blank identifiers are filtered where they would break attribution. For example, BestLife matching requires valid card numbers and valid masked card numbers. Claims used in patient-level analysis require nonblank masked card numbers. Before-versus-after analysis requires usable enrollment dates.

The BestLife before-versus-after analysis applies eligibility rules to avoid incomplete comparisons. Patients must have a valid enrollment date, and inactive tagging dates are considered so that the post-enrollment observation window is not interpreted as complete when the member became inactive too early. This helps ensure that changes in utilization are not caused only by partial visibility.

Diagnosis groupings depend on the quality of ICD coding in the source claims. If ICD group values are missing, inconsistent, or miscoded, disease-specific cohort assignment may be affected. Procedure-based analysis also depends on CPT and RUV fields being populated consistently. These limitations should be acknowledged when interpreting disease scorecards.

Readmission and panic visit metrics are directional indicators. They depend on admission dates, discharge dates, claim type classification, and the ability to link events to the same masked patient. They should be interpreted as analytical signals for review, not as final clinical judgments without chart-level validation.

## Chapter 3: BestLife Patient Analysis

### 3.1 BestLife Program Overview

The BestLife analysis evaluates utilization among members who are linked to the BestLife program registry. Unlike the disease-specific scorecards, which begin from claims-based disease cohorts, BestLife begins from a program enrollment population. Members are identified through seed data, normalized card numbers, and masked card number matching. Once matched, their MXC claims can be analyzed across the available claims history.

The BestLife program data includes member status, company, member type, dropout date, inactive tagging date, and baseline test date. The baseline test date is treated as the enrollment anchor for before-versus-after measurement. This lets PRISM compare utilization during the period before BestLife enrollment with utilization during the period after enrollment.

The BestLife claims view focuses on MXC claims from 2022 through 2025 for matched BestLife patients. This allows the report to describe where BestLife members receive care, which providers account for the largest share of utilization, and how claim types are distributed across OP Lab, Inpatient, and Others.

When presenting BestLife results, it is useful to separate population description from utilization outcomes. Population description should cover the matched member base, active and inactive status, company mix, member type, and enrollment timing. Utilization outcomes should focus on claim volume, total utilization, provider concentration, average claims per member, average utilization per claim, average utilization per member, and claim-type mix.

### 3.2 Before vs. After Enrollment: Utilization Changes

The before-versus-after analysis compares matched BestLife patients across two aligned observation windows. The before period covers the 12 months prior to enrollment. The after period begins on the enrollment date and extends through the following 12 months. Enrollment-day claims are included in the after period because they are treated as part of the program-entry context.

Claims are assigned to the before or after period based on admission date. Raw claim rows are rolled to claim grain before period metrics are calculated. This prevents line-item-level duplication from overstating the number of claims. Once claims are assigned to periods, PRISM compares utilization across total claims, approved amount, billed amount, OP Lab activity, inpatient activity, and other claim categories.

The key interpretation question is whether utilization changed after enrollment and, if so, where the change occurred. A decrease in total utilization may suggest reduced cost intensity, fewer acute events, improved care coordination, or lower service use. An increase may indicate greater engagement with care, more diagnostic monitoring, delayed claims surfacing after enrollment, higher acuity among enrolled members, or legitimate early intervention. For this reason, changes should be interpreted alongside claim type mix and clinical context.

OP Lab movement is especially important for BestLife because lab monitoring may increase after program enrollment. A rise in OP Lab claims does not automatically indicate worse performance. In many cardiometabolic programs, more frequent lab monitoring may be desirable if it supports earlier detection, medication adjustment, or better disease control. The report should distinguish between rising low-cost monitoring activity and rising high-cost inpatient utilization.

Inpatient movement should be read as a stronger signal of acute care burden. Changes in inpatient claims, inpatient utilization, length of stay, and inpatient cost per member can help identify whether BestLife participants experienced fewer severe episodes after enrollment. Where inpatient utilization declines while OP Lab monitoring increases, the pattern may suggest a shift toward earlier or more preventive management. Where both inpatient and OP Lab utilization increase, further review may be needed to understand whether the cohort includes higher-risk members or whether follow-up care intensified after enrollment.

### 3.3 BestLife-Specific Clinical Metrics

BestLife-specific clinical metrics should connect utilization patterns to program goals. The available claims-based indicators can describe monitoring intensity, acute utilization, emergency activity, readmissions, provider concentration, and cardiometabolic relevance. These indicators are not replacements for lab results or chart review, but they provide practical signals that can be reviewed across the full matched population.

Clinical outcome interpretation should focus on direction and mix. If readmission indicators decline after enrollment, the report may describe a potential improvement in downstream acute care control. If panic visit indicators decline, the report may describe a possible reduction in avoidable emergency use. If OP Lab monitoring increases while acute claims decrease, the report may describe a shift toward more proactive disease management. If professional fees or procedure utilization increase, the report should explain whether the increase is concentrated in specific providers, specialties, or claim categories.

The BestLife provider breakdown adds operational context. Providers are ranked by total utilization and claim volume, with additional metrics showing average claims per member, average utilization per claim, average utilization per member, and OP Lab, Inpatient, and Others share. These breakdowns help identify whether BestLife utilization is concentrated in a small number of providers or distributed broadly across the network.

When data is inserted into this section, the narrative should highlight the most important provider concentrations, the dominant claim type category, and whether utilization appears to be driven more by member reach, claim frequency, or cost per claim. This distinction matters because a provider can rank highly due to many members, frequent low-cost encounters, fewer but expensive inpatient episodes, or a combination of these factors.

## Chapter 4: MD Scorecard Framework

### 4.1 What the MD Scorecard Measures

The MD Scorecard measures physician-associated utilization and patient journey outcomes within a defined disease cohort. It begins with patients attributed to a starting physician and provider, then aggregates the downstream claims experience for those patients. The scorecard is designed to show how many patients are associated with a physician, how much utilization occurs across those patients, how claims are distributed by service category, and how outcome-like indicators such as readmission and panic visit rates behave.

The scorecard is not a standalone clinical performance judgment. It is a structured claims-based profile. A physician with high utilization may be managing complex cases, practicing at a high-acuity provider, seeing a larger number of severe patients, or receiving referrals for advanced disease. The scorecard identifies where utilization is concentrated and where further review may be valuable.

The physician-provider combination is central to the scorecard. A physician may appear differently depending on the provider setting in which care is delivered. This is important because hospital type, location, service availability, and patient routing can influence utilization. By keeping provider context visible, PRISM supports more nuanced interpretation.

Physicians are filtered based on cohort and volume thresholds. Disease-specific scorecards use ICD group filters to identify relevant cohorts. Top provider and top physician parameters focus the output on physicians with meaningful representation. Patient volume thresholds reduce the noise that can occur when very small cohorts produce unstable averages.

### 4.2 Scorecard Metrics Defined

Patient Volume metrics describe the size and inpatient exposure of the attributed panel. Total unique patients counts distinct masked members associated with the physician-provider combination. Patients with inpatient stays count the subset of those patients who had at least one inpatient stay. These measures provide denominator context for every other scorecard metric.

Cost of Care metrics describe overall utilization. Total utilization sums approved amounts across the relevant claim journey. Average 12-month cost per patient divides total utilization by the attributed patient count, creating a normalized comparison across physicians with different panel sizes. This metric is used as the primary ranking basis in several scorecard and delta models because it reflects cost intensity at patient level.

OP Lab metrics describe outpatient laboratory reach, frequency, and cost. Patient reach shows the percentage of attributed patients with at least one OP Lab claim. Average claims per patient among users shows how often patients with OP Lab activity use that service. Average cost per claim shows unit cost intensity. Total OP Lab utilization and average OP Lab utilization per patient help distinguish broad low-cost monitoring from concentrated high-cost lab use.

Inpatient metrics describe acute or facility-based utilization. Patient reach shows how many attributed patients had an inpatient claim. Average inpatient claims per patient among users shows recurrence or repeated admissions. Average cost per inpatient claim measures claim intensity. Total inpatient utilization and average inpatient utilization per patient identify whether inpatient cost is broad across many patients or concentrated among a smaller subset.

Others metrics capture claim types outside OP Lab and Inpatient, including emergency, outpatient consult, ACU, and other categories depending on source coding. These metrics provide visibility into non-lab, non-inpatient utilization. Others should be reviewed carefully because the bucket can contain heterogeneous services. If Others is a major driver, the next layer of analysis should break it down by LOA type, coverage, provider, and diagnosis.

Clinical Outcomes metrics include readmission rate, cardiometabolic readmission rate, panic visit rate, and non-panic visit rate. Readmission rate is based on rapid inpatient returns after discharge. Cardiometabolic readmission rate applies the readmission concept to cardiometabolic-relevant stays. Panic visit logic identifies emergency visits that are not followed by a valid inpatient admission within the expected short window. These metrics help identify possible avoidable utilization or care transition issues.

Procedure Code metrics summarize CPT count, CPT utilization, RUV count, and RUV utilization. CPT and RUV metrics help distinguish general claim cost from procedure-driven cost. High CPT or RUV utilization may indicate more intensive procedures, more frequent coded services, or concentration of specific interventions.

PhilHealth and Professional Fee metrics isolate important cost components. PhilHealth metrics show total PhilHealth amounts and PhilHealth share of utilization. Professional fee metrics show total professional fees and professional fees per patient. These help explain how much of utilization comes from benefit offsets, physician fees, and other claim components.

PCC-related metrics provide additional context where available. They help identify whether physicians are connected to PCC coordination or whether patients have PCC availment costs that may relate to outpatient access and care management patterns.

### 4.3 Physician Segmentation & Scoring Context

Physician segmentation should be used to prevent misleading comparisons. Physicians can be grouped by specialization, sub-specialization, provider, PCC coordinator status, PCC practice flag, patient volume, disease cohort, and utilization rank. These segments help distinguish like-for-like comparisons from comparisons across different clinical roles.

High-volume physicians should be interpreted differently from low-volume physicians. A high-volume physician with moderate average cost per patient may represent broad panel management. A low-volume physician with high average cost per patient may reflect a small number of severe cases. Thresholds for minimum patient count help reduce this instability, but reviewers should still consider denominator size when interpreting ranks.

Provider context also matters. Physicians practicing in tertiary hospitals, high-acuity centers, or referral-heavy facilities may naturally appear with higher inpatient or procedure intensity. Conversely, physicians in primary care or outpatient-heavy settings may show higher OP Lab reach but lower inpatient cost. The scorecard supports these comparisons but should not flatten them into one universal ranking without context.

Ranking should be read as a prioritization guide. A physician's position on the scorecard indicates where utilization intensity is highest under the selected metric and cohort. It does not automatically imply overuse, underuse, or poor care. The next step after identifying high-ranking physicians is to review claim type mix, patient complexity, provider setting, disease severity, readmission indicators, procedure utilization, and year-over-year trend.

## Chapter 5: Disease-Specific Scorecards

### 5.1 Chronic Renal Failure (CRF)

The CRF scorecard focuses on patients whose claims indicate chronic renal failure or related renal disease groupings. This cohort is expected to have higher baseline complexity because renal disease often involves recurring monitoring, medication management, specialist care, possible inpatient episodes, and procedure-related utilization. Interpretation should therefore focus on utilization composition rather than total cost alone.

Top Provider Breakdown should identify providers with the greatest CRF-related utilization and claim activity. The narrative should distinguish providers with broad CRF patient reach from providers with fewer but higher-cost claims. It should also call out whether inpatient utilization dominates the provider profile or whether outpatient monitoring and other claim types account for most activity.

Claim Type Breakdown should describe the distribution across OP Lab, Inpatient, and Others. For CRF, OP Lab utilization may reflect ongoing monitoring and disease management. Inpatient utilization may indicate acute worsening, complications, dialysis-adjacent events, or comorbid conditions. Others may include consultations, emergency care, and other services that require further decomposition if they are material.

Physician Scorecard should identify physicians with high CRF patient volume, high average 12-month utilization per patient, meaningful inpatient reach, elevated readmission indicators, or concentrated procedure utilization. The report should highlight whether top-ranked physicians are driven by many patients, higher inpatient cost, higher procedure intensity, or recurring claims among a smaller patient subset.

### 5.2 Diabetes Mellitus

The Diabetes Mellitus scorecard focuses on patients with diabetes-related diagnosis groups. Diabetes is a chronic condition where monitoring, outpatient care, medication management, complication prevention, and comorbidity control are central. Because of this, a balanced interpretation should consider both monitoring activity and acute utilization.

Top Provider Breakdown should describe where diabetes-related utilization is concentrated. Providers may rank highly because they manage large diabetic populations, because they handle complications, or because they deliver frequent monitoring services. The report should separate utilization driven by OP Lab monitoring from utilization driven by inpatient admissions or emergency-related claims.

Claim Type Breakdown should emphasize the relationship between OP Lab and acute care. OP Lab claims may represent appropriate monitoring activity for glycemic control, renal function, lipid status, and other cardiometabolic risk markers. Inpatient claims may indicate complications, uncontrolled disease, comorbid events, or care escalation. Others should be reviewed for consults, emergency visits, and outpatient procedures.

Physician Scorecard should identify physicians with high diabetic patient panels, high per-patient utilization, high inpatient reach, elevated readmission or panic visit rates, and significant CPT or RUV utilization. The narrative should distinguish physicians whose scores are driven by monitoring and follow-up from physicians whose scores are driven by acute care or high-cost procedures.

### 5.3 Essential (Primary) Hypertension (EPH)

The EPH scorecard focuses on patients with essential primary hypertension. Hypertension is often managed in outpatient settings, but it is clinically important because poor control can contribute to emergency visits, inpatient admissions, cardiovascular events, renal complications, and other downstream costs.

Top Provider Breakdown should describe whether hypertension-related utilization is concentrated in primary care, outpatient, hospital, or mixed provider settings. If high-ranking providers show a large OP Lab share, the report may frame this as monitoring or follow-up activity. If inpatient share is high, the report should review whether the utilization may be linked to complications or comorbid cardiometabolic disease.

Claim Type Breakdown should separate routine monitoring from acute escalation. OP Lab and outpatient claims may reflect routine disease surveillance. Inpatient and emergency-related claims may indicate uncontrolled disease, complications, or care gaps. Because hypertension often appears with diabetes, dyslipidaemia, renal disease, or cardiovascular risk, interpretation should also acknowledge overlapping disease burden.

Physician Scorecard should identify physicians with meaningful hypertension patient volume, high average utilization per patient, high inpatient or emergency reach, and notable year-over-year movement. For hypertension, changes in panic visit or readmission indicators may be especially useful as signals of possible care coordination needs.

### 5.4 Dyslipidaemias

The Dyslipidaemias scorecard focuses on patients with lipid disorder diagnosis groups. Dyslipidaemias are often managed through outpatient monitoring, medication adherence, and cardiometabolic risk reduction. Utilization patterns may therefore look different from conditions with more direct inpatient burden.

Top Provider Breakdown should show whether dyslipidaemia-related claims are concentrated among providers with large outpatient populations or among facilities handling downstream cardiovascular or metabolic complications. Provider ranking should be interpreted alongside claim type mix because total utilization may be driven by monitoring volume, acute events, or comorbid conditions.

Claim Type Breakdown should pay close attention to OP Lab activity. Lab monitoring may be central to lipid management, so higher OP Lab reach can be clinically meaningful and not necessarily undesirable. Inpatient or emergency utilization should be reviewed for possible cardiovascular, renal, or metabolic complications.

Physician Scorecard should identify physicians with high patient reach, high monitoring intensity, elevated per-patient cost, or notable acute utilization. For physicians with high utilization, the report should explain whether the driver is broad monitoring across many patients, concentrated inpatient cost, procedure activity, or high-cost claims among a small subset.

## Chapter 6: Year-over-Year Ranking Analysis (2024 to 2025)

### 6.1 Methodology: How Ranking Deltas Are Computed

The year-over-year ranking analysis compares physician scorecard outputs between 2024 and 2025. For each disease cohort, physicians are ranked separately within each year using average 12-month utilization per patient. The 2024 rank and 2025 rank are then joined by physician code and provider name, allowing PRISM to calculate rank movement for physicians who appear in both periods.

Rank change is calculated as 2024 rank minus 2025 rank. A positive rank change means the physician moved higher in the 2025 ranking because a lower numerical rank indicates a higher position. A negative rank change means the physician moved lower in the ranking. No rank change means the physician remained in the same position relative to peers included in both years.

The delta models also calculate changes in patient count, claim count, total utilization, average utilization per patient, OP Lab utilization, inpatient utilization, Others utilization, professional fees, PhilHealth amounts, CPT utilization, readmission rate, panic visit rate, length of stay, and PCC availment cost. These deltas allow the report to explain why ranking changed rather than only reporting that it changed.

The ranking analysis includes physicians who are present in both the 2024 and 2025 scorecard outputs for the same provider context. This improves comparability but means new entrants and physicians missing from one year may need separate review. If a physician appears in 2025 but not 2024, they may represent a new provider relationship, newly eligible volume, or a cohort change. If a physician appears in 2024 but not 2025, they may have fallen below thresholds, changed provider context, or no longer had qualifying patients.

### 6.2 Ranking Shifts: All Cohorts

Ranking shifts should be interpreted by combining movement direction with the underlying deltas. A physician who rises in rank because average utilization per patient increased may require review of inpatient claims, procedure costs, readmissions, and patient acuity. A physician who rises because patient volume grew while per-patient cost remained stable may represent expanding panel responsibility rather than worsening utilization intensity.

For physicians with large positive rank movement, the report should identify whether the movement is driven by higher inpatient utilization, higher OP Lab frequency, higher Others utilization, higher professional fees, increased procedure activity, or increased readmission and panic visit indicators. These physicians are useful candidates for deeper clinical and provider-context review.

For physicians with large negative rank movement, the report should describe whether utilization decreased, patient volume changed, inpatient exposure declined, or high-cost claims normalized. Downward rank movement may reflect improved care patterns, lower acute utilization, shifts in patient mix, or movement of patients to other providers.

For stable high-ranking physicians, the report should note whether high utilization is persistent across years. Persistent high rankings may point to consistently complex panels, recurring high-cost treatment patterns, referral center behavior, or opportunities for focused care management review. Stability can be as important as movement because it indicates a durable pattern rather than a one-year anomaly.

For stable low-ranking physicians, the report should describe whether lower utilization is paired with adequate patient volume and low acute activity. These physicians may provide comparison points for practice pattern review, especially when they serve similar disease cohorts or provider contexts as higher-cost peers.

Across all cohorts, ranking deltas should be read alongside disease-specific context. CRF may naturally show higher acute and procedure burden than dyslipidaemias. Diabetes and hypertension may have stronger links to OP Lab monitoring and cardiometabolic readmissions. Dyslipidaemias may show lower acute utilization unless complicated by cardiovascular or metabolic events. The report should avoid treating all disease cohorts as identical cost environments.

## Suggested Placement for Data Inserts

Insert the executive-level summary figures after the Executive Summary. Include total members or patients covered, total claims, total utilization, top disease cohorts, top providers, and major year-over-year changes.

Insert data source coverage details after Chapter 2.1. Include source years loaded, included PRISM raw tables, excluded ACN tables, BestLife matched population counts, and validation notes.

Insert patient attribution validation after Chapter 2.2. Include first-consult counts, subsequent-claim linkage rates, blank identifier exclusions, and claim-grain reconciliation checks.

Insert BestLife charts and extracts after Chapter 3.2 and Chapter 3.3. Include before-versus-after total utilization, OP Lab, inpatient, Others, provider breakdown, and clinical indicator movement.

Insert MD Scorecard output after Chapter 4.2 and Chapter 4.3. Include physician scorecard tables, filters used, minimum patient thresholds, and explanatory notes for rank interpretation.

Insert disease-specific provider and physician tables under each Chapter 5 disease section. Use the same ordering for CRF, Diabetes Mellitus, EPH, and Dyslipidaemias so readers can compare cohorts consistently.

Insert year-over-year rank delta tables under Chapter 6.2. Include rank movement, utilization deltas, claim type deltas, and clinical outcome deltas by physician-provider combination.

## Closing Interpretation Notes

PRISM outputs should be treated as a structured claims lens. They are strongest when used to identify patterns, outliers, movement, and areas for deeper review. They should be paired with clinical judgment, provider context, patient complexity, coding quality, and operational knowledge before being used for performance conclusions.

The most useful review pattern is to move from broad to specific: start with disease cohort and provider concentration, then review physician ranking, then inspect claim type mix, then evaluate patient volume and per-patient utilization, then check clinical indicators and procedure components. This layered approach prevents overreacting to any single metric and supports more balanced interpretation of the PRISM scorecards.
