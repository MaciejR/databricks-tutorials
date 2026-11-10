-- E4 fallback, file 3 of 3: GOLD (updated 10 Nov 2026: median definition), five registers side by side in one table (the E4 hero).
-- Amounts stay in local currency. amount_eur is filled ONLY when ref/fx_rates.csv has a sourced rate (none shipped: [VERIFY]).

CREATE OR REFRESH MATERIALIZED VIEW gold_charities
COMMENT 'Charity Lens common schema v0: one row per organisation across GB-EAW, CA, AU, US, PL. Definitions differ by country (see is_like_for_like_note). Money in local currency; never sum across currencies.'
AS
SELECT *, CASE jurisdiction
    WHEN 'GB-EAW' THEN 'Registered charity (Charities Act 2011), England & Wales only'
    WHEN 'CA'     THEN 'Registered charity under the Income Tax Act'
    WHEN 'AU'     THEN 'Registered charity under the Charities Act 2013 (Cth)'
    WHEN 'US'     THEN '501(c)(3) exempt organisation (BMF); 990-N filers have no financials'
    WHEN 'PL'     THEN 'OPP status holder on the 1.5% list; not a legal charity category'
  END AS is_like_for_like_note
FROM (
  SELECT * FROM silver_uk_charities
  UNION ALL SELECT * FROM silver_ca_charities
  UNION ALL SELECT * FROM silver_au_charities
  UNION ALL SELECT * FROM silver_us_charities
  UNION ALL SELECT * FROM silver_pl_charities
);

CREATE OR REFRESH MATERIALIZED VIEW gold_charity_causes
COMMENT 'One row per organisation and Charity Lens cause (exploded from gold_charities.causes).'
AS SELECT charity_id, jurisdiction, cause FROM gold_charities LATERAL VIEW explode(causes) c AS cause;

CREATE OR REFRESH MATERIALIZED VIEW gold_jurisdiction_summary
COMMENT 'Per jurisdiction: organisations, income and cause coverage, median income in LOCAL currency. Median = organisations with income > 0 only (NULL, zero and negative excluded; counts shown).'
AS SELECT jurisdiction, currency,
  count(*)                                                            AS organisations,
  round(avg(CASE WHEN income IS NOT NULL THEN 1 ELSE 0 END), 3)       AS share_with_income,      -- any figure on file, incl. 0
  round(avg(CASE WHEN income <= 0 THEN 1 ELSE 0 END), 3)              AS share_zero_income,      -- 0 or negative (US BMF: mostly 990-N / not required to file)
  round(avg(CASE WHEN size(causes) > 0 THEN 1 ELSE 0 END), 3)         AS share_with_cause,
  count(CASE WHEN income > 0 THEN 1 END)                              AS orgs_in_median,
  CAST(percentile_approx(CASE WHEN income > 0 THEN income END, 0.5) AS DECIMAL(18,2)) AS median_income_local, -- income > 0 only
  'income > 0 only; NULL and zero/negative excluded'                  AS median_basis
FROM gold_charities GROUP BY jurisdiction, currency;
-- Rehearsal (30 Oct) used percentile_approx(income, 0.5) over all rows: US median came out 0.00 USD because
-- ~650K of 1.65M BMF rows carry REVENUE_AMT = 0 (organisations not required to file a 990). That is "no figure", not "earns nothing".
-- FX: once fx_rates.csv has sourced 2024 annual averages (ECB reference rates [VERIFY]),
-- add: income / r.rate_per_1_base AS income_eur, with r.source and r.year carried into the row.
