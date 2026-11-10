# E1 — Genie Code prompts, step by step
Workspace: Free Edition, catalog `workspace`, schema `support_copilot`, serverless. Keep Genie Code in **Agent** mode.
Verified in docs (Oct 2026): Agent mode in Lakeflow Pipelines Editor (docs.databricks.com/aws/en/ldp/de-agent); skills in `/Users/{username}/.assistant/skills/<name>/SKILL.md`, auto-loaded or `@`-mentioned, new chat needed after edits (docs.databricks.com/aws/en/genie-code/skills).
Unverified: that Genie Code Agent mode / skills / MCP are enabled on Free Edition (partner-powered AI must be on; check the toggle on day 1).

## Step 0 — Setup (notebook, Genie Code Agent mode)
Install the skill first: create `/Users/{username}/.assistant/skills/support-copilot-medallion/SKILL.md` with the file from `skills/`. Start a NEW chat.
> Create schema `workspace.support_copilot` and a managed volume `raw` in it if they don't exist. Then run the generator script I uploaded at `<path>/generate_support_data.py` with `--out /Volumes/workspace/support_copilot/raw --seed 42` and list the files it produced with their sizes.

Expected: schema + volume exist; 4 tickets CSVs, 4 events JSONL, customers.csv, agents.json, sla_policies.json.

## Step 1 — Explore before building
> @support-copilot-medallion Profile the raw files in /Volumes/workspace/support_copilot/raw/. For each entity tell me the columns, row counts, and every data quality problem you can find (formats, casing, duplicates, nulls, orphans). Don't build anything yet.

Expected: list that catches most planted issues (P1..P4 variants, 4 timestamp formats, duplicates, invalid emails, CSAT N/A/-1, orphans, resolved<created). Screenshot moment — compare with data_generator/README.md "planted issues". If it misses some, say so in the post (honest = credible).

## Step 2 — One prompt, one pipeline (Lakeflow Pipelines Editor, Agent mode)
Create new ETL pipeline `support_copilot_pipeline` (catalog workspace, schema support_copilot), open Genie Code:
> @support-copilot-medallion Build a medallion pipeline for the Support Copilot from /Volumes/workspace/support_copilot/raw/: bronze streaming tables for tickets, customers, agents, sla_policies and ticket_events with Auto Loader; silver tables that fix the quality problems you found, deduplicate tickets by latest updated_at, and add expectations; gold materialized views gold_ticket_facts, gold_sla_daily and gold_agent_performance as described in the skill. Show me the plan first, then create the files and run the pipeline.

Expected: plan with 3 files (bronze/silver/gold), approval prompts, pipeline run, graph with ~13 datasets, all green. Use "Allow in this thread" on camera only after showing one explicit approval.

## Step 3 — Let it fix its own error
If the run fails (common: timestamp parsing, AUTO CDC syntax):
> The pipeline failed. Read the error, fix it, and rerun. Explain what was wrong in one sentence.
If it did not fail, skip; do not stage a failure.

## Step 4 — Quality check
> For silver_tickets, show the expectation results from the last update: how many rows passed, warned and were dropped per expectation. Then run a query proving there is exactly one row per ticket_id.

Expected: event log / data quality tab numbers; ~1% dropped by valid_resolution_order; uniqueness check returns 0 duplicates.

## Step 5 — Incremental proof
Upload one more batch (rerun generator with `--seed 43 --tickets 300` into a temp dir and copy only one tickets file renamed `tickets_2026_10b.csv`), then:
> New ticket files landed in the volume. Refresh the pipeline and tell me how many new rows each bronze table processed.

Expected: only the new file processed by bronze_tickets (Auto Loader).

## Step 6 — Gold sanity questions (notebook / SQL editor, Agent mode)
> Using gold_sla_daily, what is the SLA breach rate by tier for September 2026, and which priority is breached most often for Free tier? Show a chart.

Expected: Free > Pro > Business > Enterprise breach rate (generator bakes this in via tier speed).

## Step 7 (optional, MCP teaser)
> List the MCP servers you have available.
Only include on camera if Genie Code MCP settings exist on Free Edition (unverified). Otherwise mention as "coming in E4".

## Fallback
If output diverges, paste fallback_pipeline/*.sql into the editor and say so in the post.
