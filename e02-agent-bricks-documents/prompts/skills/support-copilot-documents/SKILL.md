---
name: support-copilot-documents
description: Conventions for turning Support Copilot ticket attachments (PDF invoices, refund requests, error-report screenshots) into tables in workspace.support_copilot with ai_parse_document, ai_extract and ai_classify. Use when parsing, extracting, classifying or joining ticket attachments.
---

# Support Copilot document conventions

## Scope and safety
- Read only from `/Volumes/workspace/support_copilot/raw/attachments/` and `/raw/attachments_index/`. Write only to `workspace.support_copilot`.
- Serverless only. AI Functions cost quota on Free Edition: always develop on `LIMIT 5` first, then run on the full folder once.
- Never call AI Functions twice on the same file in one query. Parse once into a table, then extract/classify from that table.

## Tables
- `bronze_attachments`: `path` (strip the `dbfs:` prefix that `read_files` returns), `file_name`, `attachment_id` (file name without `.pdf`), `length`, `modification_time`, `content` (BINARY), `_ingested_at`.
- `bronze_attachment_parsed`: `attachment_id`, `parsed` (VARIANT from `ai_parse_document(content, map('version','2.0'))`), `parsed_text` (elements' `content` joined with `\n\n`), `parse_error`.
- `silver_ticket_attachments`: one row per attachment, joined to `silver_tickets` via `attachments_index` on `ticket_id`.

## Functions and versions
- `ai_parse_document(content, map('version','2.0'))`. Text = `concat_ws('\n\n', transform(try_cast(parsed:document:elements AS ARRAY<VARIANT>), e -> e:content::string))`.
- `ai_classify(parsed_text, labels_json, map('version','2.1','enableConfidenceScores','true'))`. Read label from `:response[0]:value`. If v2.1 is rejected, fall back to `ai_classify(parsed_text, ARRAY(...))`, which returns a plain STRING.
- Labels: `invoice`, `refund_request`, `error_report`, `other` (with descriptions).
- `ai_extract(parsed_text, schema, map('version','2.1','enableConfidenceScores','true'))`. Read each field from `:response:<field>:value`.

- Confidence values may come back as strings (`"1"`): always `try_cast(... ::string AS DOUBLE)`.
- Do not use the Agent Bricks Information Extraction UI; build everything in SQL in this notebook or pipeline.

## Extraction schema (silver columns)
- `doc_invoice_number` STRING, `doc_date` DATE (ISO, normalised from any format), `doc_currency` STRING ISO-4217, `doc_total_amount` DECIMAL(12,2) (gross total / amount requested), `doc_ticket_ref` STRING (T + 6 digits, if printed), `doc_language` STRING ISO-639-1, `error_message` STRING (error reports only), `refund_reason` STRING.
- Keep `doc_type_confidence` and `amount_confidence`; flag `needs_review = confidence < 0.8 OR doc_type = 'other'`.

## Quality rules
- `ticket_id` must exist in `silver_tickets` (else `is_orphan_attachment = true`).
- If `doc_ticket_ref` is present and differs from the index `ticket_id`, set `has_ticket_ref_mismatch = true`.
- Refund vs invoice: for the same ticket, `is_refund_amount_mismatch = refund amount <> invoice amount`.
- Comments on every table and column. snake_case. Same naming as `support-copilot-medallion`.
