CREATE OR REFRESH MATERIALIZED VIEW gold_ticket_facts COMMENT 'One row per ticket with SLA targets and breach flags. Wall-clock minutes (E1 simplification).' AS
SELECT t.ticket_id, t.customer_id, c.customer_id IS NULL AS is_orphan_customer, coalesce(c.tier, 'Free') AS tier, c.country_code,
  t.agent_id, t.product, t.category, t.priority, t.channel, t.status, t.created_at, to_date(t.created_at) AS created_date,
  timestampdiff(MINUTE, t.created_at, t.first_response_at) AS first_response_minutes,
  timestampdiff(MINUTE, t.created_at, t.resolved_at) AS resolution_minutes,
  s.first_response_target_minutes, s.resolution_target_minutes,
  coalesce(timestampdiff(MINUTE, t.created_at, t.first_response_at), timestampdiff(MINUTE, t.created_at, current_timestamp())) > s.first_response_target_minutes AS is_first_response_breached,
  coalesce(timestampdiff(MINUTE, t.created_at, t.resolved_at), timestampdiff(MINUTE, t.created_at, current_timestamp())) > s.resolution_target_minutes AS is_resolution_breached,
  t.csat_score
FROM silver_tickets t
LEFT JOIN silver_customers c ON t.customer_id = c.customer_id
LEFT JOIN silver_sla_policies s ON s.tier = coalesce(c.tier, 'Free') AND s.priority = t.priority;

CREATE OR REFRESH MATERIALIZED VIEW gold_sla_daily COMMENT 'Daily SLA health by tier and priority.' AS
SELECT created_date, tier, priority, count(*) AS ticket_count,
  avg(CAST(is_first_response_breached OR is_resolution_breached AS INT)) AS sla_breach_rate,
  percentile_approx(first_response_minutes, 0.5) AS median_first_response_minutes, avg(csat_score) AS avg_csat
FROM gold_ticket_facts GROUP BY ALL;

CREATE OR REFRESH MATERIALIZED VIEW gold_agent_performance COMMENT 'Weekly agent performance.' AS
SELECT f.agent_id, a.full_name, a.team, date_trunc('WEEK', f.created_at) AS week_start, count(*) AS tickets_handled,
  percentile_approx(f.first_response_minutes, 0.5) AS median_first_response_minutes, avg(f.csat_score) AS avg_csat
FROM gold_ticket_facts f LEFT JOIN silver_agents a USING (agent_id) WHERE f.agent_id IS NOT NULL GROUP BY ALL;
