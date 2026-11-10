# Data generator
```bash
python generate_support_data.py --out ./out --seed 42      # stdlib only, ~2 s
```
Run locally, or in a Free Edition notebook writing straight to the volume:
```python
%sql CREATE SCHEMA IF NOT EXISTS workspace.support_copilot;
%sql CREATE VOLUME IF NOT EXISTS workspace.support_copilot.raw;
# upload generate_support_data.py to the workspace, then:
%run python generate_support_data.py --out /Volumes/workspace/support_copilot/raw --seed 42
```
(or `!python generate_support_data.py --out /Volumes/workspace/support_copilot/raw`). UI alternative: Catalog > workspace > support_copilot > raw > Upload to this volume.

Volume layout: `customers/`, `agents/`, `sla_policies/`, `tickets/` (monthly CSV batches, good for showing Auto Loader incremental pickup), `ticket_events/`.

Planted issues silver must fix: duplicates, 4 timestamp formats, priority/channel/status variants (P1..P4, casing, whitespace), invalid/blank emails, orphan customer_ids (~1.5%), CSAT `-1`/`N/A`/blank, resolved_at < created_at (~1%), country variants, HTML in subject/body, late-arriving status updates (same ticket_id, newer updated_at -> needs dedup by latest updated_at / AUTO CDC).
