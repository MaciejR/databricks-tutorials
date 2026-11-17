---
name: charity-lens-ontology
description: Conventions for the Charity Lens cross-jurisdiction ontology on top of the E4 tables in workspace.charity_lens - entities Jurisdiction, Charity, Finances, Cause and Programme country as ont_* tables with keys, three metric views, and the Genie Agent for donor questions. Use when building or changing the ontology layer, its metric views or the donor Genie Agent, or when answering what "charity" means in each country.
---

# Charity Lens ontology (E5)

## Scope and safety
- Read from `workspace.charity_lens` (E4 tables: `gold_charities`, `gold_jurisdiction_summary`, `ref_cause_map`) and `/Volumes/workspace/charity_lens/raw/ref/`. Write only `ont_*` tables and `mv_*` metric views in `workspace.charity_lens`. Never change the E4 pipeline or its tables. Never touch `workspace.support_copilot`.
- Run DDL in the SQL editor on the SQL warehouse (metric views fail in the serverless notebook). Show every statement first and ask before running.
- No personal data. Do not add columns for people, street addresses, full postcodes, phone numbers or e-mails. Organisation names are fine.
- Never invent numbers, exchange rates or mappings. If a value cannot be mapped, keep it as `unmapped` and list it.

## Entities and tables (create exactly these names)
| Entity | Table | Key | Built from |
|---|---|---|---|
| Jurisdiction | `ont_jurisdiction` | `jurisdiction` | `raw/ref/jurisdictions.csv` |
| Cause | `ont_cause` | `cause` | `raw/ref/causes.csv` (`synonyms` split on `|` into ARRAY<STRING>) |
| Cause crosswalk | `ont_cause_crosswalk` | (`jurisdiction`, `source_code_type`, `source_code`) | `ref_cause_map` |
| Country map | `ont_country_map` | (`jurisdiction`, `source_value`) | `raw/ref/country_map.csv` (empty strings -> NULL) |
| Country | `ont_country` | `iso2` | distinct ISO2 from the country map + GB, CA, AU, US, PL |
| Charity | `ont_charity` | `charity_id` | `gold_charities` |
| Finances | `ont_charity_finances` | `charity_id` | `gold_charities` (latest period, local currency) |
| Charity-Cause | `ont_charity_cause` | (`charity_id`, `cause`) | `explode(gold_charities.causes)` + `jurisdiction_organisations` |
| Programme area | `ont_charity_programme_area` | (`charity_id`, `area_code`) | `explode(gold_charities.programme_countries)` joined to the country map |

Use `CREATE OR REPLACE TABLE ... AS SELECT` (plain Delta tables, not pipeline datasets). `read_files` for CSVs: `format => 'csv', header => true, escape => '"', inferSchema => false`; jurisdictions also `multiLine => true`.

## Rules per entity
- **ont_charity.charity_kind**: CA `Private foundation` -> `private_foundation`, `Public foundation` -> `public_foundation`, else `charitable_organisation`; US `Private foundation` -> `private_foundation`, else `public_charity`; PL -> `public_benefit_organisation`; GB-EAW and AU -> `registered_charity`. `is_foundation` = legal_form is a foundation. AU `legal_form` holds the size band: move it to `size_band` and set `legal_form` NULL for AU.
- **ont_charity_finances**: `income_status` = `not_available` if income IS NULL, `reported_positive` if income > 0, else `zero_or_negative`. `charitable_spending_share` and `fundraising_spending_share` = amount / expenditure only when expenditure > 0, as DECIMAL(9,4). Keep `currency`; no conversion.
- **ont_charity_cause**: DISTINCT (charity_id, jurisdiction, cause); add `jurisdiction_organisations` = count of all organisations in that jurisdiction.
- **ont_charity_programme_area**: explode in a subquery first, trim values, then LEFT JOIN the country map on (jurisdiction, source_value). `area_code` = iso2, else the source value. `area_type` = `country` if iso2, `region` if mapping_status = 'region', else `unmapped`. Group so that several source values with the same ISO2 (Scotland + Northern Ireland -> GB) become one row; keep them in `source_values` ARRAY. `is_domestic` = iso2 = the jurisdiction's `home_iso2`.

## Keys (two phases, like E3)
1. `ALTER COLUMN ... SET NOT NULL`, then `ADD CONSTRAINT pk_<table> PRIMARY KEY (...) RELY` on every table. 2. Then foreign keys: charity -> jurisdiction; finances, charity_cause, programme_area -> charity; charity_cause and crosswalk -> cause; crosswalk -> jurisdiction; programme_area and country_map -> country (iso2). Before trusting RELY, prove uniqueness and zero orphans with queries.

## Metric views (YAML version 1.1, star joins only)
- `mv_charity_finance` on `ont_charity_finances`, joins `ont_charity` and `ont_jurisdiction`. Measures: `organisations`, `organisations_with_income`, `share_zero_or_missing_income`, `median_income_local` (income > 0 only), `total_income_local`, `organisations_with_spending_breakdown`, `median_charitable_spending_share`, `median_fundraising_share`.
- **Currency guard**: every money measure is wrapped as `CASE WHEN COUNT(DISTINCT source.currency) = 1 THEN <aggregate> END`.
- `mv_charity_causes` on `ont_charity_cause`, joins charity and cause. `share_of_jurisdiction` = `CASE WHEN COUNT(DISTINCT source.jurisdiction) = 1 THEN COUNT(DISTINCT source.charity_id) / MAX(source.jurisdiction_organisations) END`.
- `mv_programme_reach` on `ont_charity_programme_area`, joins charity. Measure `organisations` = COUNT(DISTINCT charity_id).
- Add `display_name`, `synonyms` (donor words: "typical income", "where they work") and comments. Tags: `domain = charity_lens`, `layer = semantic`, `contains_pii = false`.

## What "charity" means (say this whenever countries are compared)
- GB-EAW: registered charity, Charities Act 2011, England and Wales only. CA: registered charity under the Income Tax Act (charitable organisation, public or private foundation). AU: registered with the ACNC, Charities Act 2013 (Cth). US: 501(c)(3) tax-exempt organisation in the IRS BMF, an exemption list rather than a charity register. PL: no legal charity category; OPP is a public-benefit status, and the list has no open financial data.
- Only GB-EAW, CA and AU have programme countries. Only GB-EAW (larger charities) and CA have a spending breakdown. Poland has causes for about 2% of organisations (KRS sample).

## Genie Agent "Charity Lens: donor questions"
- Data (max 5 objects): `mv_charity_finance`, `mv_charity_causes`, `mv_programme_reach`, `ont_charity`, `ont_jurisdiction`.
- Instructions: answer in local currency and name it; never convert or add currencies; when comparing countries, say what "charity" means in each (from `ont_jurisdiction.charity_definition`); say when a country has no data instead of showing 0; zero income in the US usually means no financial return on file. This is information, not financial advice.
