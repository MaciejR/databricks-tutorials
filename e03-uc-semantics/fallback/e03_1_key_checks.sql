-- E3 step 1: key checks (read-only). Run in the SQL editor.
USE CATALOG workspace; USE SCHEMA support_copilot;

SELECT 'silver_customers' AS tbl, count(*) AS rows_, count(DISTINCT customer_id) AS distinct_keys, count_if(customer_id IS NULL) AS null_keys FROM silver_customers
UNION ALL SELECT 'silver_agents', count(*), count(DISTINCT agent_id), count_if(agent_id IS NULL) FROM silver_agents
UNION ALL SELECT 'silver_tickets', count(*), count(DISTINCT ticket_id), count_if(ticket_id IS NULL) FROM silver_tickets
UNION ALL SELECT 'gold_ticket_facts', count(*), count(DISTINCT ticket_id), count_if(ticket_id IS NULL) FROM gold_ticket_facts;

-- Which customers are duplicated, and do their tiers conflict?
SELECT customer_id, count(*) AS c, collect_set(tier) AS tiers
FROM silver_customers GROUP BY customer_id HAVING count(*) > 1 ORDER BY customer_id;

-- Knock-on effect in gold.
SELECT (SELECT sum(ticket_count) FROM gold_sla_daily) AS gold_sla_daily_tickets,
       (SELECT count(*) FROM silver_tickets) AS silver_tickets;

-- FK orphans.
SELECT count(*) AS tickets_with_unknown_customer FROM silver_tickets t LEFT ANTI JOIN silver_customers c USING (customer_id);
SELECT count_if(agent_id IS NULL) AS tickets_without_agent FROM silver_tickets;
SELECT count(*) AS tickets_with_unknown_agent FROM silver_tickets t LEFT ANTI JOIN silver_agents a USING (agent_id) WHERE t.agent_id IS NOT NULL;
