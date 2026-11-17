-- E5 fallback, file 2 of 5: CHARITY ENTITIES (Charity, Finances, Charity-Cause, Programme area).
-- Run in the SQL EDITOR on the SQL warehouse after file 1. Source: the E4 pipeline output workspace.charity_lens.gold_charities.
-- Snapshot tables (CREATE OR REPLACE TABLE ... AS SELECT). Re-run this file after every E4 pipeline refresh.
-- No people, no addresses: we only carry organisation-level columns that already passed the E4 PII check.

USE CATALOG workspace;
USE SCHEMA charity_lens;

-- Charity: one row per organisation, with a normalised charity_kind so "charity" can be compared honestly.
CREATE OR REPLACE TABLE ont_charity
COMMENT 'Charity Lens ontology, entity Charity: one row per organisation from the five registers. charity_kind normalises the very different legal meanings (registered charity, foundation, US 501(c)(3) public charity, Polish OPP status). Money lives in ont_charity_finances.'
AS SELECT
  charity_id,
  jurisdiction,
  source_id,
  name,
  CASE jurisdiction
    WHEN 'CA' THEN CASE legal_form WHEN 'Private foundation' THEN 'private_foundation'
                                   WHEN 'Public foundation'  THEN 'public_foundation'
                                   ELSE 'charitable_organisation' END
    WHEN 'US' THEN CASE legal_form WHEN 'Private foundation' THEN 'private_foundation' ELSE 'public_charity' END   -- [VERIFY] BMF FOUNDATION codes (E4)
    WHEN 'PL' THEN 'public_benefit_organisation'
    ELSE 'registered_charity'
  END                                                         AS charity_kind,
  CASE WHEN legal_form IN ('Private foundation', 'Public foundation') THEN true ELSE false END AS is_foundation,
  CASE WHEN jurisdiction = 'AU' THEN legal_form END           AS size_band,          -- AU register has a size band, not a legal form
  CASE WHEN jurisdiction <> 'AU' THEN legal_form END          AS legal_form,         -- PL: KRS sample only
  registration_status,
  registration_date,                                                                  -- US: IRS ruling date
  region_admin1,
  locality,                                                                           -- UK: postcode district only
  website,
  size(causes) > 0                                            AS has_cause,
  size(programme_countries) > 0                               AS has_programme_area,
  source, source_url, licence
FROM workspace.charity_lens.gold_charities;

-- Finances: one row per organisation (latest period on file), money in LOCAL currency, with an explicit income_status.
CREATE OR REPLACE TABLE ont_charity_finances
COMMENT 'Charity Lens ontology, entity Finances: latest financial period per organisation in LOCAL currency (GBP, CAD, AUD, USD, PLN). Never add or average amounts across currencies. income_status separates reported income from zero or missing figures. Spending shares are ratios within one organisation, so they are currency-free.'
AS SELECT
  charity_id,
  jurisdiction,
  fiscal_year_end,
  year(fiscal_year_end)                                       AS fiscal_year,
  currency,
  income,
  expenditure,
  charitable_spending,
  fundraising_spending,
  employees,
  CASE WHEN income IS NULL THEN 'not_available'
       WHEN income > 0     THEN 'reported_positive'
       ELSE 'zero_or_negative' END                            AS income_status,
  CASE WHEN expenditure > 0 AND charitable_spending IS NOT NULL
       THEN CAST(charitable_spending / expenditure AS DECIMAL(9,4)) END  AS charitable_spending_share,
  CASE WHEN expenditure > 0 AND fundraising_spending IS NOT NULL
       THEN CAST(fundraising_spending / expenditure AS DECIMAL(9,4)) END AS fundraising_spending_share
FROM workspace.charity_lens.gold_charities;

-- Charity-Cause: one row per organisation and Charity Lens cause (bridge). Carries the jurisdiction size for share measures.
CREATE OR REPLACE TABLE ont_charity_cause
COMMENT 'Charity Lens ontology: bridge between Charity and Cause, one row per (charity_id, cause). jurisdiction_organisations = all organisations in that jurisdiction, the denominator for cause shares.'
AS
WITH j AS (SELECT jurisdiction, count(*) AS jurisdiction_organisations FROM workspace.charity_lens.gold_charities GROUP BY jurisdiction),
e AS (
  SELECT DISTINCT charity_id, jurisdiction, cause
  FROM (SELECT charity_id, jurisdiction, explode(causes) AS cause FROM workspace.charity_lens.gold_charities)
)
SELECT e.charity_id, e.jurisdiction, e.cause, j.jurisdiction_organisations
FROM e JOIN j ON j.jurisdiction = e.jurisdiction;

-- Programme area: where an organisation says it works, normalised to ISO2 where possible.
-- Explode first in a subquery, then join (the E4 lesson: LATERAL VIEW followed by JOIN did not parse in the pipeline).
CREATE OR REPLACE TABLE ont_charity_programme_area
COMMENT 'Charity Lens ontology, entity Programme country: one row per (charity_id, area_code). area_type = country (ISO2), region (a CRA region such as "Other countries in Africa") or unmapped. Only GB-EAW, CA and AU publish programme countries. US and PL have none in this data.'
AS
WITH e AS (
  SELECT DISTINCT charity_id, jurisdiction, trim(v) AS source_value
  FROM (SELECT charity_id, jurisdiction, explode(programme_countries) AS v FROM workspace.charity_lens.gold_charities)
  WHERE v IS NOT NULL AND trim(v) <> ''
),
m AS (
  SELECT e.charity_id, e.jurisdiction, e.source_value, cm.iso2,
         coalesce(cm.iso2, e.source_value)                              AS area_code,
         CASE WHEN cm.iso2 IS NOT NULL THEN 'country'
              WHEN cm.mapping_status = 'region' THEN 'region'
              ELSE 'unmapped' END                                       AS area_type,
         CASE WHEN cm.iso2 IS NOT NULL THEN cm.country_name
              WHEN cm.mapping_status = 'region' THEN cm.mapping_note
              ELSE e.source_value END                                   AS area_label
  FROM e
  LEFT JOIN ont_country_map cm ON cm.jurisdiction = e.jurisdiction AND cm.source_value = e.source_value
)
SELECT
  m.charity_id,
  m.jurisdiction,
  m.area_code,
  m.area_type,
  m.iso2,
  coalesce(c.country_name, min(m.area_label))                           AS area_name,
  array_sort(collect_set(m.source_value))                               AS source_values,   -- e.g. Scotland + Northern Ireland -> GB
  coalesce(m.iso2 = j.home_iso2, false)                                 AS is_domestic
FROM m
JOIN ont_jurisdiction j ON j.jurisdiction = m.jurisdiction
LEFT JOIN ont_country c ON c.iso2 = m.iso2
GROUP BY m.charity_id, m.jurisdiction, m.area_code, m.area_type, m.iso2, c.country_name, j.home_iso2;
