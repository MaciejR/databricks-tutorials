---
name: charity-lens-registers
description: Conventions for loading the five national charity registers (UK/England & Wales, Canada, Australia, US, Poland) from the UC volume workspace.charity_lens.raw into bronze/silver/gold tables with the Charity Lens common schema, cause mapping, currency fields and licence tags. Use when building or changing the Charity Lens ingestion pipeline or answering questions about which file holds which field.
---

# Charity Lens registers (E4)

## Scope and safety
- Read only from `/Volumes/workspace/charity_lens/raw/`; write only to `workspace.charity_lens`. Never touch `workspace.support_copilot` (E1-E3).
- Lakeflow Declarative Pipeline in SQL, serverless, triggered mode. No clusters, no continuous mode, no AI Functions in E4.
- Show the plan and every DDL first; ask before running the pipeline.
- Personal data: the volume holds only PII-free files. In bronze use `SELECT * EXCEPT (STREET, ZIP)` for the US BMF and `* EXCEPT (Address_Type, Postcode)` for the AU register. Never add columns for people (trustees, directors, officers, preparers, "in care of"), street addresses, full postcodes, phone numbers or e-mails, even if you find them somewhere. If a needed field is missing, say so; don't look for the original files.

## Files (all CSV with header unless noted; read every column as STRING in bronze, `inferSchema => false`)
| Country | Path under raw/ | Notes |
|---|---|---|
| UK | `uk/publicextract.charity.nopii.txt`, `uk/publicextract.charity_classification.txt`, `uk/publicextract.charity_area_of_operation.txt`, `uk/publicextract.charity_annual_return_partb.txt` | **tab**-separated, unescaped quotes: `sep => '\t'`, quoting off; dates like `2009-09-30 00:00:00.0000000` (take left 10 chars) |
| CA | `ca/ident_2024_updated.nopii.csv`, `ca/financial_d_and_schedule_6_2024_updated.csv`, `ca/schedule_2_details_2024.csv`, `ca/schedule_2_countries_2024.csv`, `ca/weburl_2024_updated.nopii.csv` | financial columns are T3010 line numbers (backtick them: `` `4700` ``); 2 returns per BN possible → latest FPE |
| AU | `au/datadotgov_main.nopii.csv`, `au/datadotgov_ais24.nopii.csv` | `multiLine => true`; join on ABN (11 digits); ~600 register rows have no ABN; dates dd/MM/yyyy; purpose flags 'Y' or empty; AIS column names have spaces |
| US | `us/eo_bmf_all.nopii.csv`, `us/index_2026.csv`, `us/irs990_sample_org.nopii.csv` | EIN zero-padded to 9; filter `SUBSECTION = '03'`; REVENUE_AMT 0 = no return filed (990-N); 990 figures only for the 500-return sample |
| PL | `pl/wykaz_opp_2025_w_2026_10_2026.csv`, `pl/krs_sample_org.nopii.csv` | KRS zero-padded to 10; multi-line names with doubled quotes → `multiLine => true`; no financials |
| ref | `ref/cause_map.csv`, `ref/fx_rates_template.csv` | lookups |

## Pipeline SQL rules (tested on Free Edition; follow exactly)
- `read_files`: every comma CSV gets `escape => '"'` (names contain `""`; without it PL breaks into extra rows). UK: `sep => '\t', quote => ''`.
- Headers with spaces or `,;{}()=` (CA ident/financial/weburl, AU AIS): list the columns in bronze and rename to snake_case (`` `Legal Name` AS legal_name ``). `delta.columnMapping` TBLPROPERTIES do not work in pipeline MVs.
- Empty arrays are typed: `CAST(array() AS ARRAY<STRING>)`; one-element arrays `array(CAST(x AS STRING))`. A bare `array()` becomes ARRAY<VOID> and the UNION fails.
- Joins on codes/IDs are type-proof: `trim(CAST(a AS STRING)) = trim(CAST(b AS STRING))`, or `try_cast(... AS INT)` on both sides for numeric codes. Dates with `try_to_date`.
- Explode in a subquery, then join: `FROM (SELECT krs, explode(split(pkd_opp_codes, '\\|')) AS code FROM k) e JOIN ref_cause_map m ...`. `LATERAL VIEW` followed by `JOIN` fails to parse.
- One row per `charity_id` in every silver table: drop rows with an empty or malformed source ID (AU ABN must be 11 digits, PL KRS numeric), and pick one row per ID with `row_number()` from multi-row sources (CA latest FPE, AU AIS latest `fin report to`, US 990 sample latest period).
- Median income = median over `income > 0` only (NULL, zero and negative excluded), next to `share_zero_income`, `orgs_in_median` and a `median_basis` column.
- Pipeline mode: triggered; never continuous. Create datasets with `CREATE OR REFRESH MATERIALIZED VIEW`.

## Common schema (identical column list and order in every silver_<cc>_charities)
charity_id, jurisdiction, source_id, name, legal_form, registration_status, registration_date, causes ARRAY<STRING>, causes_source_labels ARRAY<STRING>, region_admin1, locality, programme_countries ARRAY<STRING>, fiscal_year_end DATE, income DECIMAL(18,2), expenditure DECIMAL(18,2), charitable_spending DECIMAL(18,2), fundraising_spending DECIMAL(18,2), currency, employees INT, website, source, source_url, licence.
- IDs: `GB-CHC-`+registered_charity_number, `CA-CRA-`+BN, `AU-ABN-`+ABN, `US-EIN-`+EIN, `PL-KRS-`+KRS. Jurisdiction codes: GB-EAW, CA, AU, US, PL.
- UK: only `charity_registration_status = 'Registered'` and `linked_charity_number = '0'`.
- Income: UK latest_income; CA line 4700; AU AIS `total revenue`; US 990 sample revenue else BMF REVENUE_AMT; PL NULL. Expenditure: UK latest_expenditure; CA 5100; AU `total expenses`; US 990 sample only; PL NULL.

## Causes
- Join each source code to `ref_cause_map` (jurisdiction, source_code_type, source_code) → `cause`. Keep the original labels in `causes_source_labels`.
- UK: classification_type = 'What'. CA: Category (4 digits). AU: the 12 purpose flags = 'Y'. US: first letter of NTEE_CD. PL: PKD division (first 2 digits) from the KRS sample.
- Unmapped codes: leave out of `causes`, list them in a check query. Never invent a cause from the charity name.

## Money and currency
- Keep amounts in the reporting currency with a `currency` column (GBP, CAD, AUD, USD, PLN). Never add up or average across currencies.
- Do not invent exchange rates. Only convert with `ref/fx_rates.csv` if it exists and every row has `source` and `source_url`; otherwise leave converted columns out.

## Licence and attribution
- Every silver/gold row carries `source`, `source_url`, `licence`. After the run, in a notebook SQL cell (not in the pipeline), add UC tags `source`, `licence`, `licence_url`, `attribution`, `extract_date`, `contains_pii = 'false'` per silver table with `ALTER MATERIALIZED VIEW ... SET TAGS`; volume: `ALTER VOLUME ... SET TAGS ('domain' = 'charity_lens', 'contains_pii' = 'false')`. Use exactly:

| Table | licence | licence_url | attribution | extract_date |
|---|---|---|---|---|
| silver_uk | OGL-UK-3.0 | https://www.nationalarchives.gov.uk/doc/open-government-licence/version/3/ | Contains public sector information licensed under the Open Government Licence v3.0. | 2026-10-23 |
| silver_ca | OGL-Canada-2.0 | https://open.canada.ca/en/open-government-licence-canada | Contains information licensed under the Open Government Licence – Canada. | 2026-10-26 |
| silver_au | CC-BY-3.0-AU | https://creativecommons.org/licenses/by/3.0/au/ | Source: Australian Charities and Not-for-profits Commission (ACNC), data.gov.au, CC BY 3.0 AU. | 2026-10-23 |
| silver_us | US-Government-Work | https://www.irs.gov/about-irs/use-of-content-from-irsgov | Source: U.S. Internal Revenue Service, irs.gov. Not endorsed by the IRS. | 2026-10-24 |
| silver_pl | CC0-1.0 (wykaz); KRS Open Data Act reuse | https://creativecommons.org/publicdomain/zero/1.0/ | Źródło / Source: Narodowy Instytut Wolności – CRSO (dane.gov.pl), CC0 1.0; Ministerstwo Sprawiedliwości, Krajowy Rejestr Sądowy (Open API), processed sample obtained 25 Oct 2026. | 2026-10-25 |
| gold_charities | mixed: see licence column per row | – | – | – |
- Comparisons are not like-for-like: Poland's OPP is a status, US covers 501(c)(3) exempt orgs, UK is England & Wales only. Put this in table comments.
