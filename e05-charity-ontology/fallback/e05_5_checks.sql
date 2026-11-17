-- E5 fallback, file 5 of 5: CHECKS (read-only), then certification once everything passes.
-- Run in the SQL EDITOR. Write the real numbers into blog/e05.md; never copy numbers from this file's comments into the post.

USE CATALOG workspace;
USE SCHEMA charity_lens;

-- 1. Same organisations as E4: every count must match gold_charities.
SELECT 'gold_charities' AS t, count(*) AS n FROM gold_charities
UNION ALL SELECT 'ont_charity', count(*) FROM ont_charity
UNION ALL SELECT 'ont_charity_finances', count(*) FROM ont_charity_finances;

-- 2. Primary keys really are unique (RELY is a promise; this is the proof). Expect 0 in every row.
SELECT 'ont_charity' AS t, count(*) - count(DISTINCT charity_id) AS duplicates FROM ont_charity
UNION ALL SELECT 'ont_charity_finances', count(*) - count(DISTINCT charity_id) FROM ont_charity_finances
UNION ALL SELECT 'ont_charity_cause', count(*) - count(DISTINCT charity_id, cause) FROM ont_charity_cause
UNION ALL SELECT 'ont_charity_programme_area', count(*) - count(DISTINCT charity_id, area_code) FROM ont_charity_programme_area
UNION ALL SELECT 'ont_cause_crosswalk', count(*) - count(DISTINCT jurisdiction, source_code_type, source_code) FROM ont_cause_crosswalk
UNION ALL SELECT 'ont_country_map', count(*) - count(DISTINCT jurisdiction, source_value) FROM ont_country_map
UNION ALL SELECT 'ont_country', count(*) - count(DISTINCT iso2) FROM ont_country
UNION ALL SELECT 'ont_jurisdiction', count(*) - count(DISTINCT jurisdiction) FROM ont_jurisdiction
UNION ALL SELECT 'ont_cause', count(*) - count(DISTINCT cause) FROM ont_cause;

-- 3. Foreign keys are informational, so check for orphans ourselves. Expect 0 in every row.
SELECT 'charity -> jurisdiction' AS fk, count(*) AS orphans FROM ont_charity c LEFT ANTI JOIN ont_jurisdiction j ON j.jurisdiction = c.jurisdiction
UNION ALL SELECT 'charity_cause -> cause', count(*) FROM ont_charity_cause x LEFT ANTI JOIN ont_cause c ON c.cause = x.cause
UNION ALL SELECT 'crosswalk -> cause', count(*) FROM ont_cause_crosswalk x LEFT ANTI JOIN ont_cause c ON c.cause = x.cause
UNION ALL SELECT 'programme_area -> country', count(*) FROM ont_charity_programme_area a LEFT ANTI JOIN ont_country c ON c.iso2 = a.iso2 WHERE a.iso2 IS NOT NULL
UNION ALL SELECT 'finances -> charity', count(*) FROM ont_charity_finances f LEFT ANTI JOIN ont_charity c ON c.charity_id = f.charity_id;

-- 4. What "charity" means: organisations per jurisdiction and charity_kind (the ontology in one table).
SELECT c.jurisdiction, j.charity_concept, c.charity_kind, count(*) AS organisations
FROM ont_charity c JOIN ont_jurisdiction j USING (jurisdiction)
GROUP BY ALL ORDER BY c.jurisdiction, organisations DESC;

-- 5. Programme countries: how much did the country map resolve? Expect only a handful of region/unmapped area codes.
SELECT jurisdiction, area_type, count(DISTINCT area_code) AS area_codes, count(DISTINCT charity_id) AS organisations
FROM ont_charity_programme_area GROUP BY ALL ORDER BY jurisdiction, area_type;

-- 5b. Values in the data that the country map does not know at all (new values after a refresh). Expect 0 rows.
SELECT u.jurisdiction, u.source_value, count(DISTINCT u.charity_id) AS organisations
FROM (SELECT charity_id, jurisdiction, explode(source_values) AS source_value
      FROM ont_charity_programme_area WHERE area_type = 'unmapped') u
LEFT ANTI JOIN ont_country_map m ON m.jurisdiction = u.jurisdiction AND m.source_value = u.source_value
GROUP BY ALL ORDER BY organisations DESC;

-- 6. Consistency with E4: cause shares from the metric view must equal E4's top-5 table
--    (published in the E4 post: e.g. AU religion 27.6%, GB-EAW education 48.7%).
SELECT jurisdiction, cause, MEASURE(share_of_jurisdiction) AS share
FROM mv_charity_causes WHERE jurisdiction = 'AU' AND cause = 'religion' GROUP BY ALL
UNION ALL
SELECT jurisdiction, cause, MEASURE(share_of_jurisdiction)
FROM mv_charity_causes WHERE jurisdiction = 'GB-EAW' AND cause = 'education' GROUP BY ALL;

-- 7. Consistency with E4: medians from the metric view vs gold_jurisdiction_summary (percentile_approx: allow tiny differences).
SELECT f.jurisdiction, f.median_mv, g.median_income_local AS median_gold
FROM (SELECT jurisdiction, MEASURE(median_income_local) AS median_mv FROM mv_charity_finance GROUP BY ALL) f
JOIN gold_jurisdiction_summary g USING (jurisdiction)
ORDER BY f.jurisdiction;

-- 8. Currency guard: one row across all registers -> both money measures NULL.
SELECT MEASURE(total_income_local) AS total_income_local, MEASURE(median_income_local) AS median_income_local
FROM mv_charity_finance;

-- 9. Spending shares outside 0-1 (data quality flag, not a fix). Report the count in the post if it is not 0.
SELECT jurisdiction, count(*) AS orgs_share_above_1
FROM ont_charity_finances WHERE charitable_spending_share > 1 OR fundraising_spending_share > 1 GROUP BY ALL;

-- 10. PII guard on the new layer: column names that look personal. Review every hit (expect organisation-level only).
SELECT table_name, column_name
FROM workspace.information_schema.columns
WHERE table_schema = 'charity_lens' AND (table_name LIKE 'ont_%' OR table_name LIKE 'mv_%')
  AND lower(column_name) RLIKE 'address|street|postcode|zip|email|e_mail|phone|trustee|director|officer|person|contact'
ORDER BY table_name, column_name;

-- ===== Certification (only after checks 1-10 look right) =====
-- [VERIFY on Free Edition] needs ASSIGN on the system.certification_status governed tag.
-- SET TAG needs a recent runtime; the ALTER ... SET TAGS form below is the older, widely supported one.
-- ALTER VIEW  workspace.charity_lens.mv_charity_finance SET TAGS ('system.certification_status' = 'certified');
-- ALTER VIEW  workspace.charity_lens.mv_charity_causes  SET TAGS ('system.certification_status' = 'certified');
-- ALTER VIEW  workspace.charity_lens.mv_programme_reach SET TAGS ('system.certification_status' = 'certified');
-- ALTER TABLE workspace.charity_lens.ont_jurisdiction   SET TAGS ('system.certification_status' = 'certified');
-- Optional, to steer Genie away from the E4 v0 lookup:
-- ALTER MATERIALIZED VIEW workspace.charity_lens.ref_cause_map SET TAGS ('system.certification_status' = 'deprecated');
