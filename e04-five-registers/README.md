# E4: From Synthetic Tickets to Five National Charity Registers

Companion files for Episode 4, the first Charity Lens episode. We load five national charity registers into Unity Catalog on Databricks Free Edition. Genie Code builds the pipeline, guided by a skill, and the SQL in `fallback/` gives you the same tables if your agent goes another way.

**No register data is included here.** Download the files yourself from the publishers below, remove personal data as described in `upload/upload_manifest.md`, then upload only the cleaned files to `/Volumes/workspace/charity_lens/raw/<country>/`.

## What's inside

| Path | What |
|---|---|
| `prompts/genie_code_prompts.md` | The five prompts used in the post, one per clip |
| `prompts/skills/charity-lens-registers/SKILL.md` | The skill: files and their quirks, common schema, cause mapping rules, no-PII rules. Copy the folder to `/Users/{username}/.assistant/skills/` and start a new Genie Code chat |
| `fallback/e04_pipeline_all.sql` | Bronze, silver and gold in one file. Add it as the pipeline's only source (target `workspace.charity_lens`, serverless, triggered) |
| `fallback/e04_bronze.sql`, `e04_silver.sql`, `e04_gold.sql` | The same pipeline split into three files (use these OR the all-in-one file, never both) |
| `fallback/e04_licence_tags.sql`, `e04_checks.sql` | Licence/attribution tags and comments; row-count, duplicate, median and PII checks |
| `fallback/cause_map.csv` | v0 mapping of each register's purpose codes to one Charity Lens cause list. Upload to `raw/ref/` |
| `fallback/fx_rates_template.csv` | Empty template. Nothing is converted in this episode |
| `upload/upload_manifest.md` | Allow-list and deny-list: which files may go into the volume and which must never leave your laptop |
| `upload/stage_upload.py` | Copies the allow-listed files from `charity-lens/data/raw/` (a folder next to this repo) into `charity-lens/upload/` with SHA-256 checksums, and refuses to run if a deny-listed file is included. It expects the `.nopii` copies to exist already |

## Data sources and licences

| Jurisdiction | Source | Licence |
|---|---|---|
| England & Wales | Charity Commission for England and Wales, Register of Charities extract ([download page](https://register-of-charities.charitycommission.gov.uk/en/register/full-register-download)) | Open Government Licence v3.0 |
| Canada | Canada Revenue Agency, T3010 2024 List of charities ([open.canada.ca](https://open.canada.ca/data/dataset/80c00cdb-1358-415c-bb8b-0de7f12675b8)) | Open Government Licence – Canada 2.0 |
| Australia | ACNC Charity Register and 2024 Annual Information Statements ([data.gov.au](https://data.gov.au/data/dataset/acnc-register)) | CC BY 3.0 AU |
| United States | IRS Exempt Organizations Business Master File and Form 990 series e-file data ([irs.gov](https://www.irs.gov/charities-non-profits/public-disclosure-datasets-and-downloads)) | US Government work, no copyright; credit requested, no endorsement implied |
| Poland | NIW-CRSO Wykaz OPP 1.5% ([dane.gov.pl, dataset 20137](https://dane.gov.pl/pl/dataset/20137)) | CC0 1.0 |
| Poland | Ministry of Justice, KRS Open API (organisation-level fields only) | Public-sector information reused under the Act of 11 August 2021 on open data; say that the data were processed and don't republish personal data |

Attribution lines to show:

- Contains public sector information licensed under the Open Government Licence v3.0. Source: Charity Commission for England and Wales.
- Contains information licensed under the Open Government Licence – Canada.
- Source: Australian Charities and Not-for-profits Commission (ACNC), data.gov.au, licensed under CC BY 3.0 AU.
- Source: U.S. Internal Revenue Service, irs.gov. Not endorsed by the IRS.
- Źródło / Source: Narodowy Instytut Wolności – CRSO, dane.gov.pl, CC0 1.0.
- Source: Ministerstwo Sprawiedliwości, Krajowy Rejestr Sądowy (Open API). Processed organisation-level data.

Charity Lens is independent and not endorsed by any of these publishers. Information, not financial or legal advice.
