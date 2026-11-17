-- E5 fallback, file 4 of 5: METRIC VIEWS. Run in the SQL EDITOR on the SQL warehouse (E3 lesson: the serverless
-- notebook rejected the $$ YAML body). After pasting, check the YAML indentation (the editor may auto-indent).
-- Star-schema joins only (many_to_one), YAML spec 1.1 for display_name and synonyms (1.1 worked on Free Edition in E3).
-- Currency guard: money measures return NULL unless the result covers exactly one currency.

USE CATALOG workspace;
USE SCHEMA charity_lens;

-- ===== 1. Charity finance =====
CREATE OR REPLACE VIEW workspace.charity_lens.mv_charity_finance
WITH METRICS
LANGUAGE YAML
COMMENT 'Charity Lens finance KPIs at organisation grain, in LOCAL currency. Money measures return NULL when a result mixes currencies: group or filter by jurisdiction or currency.'
AS $$
version: 1.1
source: workspace.charity_lens.ont_charity_finances
joins:
  - name: charity
    source: workspace.charity_lens.ont_charity
    on: source.charity_id = charity.charity_id
  - name: jur
    source: workspace.charity_lens.ont_jurisdiction
    on: source.jurisdiction = jur.jurisdiction
dimensions:
  - name: jurisdiction
    expr: source.jurisdiction
    display_name: Jurisdiction
    synonyms: ['country', 'register']
  - name: jurisdiction_name
    expr: jur.jurisdiction_name
    display_name: Jurisdiction name
  - name: charity_concept
    expr: jur.charity_concept
    display_name: 'What "charity" means here'
  - name: charity_kind
    expr: charity.charity_kind
    display_name: Kind of organisation
    synonyms: ['legal type', 'organisation type']
  - name: size_band
    expr: charity.size_band
    display_name: Size band (AU only)
  - name: region_admin1
    expr: charity.region_admin1
    display_name: State, province or region
  - name: currency
    expr: source.currency
    display_name: Currency
  - name: fiscal_year
    expr: source.fiscal_year
    display_name: Fiscal year (end)
  - name: income_status
    expr: source.income_status
    display_name: Income status
measures:
  - name: organisations
    expr: COUNT(1)
    display_name: Organisations
    synonyms: ['charities', 'number of charities', 'count']
  - name: organisations_with_income
    expr: COUNT(1) FILTER (WHERE source.income > 0)
    display_name: Organisations with income above zero
  - name: share_zero_or_missing_income
    expr: AVG(CASE WHEN source.income IS NULL OR source.income <= 0 THEN 1 ELSE 0 END)
    display_name: Share with zero or missing income
  - name: median_income_local
    expr: CASE WHEN COUNT(DISTINCT source.currency) = 1 THEN percentile_approx(CASE WHEN source.income > 0 THEN source.income END, 0.5) END
    comment: Median over organisations with income above zero, in local currency. NULL when the result mixes currencies.
    display_name: Median income (local currency)
    synonyms: ['typical income', 'median revenue']
  - name: total_income_local
    expr: CASE WHEN COUNT(DISTINCT source.currency) = 1 THEN SUM(source.income) END
    comment: Sum of income in local currency. NULL when the result mixes currencies (never add pounds to dollars).
    display_name: Total income (local currency)
    synonyms: ['total revenue']
  - name: organisations_with_spending_breakdown
    expr: COUNT(1) FILTER (WHERE source.charitable_spending_share IS NOT NULL)
    display_name: Organisations with a spending breakdown
  - name: median_charitable_spending_share
    expr: percentile_approx(source.charitable_spending_share, 0.5)
    comment: Median of charitable spending / total expenditure per organisation. Currency-free. Only GB-EAW (larger charities) and CA report it.
    display_name: Median share spent on charitable activities
    synonyms: ['programme ratio', 'how much goes to the cause']
  - name: median_fundraising_share
    expr: percentile_approx(source.fundraising_spending_share, 0.5)
    comment: Median of fundraising spending / total expenditure per organisation. Currency-free. GB-EAW (larger charities) and CA only.
    display_name: Median share spent on fundraising
$$;

-- ===== 2. Causes =====
CREATE OR REPLACE VIEW workspace.charity_lens.mv_charity_causes
WITH METRICS
LANGUAGE YAML
COMMENT 'Charity Lens cause KPIs: organisations per Charity Lens cause. share_of_jurisdiction is only defined for one jurisdiction at a time, over ALL its organisations.'
AS $$
version: 1.1
source: workspace.charity_lens.ont_charity_cause
joins:
  - name: charity
    source: workspace.charity_lens.ont_charity
    on: source.charity_id = charity.charity_id
  - name: cause_def
    source: workspace.charity_lens.ont_cause
    on: source.cause = cause_def.cause
dimensions:
  - name: jurisdiction
    expr: source.jurisdiction
    display_name: Jurisdiction
    synonyms: ['country', 'register']
  - name: cause
    expr: source.cause
    display_name: Cause
    synonyms: ['purpose', 'cause area', 'what they do']
  - name: cause_display_name
    expr: cause_def.display_name
    display_name: Cause name
  - name: cause_group
    expr: cause_def.cause_group
    display_name: Cause group
  - name: charity_kind
    expr: charity.charity_kind
    display_name: Kind of organisation
measures:
  - name: organisations
    expr: COUNT(DISTINCT source.charity_id)
    display_name: Organisations
    synonyms: ['charities', 'number of charities']
  - name: share_of_jurisdiction
    expr: CASE WHEN COUNT(DISTINCT source.jurisdiction) = 1 THEN COUNT(DISTINCT source.charity_id) / MAX(source.jurisdiction_organisations) END
    comment: Organisations with this cause / all organisations in the jurisdiction. One organisation can have several causes, so shares do not add up to 1. NULL across jurisdictions.
    display_name: Share of organisations in the jurisdiction
$$;

-- ===== 3. Programme reach =====
CREATE OR REPLACE VIEW workspace.charity_lens.mv_programme_reach
WITH METRICS
LANGUAGE YAML
COMMENT 'Charity Lens programme reach: organisations by the countries or regions they say they work in. Only GB-EAW, CA and AU publish this. US and PL have no programme-country data here.'
AS $$
version: 1.1
source: workspace.charity_lens.ont_charity_programme_area
joins:
  - name: charity
    source: workspace.charity_lens.ont_charity
    on: source.charity_id = charity.charity_id
dimensions:
  - name: jurisdiction
    expr: source.jurisdiction
    display_name: Registered in
    synonyms: ['home country', 'register']
  - name: area_name
    expr: source.area_name
    display_name: Works in
    synonyms: ['programme country', 'country of operation', 'where they work']
  - name: iso2
    expr: source.iso2
    display_name: Country code (ISO2)
  - name: area_type
    expr: source.area_type
    display_name: Area type
  - name: is_domestic
    expr: source.is_domestic
    display_name: Home country
  - name: charity_kind
    expr: charity.charity_kind
    display_name: Kind of organisation
measures:
  - name: organisations
    expr: COUNT(DISTINCT source.charity_id)
    display_name: Organisations
    synonyms: ['charities', 'number of charities']
$$;

ALTER VIEW workspace.charity_lens.mv_charity_finance SET TAGS ('domain' = 'charity_lens', 'layer' = 'semantic', 'contains_pii' = 'false');
ALTER VIEW workspace.charity_lens.mv_charity_causes  SET TAGS ('domain' = 'charity_lens', 'layer' = 'semantic', 'contains_pii' = 'false');
ALTER VIEW workspace.charity_lens.mv_programme_reach SET TAGS ('domain' = 'charity_lens', 'layer' = 'semantic', 'contains_pii' = 'false');

-- ===== Donor questions, answered with MEASURE() =====
-- Q1 Typical income per register (local currency, never converted).
SELECT jurisdiction, currency, MEASURE(organisations) AS organisations, MEASURE(organisations_with_income) AS with_income,
       MEASURE(median_income_local) AS median_income_local
FROM workspace.charity_lens.mv_charity_finance GROUP BY ALL ORDER BY jurisdiction;

-- Q2 The currency guard: one row over all five registers -> total and median must be NULL.
SELECT MEASURE(organisations) AS organisations, MEASURE(total_income_local) AS total_income_local,
       MEASURE(median_income_local) AS median_income_local
FROM workspace.charity_lens.mv_charity_finance;

-- Q3 Where does the money go? (GB-EAW and CA only)
SELECT jurisdiction, charity_kind, MEASURE(organisations_with_spending_breakdown) AS orgs_with_breakdown,
       MEASURE(median_charitable_spending_share) AS median_charitable_share, MEASURE(median_fundraising_share) AS median_fundraising_share
FROM workspace.charity_lens.mv_charity_finance WHERE jurisdiction IN ('GB-EAW', 'CA') GROUP BY ALL ORDER BY jurisdiction, charity_kind;

-- Q4 Animal charities: how common are they in each register?
SELECT jurisdiction, MEASURE(organisations) AS organisations, MEASURE(share_of_jurisdiction) AS share_of_jurisdiction
FROM workspace.charity_lens.mv_charity_causes WHERE cause = 'animals' GROUP BY ALL ORDER BY share_of_jurisdiction DESC;

-- Q5 Which registers have the most organisations working in Kenya?
SELECT jurisdiction, MEASURE(organisations) AS organisations
FROM workspace.charity_lens.mv_programme_reach WHERE iso2 = 'KE' GROUP BY ALL ORDER BY organisations DESC;
