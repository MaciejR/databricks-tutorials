# E4 fallback pipeline (if Genie Code goes off-track on camera)

Lakeflow Declarative Pipeline, SQL, serverless, **triggered**. Catalog `workspace`, schema `charity_lens`.
Source files: UC volume `/Volumes/workspace/charity_lens/raw/<country>/` (filled from `charity-lens/upload/`, see `../upload/upload_manifest.md`).

| File | What |
|---|---|
| `e04_pipeline_all.sql` | **all-in-one** bronze+silver+gold (rehearsal run 6 + 10 Nov fixes); add as the pipeline's ONLY source file if Genie diverges |
| `e04_bronze.sql` | `read_files` over each staged file, all STRING, + `_source_file`, `_ingested_at` |
| `e04_silver.sql` | one conformed table per jurisdiction, identical 23-column list |
| `e04_gold.sql` | `gold_charities` (UNION ALL), `gold_charity_causes`, `gold_jurisdiction_summary` |
| `e04_licence_tags.sql` | licence/attribution tags + comments (notebook, after the run) |
| `e04_checks.sql` | counts, one row per (jurisdiction, charity_id) in silver and gold, malformed IDs, dropped rows, median basis, cause coverage, PII column guard, currency guard |
| `cause_map.csv` | 95 rows: UK What codes 101-117, CA categories (30), AU purpose flags (12), US NTEE major groups (26), PL PKD divisions (10, partial) → 19 Charity Lens causes |
| `fx_rates_template.csv` | ECB annual-average template, **rates empty** [VERIFY]; nothing converts until filled from source |

Pipeline settings: add EITHER the three SQL files OR `e04_pipeline_all.sql` as source code (never both: duplicate datasets); target `workspace.charity_lens`; serverless; triggered.

Fixes after the 30 Oct rehearsal (run 6 completed in ~7-8 min): PL explode in a subquery (LATERAL VIEW + JOIN parse error); spaced CSV headers renamed in bronze (columnMapping did not help); typed empty arrays; type-proof joins; and on 10 Nov: `escape => '"'` on comma CSVs (PL 9,607 -> 9,604), AU one row per 11-digit ABN (66,515 -> 65,907; 607 register rows have no ABN), US BMF STREET/ZIP and AU Address_Type/Postcode not loaded, median over income > 0 only (US was 0.00).

## Common schema v0 (silver_* and gold_charities)
`charity_id, jurisdiction, source_id, name, legal_form, registration_status, registration_date, causes[], causes_source_labels[], region_admin1, locality, programme_countries[], fiscal_year_end, income, expenditure, charitable_spending, fundraising_spending, currency, employees, website, source, source_url, licence` (+ `is_like_for_like_note` in gold).

| Field | UK | CA | AU | US | PL |
|---|---|---|---|---|---|
| charity_id | GB-CHC-+reg no | CA-CRA-+BN | AU-ABN-+ABN | US-EIN-+EIN | PL-KRS-+KRS |
| causes | classification What → map | Category → map | 12 purpose flags → map | NTEE first letter → map | KRS PKD division (sample of 200 only) |
| income / expenditure | latest_income / latest_expenditure | lines 4700 / 5100 | AIS total revenue / total expenses | 990 sample else BMF REVENUE_AMT / 990 sample only | none in open data |
| charitable / fundraising | part B (large charities) | 5000 / 5020 | – | – | – |
| currency | GBP | CAD | AUD | USD | PLN |
| programme_countries | country **names** | ISO2 + CRA Q-regions | **ISO3** | – | – |

Known simplifications (fix in E5, say so in the post): country code systems differ; US expenditure only for the sample; AU `legal_form` holds the size band; US `registration_date` is the IRS ruling date; PL has no financials; causes are a v0 hand mapping. FOUNDATION codes 02/03/04 = private foundation [VERIFY against BMF docs].
