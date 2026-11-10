-- E3 step 3: comments + keys in the pipeline schema blocks, in TWO phases.
-- Column types: generate from the live tables, never guess (CSV/JSON types are inferred by read_files):
SELECT table_name,
       concat_ws(',\n', collect_list(concat('  ', column_name, ' ', data_type, ' COMMENT ''TODO''')) ) AS schema_block
FROM (SELECT * FROM workspace.information_schema.columns
      WHERE table_schema = 'support_copilot'
        AND table_name IN ('silver_customers','silver_agents','silver_tickets','gold_ticket_facts')
      ORDER BY table_name, ordinal_position)
GROUP BY table_name;

-- PHASE 1 (parents). Example for silver_customers (types as seen in rehearsal; confirm with the query above):
-- CREATE MATERIALIZED VIEW silver_customers(
--   customer_id STRING NOT NULL COMMENT 'Customer id. One row per customer (deduplicated: latest row wins).',
--   company_name STRING COMMENT 'Customer company name.',
--   contact_name STRING COMMENT 'Primary contact person (personal data).',
--   contact_email STRING COMMENT 'Lower-cased, trimmed contact email (personal data).',
--   country STRING COMMENT 'ISO-2 country code (PL, DE, US, GB, FR).',
--   tier STRING COMMENT 'Free, Pro, Business or Enterprise; drives SLA targets.',
--   signup_date STRING COMMENT 'Signup date as in source.',
--   is_active BOOLEAN COMMENT 'Active account.',
--   _source_file STRING COMMENT 'Bronze source file.',
--   _ingested_at TIMESTAMP COMMENT 'Bronze ingestion time.',
--   _rescued_data STRING COMMENT 'Malformed source data rescued at ingestion.',
--   CONSTRAINT valid_email EXPECT (contact_email IS NULL OR contact_email RLIKE '^[a-z0-9._%+-]+@[a-z0-9.-]+\\.[a-z]{2,}$'),
--   CONSTRAINT pk_silver_customers PRIMARY KEY (customer_id)
-- ) COMMENT 'One row per customer (latest row per customer_id).' AS <dedup SELECT from step 2>;
-- silver_agents: same pattern, agent_id ... NOT NULL, CONSTRAINT pk_silver_agents PRIMARY KEY (agent_id).
-- -> Run the pipeline.

-- PHASE 2 (children). silver_tickets schema block: keep the 5 E1 expectations, add
--   ticket_id ... NOT NULL, all columns with COMMENTs, and
--   CONSTRAINT pk_silver_tickets PRIMARY KEY (ticket_id),
--   CONSTRAINT fk_silver_tickets_customer_id FOREIGN KEY (customer_id) REFERENCES silver_customers(customer_id),  -- orphans: no RELY
--   CONSTRAINT fk_silver_tickets_agent_id FOREIGN KEY (agent_id) REFERENCES silver_agents(agent_id)
-- gold_ticket_facts: all 23 columns with COMMENTs, ticket_id NOT NULL, CONSTRAINT pk_gold_ticket_facts PRIMARY KEY (ticket_id).
-- -> Run the pipeline.
-- Why two phases: in rehearsal, adding everything at once failed: the FK on silver_tickets referenced
-- silver_customers before its primary key existed.

-- Check:
SELECT table_name, constraint_name, constraint_type FROM workspace.information_schema.table_constraints
WHERE table_schema = 'support_copilot' ORDER BY table_name;
