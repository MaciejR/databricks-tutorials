-- E5 fallback, file 1 of 5: REFERENCE ENTITIES (Jurisdiction, Cause, Country).
-- Run in the SQL EDITOR on the SQL warehouse, catalog workspace, schema charity_lens.
-- Before: upload jurisdictions.csv, causes.csv and country_map.csv from this folder to
--         /Volumes/workspace/charity_lens/raw/ref/ (Catalog Explorer > raw > ref > Upload to this volume).
-- These are plain Delta tables (not pipeline datasets), so primary and foreign keys can be added with ALTER TABLE (file 3).
-- Re-running: file 3 adds foreign keys. If you re-run this file after file 3, run the "reset" block at the top of file 3 first.

USE CATALOG workspace;
USE SCHEMA charity_lens;

-- Jurisdiction: one row per register. Holds what "charity" means there, who regulates it, what money and cause data exist.
CREATE OR REPLACE TABLE ont_jurisdiction
COMMENT 'Charity Lens ontology, entity Jurisdiction: one row per national register (GB-EAW, CA, AU, US, PL). charity_definition says what a row in that register means. Read it before comparing countries.'
AS SELECT
  trim(jurisdiction)                         AS jurisdiction,
  trim(home_iso2)                            AS home_iso2,
  jurisdiction_name, regulator, legal_basis,
  trim(charity_concept)                      AS charity_concept,
  charity_definition, register_scope, currency, income_definition,
  CAST(has_income AS BOOLEAN)                AS has_income,
  has_spending_breakdown, cause_source, programme_country_source, comparability_note,
  source, source_url, licence
FROM read_files('/Volumes/workspace/charity_lens/raw/ref/jurisdictions.csv',
                format => 'csv', header => true, escape => '"', multiLine => true, inferSchema => false);

-- Cause: the Charity Lens cause vocabulary (v1), with a top-level group and synonyms for search and Genie.
CREATE OR REPLACE TABLE ont_cause
COMMENT 'Charity Lens ontology, entity Cause: the shared cause vocabulary (v1). Each register''s own codes map to it through ont_cause_crosswalk. cause_group is a coarser level for charts.'
AS SELECT
  trim(cause) AS cause, display_name, description, trim(cause_group) AS cause_group,
  split(synonyms, '\\|') AS synonyms
FROM read_files('/Volumes/workspace/charity_lens/raw/ref/causes.csv',
                format => 'csv', header => true, escape => '"', inferSchema => false);

-- Cause crosswalk: each register's source code -> one Charity Lens cause (same rows as the E4 cause_map.csv, now with keys).
CREATE OR REPLACE TABLE ont_cause_crosswalk
COMMENT 'Charity Lens ontology: crosswalk from each register''s own cause code (UK What code, CRA category, ACNC purpose flag, NTEE major group, PKD division) to a Charity Lens cause. One row per (jurisdiction, source_code_type, source_code).'
AS SELECT
  trim(jurisdiction) AS jurisdiction, trim(source_code_type) AS source_code_type, trim(source_code) AS source_code,
  source_label, trim(cause) AS cause
FROM workspace.charity_lens.ref_cause_map;

-- Country map: three different ways the registers name countries -> ISO 3166-1 alpha-2.
CREATE OR REPLACE TABLE ont_country_map
COMMENT 'Charity Lens ontology: maps programme-country values as they appear in each register (UK country names, CRA ISO2 and region codes, ACNC ISO3) to ISO 3166-1 alpha-2. mapping_status is mapped, region (a CRA region, not a country) or unmapped.'
AS SELECT
  trim(jurisdiction) AS jurisdiction, trim(source_code_type) AS source_code_type, trim(source_value) AS source_value,
  nullif(trim(iso2), '') AS iso2, nullif(trim(country_name), '') AS country_name,
  nullif(trim(mapping_note), '') AS mapping_note, trim(mapping_status) AS mapping_status
FROM read_files('/Volumes/workspace/charity_lens/raw/ref/country_map.csv',
                format => 'csv', header => true, escape => '"', inferSchema => false);

-- Country: one row per ISO2 code seen in any register, plus the five home countries.
CREATE OR REPLACE TABLE ont_country
COMMENT 'Charity Lens ontology, entity Country: one row per ISO 3166-1 alpha-2 code used in programme countries or as a home country.'
AS
SELECT iso2, min_by(country_name, priority) AS country_name
FROM (
  SELECT iso2, country_name, 0 AS priority
  FROM (VALUES ('GB','United Kingdom'),('CA','Canada'),('AU','Australia'),('US','United States'),('PL','Poland')) AS h(iso2, country_name)
  UNION ALL
  SELECT iso2, country_name, 1 AS priority FROM ont_country_map WHERE iso2 IS NOT NULL
)
GROUP BY iso2;

-- Quick look
SELECT jurisdiction, charity_concept, currency, has_income, charity_definition FROM ont_jurisdiction ORDER BY jurisdiction;
