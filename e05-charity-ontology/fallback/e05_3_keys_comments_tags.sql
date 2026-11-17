-- E5 fallback, file 3 of 5: KEYS, COMMENTS, TAGS. Run in the SQL EDITOR after files 1 and 2.
-- Primary keys use RELY (we check uniqueness in file 5 before trusting them). Foreign keys are informational (not enforced).
-- Order matters: parents first (primary keys), then children (foreign keys). Same lesson as E3.

USE CATALOG workspace;
USE SCHEMA charity_lens;

-- ===== Reset (only when re-running files 1-2 after this file) =====
-- ALTER TABLE ont_charity_programme_area DROP CONSTRAINT IF EXISTS fk_area_charity;
-- ALTER TABLE ont_charity_programme_area DROP CONSTRAINT IF EXISTS fk_area_country;
-- ALTER TABLE ont_charity_cause         DROP CONSTRAINT IF EXISTS fk_cc_charity;
-- ALTER TABLE ont_charity_cause         DROP CONSTRAINT IF EXISTS fk_cc_cause;
-- ALTER TABLE ont_charity_finances      DROP CONSTRAINT IF EXISTS fk_fin_charity;
-- ALTER TABLE ont_charity               DROP CONSTRAINT IF EXISTS fk_charity_jurisdiction;
-- ALTER TABLE ont_cause_crosswalk       DROP CONSTRAINT IF EXISTS fk_xw_cause;
-- ALTER TABLE ont_cause_crosswalk       DROP CONSTRAINT IF EXISTS fk_xw_jurisdiction;
-- ALTER TABLE ont_country_map           DROP CONSTRAINT IF EXISTS fk_cmap_country;

-- ===== Phase 1: primary keys =====
ALTER TABLE ont_jurisdiction ALTER COLUMN jurisdiction SET NOT NULL;
ALTER TABLE ont_jurisdiction ADD CONSTRAINT pk_ont_jurisdiction PRIMARY KEY (jurisdiction) RELY;

ALTER TABLE ont_cause ALTER COLUMN cause SET NOT NULL;
ALTER TABLE ont_cause ADD CONSTRAINT pk_ont_cause PRIMARY KEY (cause) RELY;

ALTER TABLE ont_country ALTER COLUMN iso2 SET NOT NULL;
ALTER TABLE ont_country ADD CONSTRAINT pk_ont_country PRIMARY KEY (iso2) RELY;

ALTER TABLE ont_cause_crosswalk ALTER COLUMN jurisdiction SET NOT NULL;
ALTER TABLE ont_cause_crosswalk ALTER COLUMN source_code_type SET NOT NULL;
ALTER TABLE ont_cause_crosswalk ALTER COLUMN source_code SET NOT NULL;
ALTER TABLE ont_cause_crosswalk ADD CONSTRAINT pk_ont_cause_crosswalk PRIMARY KEY (jurisdiction, source_code_type, source_code) RELY;

ALTER TABLE ont_country_map ALTER COLUMN jurisdiction SET NOT NULL;
ALTER TABLE ont_country_map ALTER COLUMN source_value SET NOT NULL;
ALTER TABLE ont_country_map ADD CONSTRAINT pk_ont_country_map PRIMARY KEY (jurisdiction, source_value) RELY;

ALTER TABLE ont_charity ALTER COLUMN charity_id SET NOT NULL;
ALTER TABLE ont_charity ADD CONSTRAINT pk_ont_charity PRIMARY KEY (charity_id) RELY;

ALTER TABLE ont_charity_finances ALTER COLUMN charity_id SET NOT NULL;
ALTER TABLE ont_charity_finances ADD CONSTRAINT pk_ont_charity_finances PRIMARY KEY (charity_id) RELY;

ALTER TABLE ont_charity_cause ALTER COLUMN charity_id SET NOT NULL;
ALTER TABLE ont_charity_cause ALTER COLUMN cause SET NOT NULL;
ALTER TABLE ont_charity_cause ADD CONSTRAINT pk_ont_charity_cause PRIMARY KEY (charity_id, cause) RELY;

ALTER TABLE ont_charity_programme_area ALTER COLUMN charity_id SET NOT NULL;
ALTER TABLE ont_charity_programme_area ALTER COLUMN area_code SET NOT NULL;
ALTER TABLE ont_charity_programme_area ADD CONSTRAINT pk_ont_programme_area PRIMARY KEY (charity_id, area_code) RELY;

-- ===== Phase 2: foreign keys (the relationships of the ontology) =====
ALTER TABLE ont_charity                ADD CONSTRAINT fk_charity_jurisdiction FOREIGN KEY (jurisdiction) REFERENCES ont_jurisdiction (jurisdiction);
ALTER TABLE ont_charity_finances       ADD CONSTRAINT fk_fin_charity          FOREIGN KEY (charity_id)   REFERENCES ont_charity (charity_id);
ALTER TABLE ont_charity_cause          ADD CONSTRAINT fk_cc_charity           FOREIGN KEY (charity_id)   REFERENCES ont_charity (charity_id);
ALTER TABLE ont_charity_cause          ADD CONSTRAINT fk_cc_cause             FOREIGN KEY (cause)        REFERENCES ont_cause (cause);
ALTER TABLE ont_charity_programme_area ADD CONSTRAINT fk_area_charity         FOREIGN KEY (charity_id)   REFERENCES ont_charity (charity_id);
ALTER TABLE ont_charity_programme_area ADD CONSTRAINT fk_area_country         FOREIGN KEY (iso2)         REFERENCES ont_country (iso2);
ALTER TABLE ont_cause_crosswalk        ADD CONSTRAINT fk_xw_cause             FOREIGN KEY (cause)        REFERENCES ont_cause (cause);
ALTER TABLE ont_cause_crosswalk        ADD CONSTRAINT fk_xw_jurisdiction      FOREIGN KEY (jurisdiction) REFERENCES ont_jurisdiction (jurisdiction);
ALTER TABLE ont_country_map            ADD CONSTRAINT fk_cmap_country         FOREIGN KEY (iso2)         REFERENCES ont_country (iso2);

-- ===== Column comments on the columns Genie will meet most =====
ALTER TABLE ont_jurisdiction ALTER COLUMN charity_definition COMMENT 'What one row in this register means legally. Not the same in every country.';
ALTER TABLE ont_jurisdiction ALTER COLUMN charity_concept    COMMENT 'registered_charity (GB-EAW, CA, AU), tax_exempt_organisation (US 501(c)(3)) or public_benefit_status (PL OPP).';
ALTER TABLE ont_jurisdiction ALTER COLUMN has_income         COMMENT 'false for PL: no open financial data for OPPs.';
ALTER TABLE ont_charity ALTER COLUMN charity_kind  COMMENT 'registered_charity, charitable_organisation, public_foundation, private_foundation, public_charity or public_benefit_organisation.';
ALTER TABLE ont_charity ALTER COLUMN size_band     COMMENT 'AU only: ACNC size band (Small, Medium, Large).';
ALTER TABLE ont_charity ALTER COLUMN locality      COMMENT 'Town or city. For GB-EAW the postcode district. Never a street address.';
ALTER TABLE ont_charity_finances ALTER COLUMN income        COMMENT 'Latest income in LOCAL currency (see currency). NULL = not available (all PL rows).';
ALTER TABLE ont_charity_finances ALTER COLUMN currency      COMMENT 'ISO 4217 code: GBP, CAD, AUD, USD or PLN. Group by currency before any SUM or AVG.';
ALTER TABLE ont_charity_finances ALTER COLUMN income_status COMMENT 'reported_positive, zero_or_negative (US: usually no financial return on file) or not_available.';
ALTER TABLE ont_charity_finances ALTER COLUMN charitable_spending_share COMMENT 'charitable_spending / expenditure for one organisation (GB-EAW larger charities and CA only).';
ALTER TABLE ont_charity_programme_area ALTER COLUMN area_type   COMMENT 'country (ISO2), region (CRA region code, not a country) or unmapped.';
ALTER TABLE ont_charity_programme_area ALTER COLUMN is_domestic COMMENT 'true when the area is the home country of the register (GB for GB-EAW, including Scotland and Northern Ireland).';

-- ===== Tags: plain tags, same keys as E4 =====
ALTER TABLE ont_jurisdiction           SET TAGS ('domain' = 'charity_lens', 'layer' = 'ontology', 'contains_pii' = 'false');
ALTER TABLE ont_cause                  SET TAGS ('domain' = 'charity_lens', 'layer' = 'ontology', 'contains_pii' = 'false');
ALTER TABLE ont_cause_crosswalk        SET TAGS ('domain' = 'charity_lens', 'layer' = 'ontology', 'contains_pii' = 'false');
ALTER TABLE ont_country                SET TAGS ('domain' = 'charity_lens', 'layer' = 'ontology', 'contains_pii' = 'false');
ALTER TABLE ont_country_map            SET TAGS ('domain' = 'charity_lens', 'layer' = 'ontology', 'contains_pii' = 'false');
ALTER TABLE ont_charity                SET TAGS ('domain' = 'charity_lens', 'layer' = 'ontology', 'contains_pii' = 'false', 'licence' = 'mixed: see licence column per row');
ALTER TABLE ont_charity_finances       SET TAGS ('domain' = 'charity_lens', 'layer' = 'ontology', 'contains_pii' = 'false', 'licence' = 'mixed: see ont_charity.licence');
ALTER TABLE ont_charity_cause          SET TAGS ('domain' = 'charity_lens', 'layer' = 'ontology', 'contains_pii' = 'false');
ALTER TABLE ont_charity_programme_area SET TAGS ('domain' = 'charity_lens', 'layer' = 'ontology', 'contains_pii' = 'false');

-- Check
SELECT table_name, constraint_name, constraint_type
FROM workspace.information_schema.table_constraints
WHERE table_schema = 'charity_lens' AND table_name LIKE 'ont_%'
ORDER BY table_name, constraint_type DESC;
