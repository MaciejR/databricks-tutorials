-- E2 fallback: documents into data without Genie Code. Run top to bottom in the SQL editor
-- (serverless SQL warehouse) or as %sql cells in a notebook (serverless env v3+).
-- Prereq: E1 tables exist (workspace.support_copilot.silver_tickets, silver_customers) and
-- raw_data.zip is unzipped into /Volumes/workspace/support_copilot/raw/.
-- Cost guard: every AI call runs once per file and the results are stored. Re-runs read tables.
USE CATALOG workspace;
USE SCHEMA support_copilot;

-- 1. Attachment index (helpdesk export) --------------------------------------------------
CREATE OR REPLACE TABLE bronze_attachments_index
COMMENT 'Helpdesk export linking attachment files to E1 ticket ids' AS
SELECT attachment_id, ticket_id, file_name, to_timestamp(uploaded_at) AS uploaded_at
FROM read_files('/Volumes/workspace/support_copilot/raw/attachments_index/', format => 'csv', header => true);

-- 2. Raw PDFs as binary -------------------------------------------------------------------
CREATE OR REPLACE TABLE bronze_attachments
COMMENT 'Ticket attachment PDFs, raw bytes' AS
SELECT regexp_replace(path, '^dbfs:', '')          AS path,   -- read_files returns dbfs:/Volumes/... (verified 23 Oct)
       regexp_extract(path, '([^/]+)$', 1)            AS file_name,
       regexp_extract(path, '(ATT-[0-9]+)\\.pdf$', 1)  AS attachment_id,
       length, modificationTime AS modification_time, content,
       current_timestamp() AS _ingested_at
FROM read_files('/Volumes/workspace/support_copilot/raw/attachments/', format => 'binaryFile');

-- 3. Parse once (OCR + layout). VERIFIED 23 Oct on Free Edition: 5 files ~20 s, output shape document.elements[].content/bbox/confidence.
--    Try on 5 first: add `WHERE attachment_id <= 'ATT-0005'` ----
CREATE OR REPLACE TABLE bronze_attachment_parsed
COMMENT 'ai_parse_document v2.0 output per attachment' AS
WITH p AS (
  SELECT attachment_id, ai_parse_document(content, map('version', '2.0', 'descriptionElementTypes', '')) AS parsed
  FROM bronze_attachments
)
SELECT attachment_id, parsed,
       concat_ws('\n\n', transform(try_cast(parsed:document:elements AS ARRAY<VARIANT>),
                                  e -> e:content::string))           AS parsed_text,
       parsed:error_status::string                                    AS parse_error
FROM p;

-- quick look
SELECT attachment_id, left(parsed_text, 300) AS preview, parse_error FROM bronze_attachment_parsed ORDER BY 1 LIMIT 10;

-- 4. Classify + extract (stored once) ------------------------------------------------------
-- VERIFIED: ai_classify legacy form (ARRAY labels) returns a plain STRING. The v2.1 form below (JSON labels + options)
-- returns VARIANT {response:[{value, confidence_score}]} per docs. If v2.1 is rejected, use:
--   ai_classify(parsed_text, ARRAY('invoice','refund_request','error_report','other')) AS doc_type_legacy
-- ai_extract v2.1 returns VARIANT {response:{<field>:{value, confidence_score}}}.
CREATE OR REPLACE TABLE bronze_attachment_ai
COMMENT 'ai_classify v2.1 and ai_extract v2.1 raw outputs per attachment' AS
SELECT attachment_id,
  ai_classify(parsed_text, '{
      "invoice": "A bill from the software vendor with invoice number, line items and a total due",
      "refund_request": "A form in which the customer asks for money back",
      "error_report": "A screenshot of an application error message",
      "other": "Anything else"}',
    map('version', '2.1', 'enableConfidenceScores', 'true',
        'instructions', 'Attachments sent with SaaS support tickets. Documents can be English, Polish or German.')) AS cls,
  ai_extract(parsed_text, '{
      "invoice_number":  {"type": "string", "description": "Invoice number like INV-YYYYMM-NNNN; for refund forms the related invoice"},
      "document_date":   {"type": "string", "description": "Issue date / request date / error time, as YYYY-MM-DD"},
      "currency":        {"type": "string", "description": "ISO 4217 code: PLN for zł, EUR for €, GBP for £, USD for $"},
      "total_amount":    {"type": "number", "description": "Gross total due (invoice) or amount requested (refund), as a plain number"},
      "ticket_ref":      {"type": "string", "description": "Support ticket id printed on the document, T followed by 6 digits"},
      "language":        {"type": "string", "description": "ISO 639-1 language of the document"},
      "refund_reason":   {"type": "string", "description": "Reason given for a refund, if any"},
      "error_message":   {"type": "string", "description": "Error title and message shown in a screenshot, if any"}
    }',
    options => map('version', '2.1', 'enableConfidenceScores', 'true')) AS ext
FROM bronze_attachment_parsed;

-- 5. Silver: typed, joined to tickets, with review flags ----------------------------------
CREATE OR REPLACE TABLE silver_ticket_attachments
COMMENT 'One row per ticket attachment: doc type, extracted fields, joined to silver_tickets' AS
WITH a AS (
  SELECT i.attachment_id, i.ticket_id, i.file_name, i.uploaded_at,
    x.cls:response[0]:value::string                              AS doc_type,
    try_cast(x.cls:response[0]:confidence_score::string AS DOUBLE)                   AS doc_type_confidence,
    x.ext:response:invoice_number:value::string                  AS doc_invoice_number,
    try_to_date(x.ext:response:document_date:value::string)      AS doc_date,
    upper(x.ext:response:currency:value::string)                 AS doc_currency,
    try_cast(x.ext:response:total_amount:value::string AS DECIMAL(12,2)) AS doc_total_amount,
    try_cast(x.ext:response:total_amount:confidence_score::string AS DOUBLE)         AS amount_confidence,
    x.ext:response:ticket_ref:value::string                      AS doc_ticket_ref,
    lower(x.ext:response:language:value::string)                 AS doc_language,
    x.ext:response:refund_reason:value::string                   AS refund_reason,
    x.ext:response:error_message:value::string                   AS error_message,
    coalesce(x.cls:error_message::string, x.ext:error_message::string) AS ai_error
  FROM bronze_attachments_index i
  LEFT JOIN bronze_attachment_ai x USING (attachment_id)
),
inv AS (SELECT ticket_id, max(doc_total_amount) AS invoice_amount FROM a WHERE doc_type = 'invoice' GROUP BY 1)
SELECT a.*,
  t.ticket_id IS NULL                                                         AS is_orphan_attachment,
  coalesce(a.doc_ticket_ref <> a.ticket_id, false)                            AS has_ticket_ref_mismatch,
  a.doc_type = 'refund_request' AND inv.invoice_amount IS NOT NULL
    AND a.doc_total_amount <> inv.invoice_amount                              AS is_refund_amount_mismatch,
  (coalesce(a.doc_type_confidence, 0) < 0.8 OR a.doc_type = 'other'
    OR a.ai_error IS NOT NULL
    OR (a.doc_type IN ('invoice','refund_request') AND coalesce(a.amount_confidence,0) < 0.8)) AS needs_review,
  t.customer_id, t.category AS ticket_category, t.priority, t.status, t.created_at AS ticket_created_at
FROM a
LEFT JOIN silver_tickets t ON t.ticket_id = a.ticket_id
LEFT JOIN inv ON inv.ticket_id = a.ticket_id;

-- 6. Checks ---------------------------------------------------------------------------------
-- expected with seed 42: 48 rows, 17 invoice / 11 refund_request / 20 error_report
SELECT doc_type, count(*) n, round(avg(doc_type_confidence), 2) avg_conf FROM silver_ticket_attachments GROUP BY 1 ORDER BY 2 DESC;
SELECT count(*) AS orphan_attachments FROM silver_ticket_attachments WHERE is_orphan_attachment;  -- expect 0
-- Support Copilot question: refund requests that ask for a different amount than the invoice
SELECT ticket_id, doc_invoice_number, doc_total_amount, doc_currency, refund_reason, priority, status
FROM silver_ticket_attachments WHERE is_refund_amount_mismatch ORDER BY ticket_id;  -- seed 42 ground truth: 3
