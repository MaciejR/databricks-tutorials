---
name: support-copilot-semantics
description: Conventions for adding business semantics (comments, primary and foreign keys, a metric view, tags) to the Support Copilot tables in workspace.support_copilot, and for checking keys before declaring them. Use when documenting tables, checking or declaring keys, fixing duplicate keys, or creating or querying the metric view for first_response_time, sla_breach_rate or csat.
---

# Support Copilot semantics conventions

## Scope and safety
- Only read and change objects in `workspace.support_copilot`. Never drop E1/E2 tables. No AI Functions.
- Show every change (diff or DDL) and ask before running it.
- Pipeline-managed tables (bronze_*/silver_tickets/silver_ticket_events = streaming tables; silver_customers, silver_agents, silver_sla_policies, gold_* = materialized views) get comments, NOT NULL and keys ONLY in the pipeline SQL schema block, never via ALTER (a refresh can overwrite manual changes).
- Column list in a schema block must match the SELECT exactly. Take names and types from `information_schema.columns`; never guess types.

## Key checks (always before declaring a key)
For every planned PK: `count(*)` vs `count(DISTINCT key)` and NULL count. For every FK: orphan count.
Keys in Unity Catalog are informational and NOT enforced: a PK on a column with duplicates is accepted silently. If a check fails, stop and report: fix the data in the pipeline first, never declare a key you know is false.

Known fix: silver_customers must be one row per customer_id. Deduplicate in the SELECT, keeping the latest row:
`row_number() OVER (PARTITION BY customer_id ORDER BY _ingested_at DESC, _source_file DESC) = 1` (subquery + WHERE rn = 1), like the E1 fallback silver.sql. After the run, gold_ticket_facts row count must equal count(DISTINCT ticket_id) in silver_tickets.

## Keys
- PKs: silver_customers(customer_id), silver_agents(agent_id), silver_tickets(ticket_id), gold_ticket_facts(ticket_id). Names `pk_<table>`, `fk_<table>_<column>`.
- FKs: silver_tickets.customer_id -> silver_customers, silver_tickets.agent_id -> silver_agents. Orphans exist: never `RELY` on these FKs.
- Ordering: an FK fails if the parent's PK does not exist yet. Two phases: (1) add PKs to parents (silver_customers, silver_agents) and run the pipeline; (2) add the FKs on silver_tickets and run again.

## Comments
- Table: grain + source ("One row per ticket ..."). Column: meaning + unit. Durations: "minutes, wall-clock (E1 simplification)".

## Metric view `mv_support_metrics`
- Create it in the **SQL editor on the SQL warehouse** (or a notebook attached to the SQL warehouse). A notebook on serverless compute rejects the `$$` YAML body. Do not use REST APIs or Python workarounds.
- Use this DDL verbatim; do not add dimensions (gold_ticket_facts has no product/category/country columns):

```sql
CREATE OR REPLACE VIEW workspace.support_copilot.mv_support_metrics
WITH METRICS
LANGUAGE YAML
COMMENT 'Support KPIs at ticket grain: first_response_time, sla_breach_rate, resolution_breach_rate, csat.'
AS $$
version: 1.1
source: workspace.support_copilot.gold_ticket_facts
dimensions:
  - name: created_date
    expr: DATE(created_at)
  - name: created_month
    expr: DATE_TRUNC('MONTH', created_at)
  - name: tier
    expr: tier
  - name: priority
    expr: priority
  - name: channel
    expr: channel
  - name: status
    expr: status
  - name: agent_id
    expr: agent_id
measures:
  - name: ticket_count
    expr: COUNT(1)
  - name: first_response_time
    expr: percentile_approx(first_response_time, 0.5)
  - name: sla_breach_rate
    expr: AVG(CASE WHEN is_first_response_breached OR is_resolution_breached THEN 1 ELSE 0 END)
  - name: resolution_breach_rate
    expr: AVG(CASE WHEN is_resolution_breached THEN 1 ELSE 0 END)
  - name: csat
    expr: AVG(csat_score)
$$;
```
- The SQL editor may auto-indent pasted YAML: check indentation before running.
- Tags (plain tags; no governed tags exist for these keys): `ALTER VIEW workspace.support_copilot.mv_support_metrics SET TAGS ('domain' = 'support', 'layer' = 'semantic');`
- Query with `MEASURE(<name>)` + GROUP BY dimensions. Never average a pre-aggregated rate.

## Metric definitions
- first_response_time: median minutes from ticket creation to first agent reply (column `first_response_time` in gold_ticket_facts).
- sla_breach_rate: share of tickets that breached the first-response or resolution target; tickets without a breach flag count as not breached.
- resolution_breach_rate: same, resolution target only (matches gold_sla_daily.sla_breach_rate's definition).
- csat: average customer satisfaction 1-5, answered tickets only.
