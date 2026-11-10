-- E4 sanity checks (run after the pipeline, SQL warehouse or serverless notebook). Write the real numbers into the blog;
-- do not copy numbers from anywhere else (the "expected" figures below are local profiling of the staged files, for sanity only).
-- 1. Five registers side by side (hero query)
SELECT * FROM workspace.charity_lens.gold_jurisdiction_summary ORDER BY organisations DESC;

-- 2. Rows vs distinct IDs per jurisdiction in gold: n must equal n_ids.
--    Expected (local profiling, 10 Nov): GB-EAW 171,914; CA 83,761; AU 65,907 (66,514 register rows minus 607 without an ABN);
--    US 1,650,468; PL 9,604. Rehearsal 30 Oct had AU 66,515 and PL 9,607 (fixed: AU dedup, PL escape => '"').
SELECT jurisdiction, count(*) AS n, count(DISTINCT charity_id) AS n_ids
FROM workspace.charity_lens.gold_charities GROUP BY 1 ORDER BY 1;

-- 3a. One row per (jurisdiction, charity_id) in every SILVER table: must return 0 rows.
SELECT 'silver' AS layer, jurisdiction, charity_id, count(*) AS n FROM (
  SELECT jurisdiction, charity_id FROM workspace.charity_lens.silver_uk_charities
  UNION ALL SELECT jurisdiction, charity_id FROM workspace.charity_lens.silver_ca_charities
  UNION ALL SELECT jurisdiction, charity_id FROM workspace.charity_lens.silver_au_charities
  UNION ALL SELECT jurisdiction, charity_id FROM workspace.charity_lens.silver_us_charities
  UNION ALL SELECT jurisdiction, charity_id FROM workspace.charity_lens.silver_pl_charities
) GROUP BY jurisdiction, charity_id HAVING count(*) > 1 ORDER BY n DESC LIMIT 20;

-- 3b. Same in GOLD: must return 0 rows.
SELECT 'gold' AS layer, jurisdiction, charity_id, count(*) AS n FROM workspace.charity_lens.gold_charities
GROUP BY jurisdiction, charity_id HAVING count(*) > 1 ORDER BY n DESC LIMIT 20;

-- 3c. Malformed IDs (empty or non-numeric source IDs): must return 0 rows.
SELECT jurisdiction, charity_id FROM workspace.charity_lens.gold_charities
WHERE source_id IS NULL OR NOT (
     (jurisdiction = 'GB-EAW' AND source_id RLIKE '^[0-9]+$')
  OR (jurisdiction = 'CA'     AND source_id RLIKE '^[0-9]{9}RR[0-9]{4}$')
  OR (jurisdiction = 'AU'     AND source_id RLIKE '^[0-9]{11}$')
  OR (jurisdiction = 'US'     AND source_id RLIKE '^[0-9]{9}$')
  OR (jurisdiction = 'PL'     AND source_id RLIKE '^[0-9]{10}$'))
LIMIT 20;

-- 3d. What the AU and PL filters dropped (say it in the post): AU expect 607 register rows without an ABN; PL expect 0 with escape => '"'.
SELECT 'AU register rows without an 11-digit ABN' AS what, count(*) AS n FROM workspace.charity_lens.bronze_au_register
WHERE length(regexp_replace(CAST(ABN AS STRING), '[^0-9]', '')) <> 11 OR ABN IS NULL
UNION ALL
SELECT 'PL OPP rows with a non-numeric KRS', count(*) FROM workspace.charity_lens.bronze_pl_opp
WHERE NOT (trim(CAST(nr_krs AS STRING)) RLIKE '^[0-9]{1,10}$') OR nr_krs IS NULL;

-- 4. Median basis: income NULL / zero-or-negative / positive per jurisdiction (median_income_local uses income > 0 only).
SELECT jurisdiction, currency,
  count(CASE WHEN income IS NULL THEN 1 END) AS income_null,
  count(CASE WHEN income <= 0 THEN 1 END)    AS income_zero_or_negative,
  count(CASE WHEN income > 0 THEN 1 END)     AS income_positive
FROM workspace.charity_lens.gold_charities GROUP BY 1, 2 ORDER BY 1;

-- 5. Cause coverage by country
SELECT jurisdiction, cause, count(*) n FROM workspace.charity_lens.gold_charity_causes GROUP BY 1, 2 ORDER BY 1, 3 DESC;

-- 6. Unmapped cause codes (should be empty except PKD divisions not in cause_map)
SELECT k.classification_code, k.classification_description, count(*) FROM workspace.charity_lens.bronze_uk_classification k
LEFT JOIN workspace.charity_lens.ref_cause_map m ON m.jurisdiction = 'GB-EAW' AND m.source_code_type = 'ccew_classification_what'
     AND trim(m.source_code) = trim(CAST(k.classification_code AS STRING))
WHERE k.classification_type = 'What' AND m.cause IS NULL GROUP BY 1, 2;
SELECT i.Category, count(*) FROM workspace.charity_lens.bronze_ca_ident i
LEFT JOIN workspace.charity_lens.ref_cause_map m ON m.jurisdiction = 'CA' AND m.source_code_type = 'cra_category'
     AND try_cast(trim(m.source_code) AS INT) = try_cast(trim(CAST(i.Category AS STRING)) AS INT)
WHERE m.cause IS NULL GROUP BY 1;

-- 7. PII guard: none of these columns may exist anywhere in the schema (bronze included): must return 0 rows.
SELECT table_name, column_name FROM workspace.information_schema.columns
WHERE table_schema = 'charity_lens'
  AND lower(column_name) RLIKE '^address|address_line|^postal code$|^postcode$|^street|^zip$|phone|email|e_mail|trustee|director|officer|personnm|^ico$|in care|indiv/org name|key management';

-- 8. Never sum across currencies: this must return one currency per jurisdiction
SELECT jurisdiction, count(DISTINCT currency) FROM workspace.charity_lens.gold_charities GROUP BY 1;
