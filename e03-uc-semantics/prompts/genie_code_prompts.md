# E3 Genie Code prompts
Skill: `/Users/{username}/.assistant/skills/support-copilot-semantics/SKILL.md` (copy from `skills/`). Type each prompt with the `@support-copilot-semantics` chip.
Prompts 1-2: Genie Code in the E1 pipeline editor (or a notebook). Prompt 3-4: SQL editor on the SQL warehouse.

## Prompt 1: Profile and check the keys (clip 2)
```text
@support-copilot-semantics List the tables in workspace.support_copilot with their comment and primary key status. Then run the key checks from the skill for every planned primary and foreign key (rows vs distinct keys, NULLs, orphans). Don't change anything yet.
```
Expected finding (rehearsal): duplicate customer_id values in silver_customers, and gold_ticket_facts with more rows than distinct ticket_id.

## Prompt 2a: Fix the duplicates (clip 3)
```text
@support-copilot-semantics silver_customers has duplicate customer_ids, and they double tickets in gold_ticket_facts. Fix it in the pipeline: deduplicate silver_customers as the skill says (latest row per customer_id). Show me the diff, then run the pipeline and show me gold_ticket_facts row count vs distinct ticket_id.
```

## Prompt 2b: Comments and keys, in two phases (clip 4)
```text
@support-copilot-semantics Now that the keys are clean, add table and column comments and the primary and foreign keys from the skill to the pipeline schema blocks of silver_customers, silver_agents, silver_tickets and gold_ticket_facts. Take column types from information_schema. Do it in the two phases from the skill: parent primary keys first and run, then the foreign keys and run. Keep the SELECT bodies unchanged. Show me the diff before each run.
```

## Prompt 3: The metric view (clip 5, hero; SQL editor)
```text
@support-copilot-semantics Create mv_support_metrics with the exact DDL from the skill and add its tags. Then answer with MEASURE(): which tier and priority had the highest sla_breach_rate in October 2026, and what was its first_response_time and ticket_count?
```

## Prompt 4: Why not average the daily table (clip 6; SQL editor)
```text
@support-copilot-semantics For Enterprise in October 2026, compare MEASURE(resolution_breach_rate) from mv_support_metrics with the plain AVG of gold_sla_daily.sla_breach_rate (same definition: resolution target only). Explain the difference in one sentence.
```
