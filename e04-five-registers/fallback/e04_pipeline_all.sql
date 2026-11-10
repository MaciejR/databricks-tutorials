-- E4 fallback, ALL-IN-ONE pipeline source (bronze + silver + gold) for pasting if Genie Code diverges on camera.
-- = work/rehearsal/e04_pipeline_all.sql (completed on Free Edition, 30 Oct 2026, run 6) + fixes of 10 Nov 2026:
--   * bronze: escape => '"' on all comma CSVs (PL had 3 broken rows without it); US BMF without STREET/ZIP, AU register without Address_Type/Postcode
--   * silver AU: only 11-digit ABNs (607 register rows have none), one register row and one AIS row per ABN
--   * silver PL: KRS must be numeric (10 digits), one row per KRS, line breaks in names collapsed
--   * gold_jurisdiction_summary: median over income > 0 only, with share_zero_income, orgs_in_median, median_basis
-- Pipeline: SQL, serverless, TRIGGERED (never continuous), target catalog workspace, schema charity_lens. Add this ONE file as source code
-- (do not also add e04_bronze/silver/gold.sql, or every dataset is defined twice). Then run e04_checks.sql and e04_licence_tags.sql.

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

-- E4 fallback, file 2 of 3: SILVER (updated 10 Nov 2026 after the 30 Oct rehearsal), one conformed table per jurisdiction (same column list in all five).
-- Money stays in the original currency (amount + currency code). No FX conversion here (see gold + fx_rates_template.csv).
-- Rows: exactly ONE row per charity_id (checked in e04_checks.sql). Rows without a usable source ID are dropped, not invented.
-- Causes: array of Charity Lens causes via ref_cause_map. Rehearsal lessons (30 Oct): typed empty arrays CAST(array() AS ARRAY<STRING>),
-- type-proof joins (trim/CAST both sides), explode in a subquery before a JOIN (LATERAL VIEW + JOIN failed to parse).

-- ===== UK (England & Wales) =====
CREATE OR REFRESH MATERIALIZED VIEW silver_uk_charities
COMMENT 'Registered main charities in England & Wales (linked_charity_number = 0), latest income/expenditure in GBP.'
AS
WITH c AS (
  SELECT * FROM bronze_uk_charity
  WHERE trim(CAST(charity_registration_status AS STRING)) = 'Registered' AND try_cast(trim(CAST(linked_charity_number AS STRING)) AS INT) = 0
),
causes AS (
  SELECT k.registered_charity_number,
         array_sort(collect_set(trim(m.cause))) AS causes,
         array_sort(collect_set(k.classification_description)) AS causes_source_labels
  FROM bronze_uk_classification k
  JOIN ref_cause_map m ON m.jurisdiction = 'GB-EAW' AND m.source_code_type = 'ccew_classification_what'
                      AND trim(m.source_code) = trim(CAST(k.classification_code AS STRING))
  WHERE k.classification_type = 'What' AND try_cast(trim(CAST(k.linked_charity_number AS STRING)) AS INT) = 0
  GROUP BY k.registered_charity_number
),
countries AS (
  SELECT registered_charity_number, array_sort(collect_set(geographic_area_description)) AS programme_countries
  FROM bronze_uk_area_of_operation
  WHERE geographic_area_type = 'Country' AND try_cast(trim(CAST(linked_charity_number AS STRING)) AS INT) = 0
  GROUP BY registered_charity_number
),
pb AS (
  SELECT registered_charity_number,
         try_cast(expenditure_charitable_expenditure AS DECIMAL(18,2)) AS charitable_spending,
         try_cast(expenditure_raising_funds AS DECIMAL(18,2)) AS fundraising_spending,
         try_cast(count_employees AS INT) AS employees
  FROM bronze_uk_partb
  WHERE latest_fin_period_submitted_ind = 'True' AND fin_period_order_number = '1' -- checked locally: True|1 = 17,771 rows
)
SELECT
  concat('GB-CHC-', c.registered_charity_number)          AS charity_id,
  'GB-EAW'                                                AS jurisdiction,
  c.registered_charity_number                             AS source_id,
  c.charity_name                                          AS name,
  c.charity_type                                          AS legal_form,
  c.charity_registration_status                           AS registration_status,
  try_to_date(left(c.date_of_registration, 10))               AS registration_date,
  coalesce(causes.causes, CAST(array() AS ARRAY<STRING>))                        AS causes,
  coalesce(causes.causes_source_labels, CAST(array() AS ARRAY<STRING>))          AS causes_source_labels,
  CAST(NULL AS STRING)                                    AS region_admin1,
  c.charity_contact_postcode_district                     AS locality,
  coalesce(countries.programme_countries, CAST(array() AS ARRAY<STRING>))        AS programme_countries,
  try_to_date(left(c.latest_acc_fin_period_end_date, 10))     AS fiscal_year_end,
  try_cast(c.latest_income AS DECIMAL(18,2))              AS income,
  try_cast(c.latest_expenditure AS DECIMAL(18,2))         AS expenditure,
  pb.charitable_spending,
  pb.fundraising_spending,
  'GBP'                                                   AS currency,
  pb.employees,
  c.charity_contact_web                                   AS website,
  'Charity Commission for England and Wales, Register of Charities (extract 2026-10-23)' AS source,
  'https://register-of-charities.charitycommission.gov.uk/en/register/full-register-download' AS source_url,
  'OGL-UK-3.0'                                            AS licence
FROM c
LEFT JOIN causes    ON causes.registered_charity_number    = c.registered_charity_number
LEFT JOIN countries ON countries.registered_charity_number = c.registered_charity_number
LEFT JOIN pb        ON pb.registered_charity_number        = c.registered_charity_number;

-- ===== Canada =====
CREATE OR REFRESH MATERIALIZED VIEW silver_ca_charities
COMMENT 'CRA registered charities with a 2024 T3010 (latest FPE per BN), amounts in CAD.'
AS
WITH fin AS (
  SELECT *, row_number() OVER (PARTITION BY BN ORDER BY FPE DESC) AS rn FROM bronze_ca_financial_d
),
s2 AS (SELECT BN, FPE, try_cast(`200` AS DECIMAL(18,2)) AS overseas_spend FROM bronze_ca_schedule_2_details),
ctry AS (SELECT BN, FPE, array_sort(collect_set(Country)) AS programme_countries FROM bronze_ca_schedule_2_countries GROUP BY BN, FPE),
web AS (
  SELECT `BN/NE` AS BN,
         min_by(CASE WHEN lower(contact_url) LIKE 'http%' THEN lower(contact_url) ELSE concat('https://', lower(contact_url)) END, `#`) AS website
  FROM bronze_ca_weburl GROUP BY `BN/NE`
)
SELECT
  concat('CA-CRA-', i.BN)                                  AS charity_id,
  'CA'                                                     AS jurisdiction,
  i.BN                                                     AS source_id,
  i.legal_name                                           AS name,
  CASE i.Designation WHEN 'A' THEN 'Public foundation' WHEN 'B' THEN 'Private foundation'
                     WHEN 'C' THEN 'Charitable organization' END AS legal_form,
  'Registered'                                             AS registration_status,
  CAST(NULL AS DATE)                                       AS registration_date,
  CASE WHEN m.cause IS NULL THEN CAST(array() AS ARRAY<STRING>) ELSE array(CAST(m.cause AS STRING)) END AS causes,
  CASE WHEN m.source_label IS NULL THEN CAST(array() AS ARRAY<STRING>) ELSE array(CAST(m.source_label AS STRING)) END AS causes_source_labels,
  i.Province                                               AS region_admin1,
  i.City                                                   AS locality,
  coalesce(ctry.programme_countries, CAST(array() AS ARRAY<STRING>))              AS programme_countries, -- Q-codes = CRA regions, not ISO2
  try_to_date(f.FPE)                                           AS fiscal_year_end,
  try_cast(f.`4700` AS DECIMAL(18,2))                      AS income,
  try_cast(f.`5100` AS DECIMAL(18,2))                      AS expenditure,
  try_cast(f.`5000` AS DECIMAL(18,2))                      AS charitable_spending,
  try_cast(f.`5020` AS DECIMAL(18,2))                      AS fundraising_spending,
  'CAD'                                                    AS currency,
  CAST(NULL AS INT)                                        AS employees, -- E5: Schedule 3 lines 300 + 370
  web.website,
  'Canada Revenue Agency, T3010 charity information returns, 2024 fiscal periods' AS source,
  'https://open.canada.ca/data/dataset/80c00cdb-1358-415c-bb8b-0de7f12675b8' AS source_url,
  'OGL-Canada-2.0'                                         AS licence
FROM bronze_ca_ident i
LEFT JOIN fin f    ON f.BN = i.BN AND f.rn = 1
LEFT JOIN s2       ON s2.BN = f.BN AND s2.FPE = f.FPE
LEFT JOIN ctry     ON ctry.BN = f.BN AND ctry.FPE = f.FPE
LEFT JOIN web      ON web.BN = i.BN
LEFT JOIN ref_cause_map m ON m.jurisdiction = 'CA' AND m.source_code_type = 'cra_category' AND try_cast(trim(m.source_code) AS INT) = try_cast(trim(CAST(i.Category AS STRING)) AS INT);

-- ===== Australia =====
CREATE OR REFRESH MATERIALIZED VIEW silver_au_charities
COMMENT 'ACNC registered charities with 2024 AIS financials where available, amounts in AUD. One row per ABN; register rows without an ABN (withheld entries) are excluded.'
AS
-- Dedup (rehearsal: bronze 66,514 -> silver 66,515). Cause: 607 register rows have an EMPTY ABN (they all became AU-ABN-00000000000)
-- and one ABN appears twice in the 2024 AIS. Rule: keep only 11-digit ABNs; one register row per ABN; one AIS row per ABN (latest period).
WITH r AS (
  SELECT * FROM (
    SELECT *, row_number() OVER (PARTITION BY abn11 ORDER BY try_to_date(Registration_Date, 'dd/MM/yyyy') DESC) AS rn_reg
    FROM (SELECT *, regexp_replace(CAST(ABN AS STRING), '[^0-9]', '') AS abn11 FROM bronze_au_register)
    WHERE length(abn11) = 11
  ) WHERE rn_reg = 1
),
purposes AS (
  SELECT abn11, array_sort(collect_set(trim(m.cause))) AS causes, array_sort(collect_set(m.source_code)) AS labels
  FROM (SELECT abn11, stack(12,
          'Preventing_or_relieving_suffering_of_animals', Preventing_or_relieving_suffering_of_animals,
          'Advancing_Culture', Advancing_Culture,
          'Advancing_Education', Advancing_Education,
          'Advancing_Health', Advancing_Health,
          'Promote_or_oppose_a_change_to_law__government_poll_or_prac', Promote_or_oppose_a_change_to_law__government_poll_or_prac,
          'Advancing_natual_environment', Advancing_natual_environment,
          'Promoting_or_protecting_human_rights', Promoting_or_protecting_human_rights,
          'Purposes_beneficial_to_ther_general_public_and_other_analogous', Purposes_beneficial_to_ther_general_public_and_other_analogous,
          'Promoting_reconciliation__mutual_respect_and_tolerance', Promoting_reconciliation__mutual_respect_and_tolerance,
          'Advancing_Religion', Advancing_Religion,
          'Advancing_social_or_public_welfare', Advancing_social_or_public_welfare,
          'Advancing_security_or_safety_of_Australia_or_Australian_public', Advancing_security_or_safety_of_Australia_or_Australian_public
        ) AS (flag, val) FROM r) p
  JOIN ref_cause_map m ON m.jurisdiction = 'AU' AND m.source_code_type = 'acnc_purpose_flag' AND trim(m.source_code) = p.flag
  WHERE upper(trim(CAST(p.val AS STRING))) = 'Y'
  GROUP BY abn11
),
ais AS (
  SELECT * FROM (
    SELECT *, row_number() OVER (PARTITION BY abn11
             ORDER BY try_to_date(fin_report_to, 'dd/MM/yyyy') DESC, try_to_date(date_ais_received, 'dd/MM/yyyy') DESC,
                      try_cast(total_revenue AS DECIMAL(18,2)) DESC) AS rn_ais
    FROM (SELECT *, lpad(regexp_replace(CAST(abn AS STRING), '[^0-9]', ''), 11, '0') AS abn11 FROM bronze_au_ais24)
  ) WHERE rn_ais = 1
)
SELECT
  concat('AU-ABN-', r.abn11)                                AS charity_id,
  'AU'                                                      AS jurisdiction,
  r.abn11                                                   AS source_id,
  r.Charity_Legal_Name                                      AS name,
  r.Charity_Size                                            AS legal_form, -- size band; legal form not in the register file
  'Registered'                                              AS registration_status,
  try_to_date(r.Registration_Date, 'dd/MM/yyyy')                AS registration_date,
  coalesce(purposes.causes, CAST(array() AS ARRAY<STRING>))                        AS causes,
  coalesce(purposes.labels, CAST(array() AS ARRAY<STRING>))                        AS causes_source_labels,
  r.State                                                   AS region_admin1,
  r.Town_City                                               AS locality,
  CASE WHEN r.Operating_Countries IS NULL OR r.Operating_Countries = '' THEN CAST(array() AS ARRAY<STRING>)
       ELSE split(r.Operating_Countries, '\\s*[,;]\\s*') END AS programme_countries, -- ISO3 codes (e.g. AUS), unlike ISO2 elsewhere: normalise in E5
  try_to_date(ais.fin_report_to, 'dd/MM/yyyy')                AS fiscal_year_end,
  try_cast(ais.total_revenue AS DECIMAL(18,2))            AS income,
  try_cast(ais.total_expenses AS DECIMAL(18,2))           AS expenditure,
  CAST(NULL AS DECIMAL(18,2))                               AS charitable_spending, -- AIS has no programme/admin split
  CAST(NULL AS DECIMAL(18,2))                               AS fundraising_spending,
  'AUD'                                                     AS currency,
  CAST(round(try_cast(ais.total_full_time_equivalent_staff AS DOUBLE)) AS INT) AS employees, -- FTE, rounded
  r.Charity_Website                                         AS website,
  'Australian Charities and Not-for-profits Commission (ACNC) Charity Register and 2024 AIS, data.gov.au' AS source,
  'https://data.gov.au/data/dataset/acnc-register' AS source_url,
  'CC-BY-3.0-AU'                                            AS licence
FROM r
LEFT JOIN purposes ON purposes.abn11 = r.abn11
LEFT JOIN ais      ON ais.abn11 = r.abn11;

-- ===== United States =====
CREATE OR REFRESH MATERIALIZED VIEW silver_us_charities
COMMENT '501(c)(3) organisations from the IRS EO BMF; revenue from the BMF (latest return on file), cause = NTEE major group. 990 XML figures only for the 500-file sample (see bronze_us_990_sample).'
AS
SELECT
  concat('US-EIN-', lpad(b.EIN, 9, '0'))                    AS charity_id,
  'US'                                                      AS jurisdiction,
  lpad(b.EIN, 9, '0')                                       AS source_id,
  b.NAME                                                    AS name,
  CASE WHEN b.FOUNDATION IN ('02','03','04') THEN 'Private foundation' ELSE '501(c)(3) public charity' END AS legal_form, -- [VERIFY] FOUNDATION codes
  'Exempt (BMF)'                                            AS registration_status,
  try_to_date(b.RULING, 'yyyyMM')                               AS registration_date, -- ruling date, not registration
  CASE WHEN m.cause IS NULL THEN CAST(array() AS ARRAY<STRING>) ELSE array(CAST(m.cause AS STRING)) END AS causes,
  CASE WHEN m.source_label IS NULL THEN CAST(array() AS ARRAY<STRING>) ELSE array(CAST(m.source_label AS STRING)) END AS causes_source_labels,
  b.STATE                                                   AS region_admin1,
  b.CITY                                                    AS locality,
  CAST(array() AS ARRAY<STRING>)                                                   AS programme_countries, -- E5: Schedule F regions from 990
  last_day(try_to_date(b.TAX_PERIOD, 'yyyyMM'))                 AS fiscal_year_end,
  coalesce(try_cast(s.total_revenue AS DECIMAL(18,2)), try_cast(b.REVENUE_AMT AS DECIMAL(18,2))) AS income,
  try_cast(s.total_expenses AS DECIMAL(18,2))               AS expenditure, -- BMF has no expenses
  CAST(NULL AS DECIMAL(18,2))                               AS charitable_spending,
  CAST(NULL AS DECIMAL(18,2))                               AS fundraising_spending,
  'USD'                                                     AS currency,
  try_cast(s.total_employees AS INT)                        AS employees,
  s.website                                                 AS website,
  'U.S. Internal Revenue Service, Exempt Organizations Business Master File and Form 990 series e-file data' AS source,
  'https://www.irs.gov/charities-non-profits/exempt-organizations-business-master-file-extract-eo-bmf' AS source_url,
  'US-PD (IRS-compiled; credit requested)'                  AS licence
FROM bronze_us_bmf b
LEFT JOIN ref_cause_map m ON m.jurisdiction = 'US' AND m.source_code_type = 'ntee_major_group' AND trim(m.source_code) = upper(left(trim(b.NTEE_CD), 1))
LEFT JOIN (SELECT *, row_number() OVER (PARTITION BY ein ORDER BY tax_period_end DESC) rn FROM bronze_us_990_sample) s
       ON lpad(s.ein, 9, '0') = lpad(b.EIN, 9, '0') AND s.rn = 1
WHERE lpad(trim(CAST(b.SUBSECTION AS STRING)), 2, '0') = '03';

-- ===== Poland =====
CREATE OR REFRESH MATERIALIZED VIEW silver_pl_charities
COMMENT 'Polish OPPs eligible for 1.5% PIT in 2026 (NIW-CRSO list). OPP is a status, not a legal charity category. No financials in open data; causes only for the 200-entity KRS sample. One row per KRS.'
AS
-- Rehearsal had 9,607 rows for 9,604 OPPs: without escape => '"' in bronze, 3 names with doubled quotes split into broken rows
-- (nr_krs = a voivodeship name). Guard here too: KRS must be 10 digits, one row per KRS.
WITH o AS (
  SELECT * FROM (
    SELECT *, lpad(trim(CAST(nr_krs AS STRING)), 10, '0') AS krs10,
           row_number() OVER (PARTITION BY lpad(trim(CAST(nr_krs AS STRING)), 10, '0') ORDER BY try_cast(regexp_replace(lp, '[^0-9]', '') AS INT)) AS rn_opp
    FROM bronze_pl_opp
    WHERE trim(CAST(nr_krs AS STRING)) RLIKE '^[0-9]{1,10}$'
  ) WHERE rn_opp = 1
),
k AS (SELECT *, lpad(trim(CAST(krs AS STRING)), 10, '0') AS krs10 FROM bronze_pl_krs_sample),
kc AS (
  SELECT e.krs10, array_sort(collect_set(trim(m.cause))) AS causes, array_sort(collect_set(m.source_label)) AS labels
  FROM (SELECT krs10, explode(split(pkd_opp_codes, '\\|')) AS code FROM k) e
  JOIN ref_cause_map m ON m.jurisdiction = 'PL' AND m.source_code_type = 'pkd_division_opp' AND trim(m.source_code) = trim(split(e.code, '\\.')[0])
  GROUP BY e.krs10
)
SELECT
  concat('PL-KRS-', o.krs10)                                AS charity_id,
  'PL'                                                      AS jurisdiction,
  o.krs10                                                   AS source_id,
  trim(regexp_replace(o.nazwa, '\\s+', ' '))                AS name, -- 21 names contain line breaks
  k.forma_prawna                                            AS legal_form, -- sample only
  'OPP eligible for 1.5% (2026)'                            AS registration_status,
  try_to_date(k.data_rejestracji, 'dd.MM.yyyy')                 AS registration_date,
  coalesce(kc.causes, CAST(array() AS ARRAY<STRING>))                              AS causes,
  coalesce(kc.labels, CAST(array() AS ARRAY<STRING>))                              AS causes_source_labels,
  o.wojewodztwo                                             AS region_admin1,
  o.miejscowosc                                             AS locality,
  CAST(array() AS ARRAY<STRING>)                                                   AS programme_countries,
  CAST(NULL AS DATE)                                        AS fiscal_year_end,
  CAST(NULL AS DECIMAL(18,2))                               AS income,
  CAST(NULL AS DECIMAL(18,2))                               AS expenditure,
  CAST(NULL AS DECIMAL(18,2))                               AS charitable_spending,
  CAST(NULL AS DECIMAL(18,2))                               AS fundraising_spending,
  'PLN'                                                     AS currency,
  CAST(NULL AS INT)                                         AS employees,
  CAST(NULL AS STRING)                                      AS website,
  'Narodowy Instytut Wolności – CRSO, Wykaz OPP 1,5% (dane.gov.pl); Ministerstwo Sprawiedliwości, KRS API (sample)' AS source,
  'https://dane.gov.pl/pl/dataset/20137' AS source_url, -- [VERIFY] public page URL (API: https://api.dane.gov.pl/1.4/datasets/20137)
  'CC0-1.0 (wykaz); KRS Open Data Act reuse'                AS licence
FROM o
LEFT JOIN k  ON k.krs10  = o.krs10
LEFT JOIN kc ON kc.krs10 = o.krs10;

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
