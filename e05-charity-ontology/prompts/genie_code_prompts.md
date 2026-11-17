# E5 Genie Code prompts (Agent mode, Free Edition)
Skill: `/Users/{username}/.assistant/skills/charity-lens-ontology/SKILL.md` (copy from `skills/`). Type prompts with the `@charity-lens-ontology` chip.
Prompts 1-4: Genie Code in the **SQL editor** on the SQL warehouse (not the E4 pipeline editor). Prompt 5: Genie Code pane in the Page editor (Discover > Pages), if Pages are available. Prompts 6-7: Genie Agents.
Before prompt 1: upload `fallback/jurisdictions.csv`, `causes.csv`, `country_map.csv` to `/Volumes/workspace/charity_lens/raw/ref/` (on camera in clip 1).
Fallback for every step: `../fallback/` (same file numbers). Say so in the caption if you use it.

## Prompt 1: Five meanings of "charity" (clip 1)
```text
@charity-lens-ontology Read /Volumes/workspace/charity_lens/raw/ref/jurisdictions.csv and causes.csv and create ont_jurisdiction, ont_cause and ont_cause_crosswalk as the skill says. Show me the SQL first. After the run, show jurisdiction, charity_concept, currency, has_income and charity_definition from ont_jurisdiction.
```
Expected: 5 rows; PL `has_income = false`, US `tax_exempt_organisation`, PL `public_benefit_status`.

## Prompt 2: Charity, Finances, Causes, with keys (clip 2)
```text
@charity-lens-ontology Create ont_charity, ont_charity_finances and ont_charity_cause from gold_charities with the rules from the skill. Then add the primary keys and foreign keys in two phases: primary keys first, then foreign keys. Before adding keys, prove each primary key is unique and that no foreign key has orphans. Show the SQL before each step.
```
Then open Catalog Explorer > `ont_charity` > the entity relationship view [VERIFY name and availability on Free Edition] for the shot.

## Prompt 3: Three ways to name a country (clip 3)
```text
@charity-lens-ontology Load raw/ref/country_map.csv as ont_country_map, build ont_country, then build ont_charity_programme_area as the skill says, with its keys. Show me, per jurisdiction, how many area codes are countries, regions and unmapped, and list every unmapped or region value with its organisation count. Don't guess any mapping.
```
Expected: GB-EAW, CA, AU only; CA regions = the CRA "Other countries in ..." codes; a few unmapped values (UK Sovereign Base Areas, Netherlands Antilles, CA `QZ`/`XZ`).

## Prompt 4: Metric views with a currency guard (clip 4, hero)
```text
@charity-lens-ontology Create mv_charity_finance, mv_charity_causes and mv_programme_reach exactly as the skill describes, with display names, synonyms and tags. Then run two queries: median_income_local and organisations per jurisdiction, and the same measures with no GROUP BY. Explain in one sentence why the second query returns NULL for money.
```
Expected: per-jurisdiction medians equal E4's `gold_jurisdiction_summary`; no-GROUP-BY row has NULL money. If the YAML fails, paste `../fallback/e05_4_metric_views.sql`.

## Prompt 5: A Page for "charity" (clip 5, only if Discover > Pages is available)
In the Page editor, domain = the Charity Lens domain, attach `ont_jurisdiction` as source:
```text
Draft a Page called "Charity (Charity Lens)" from the attached table. Explain in plain English that each country defines charity differently, with one short paragraph per jurisdiction based on charity_definition and comparability_note. Synonyms: charity, nonprofit, NGO, OPP, 501(c)(3), registered charity. No personal data.
```
Repeat for the other drafts in `pages.md` (or paste them). If Pages are not available, put the same text into the Genie Agent instructions (see `genie_agent_setup.md`) and say so in the post.

## Prompt 6: Create the donor Genie Agent with Genie Code (clip 6)
From Genie Agents > New (Genie Code opens automatically), or in the Genie Code pane:
```text
@charity-lens-ontology Create a Genie agent "Charity Lens: donor questions" for people who want to compare charities across the UK (England and Wales), Canada, Australia, the US and Poland. Use only mv_charity_finance, mv_charity_causes, mv_programme_reach, ont_charity and ont_jurisdiction. Add the instructions from the skill, and the example questions from genie_agent_setup.md. Show me the instructions before you save.
```

## Prompt 7: Donor questions (clip 7; in the Genie Agent, then Agent mode)
Chat mode, one by one:
```text
How big is a typical charity in each country?
```
```text
What is the total income of all charities in all five countries?
```
```text
I care about animals. Where are animal charities most common, and what does "charity" mean in each of those countries?
```
Agent mode (multi-step):
```text
I want to support education projects in Kenya through a charity registered in the UK, Canada or Australia. Which registers have the most organisations working in Kenya, how many of them list education as a cause, and what should I keep in mind when comparing their income?
```

## If Genie diverges (more than 2 retries)
Paste the matching file from `../fallback/` and say so in the caption. Common slips the skill should prevent: summing income across currencies, treating NULL income as 0, `LATERAL VIEW ... JOIN`, guessing country codes for regions, putting metric views in a notebook.
