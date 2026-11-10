-- Fallback reference: Lakeflow Spark Declarative Pipeline, target catalog=workspace, schema=support_copilot, serverless.
CREATE OR REFRESH STREAMING TABLE bronze_tickets COMMENT 'Raw support tickets, all strings, as landed (monthly CSV batches).'
AS SELECT *, _metadata.file_path AS _source_file, current_timestamp() AS _ingested_at
FROM STREAM read_files('/Volumes/workspace/support_copilot/raw/tickets/', format => 'csv', header => true, schemaHints => 'ticket_id STRING', inferColumnTypes => false);

CREATE OR REFRESH STREAMING TABLE bronze_customers COMMENT 'Raw customers CSV.'
AS SELECT *, _metadata.file_path AS _source_file, current_timestamp() AS _ingested_at
FROM STREAM read_files('/Volumes/workspace/support_copilot/raw/customers/', format => 'csv', header => true, inferColumnTypes => false);

CREATE OR REFRESH STREAMING TABLE bronze_agents COMMENT 'Raw agents (JSON lines).'
AS SELECT *, _metadata.file_path AS _source_file, current_timestamp() AS _ingested_at
FROM STREAM read_files('/Volumes/workspace/support_copilot/raw/agents/', format => 'json');

CREATE OR REFRESH STREAMING TABLE bronze_sla_policies COMMENT 'Raw SLA policies (JSON array).'
AS SELECT *, _metadata.file_path AS _source_file, current_timestamp() AS _ingested_at
FROM STREAM read_files('/Volumes/workspace/support_copilot/raw/sla_policies/', format => 'json', multiLine => true);

CREATE OR REFRESH STREAMING TABLE bronze_ticket_events COMMENT 'Raw ticket lifecycle events (JSONL).'
AS SELECT *, _metadata.file_path AS _source_file, current_timestamp() AS _ingested_at
FROM STREAM read_files('/Volumes/workspace/support_copilot/raw/ticket_events/', format => 'json');
