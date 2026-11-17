# E5: What is a charity? One ontology for five registers, and a Genie Agent for donors

Second Charity Lens episode. On top of the five national registers loaded in E4 (England & Wales, Canada, Australia, US, Poland), we build a small cross-jurisdiction ontology in Unity Catalog (Jurisdiction, Charity, Finances, Cause, Programme country), three metric views with a currency guard, modeled knowledge for Genie Ontology, and a Genie Agent that answers donor questions. Free Edition only.

Blog post: [What Is a Charity? One Ontology for Five National Registers](https://white-pebble-015b3e003.6.azurestaticapps.net/posts/e05-charity-ontology/)

## What's here
| Path | What |
|---|---|
| `prompts/genie_code_prompts.md` | the seven Genie Code prompts, one per clip |
| `prompts/skills/charity-lens-ontology/SKILL.md` | Genie Code skill. Copy to `/Users/{username}/.assistant/skills/charity-lens-ontology/SKILL.md` |
| `prompts/genie_agent_setup.md` | Genie Agent "Charity Lens: donor questions": data, instructions, common and benchmark questions |
| `prompts/pages.md` | four Page drafts (Charity, OPP, Programme country, Median income) for Discover > Pages |
| `fallback/` | the whole layer in plain SQL (5 numbered files), example SQL for the agent, and three reference CSVs. See `fallback/README.md` |

## Requirements
- The E4 tables in `workspace.charity_lens` (`gold_charities`, `gold_jurisdiction_summary`, `ref_cause_map`) and the volume `raw`.
- A SQL warehouse (Free Edition has one, 2X-Small). Metric views are created in the SQL editor, not in a notebook.
- Upload `fallback/jurisdictions.csv`, `fallback/causes.csv` and `fallback/country_map.csv` to `/Volumes/workspace/charity_lens/raw/ref/`.

## Quick start without Genie
Run `fallback/e05_1_...` to `e05_5_...` in order in the SQL editor, then create the Genie Agent from `prompts/genie_agent_setup.md`.

## Objects created (all in `workspace.charity_lens`)
`ont_jurisdiction`, `ont_cause`, `ont_cause_crosswalk`, `ont_country`, `ont_country_map`, `ont_charity`, `ont_charity_finances`, `ont_charity_cause`, `ont_charity_programme_area`, `mv_charity_finance`, `mv_charity_causes`, `mv_programme_reach`. Nothing from E4 is changed.

## Data and licences
No new source data: everything is derived from the E4 registers, so the E4 attributions apply (see the [E4 data sources and licences](../e04-five-registers/README.md#data-sources-and-licences)). No personal data: only organisation-level columns.
