-- Helper: parse the 4 timestamp formats planted by the generator.
CREATE TEMPORARY VIEW v_tickets_typed AS
SELECT
  trim(ticket_id) AS ticket_id, trim(customer_id) AS customer_id, nullif(trim(agent_id), '') AS agent_id,
  trim(regexp_replace(regexp_replace(subject, '<[^>]+>', ''), '^(RE: |FW: )+', '')) AS subject,
  trim(regexp_replace(body, '<[^>]+>', ' ')) AS body,
  product, category,
  CASE lower(trim(priority)) WHEN 'p1' THEN 'urgent' WHEN 'p2' THEN 'high' WHEN 'p3' THEN 'normal' WHEN 'medium' THEN 'normal'
       WHEN 'p4' THEN 'low' ELSE lower(trim(priority)) END AS priority,
  CASE lower(trim(channel)) WHEN 'e-mail' THEN 'email' WHEN 'live_chat' THEN 'chat' WHEN 'web form' THEN 'web' WHEN 'webform' THEN 'web'
       ELSE lower(trim(channel)) END AS channel,
  CASE lower(trim(status)) WHEN 'resolved' THEN 'solved' WHEN 'waiting on customer' THEN 'pending' ELSE lower(trim(status)) END AS status,
  coalesce(try_to_timestamp(created_at, "yyyy-MM-dd'T'HH:mm:ss'Z'"), try_to_timestamp(created_at, 'yyyy-MM-dd HH:mm:ss'),
           try_to_timestamp(created_at, 'dd/MM/yyyy HH:mm'), try_to_timestamp(created_at, "yyyy-MM-dd'T'HH:mm:ss.SSSXXX")) AS created_at,
  coalesce(try_to_timestamp(first_response_at, "yyyy-MM-dd'T'HH:mm:ss'Z'"), try_to_timestamp(first_response_at, 'yyyy-MM-dd HH:mm:ss'),
           try_to_timestamp(first_response_at, 'dd/MM/yyyy HH:mm'), try_to_timestamp(first_response_at, "yyyy-MM-dd'T'HH:mm:ss.SSSXXX")) AS first_response_at,
  coalesce(try_to_timestamp(resolved_at, "yyyy-MM-dd'T'HH:mm:ss'Z'"), try_to_timestamp(resolved_at, 'yyyy-MM-dd HH:mm:ss'),
           try_to_timestamp(resolved_at, 'dd/MM/yyyy HH:mm'), try_to_timestamp(resolved_at, "yyyy-MM-dd'T'HH:mm:ss.SSSXXX")) AS resolved_at,
  try_to_timestamp(updated_at, "yyyy-MM-dd'T'HH:mm:ss'Z'") AS updated_at,
  CASE WHEN try_cast(csat_score AS INT) BETWEEN 1 AND 5 THEN try_cast(csat_score AS INT) END AS csat_score,
  language, _source_file
FROM STREAM(bronze_tickets);

-- Latest version per ticket (handles exact duplicates + late-arriving updates).
CREATE OR REFRESH STREAMING TABLE silver_tickets (
  CONSTRAINT valid_ticket_id EXPECT (ticket_id IS NOT NULL) ON VIOLATION DROP ROW,
  CONSTRAINT valid_created_at EXPECT (created_at IS NOT NULL) ON VIOLATION DROP ROW,
  CONSTRAINT valid_resolution_order EXPECT (resolved_at IS NULL OR resolved_at >= created_at) ON VIOLATION DROP ROW,
  CONSTRAINT valid_priority EXPECT (priority IN ('urgent','high','normal','low')),
  CONSTRAINT valid_channel EXPECT (channel IN ('email','chat','phone','web'))
) COMMENT 'Cleaned, deduplicated support tickets (SCD1, latest updated_at wins).';

CREATE FLOW silver_tickets_cdc AS AUTO CDC INTO silver_tickets
FROM STREAM(v_tickets_typed) KEYS (ticket_id) SEQUENCE BY updated_at STORED AS SCD TYPE 1;

CREATE OR REFRESH MATERIALIZED VIEW silver_customers (
  CONSTRAINT valid_email EXPECT (contact_email IS NULL OR contact_email RLIKE '^[^@ ]+@[^@ ]+\\.[^@ ]+$')
) COMMENT 'Cleaned customers, one row per customer_id, ISO-2 country.' AS
SELECT customer_id, company_name, contact_name, contact_email, country_code, tier, signup_at, is_active FROM (
  SELECT trim(customer_id) AS customer_id, trim(company_name) AS company_name, trim(contact_name) AS contact_name,
    CASE WHEN lower(trim(contact_email)) RLIKE '^[^@ ]+@[^@ ]+\\.[^@ ]+$' THEN lower(trim(contact_email)) END AS contact_email,
    CASE lower(trim(country)) WHEN 'poland' THEN 'PL' WHEN 'polska' THEN 'PL' WHEN 'germany' THEN 'DE' WHEN 'deutschland' THEN 'DE'
      WHEN 'usa' THEN 'US' WHEN 'united states' THEN 'US' WHEN 'uk' THEN 'GB' WHEN 'united kingdom' THEN 'GB' WHEN 'france' THEN 'FR'
      ELSE upper(trim(country)) END AS country_code,
    initcap(trim(tier)) AS tier,
    coalesce(try_to_timestamp(signup_date, "yyyy-MM-dd'T'HH:mm:ss'Z'"), try_to_timestamp(signup_date, 'yyyy-MM-dd HH:mm:ss'),
             try_to_timestamp(signup_date, 'dd/MM/yyyy HH:mm'), try_to_timestamp(signup_date, "yyyy-MM-dd'T'HH:mm:ss.SSSXXX")) AS signup_at,
    lower(trim(is_active)) IN ('true','1','yes') AS is_active,
    row_number() OVER (PARTITION BY trim(customer_id) ORDER BY _ingested_at DESC, signup_date DESC) AS rn
  FROM bronze_customers) WHERE rn = 1;

CREATE OR REFRESH MATERIALIZED VIEW silver_agents COMMENT 'Support agents.' AS
SELECT DISTINCT agent_id, full_name, upper(substr(team,1,2)) || substr(team,3) AS team, to_date(hired_on) AS hired_date, languages, active AS is_active
FROM bronze_agents;

CREATE OR REFRESH MATERIALIZED VIEW silver_sla_policies COMMENT 'SLA targets per tier and priority (wall-clock minutes).' AS
SELECT DISTINCT policy_id, customer_tier AS tier, priority, CAST(first_response_minutes AS INT) AS first_response_target_minutes,
  CAST(resolution_minutes AS INT) AS resolution_target_minutes, business_hours_only AS is_business_hours_only, to_date(effective_from) AS effective_from_date
FROM bronze_sla_policies;
