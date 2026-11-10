-- Optional: upload data_generator/ground_truth.csv to /Volumes/workspace/support_copilot/raw/_ground_truth/ (outside attachments/)
USE CATALOG workspace; USE SCHEMA support_copilot;
CREATE OR REPLACE TEMP VIEW gt AS
SELECT * FROM read_files('/Volumes/workspace/support_copilot/raw/_ground_truth/ground_truth.csv', format => 'csv', header => true);
SELECT
  count(*)                                                                    AS docs,
  avg(CASE WHEN s.doc_type = g.doc_type THEN 1 ELSE 0 END)                    AS doc_type_accuracy,
  avg(CASE WHEN g.doc_type <> 'error_report' THEN CASE WHEN s.doc_total_amount = CAST(g.amount AS DECIMAL(12,2)) THEN 1 ELSE 0 END END) AS amount_accuracy,
  avg(CASE WHEN g.doc_type <> 'error_report' THEN CASE WHEN s.doc_currency = g.currency THEN 1 ELSE 0 END END)  AS currency_accuracy,
  avg(CASE WHEN g.doc_type <> 'error_report' THEN CASE WHEN s.doc_date = to_date(g.document_date) THEN 1 ELSE 0 END END) AS date_accuracy
FROM gt g JOIN silver_ticket_attachments s USING (attachment_id);
