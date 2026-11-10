# E4 upload manifest: what may go into the UC volume

Target volume: `/Volumes/workspace/charity_lens/raw/` (create: catalog `workspace` > schema `charity_lens` > volume `raw`, managed).
Stage with `python3 stage_upload.py` → `charity-lens/upload/` (a folder next to this repo) (+ `SHA256SUMS`, `upload_manifest_staged.csv` with bytes and SHA-256 per file). Upload **the staged folder only**, country by country, via Catalog Explorer > volume > "Upload to this volume". Verify checksums against `SHA256SUMS` before upload; the staged file list is the allow-list.

## Allowed (26 files, 1,140.4 MB staged on 26 Oct 2026)
| Volume path | Source | Why safe |
|---|---|---|
| uk/publicextract.charity.nopii.txt | CCEW charity table | contact address/postcode/phone/email dropped; postcode district only |
| uk/publicextract.charity_classification.txt | CCEW | codes only |
| uk/publicextract.charity_area_of_operation.txt | CCEW | geography only |
| uk/publicextract.charity_annual_return_partb.txt | CCEW | financials, employee counts |
| uk/publicextract.charity_annual_return_history.txt | CCEW | financial history (E5) |
| ca/ident_2024_updated.nopii.csv | CRA | address lines + full postcode dropped, FSA kept |
| ca/new_ongoing_programs_2024_updated.nopii.csv | CRA | e-mails/phones redacted; **free text may still name people – never display verbatim without review** |
| ca/schedule_2_resources_2024_updated.nopii.csv | CRA | recipient names dropped |
| ca/weburl_2024_updated.nopii.csv | CRA | e-mail entries dropped |
| ca/financial_section_a_b_and_c_2024_updated.csv, ca/financial_d_and_schedule_6_2024_updated.csv, ca/qualified_donees_2024_updated.csv, ca/schedule_2_details_2024.csv, ca/schedule_2_countries_2024.csv, ca/schedule_2_goods_2024_updated.csv, ca/schedule_3_compensation_2024.csv | CRA | codes, amounts, organisation names (README §10); schedule 3 bands: aggregate display only |
| au/datadotgov_main.nopii.csv | ACNC | address lines dropped |
| au/datadotgov_ais24.nopii.csv | ACNC AIS 2024 | related-party text, KMP pay and free-text columns dropped |
| us/eo_bmf_all.nopii.csv | IRS EO BMF | "in care of" name dropped (organisation street address remains: not used in silver, never shown) |
| us/index_2026.csv | IRS TEOS index | org-level filing index |
| us/irs990_sample_org.nopii.csv | **derived** from the 500 sample XMLs | org-level fields only (EIN, name, state, return type, period, revenue, expenses, employees, website); no Part VII/Sch J/Sch L, no PersonNm, no preparer, no mission text |
| pl/wykaz_opp_2025_w_2026_10_2026.xlsx + .csv | NIW-CRSO, CC0 | organisation-level; CSV is a straight conversion (KRS/NIP as text) |
| pl/krs_sample_org.nopii.csv | **derived** from 200 KRS JSONs | org-level fields; e-mail, representation text and organ members dropped. `cel_dzialania` is statute text: review before display |
| ref/cause_map.csv, ref/fx_rates_template.csv | this repo | lookups, no personal data |

## Never upload
- `uk/publicextract.charity.zip` (original with contact details) and any extracted `publicextract.charity.txt`
- `au/datadotgov_main.csv`, `au/datadotgov_ais24.csv` (originals)
- `ca/ident_2024_updated.csv`, `ca/new_ongoing_programs_2024_updated.csv`, `ca/schedule_2_resources_2024_updated.csv`, `ca/weburl_2024_updated.csv` (originals)
- `us/xml_sample/*.xml` (officer, director, key-employee and preparer names), `us/eo_bmf/eo1-4.csv` (contain `ICO`)
- `pl/krs_sample/*.json` raw files and `_fetch_log.csv`; the August wykaz (superseded)
- UK `.zip` files in general (unzip-in-notebook not needed; we upload the txt)
- anything not produced by `stage_upload.py`

`stage_upload.py` hard-fails if a deny-listed path is in the copy list.
