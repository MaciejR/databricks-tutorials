-- E4 fallback, file 1 of 3: BRONZE (updated 10 Nov 2026 after the 30 Oct rehearsal) (Lakeflow Declarative Pipeline, SQL, serverless, triggered)
-- Target: workspace.charity_lens. Source: UC volume /Volumes/workspace/charity_lens/raw/ (staged by upload/stage_upload.py)
-- Bronze = files as delivered, all columns STRING, plus _source_file + _ingested_at. No personal-data columns exist in these files.
-- Ran end-to-end on Free Edition (rehearsal 30 Oct 2026, run 6). Fixes since: escape => '"' on comma CSVs (PL had 3 broken rows),
-- US/AU address-like columns dropped in bronze. Headers with spaces are renamed here (columnMapping does NOT work in pipeline MVs).

-- UK (Charity Commission for England and Wales, OGL v3.0). Tab-separated, unescaped quotes -> quote disabled.
CREATE OR REFRESH MATERIALIZED VIEW bronze_uk_charity
COMMENT 'CCEW register extract 2026-10-23, contact details removed (.nopii). One row per charity or linked charity. OGL v3.0.'
AS SELECT *, _metadata.file_path AS _source_file, current_timestamp() AS _ingested_at
FROM read_files('/Volumes/workspace/charity_lens/raw/uk/publicextract.charity.nopii.txt',
  format => 'csv', sep => '\t', header => true, quote => '', inferSchema => false); -- quote => '' disables quoting (verified in rehearsal)

CREATE OR REFRESH MATERIALIZED VIEW bronze_uk_classification
COMMENT 'CCEW classification (What/Who/How codes). OGL v3.0.'
AS SELECT *, _metadata.file_path AS _source_file, current_timestamp() AS _ingested_at
FROM read_files('/Volumes/workspace/charity_lens/raw/uk/publicextract.charity_classification.txt',
  format => 'csv', sep => '\t', header => true, quote => '', inferSchema => false);

CREATE OR REFRESH MATERIALIZED VIEW bronze_uk_area_of_operation
COMMENT 'CCEW area of operation (countries, regions, local authorities). OGL v3.0.'
AS SELECT *, _metadata.file_path AS _source_file, current_timestamp() AS _ingested_at
FROM read_files('/Volumes/workspace/charity_lens/raw/uk/publicextract.charity_area_of_operation.txt',
  format => 'csv', sep => '\t', header => true, quote => '', inferSchema => false);

CREATE OR REFRESH MATERIALIZED VIEW bronze_uk_partb
COMMENT 'CCEW annual return part B (larger charities only): detailed income, spend, employees. OGL v3.0.'
AS SELECT *, _metadata.file_path AS _source_file, current_timestamp() AS _ingested_at
FROM read_files('/Volumes/workspace/charity_lens/raw/uk/publicextract.charity_annual_return_partb.txt',
  format => 'csv', sep => '\t', header => true, quote => '', inferSchema => false);
-- annual_return_history (231 MB) is staged for E5 trend work; not read in E4 to save Free Edition quota.

-- Canada (CRA T3010 2024 fiscal periods, OGL-Canada 2.0). Headers with spaces renamed to snake_case.
CREATE OR REFRESH MATERIALIZED VIEW bronze_ca_ident
COMMENT 'CRA T3010 2024 identification, street address and full postal code removed (.nopii). One row per BN.'
AS SELECT 
  `BN`,
  `Category`,
  `Sub Category` AS sub_category,
  `Designation`,
  `Legal Name` AS legal_name,
  `Account Name` AS account_name,
  `City`,
  `Province`,
  `Country`,
  `Postal FSA` AS postal_fsa,
  _metadata.file_path AS _source_file, current_timestamp() AS _ingested_at
FROM read_files('/Volumes/workspace/charity_lens/raw/ca/ident_2024_updated.nopii.csv', format => 'csv', header => true, escape => '"', inferSchema => false);

CREATE OR REFRESH MATERIALIZED VIEW bronze_ca_financial_d
COMMENT 'CRA T3010 2024 Section D / Schedule 6 financials (line numbers as column names).'
AS SELECT 
  `BN`,
  `FPE`,
  `Form ID` AS form_id,
  `Section Used` AS section_used,
  `4020`,
  `4050`,
  `4100`,
  `4110`,
  `4120`,
  `4130`,
  `4140`,
  `4150`,
  `4155`,
  `4160`,
  `4165`,
  `4166`,
  `4170`,
  `4180`,
  `4200`,
  `4250`,
  `4300`,
  `4310`,
  `4320`,
  `4330`,
  `4350`,
  `4400`,
  `4490`,
  `4500`,
  `5610`,
  `4505`,
  `4510`,
  `4530`,
  `4540`,
  `4550`,
  `4560`,
  `4565`,
  `4570`,
  `4571`,
  `4575`,
  `4580`,
  `4590`,
  `4600`,
  `4610`,
  `4620`,
  `4630`,
  `4640`,
  `4650`,
  `4655`,
  `4700`,
  `4800`,
  `4810`,
  `4820`,
  `4830`,
  `4840`,
  `4850`,
  `4860`,
  `4870`,
  `4880`,
  `4890`,
  `4891`,
  `4900`,
  `4910`,
  `4920`,
  `4930`,
  `4950`,
  `5000`,
  `5010`,
  `5020`,
  `5030`,
  `5040`,
  `5050`,
  `5100`,
  `5500`,
  `5510`,
  `5750`,
  `5900`,
  `5910`,
  `5045`,
  `4101`,
  `4102`,
  `4157`,
  `4158`,
  `4190`,
  `4576`,
  `4577`,
  _metadata.file_path AS _source_file, current_timestamp() AS _ingested_at
FROM read_files('/Volumes/workspace/charity_lens/raw/ca/financial_d_and_schedule_6_2024_updated.csv', format => 'csv', header => true, escape => '"', inferSchema => false);

CREATE OR REFRESH MATERIALIZED VIEW bronze_ca_schedule_2_details
COMMENT 'CRA T3010 2024 Schedule 2 (activities outside Canada) totals.'
AS SELECT 
  `BN`,
  `FPE`,
  `Form ID` AS form_id,
  `200`,
  `210`,
  `220`,
  `230`,
  `240`,
  `250`,
  `260`,
  _metadata.file_path AS _source_file, current_timestamp() AS _ingested_at
FROM read_files('/Volumes/workspace/charity_lens/raw/ca/schedule_2_details_2024.csv', format => 'csv', header => true, escape => '"', inferSchema => false);

CREATE OR REFRESH MATERIALIZED VIEW bronze_ca_schedule_2_countries
COMMENT 'CRA T3010 2024 Schedule 2 countries (ISO2 + CRA Q-code regions).'
AS SELECT 
  `BN`,
  `FPE`,
  `Form ID` AS form_id,
  `#`,
  `Country`,
  _metadata.file_path AS _source_file, current_timestamp() AS _ingested_at
FROM read_files('/Volumes/workspace/charity_lens/raw/ca/schedule_2_countries_2024.csv', format => 'csv', header => true, escape => '"', inferSchema => false);

CREATE OR REFRESH MATERIALIZED VIEW bronze_ca_weburl
COMMENT 'CRA contact URLs; e-mail entries removed (.nopii).'
AS SELECT 
  `BN/NE`,
  `#`,
  `Contact URL` AS contact_url,
  _metadata.file_path AS _source_file, current_timestamp() AS _ingested_at
FROM read_files('/Volumes/workspace/charity_lens/raw/ca/weburl_2024_updated.nopii.csv', format => 'csv', header => true, escape => '"', inferSchema => false);

-- Australia (ACNC, CC BY 3.0 AU).
CREATE OR REFRESH MATERIALIZED VIEW bronze_au_register
COMMENT 'ACNC Charity Register, address lines removed (.nopii); Address_Type and Postcode not loaded. One row per ABN (607 rows have no ABN: dropped in silver). CC BY 3.0 AU.'
AS SELECT * EXCEPT (Address_Type, Postcode), _metadata.file_path AS _source_file, current_timestamp() AS _ingested_at
FROM read_files('/Volumes/workspace/charity_lens/raw/au/datadotgov_main.nopii.csv', format => 'csv', header => true, escape => '"', multiLine => true, inferSchema => false);

CREATE OR REFRESH MATERIALIZED VIEW bronze_au_ais24
COMMENT 'ACNC 2024 Annual Information Statement, related-party and KMP pay columns removed (.nopii). CC BY 3.0 AU.'
AS SELECT 
  `abn`,
  `charity name` AS charity_name,
  `registration status` AS registration_status,
  `charity website` AS charity_website,
  `charity size` AS charity_size,
  `basic religious charity` AS basic_religious_charity,
  `ais due date` AS ais_due_date,
  `date ais received` AS date_ais_received,
  `financial report date received` AS financial_report_date_received,
  `conducted activities` AS conducted_activities,
  `international activities details` AS international_activities_details,
  `international activities undertaken - transferring goods or services overseas` AS international_activities_undertaken_transferring_goods_or_services_overseas,
  `international activities undertaken - operating overseas including programs` AS international_activities_undertaken_operating_overseas_including_programs,
  `other international activities` AS other_international_activities,
  `how purposes were pursued` AS how_purposes_were_pursued,
  `staff - full time` AS staff_full_time,
  `staff - part time` AS staff_part_time,
  `staff - casual` AS staff_casual,
  `total full time equivalent staff` AS total_full_time_equivalent_staff,
  `staff - volunteers` AS staff_volunteers,
  `cash or accrual` AS cash_or_accrual,
  `type of financial statement` AS type_of_financial_statement,
  `report consolidated with more than one entity` AS report_consolidated_with_more_than_one_entity,
  `charity report has a modification` AS charity_report_has_a_modification,
  `type of report modification` AS type_of_report_modification,
  `charity has reportable related party transactions` AS charity_has_reportable_related_party_transactions,
  `fin report from` AS fin_report_from,
  `fin report to` AS fin_report_to,
  `revenue from government` AS revenue_from_government,
  `donations and bequests` AS donations_and_bequests,
  `revenue from goods and services` AS revenue_from_goods_and_services,
  `revenue from investments` AS revenue_from_investments,
  `all other revenue` AS all_other_revenue,
  `total revenue` AS total_revenue,
  `other income` AS other_income,
  `total gross income` AS total_gross_income,
  `employee expenses` AS employee_expenses,
  `interest expenses` AS interest_expenses,
  `grants and donations made for use in Australia` AS grants_and_donations_made_for_use_in_australia,
  `grants and donations made for use outside Australia` AS grants_and_donations_made_for_use_outside_australia,
  `all other expenses` AS all_other_expenses,
  `total expenses` AS total_expenses,
  `net surplus/deficit` AS net_surplus_deficit,
  `other comprehensive income` AS other_comprehensive_income,
  `total comprehensive income` AS total_comprehensive_income,
  `total current assets` AS total_current_assets,
  `non-current loans receivable` AS non_current_loans_receivable,
  `other non-current assets` AS other_non_current_assets,
  `total non-current assets` AS total_non_current_assets,
  `total assets` AS total_assets,
  `total current liabilities` AS total_current_liabilities,
  `non-current loans payable` AS non_current_loans_payable,
  `other non-current liabilities` AS other_non_current_liabilities,
  `total non-current liabilities` AS total_non_current_liabilities,
  `total liabilities` AS total_liabilities,
  `net assets/liabilities` AS net_assets_liabilities,
  `coop financial report submitted to regulator` AS coop_financial_report_submitted_to_regulator,
  `incorporated association` AS incorporated_association,
  `association number - act` AS association_number_act,
  `association number - nsw` AS association_number_nsw,
  `association number - nt` AS association_number_nt,
  `association number - qld` AS association_number_qld,
  `association number - sa` AS association_number_sa,
  `association number - tas` AS association_number_tas,
  `association number - vic` AS association_number_vic,
  `association number - wa` AS association_number_wa,
  `fundraising - act` AS fundraising_act,
  `fundraising number - act` AS fundraising_number_act,
  `fundraising - nsw` AS fundraising_nsw,
  `fundraising number - nsw` AS fundraising_number_nsw,
  `fundraising - nt` AS fundraising_nt,
  `fundraising - qld` AS fundraising_qld,
  `fundraising number - qld` AS fundraising_number_qld,
  `fundraising - sa` AS fundraising_sa,
  `fundraising number - sa` AS fundraising_number_sa,
  `fundraising - tas` AS fundraising_tas,
  `fundraising number - tas` AS fundraising_number_tas,
  `fundraising - vic` AS fundraising_vic,
  `fundraising number - vic` AS fundraising_number_vic,
  `fundraising - wa` AS fundraising_wa,
  `fundraising number - wa` AS fundraising_number_wa,
  `fundraising - online` AS fundraising_online,
  `Number of Key Management Personnel` AS number_of_key_management_personnel,
  _metadata.file_path AS _source_file, current_timestamp() AS _ingested_at
FROM read_files('/Volumes/workspace/charity_lens/raw/au/datadotgov_ais24.nopii.csv', format => 'csv', header => true, escape => '"', multiLine => true, inferSchema => false);

-- United States (IRS; public domain US Government work for IRS-compiled data, credit requested).
CREATE OR REFRESH MATERIALIZED VIEW bronze_us_bmf
COMMENT 'IRS EO Business Master File (eo1-4 merged), in-care-of name removed (.nopii); STREET and ZIP not loaded. One row per EIN.'
AS SELECT * EXCEPT (STREET, ZIP), _metadata.file_path AS _source_file, current_timestamp() AS _ingested_at
FROM read_files('/Volumes/workspace/charity_lens/raw/us/eo_bmf_all.nopii.csv', format => 'csv', header => true, escape => '"', inferSchema => false);

CREATE OR REFRESH MATERIALIZED VIEW bronze_us_990_index
COMMENT 'IRS TEOS 990 e-file index, submissions in 2026. One row per filed return.'
AS SELECT *, _metadata.file_path AS _source_file, current_timestamp() AS _ingested_at
FROM read_files('/Volumes/workspace/charity_lens/raw/us/index_2026.csv', format => 'csv', header => true, escape => '"', inferSchema => false);

CREATE OR REFRESH MATERIALIZED VIEW bronze_us_990_sample
COMMENT 'Org-level fields parsed from a random sample of 500 990 XMLs (no people, no free text). Sample, not population.'
AS SELECT *, _metadata.file_path AS _source_file, current_timestamp() AS _ingested_at
FROM read_files('/Volumes/workspace/charity_lens/raw/us/irs990_sample_org.nopii.csv', format => 'csv', header => true, escape => '"', inferSchema => false);

-- Poland (NIW-CRSO wykaz OPP, CC0 1.0; KRS API sample, Open Data Act reuse). Doubled quotes in names -> escape => '"' is required.
CREATE OR REFRESH MATERIALIZED VIEW bronze_pl_opp
COMMENT 'NIW-CRSO list of OPPs eligible for 1.5% PIT in 2026 (update 13 Oct 2026), CSV converted from the CC0 XLSX.'
AS SELECT *, _metadata.file_path AS _source_file, current_timestamp() AS _ingested_at
FROM read_files('/Volumes/workspace/charity_lens/raw/pl/wykaz_opp_2025_w_2026_10_2026.csv', format => 'csv', header => true, escape => '"', multiLine => true, inferSchema => false);

CREATE OR REFRESH MATERIALIZED VIEW bronze_pl_krs_sample
COMMENT 'Org-level fields from KRS OdpisAktualny for a random sample of 200 OPPs (no people, no e-mail).'
AS SELECT *, _metadata.file_path AS _source_file, current_timestamp() AS _ingested_at
FROM read_files('/Volumes/workspace/charity_lens/raw/pl/krs_sample_org.nopii.csv', format => 'csv', header => true, escape => '"', multiLine => true, inferSchema => false);

-- Reference lookups (from this repo).
CREATE OR REFRESH MATERIALIZED VIEW ref_cause_map
COMMENT 'Hand-made mapping from each register''s cause codes to the Charity Lens cause vocabulary (v0, E4). Reviewed in E5.'
AS SELECT * FROM read_files('/Volumes/workspace/charity_lens/raw/ref/cause_map.csv', format => 'csv', header => true, escape => '"', inferSchema => false);
