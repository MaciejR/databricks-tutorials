# Databricks Free Edition tutorials

Companion code for a hands-on blog series. We build a Support Copilot on Databricks Free Edition, one episode at a time, mostly with Genie Code in Agent mode. Each folder holds what the matching post asks you to use: data, skills, prompts and a reference SQL fallback for when the agent's output differs from ours.

| Episode | Folder | What's inside |
|---|---|---|
| E1: One Prompt, One Pipeline | [`e01-genie-code-pipeline/`](e01-genie-code-pipeline/) | Messy support-ticket data generator (`data_generator/`), the same data pre-generated with seed 42 (`raw_data.zip`), the extra ticket batch for the incremental step (`extra/`), the `support-copilot-medallion` skill and prompts (`prompts/`), reference bronze/silver/gold SQL (`fallback_pipeline/`) |
| E2: Documents into Data | [`e02-agent-bricks-documents/`](e02-agent-bricks-documents/) | PDF attachment generator and ground truth (`data_generator/`), the 48 generated PDFs plus index (`raw_data.zip`), the `support-copilot-documents` skill and prompts (`prompts/`), reference SQL and a scoring query (`fallback/`) |
| E3: Modeling the Business with Unity Catalog | [`e03-uc-semantics/`](e03-uc-semantics/) | The `support-copilot-semantics` skill and prompts (`prompts/`), four numbered SQL files: key checks, the duplicate fix, keys and comments, the metric view (`fallback/`) |
| E4: Five National Charity Registers | [`e04-five-registers/`](e04-five-registers/) | First Charity Lens episode: the `charity-lens-registers` skill and prompts (`prompts/`), bronze/silver/gold fallback SQL, licence tags and checks (`fallback/`), the upload allow-list and staging script (`upload/`). No register data: download it from the publishers listed in the folder README |

## How to use it with Databricks Free Edition

1. Sign up for [Databricks Free Edition](https://www.databricks.com/learn/free-edition). Serverless compute and the starter SQL warehouse are all we need.
2. Create the schema and volume once:
   ```sql
   CREATE SCHEMA IF NOT EXISTS workspace.support_copilot;
   CREATE VOLUME IF NOT EXISTS workspace.support_copilot.raw;
   ```
3. Load the E1 data: run `python e01-genie-code-pipeline/data_generator/generate_support_data.py --out <folder> --seed 42` (standard library only), or unzip `e01-genie-code-pipeline/raw_data.zip`. Upload the folders to `/Volumes/workspace/support_copilot/raw/` (Catalog > workspace > support_copilot > raw > Upload to this volume).
4. Copy a skill folder from `eNN-.../prompts/skills/` to `/Users/{username}/.assistant/skills/` in your workspace, then start a **new** Genie Code chat so it picks the skill up.
5. Follow the post. If your agent's output differs from ours (agents are not deterministic), run the SQL in the episode's fallback folder to get the exact tables used in the rest of the series.

Episodes build on each other: E2 and E3 expect the E1 tables in `workspace.support_copilot`.

## Data

E1–E3 data is synthetic, made by the generators in this repo: fictional companies and people, `example.com` emails, invented invoices and screenshots. Nothing comes from real customers. From E4 on we use real open data from national charity registers; it is not stored here, and each episode folder lists the sources and licences.

## Licence

Code, SQL, skills and prompts: [MIT](LICENSE). The synthetic data is released under the same terms.
