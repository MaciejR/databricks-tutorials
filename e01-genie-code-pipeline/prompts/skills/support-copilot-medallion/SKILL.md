---
name: support-copilot-medallion
description: Conventions for building the Support Copilot Lakeflow pipeline (bronze/silver/gold) in workspace.support_copilot. Use when creating, editing or reviewing any pipeline dataset, expectation or table for support tickets, customers, agents or SLA policies.
---

# Support Copilot medallion conventions

## Scope and safety
- Only read from `/Volumes/workspace/support_copilot/raw/` and only write to schema `workspace.support_copilot`.
- Do not create clusters; everything runs on serverless.

## Naming
- Layers are prefixes: `bronze_<entity>`, `silver_<entity>`, `gold_<subject>`. snake_case, plural entities (`bronze_tickets`, `silver_customers`, `gold_sla_daily`).
- One source file per layer: `transformations/bronze.sql`, `silver.sql`, `gold.sql` (SQL preferred; Python only if SQL cannot express it).
- Columns: snake_case; timestamps end in `_at` (TIMESTAMP, UTC); dates end in `_date`; booleans start with `is_`/`has_`; durations carry the unit (`first_response_minutes`).
- Every table gets a `COMMENT` and every silver/gold column a short comment.

## Bronze
- Streaming tables with Auto Loader (`read_files`, `STREAM`), all columns as STRING, plus `_source_file` (`_metadata.file_path`) and `_ingested_at` (`current_timestamp()`).
- No cleaning in bronze. Add `_rescued_data`.

## Silver
- Canonical values: priority in (urgent, high, normal, low) mapping P1..P4 and Medium->normal; channel in (email, chat, phone, web); status in (open, pending, solved, closed) with resolved->solved, "waiting on customer"->pending.
- Parse timestamps with `coalesce(try_to_timestamp(x, fmt1), ...)` over the 4 known formats.
- Deduplicate tickets: keep latest `updated_at` per `ticket_id` (use `AUTO CDC` / `APPLY CHANGES` SCD type 1, sequenced by `updated_at`).
- Lower-case and validate emails; strip HTML tags from subject/body; trim all strings; map country variants to ISO-2.
- CSAT: integer 1..5, else NULL.
- Expectations (named `CONSTRAINT valid_<rule>`):
  - `ticket_id IS NOT NULL` -> DROP ROW
  - `created_at IS NOT NULL` -> DROP ROW
  - `resolved_at IS NULL OR resolved_at >= created_at` -> DROP ROW
  - `priority IN (...)` -> WARN (keep row, track)
  - `csat_score IS NULL OR csat_score BETWEEN 1 AND 5` -> WARN
  - customer email format -> WARN
- Orphan tickets (unknown customer) are kept, flagged `is_orphan_customer = true`.

## Gold
- Materialized views only. Required: `gold_ticket_facts` (one row per ticket with SLA targets joined by tier+priority, `first_response_minutes`, `resolution_minutes`, `is_first_response_breached`, `is_resolution_breached`), `gold_sla_daily` (date, tier, priority, ticket count, breach rate, avg CSAT), `gold_agent_performance` (agent, week, tickets, median first response, CSAT).
- Metric names must match the series glossary: `first_response_time`, `sla_breach_rate`, `csat`.

## Examples
- Input `" urgent"` / `"P1"` -> `urgent`. Input `"N/A"` CSAT -> NULL. Input `"Anna.Nowak@EXAMPLE.com"` -> `anna.nowak@example.com`.

## Edge cases
- `business_hours_only` SLA policies: in E1 compute breach on wall-clock minutes and say so in the table comment (business-hours logic comes later).
