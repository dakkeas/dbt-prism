

SELECT
    md1.physiciancode
FROM
    {{ ref('md_scorecard_t500') }} md1
JOIN
    {{ ref('t500_md') }} md2
    ON md1.physiciancode = md2.physiciancode
    AND
    md1.providercode = md2.providercode
WHERE
    -- 1. General Counts (Integers do not need casting or rounding)
    COALESCE(md1.total_unique_patient_cnt, 0) != COALESCE(md2.total_unique_patient_cnt, 0)
    OR COALESCE(md1.total_claim_count, 0) != COALESCE(md2.total_claim_count, 0)

    -- 2. General Sums/Averages (Cast to ::numeric before rounding)
    -- OR ROUND(COALESCE(md1.all_claims_sum_of_util, 0)::numeric, 2) != ROUND(COALESCE(md2.all_claims_sum_of_util, 0)::numeric, 2)
    -- OR ROUND(COALESCE(md1.ave_12_month_util_per_patient, 0)::numeric, 2) != ROUND(COALESCE(md2.ave_12_month_util_per_patient, 0)::numeric, 2)

    -- -- 3. OPL Metrics
    -- OR COALESCE(md1.opl_unique_px_cnt_at_least_one, 0) != COALESCE(md2.opl_unique_px_cnt_at_least_one, 0) -- Int
    -- OR ROUND(COALESCE(md1.opl_unique_px_count_at_least_one_pct, 0)::numeric, 2) != ROUND(COALESCE(md2.opl_unique_px_count_at_least_one_pct, 0)::numeric, 2)
    -- OR ROUND(COALESCE(md1.opl_ave_claims_per_px_at_least_one, 0)::numeric, 2) != ROUND(COALESCE(md2.opl_ave_claims_per_px_at_least_one, 0)::numeric, 2)
    -- OR COALESCE(md1.opl_total_claims, 0) != COALESCE(md2.opl_total_claims, 0) -- Int
    -- OR ROUND(COALESCE(md1.opl_ave_cost_per_claim_per_px_at_least_one, 0)::numeric, 2) != ROUND(COALESCE(md2.opl_ave_cost_per_claim_per_px_at_least_one, 0)::numeric, 2)
    -- OR ROUND(COALESCE(md1.opl_sum_of_util, 0)::numeric, 2) != ROUND(COALESCE(md2.opl_sum_of_util, 0)::numeric, 2)
    -- OR ROUND(COALESCE(md1.opl_ave_twelve_month_util_per_px, 0)::numeric, 2) != ROUND(COALESCE(md2.opl_ave_twelve_month_util_per_px, 0)::numeric, 2)

    -- -- 4. INP Metrics
    -- OR COALESCE(md1.inp_unique_px_count_at_least_one, 0) != COALESCE(md2.inp_unique_px_count_at_least_one, 0) -- Int
    -- OR ROUND(COALESCE(md1.inp_unique_px_count_at_least_one_pct, 0)::numeric, 2) != ROUND(COALESCE(md2.inp_unique_px_count_at_least_one_pct, 0)::numeric, 2)
    -- OR ROUND(COALESCE(md1.inp_ave_claims_per_px_at_least_one, 0)::numeric, 2) != ROUND(COALESCE(md2.inp_ave_claims_per_px_at_least_one, 0)::numeric, 2)
    -- -- OR COALESCE(md1.inp_total_claims, 0) != COALESCE(md2.inp_total_claims, 0) -- Int
    -- OR ROUND(COALESCE(md1.inp_ave_cost_per_claim_per_px_at_least_one, 0)::numeric, 2) != ROUND(COALESCE(md2.inp_ave_cost_per_claim_per_px_at_least_one, 0)::numeric, 2)
    -- OR ROUND(COALESCE(md1.inp_sum_of_util, 0)::numeric, 2) != ROUND(COALESCE(md2.inp_sum_of_util, 0)::numeric, 2)
    -- OR ROUND(COALESCE(md1.inp_ave_twelve_month_util_per_px, 0)::numeric, 2) != ROUND(COALESCE(md2.inp_ave_twelve_month_util_per_px, 0)::numeric, 2)

    -- -- 5. Others Metrics
    -- OR COALESCE(md1.others_unique_px_count_at_least_one, i0) != COALESCE(md2.others_unique_px_count_at_least_one, 0) -- Int
    -- OR ROUND(COALESCE(md1.others_unique_px_count_at_least_one_pct, 0)::numeric, 2) != ROUND(COALESCE(md2.others_unique_px_count_at_least_one_pct, 0)::numeric, 2)
    -- OR ROUND(COALESCE(md1.others_ave_claims_per_px_at_least_one, 0)::numeric, 2) != ROUND(COALESCE(md2.others_ave_claims_per_px_at_least_one, 0)::numeric, 2)
    -- OR COALESCE(md1.others_total_claims, 0) != COALESCE(md2.others_total_claims, 0) -- Int
    -- OR ROUND(COALESCE(md1.others_ave_cost_per_claim_per_px_at_least_one, 0)::numeric, 2) != ROUND(COALESCE(md2.others_ave_cost_per_claim_per_px_at_least_one, 0)::numeric, 2)
    -- OR ROUND(COALESCE(md1.others_sum_of_util, 0)::numeric, 2) != ROUND(COALESCE(md2.others_sum_of_util, 0)::numeric, 2)
    -- OR ROUND(COALESCE(md1.others_ave_twelve_month_util_per_px, 0)::numeric, 2) != ROUND(COALESCE(md2.others_ave_twelve_month_util_per_px, 0)::numeric, 2)

    -- 6. Philhealth Metrics
    OR ABS(ROUND(COALESCE(md1.total_philhealth, 0)::numeric, 2)) != ABS(ROUND(COALESCE(md2.total_philhealth, 0)::numeric, 2))
    OR ABS(ROUND(COALESCE(md1.ave_philhealth_claim, 0)::numeric, 2)) != ABS(ROUND(COALESCE(md2.ave_philhealth_claim, 0)::numeric, 2))