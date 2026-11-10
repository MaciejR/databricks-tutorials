# E2 data generator: ticket attachments
```bash
pip install reportlab pillow
python generate_attachments.py --seed 42            # reads ../../e01-genie-code-pipeline/raw_data, writes ../raw_data
```
The generator needs E1's raw data in `e01-genie-code-pipeline/raw_data/`: unzip it first (`cd ../../e01-genie-code-pipeline && unzip raw_data.zip -d raw_data`), or run the E1 generator with `--out ../../e01-genie-code-pipeline/raw_data --seed 42`. If you just want the PDFs, skip the generator and use `../raw_data.zip`.
Output (seed 42): **48 PDFs for 36 E1 tickets**: 17 invoices, 11 refund requests, 20 error reports.
- `raw_data/attachments/ATT-0001.pdf ...`: neutral file names, so the doc type has to come from the content.
- `raw_data/attachments_index/attachments_index.csv`: helpdesk export (`attachment_id, ticket_id, file_name, uploaded_at`), the join key to `silver_tickets`.
- `ground_truth.csv`: expected `doc_type`, invoice number, date, currency, amount, language, `amount_mismatch`. Use it to score extraction; **do not upload it** to the volume.

Only tickets that survive E1 silver are used (customer exists, ISO `created_at`, `resolved_at >= created_at`).

Planted difficulty: invoices in EN/PL/DE with `1 234,56 zł`, `1.234,56 €`, `£394.21`; four date formats (`2026-10-15`, `15.10.2026`, `15 October 2026`, `10/15/2026`); ~30% of invoices have no ticket reference; some `(DUPLICATE)` invoices on double-charge tickets; ~25% of refund requests ask for an amount that does not match the invoice; error reports are **image-only PDFs** (no text layer, ~40% rotated/blurred like a phone photo), so `ai_parse_document` has to OCR them.

Upload: Catalog > workspace > support_copilot > raw > Upload, or unzip `raw_data.zip` into `/Volumes/workspace/support_copilot/raw/` (creates `attachments/` and `attachments_index/` next to E1's folders).

Everything is synthetic: fictional vendor, company names reused from the E1 synthetic customers, no people's names, emails or addresses.
