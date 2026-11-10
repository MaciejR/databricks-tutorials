# E2 — Genie Code prompts, step by step
Workspace: Free Edition, catalog `workspace`, schema `support_copilot`, serverless notebook (environment version 3+ for VARIANT). Genie Code in **Agent** mode.
Skill: copy `skills/support-copilot-documents/` to `/Users/{username}/.assistant/skills/`, then start a **new chat**.

Verified live (23 Oct 2026, Free Edition): `ai_parse_document` v2.0 (5 PDFs ~20 s; `document.elements[].content/bbox/confidence`; confidence as string), legacy `ai_classify(text, ARRAY(...))` -> STRING (~1.7 s), `read_files` paths come back as `dbfs:/Volumes/...`. Agents page has no Information Extraction option; a banner points document workflows to Genie Code.
In the recorded E2 run, `ai_classify` v2.1, `ai_extract` v2.1 and the full 48-file run also worked.

## Step 0: sanity check (SQL editor)
```sql
SELECT ai_classify('I was charged twice', '["invoice","refund_request","error_report"]', map('version','2.1','enableConfidenceScores','true'));
SELECT ai_extract('Invoice INV-202610-4582 total 7 606,32 zł', '{"invoice_number":{"type":"string"},"total_amount":{"type":"number"},"currency":{"type":"string"}}', options => map('version','2.1'));
```

## Step 1: profile the attachments (no AI calls)
```text
@support-copilot-documents Look at /Volumes/workspace/support_copilot/raw/attachments/ and raw/attachments_index/. Tell me how many files there are, how they link to silver_tickets, and how many ticket_ids are missing from silver_tickets. Don't call any AI functions yet.
```
Expect: 48 files, 48 index rows, 36 tickets, 0 missing.

## Step 2 (hero): one prompt, one document workflow
```text
@support-copilot-documents Build the document workflow for ticket attachments, following the skill:
1. bronze_attachments_index and bronze_attachments (binary) from the volume,
2. bronze_attachment_parsed with ai_parse_document, parse each file once, test on 5 files first and show me the text of one invoice and one image-only error report,
3. bronze_attachment_ai with ai_classify (labels and descriptions from the skill) and ai_extract (schema from the skill), one call per document,
4. silver_ticket_attachments joined to silver_tickets with the review and mismatch flags.
Show the plan first, and ask before running steps 2-3 on all files.
```
Expect: plan, a 5-file test, approval, then the full run. If Genie rewrites the AI calls in a way that fails, paste the error and let it fix it (same loop as E1).

## Step 3: check the silver table
```text
Show counts by doc_type with average confidence, the rows where needs_review is true, and the refund requests whose amount does not match the invoice for the same ticket.
```
Expect: 17 / 11 / 20, 3 mismatched refunds (seed 42 ground truth).

## Step 4: score against ground truth (optional)
```text
Compare silver_ticket_attachments with /Volumes/workspace/support_copilot/raw/_ground_truth/ground_truth.csv: accuracy of doc_type, amount, currency and date. List the misses.
```

## Step 5: ask a Support Copilot question
```text
Which open or pending tickets have a refund request attached, what amount and currency do they ask for, and which are from Enterprise customers? Sort by priority.
```

## Optional: make it incremental
```text
Turn this workflow into a Lakeflow pipeline so ai_parse_document only runs on new files.
```
Free Edition allows one active pipeline per type: stop the E1 pipeline first.
