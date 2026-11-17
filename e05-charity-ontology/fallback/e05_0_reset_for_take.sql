-- E5 reset before the recorded take. Drops only E5 objects (ont_*, mv_*). E4 tables are untouched.
USE CATALOG workspace;
USE SCHEMA charity_lens;
DROP VIEW IF EXISTS mv_charity_finance;
DROP VIEW IF EXISTS mv_charity_causes;
DROP VIEW IF EXISTS mv_programme_reach;
DROP TABLE IF EXISTS ont_charity_programme_area;
DROP TABLE IF EXISTS ont_charity_cause;
DROP TABLE IF EXISTS ont_charity_finances;
DROP TABLE IF EXISTS ont_charity;
DROP TABLE IF EXISTS ont_cause_crosswalk;
DROP TABLE IF EXISTS ont_country_map;
DROP TABLE IF EXISTS ont_country;
DROP TABLE IF EXISTS ont_cause;
DROP TABLE IF EXISTS ont_jurisdiction;
SHOW TABLES IN workspace.charity_lens LIKE 'ont_*|mv_*';
