-- E3 step 2: the fix. Replace silver_customers in the E1 pipeline silver.sql with this, then run the pipeline.
-- Only change vs E1: the subquery + WHERE rn = 1 (latest row per customer_id, like the E1 fallback silver.sql).
CREATE MATERIALIZED VIEW silver_customers(
  CONSTRAINT valid_email EXPECT (contact_email IS NULL OR contact_email RLIKE '^[a-z0-9._%+-]+@[a-z0-9.-]+\\.[a-z]{2,}$')
) AS
SELECT customer_id, company_name, contact_name, contact_email, country, tier, signup_date, is_active,
       _source_file, _ingested_at, _rescued_data
FROM (
  SELECT
    customer_id,
    company_name,
    contact_name,
    LOWER(TRIM(contact_email)) AS contact_email,
    CASE
      WHEN LOWER(country) IN ('polska','poland') THEN 'PL'
      WHEN LOWER(country) IN ('deutschland','germany','de') THEN 'DE'
      WHEN LOWER(country) IN ('usa','united states','us') THEN 'US'
      WHEN LOWER(country) IN ('uk','united kingdom','gb') THEN 'GB'
      WHEN LOWER(country) IN ('fr','france') THEN 'FR'
      ELSE NULL END AS country,
    CASE LOWER(TRIM(tier))
      WHEN 'free' THEN 'Free'
      WHEN 'pro' THEN 'Pro'
      WHEN 'business' THEN 'Business'
      WHEN 'enterprise' THEN 'Enterprise'
      ELSE NULL END AS tier,
    signup_date,
    CASE WHEN LOWER(TRIM(is_active)) IN ('true','yes','1') THEN TRUE ELSE FALSE END AS is_active,
    _source_file, _ingested_at, _rescued_data,
    row_number() OVER (PARTITION BY customer_id ORDER BY _ingested_at DESC, _source_file DESC) AS rn
  FROM bronze_customers
)
WHERE rn = 1;

-- After the run, both must hold (run in SQL editor):
-- SELECT count(*) = count(DISTINCT customer_id) FROM workspace.support_copilot.silver_customers;
-- SELECT (SELECT count(*) FROM workspace.support_copilot.gold_ticket_facts) = (SELECT count(DISTINCT ticket_id) FROM workspace.support_copilot.silver_tickets);
