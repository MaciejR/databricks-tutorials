# E4 Genie Code prompts (Agent mode, Free Edition)
Skill: `/Users/{username}/.assistant/skills/charity-lens-registers/SKILL.md` (copy from `skills/`).
Run in order; each prompt matches a clip. Files are already in the volume (clip 2 shows the upload). Fallback: `../fallback/`.

## Prompt 1: What did we just upload? (clip 3)
```text
@charity-lens-registers List the files in /Volumes/workspace/charity_lens/raw/ by country with their size. For each country, read the header of the main file and tell me which columns will give us the charity ID, name, causes, income, expenditure and currency. Don't create anything yet.
```

## Prompt 2: Bronze and silver per country (clip 4)
```text
@charity-lens-registers Create a new Lakeflow pipeline "charity_lens_registers" (SQL, serverless, triggered, target workspace.charity_lens).
1. Bronze: one materialized view per file listed in the skill, using read_files, all columns as STRING, plus _source_file and _ingested_at.
2. Silver: one table per country (silver_uk_charities, silver_ca_charities, silver_au_charities, silver_us_charities, silver_pl_charities) with exactly the common schema columns from the skill, in that order, one row per charity_id, and the causes mapping through ref_cause_map.
Follow the skill's Pipeline SQL rules.
Keep money in local currency with a currency column. Don't convert currencies.
Show me the plan and the SQL first, and ask before running.
```

## Prompt 3: Five registers side by side (clip 5, hero)
```text
@charity-lens-registers Add gold_charities as a UNION ALL of the five silver tables with a column explaining what "charity" means in each jurisdiction, gold_charity_causes (one row per organisation and cause), plus gold_jurisdiction_summary with organisations, share with income, share with zero income, share with a cause and median income in local currency (skill's median rule) per jurisdiction. Run the pipeline, then show gold_jurisdiction_summary.
```

## Prompt 4: Causes side by side (clip 6)
```text
Using gold_charity_causes, show the top 5 causes per jurisdiction as a share of that country's organisations. Then list any UK classification codes or CA categories that are not in ref_cause_map.
```

## Prompt 5: Licence as metadata (clip 7)
```text
@charity-lens-registers Add the licence and attribution tags and table comments from the skill to the five silver tables, gold_charities and the volume. Show the statements first. Then check information_schema that no column in workspace.charity_lens looks like personal data (addresses, phone, e-mail, trustee, director, person names; counts and postcode districts are fine).
```

## If Genie diverges (more than 2 retries)
Paste `../fallback/e04_pipeline_all.sql` as the pipeline's only source file (or the matching bronze/silver/gold file) and say so in the caption.
Common slips the skill should prevent: bare `array()`, `LATERAL VIEW ... JOIN`, spaced CSV headers in bronze, missing `escape => '"'`, AU duplicate/empty ABNs, median over zeros.

## If Genie asks about FX
```text
No conversion in this episode. Keep local currency. We'll add sourced reference rates later.
```
