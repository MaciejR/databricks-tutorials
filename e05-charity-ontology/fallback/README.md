# E5 fallback: the ontology layer without Genie

Use this if Genie Code goes off-track on camera (more than 2 retries), or to rebuild the layer after an E4 pipeline refresh.
Everything runs in the **SQL editor on the SQL warehouse** (Free Edition: one 2X-Small warehouse). Catalog `workspace`, schema `charity_lens`.
Input: the E4 tables (`gold_charities`, `gold_jurisdiction_summary`, `ref_cause_map`) and three reference CSVs from this folder.

## Before you start
Upload to `/Volumes/workspace/charity_lens/raw/ref/` (Catalog Explorer > `raw` > `ref` > **Upload to this volume**):
- `jurisdictions.csv`: 5 rows, one per register: regulator, legal basis, what "charity" means, currency, which data exist.
- `causes.csv`: 22 Charity Lens causes (every cause used in the E4 `cause_map.csv`) with a display name, description, cause group and synonyms.
- `country_map.csv`: 707 rows mapping every programme-country value found in the E4 files (UK names, CRA codes, ACNC ISO3) to ISO 3166-1 alpha-2.

## Run in order
| File | What it does |
|---|---|
| `e05_1_reference_entities.sql` | `ont_jurisdiction`, `ont_cause`, `ont_cause_crosswalk` (from `ref_cause_map`), `ont_country_map`, `ont_country` |
| `e05_2_charity_entities.sql` | `ont_charity` (with `charity_kind`), `ont_charity_finances` (with `income_status` and spending shares), `ont_charity_cause`, `ont_charity_programme_area` |
| `e05_3_keys_comments_tags.sql` | primary keys (RELY), then foreign keys, column comments, plain tags. Two phases: parents first |
| `e05_4_metric_views.sql` | `mv_charity_finance`, `mv_charity_causes`, `mv_programme_reach` + five donor questions with `MEASURE()` |
| `e05_5_checks.sql` | counts vs E4, key uniqueness, orphans, country-map coverage, consistency with E4 numbers, currency guard, PII column guard, then (commented) certification |
| `e05_genie_example_queries.sql` | example SQL for the Genie Agent |

## The ontology
```
Jurisdiction 1 ── * Charity 1 ── 1 Finances
                     │  1
                     ├── * Charity-Cause * ── 1 Cause 1 ── * Cause crosswalk (register code -> cause)
                     └── * Programme area * ── 0..1 Country 1 ── * Country map (register value -> ISO2)
```
| Entity | Table | Key |
|---|---|---|
| Jurisdiction | `ont_jurisdiction` | `jurisdiction` |
| Charity | `ont_charity` | `charity_id` |
| Finances | `ont_charity_finances` | `charity_id` (latest period, local currency) |
| Cause | `ont_cause` (+ `ont_cause_crosswalk`, `ont_charity_cause`) | `cause` |
| Programme country | `ont_country` (+ `ont_country_map`, `ont_charity_programme_area`) | `iso2` / (`charity_id`, `area_code`) |

## Design rules (why it looks like this)
- **"Charity" is an attribute, not an assumption.** `ont_jurisdiction.charity_concept` and `ont_charity.charity_kind` say what a row is: a registered charity, a foundation, a US 501(c)(3) exempt organisation, or a Polish OPP status holder.
- **Money never crosses currencies.** `total_income_local` and `median_income_local` return NULL when a result mixes currencies. Spending *shares* are ratios inside one organisation, so they can be compared across countries.
- **Missing is not zero.** `income_status` separates `reported_positive`, `zero_or_negative` (US: usually no financial return on file) and `not_available` (all of Poland).
- **Unmapped stays visible.** Country values that are regions (CRA "Other countries in Africa") or have no ISO code (UK Sovereign Base Areas) keep their own `area_type`; nothing is guessed.
- Snapshot tables, not pipeline datasets: keys and comments can be added with `ALTER TABLE`. Re-run files 1, 2 and 5 after every E4 refresh.

## Country map notes
Built from the E4 staged files (distinct values in UK `area_of_operation` type Country, CA Schedule 2 `Country`, AU `Operating_Countries`), mapped with ISO 3166-1 and a short manual list.
- CA region codes `QM, QN, QO, QP, QR, QS` = CRA "Other countries in ..." regions (CRA guide T4033). `QZ` and `XZ` are not in that list: `unmapped` [VERIFY].
- UK: emirates -> AE, Scotland and Northern Ireland -> GB (domestic for England & Wales charities), Akrotiri and Dhekelia, Netherlands Antilles -> unmapped.
- AU: `ROM` (legacy ISO3 for Romania) -> RO.
- Kosovo uses `XK`, a user-assigned code that is widely used but not an official ISO 3166-1 code.
