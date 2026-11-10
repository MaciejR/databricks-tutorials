# Fallback reference pipeline
Use when Genie Code's output differs from the post. Lakeflow Pipelines Editor > New ETL pipeline, catalog `workspace`, schema `support_copilot`, serverless; add `bronze.sql`, `silver.sql`, `gold.sql` under `transformations/`; Run pipeline.
Free Edition: one active pipeline per type — stop/delete other pipelines first.
Validate:
```sql
SELECT count(*), count(DISTINCT ticket_id) FROM workspace.support_copilot.silver_tickets;   -- equal, = 5000 minus dropped
SELECT priority, count(*) FROM workspace.support_copilot.silver_tickets GROUP BY 1;           -- 4 values only
SELECT tier, round(avg(sla_breach_rate),3) FROM workspace.support_copilot.gold_sla_daily GROUP BY 1; -- Free worst, Enterprise best
```
