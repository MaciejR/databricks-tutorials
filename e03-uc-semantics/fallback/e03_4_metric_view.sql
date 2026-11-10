-- E3 step 4: metric view. Run in the SQL EDITOR on the SQL warehouse (not a serverless notebook:
-- it rejects the $$ YAML body). Check YAML indentation after pasting (editor auto-indent).
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

ALTER VIEW workspace.support_copilot.mv_support_metrics SET TAGS ('domain' = 'support', 'layer' = 'semantic');

-- The SLA question.
SELECT tier, priority, MEASURE(ticket_count) AS tickets, MEASURE(sla_breach_rate) AS sla_breach_rate,
       MEASURE(first_response_time) AS first_response_time, MEASURE(csat) AS csat
FROM workspace.support_copilot.mv_support_metrics
WHERE created_month = DATE'2026-10-01'
GROUP BY ALL ORDER BY sla_breach_rate DESC LIMIT 5;

-- Weighting demo (same definition both sides).
SELECT 'metric_view' AS method, MEASURE(resolution_breach_rate) AS enterprise_oct
FROM workspace.support_copilot.mv_support_metrics
WHERE tier = 'Enterprise' AND created_month = DATE'2026-10-01'
UNION ALL
SELECT 'avg_of_daily_rows', avg(sla_breach_rate)
FROM workspace.support_copilot.gold_sla_daily
WHERE tier = 'Enterprise' AND date >= DATE'2026-10-01' AND date < DATE'2026-11-01';
