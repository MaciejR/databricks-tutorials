# E2 fallback (no Genie Code needed)
1. Unzip `../raw_data.zip` into `/Volumes/workspace/support_copilot/raw/`.
2. Run `e02_documents.sql` top to bottom (SQL editor or notebook `%sql`). Step 3 is the slow/expensive one: test with 5 files first.
3. Optional: `score_against_ground_truth.sql` compares results with `data_generator/ground_truth.csv`.
Version pins: `ai_parse_document` 2.0, `ai_classify` 2.1, `ai_extract` 2.1 (docs, Oct 2026). VARIANT paths follow the documented output (`:response[0]:value` for classify, `:response:<field>:value` for extract).

Verified live (Free Edition, 23 Oct 2026): `read_files(... binaryFile)` paths come back as `dbfs:/Volumes/...` (we strip the prefix; ids come from the file name, so joins don't depend on it); `ai_parse_document` v2.0 on 5 files in ~20 s; element `confidence` is returned as a string ("1"), so we `try_cast` confidences; legacy `ai_classify(text, ARRAY(...))` returns a plain string in ~1.7 s.
`ai_classify` v2.1 and `ai_extract` v2.1 VARIANT outputs and the full 48-file run then worked in the recorded E2 session (through Genie Code).
