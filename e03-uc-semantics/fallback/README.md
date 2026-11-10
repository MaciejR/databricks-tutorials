# E3 fallback (no Genie needed)
Run in order. Pipeline changes go into the E1 pipeline files (`transformations/silver.sql`, `gold.sql`); SQL checks and the metric view run in the SQL editor on the SQL warehouse.
1. `e03_1_key_checks.sql`: rows vs distinct keys, duplicate customers, orphans (read-only).
2. `e03_2_dedup_silver_customers.sql`: the fix (latest row per customer_id). Run pipeline; gold_ticket_facts rows must equal distinct tickets.
3. `e03_3_keys_and_comments.sql`: schema blocks in two phases (parent PKs, run; then FKs, run). Column types from information_schema.
4. `e03_4_metric_view.sql`: metric view + plain tags + the SLA question + weighting demo. SQL editor only.

Don't use ALTER for comments/keys on pipeline tables (only `COMMENT ON TABLE` on the gold MV was tested; survival after refresh not tested).
