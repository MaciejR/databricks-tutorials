"""Synthetic Support Copilot raw data generator (deterministic).
Usage: python generate_support_data.py --out ./out --seed 42 --tickets 5000
Outputs (upload to /Volumes/workspace/support_copilot/raw/):
  customers/customers.csv, agents/agents.json (JSON lines), sla_policies/sla_policies.json (array),
  tickets/tickets_YYYY_MM.csv (monthly batches), ticket_events/events_YYYY_MM.jsonl
Deliberate messiness (for silver): duplicate ticket rows, mixed timestamp formats, inconsistent casing/whitespace
in priority/channel/status, null/blank emails, invalid emails, unknown customer_id (orphans), negative/blank CSAT,
closed_at < created_at, legacy priority codes (P1..P4), country name variants, late-arriving updates (same ticket_id
in later file with newer updated_at), stray HTML in subject/body.
Stdlib only."""
import argparse, csv, json, os, random
from datetime import datetime, timedelta

PRODUCTS = ["Billing", "Mobile App", "Web Portal", "API", "Integrations", "Account"]
CATEGORIES = {"Billing": ["refund", "invoice", "double charge"], "Mobile App": ["crash", "login", "push notifications"],
              "Web Portal": ["slow page", "export", "2FA"], "API": ["rate limit", "401 error", "webhook"],
              "Integrations": ["Salesforce sync", "Slack alerts", "SSO"], "Account": ["password reset", "plan change", "delete account"]}
PRIORITY_VARIANTS = {"urgent": ["Urgent", "URGENT", " urgent", "P1"], "high": ["High", "high ", "P2", "HIGH"],
                     "normal": ["Normal", "normal", "P3", "Medium"], "low": ["Low", "low", "P4", " LOW "]}
CHANNEL_VARIANTS = {"email": ["email", "Email", "E-mail"], "chat": ["chat", "Chat", "live_chat"],
                    "phone": ["phone", "Phone", "PHONE"], "web": ["web", "Web form", "webform"]}
STATUS_VARIANTS = {"open": ["open", "Open"], "pending": ["pending", "Pending", "waiting on customer"],
                   "solved": ["solved", "Solved", "resolved"], "closed": ["closed", "Closed", "CLOSED"]}
COUNTRIES = {"PL": ["Poland", "PL", "polska"], "DE": ["Germany", "DE", "Deutschland"], "US": ["USA", "United States", "US"],
             "GB": ["UK", "United Kingdom", "GB"], "FR": ["France", "FR"]}
TIERS = ["Free", "Pro", "Business", "Enterprise"]
FIRST = ["Anna", "Jan", "Ola", "Piotr", "Maria", "Tom", "Emma", "Lukas", "Sophie", "Noah", "Zofia", "Marek"]
LAST = ["Nowak", "Kowalski", "Smith", "Müller", "Martin", "Brown", "Wiśniewska", "Dubois", "Schmidt", "Lee"]
TS_FORMATS = ["%Y-%m-%d %H:%M:%S", "%Y-%m-%dT%H:%M:%SZ", "%d/%m/%Y %H:%M", "%Y-%m-%dT%H:%M:%S.000+00:00"]

def ts(r, d, messy=True):
    return d.strftime(r.choice(TS_FORMATS) if messy and r.random() < 0.15 else TS_FORMATS[1])

def main():
    p = argparse.ArgumentParser(); p.add_argument("--out", default="./out"); p.add_argument("--seed", type=int, default=42)
    p.add_argument("--tickets", type=int, default=5000); p.add_argument("--customers", type=int, default=800)
    p.add_argument("--agents", type=int, default=25); a = p.parse_args()
    r = random.Random(a.seed); start = datetime(2026, 7, 1)
    for sub in ["customers", "agents", "sla_policies", "tickets", "ticket_events"]:
        os.makedirs(os.path.join(a.out, sub), exist_ok=True)

    # SLA policies (clean reference data, JSON array)
    sla = []
    for tier_i, tier in enumerate(TIERS):
        for pr, (frt, res) in {"urgent": (60, 480), "high": (240, 1440), "normal": (480, 2880), "low": (1440, 7200)}.items():
            f = max(15, frt // (tier_i + 1)); sla.append({"policy_id": f"SLA-{tier[:3].upper()}-{pr[:1].upper()}",
                "customer_tier": tier, "priority": pr, "first_response_minutes": f, "resolution_minutes": max(f * 4, res // (tier_i + 1)),
                "business_hours_only": tier in ("Free", "Pro"), "effective_from": "2026-01-01"})
    json.dump(sla, open(os.path.join(a.out, "sla_policies", "sla_policies.json"), "w"), indent=2)
    sla_by = {(p["customer_tier"], p["priority"]): p for p in sla}

    # Customers (CSV, messy)
    custs = []
    with open(os.path.join(a.out, "customers", "customers.csv"), "w", newline="", encoding="utf-8") as f:
        w = csv.writer(f); w.writerow(["customer_id", "company_name", "contact_name", "contact_email", "country", "tier", "signup_date", "is_active"])
        for i in range(1, a.customers + 1):
            cid = f"C{i:05d}"; cc = r.choice(list(COUNTRIES)); tier = r.choices(TIERS, [40, 30, 20, 10])[0]
            fn, ln = r.choice(FIRST), r.choice(LAST); comp = f"{ln} {r.choice(['GmbH', 'Sp. z o.o.', 'Inc', 'Ltd', 'SAS'])}"
            email = f"{fn.lower()}.{ln.lower()}@example.com"; x = r.random()
            if x < 0.04: email = ""
            elif x < 0.07: email = email.replace("@", " at ")
            elif x < 0.10: email = email.upper()
            custs.append((cid, tier))
            w.writerow([cid, comp if r.random() > 0.03 else f"  {comp}  ", f"{fn} {ln}", email, r.choice(COUNTRIES[cc]),
                        tier if r.random() > 0.05 else tier.lower(), ts(r, start - timedelta(days=r.randint(30, 900))),
                        r.choice(["true", "True", "1", "yes"]) if r.random() > 0.08 else "false"])
            if r.random() < 0.02:  # exact duplicate customer row
                w.writerow([cid, comp, f"{fn} {ln}", email, cc, tier, "2025-01-01T00:00:00Z", "true"])
    tier_of = dict(custs)

    # Agents (JSON lines)
    agents = []
    with open(os.path.join(a.out, "agents", "agents.json"), "w") as f:
        for i in range(1, a.agents + 1):
            ag = {"agent_id": f"A{i:03d}", "full_name": f"{r.choice(FIRST)} {r.choice(LAST)}",
                  "team": r.choice(["L1 EMEA", "L1 AMER", "L2 Technical", "Billing Desk"]),
                  "hired_on": (start - timedelta(days=r.randint(60, 1500))).date().isoformat(),
                  "languages": r.sample(["en", "pl", "de", "fr"], r.randint(1, 3)), "active": r.random() > 0.1}
            if r.random() < 0.1: ag["team"] = ag["team"].lower()
            agents.append(ag["agent_id"]); f.write(json.dumps(ag, ensure_ascii=False) + "\n")

    # Tickets (monthly CSV batches) + events (JSONL)
    cols = ["ticket_id", "customer_id", "agent_id", "subject", "body", "product", "category", "priority", "channel", "status",
            "created_at", "first_response_at", "resolved_at", "updated_at", "csat_score", "language"]
    batches, events = {}, {}
    for t in range(1, a.tickets + 1):
        tid = f"T{t:06d}"; created = start + timedelta(minutes=r.randint(0, 60 * 24 * 110))
        cid = r.choice(custs)[0] if r.random() > 0.015 else f"C{r.randint(90000, 99999)}"  # orphan
        prod = r.choice(PRODUCTS); cat = r.choice(CATEGORIES[prod])
        pr = r.choices(list(PRIORITY_VARIANTS), [8, 22, 50, 20])[0]; ch = r.choice(list(CHANNEL_VARIANTS))
        tier = tier_of.get(cid, "Free"); pol = sla_by[(tier, pr)]
        # Handling times scale with the tier+priority SLA target, so breach odds are controlled per tier:
        # P(first response > target) = exp(-1/k): Free ~8%, Pro ~4%, Business ~1.5%, Enterprise <1%.
        k_frt, k_res, open_w = {"Free": (0.40, 0.33, 5), "Pro": (0.31, 0.25, 3), "Business": (0.27, 0.22, 2), "Enterprise": (0.17, 0.13, 0.25)}[tier]
        frt = timedelta(minutes=max(1, int(r.expovariate(1 / (pol["first_response_minutes"] * k_frt)))))
        res = frt + timedelta(minutes=int(r.expovariate(1 / (pol["resolution_minutes"] * k_res))))
        st = r.choices(list(STATUS_VARIANTS), [open_w, open_w, 30, 64 - 2 * open_w])[0]
        first = created + frt if (st != "open" or r.random() > 0.5) else None
        resolved = created + res if st in ("solved", "closed") else None
        if resolved and r.random() < 0.01: resolved = created - timedelta(hours=r.randint(1, 5))  # bad ordering
        csat = r.choices(["5", "4", "3", "2", "1", "", "-1", "N/A"], [30, 25, 10, 6, 5, 20, 2, 2])[0] if resolved else ""
        subj = f"{cat.capitalize()} issue with {prod}"
        if r.random() < 0.05: subj = f"<b>{subj}</b>"
        if r.random() < 0.03: subj = "RE: FW: " + subj
        body = f"Hi, we have a problem: {cat} in {prod}. Ticket opened via {ch}. Please help asap." + (" <br/>Thanks" if r.random() < 0.1 else "")
        upd = resolved or first or created
        row = [tid, cid, r.choice(agents) if first else "", subj, body, prod, cat, r.choice(PRIORITY_VARIANTS[pr]),
               r.choice(CHANNEL_VARIANTS[ch]), r.choice(STATUS_VARIANTS[st]), ts(r, created), ts(r, first) if first else "",
               ts(r, resolved) if resolved else "", ts(r, upd, messy=False), csat, r.choice(["en", "en", "en", "pl", "de"])]
        key = created.strftime("%Y_%m"); batches.setdefault(key, []).append(row)
        if r.random() < 0.02: batches[key].append(list(row))  # exact duplicate
        if st in ("open", "pending") and r.random() < 0.6:  # late update lands in a later batch
            later = min(created + timedelta(days=r.randint(5, 30)), datetime(2026, 10, 21, 18)); row2 = list(row)
            row2[9] = "solved"; row2[12] = ts(r, later, messy=False); row2[13] = ts(r, later, messy=False); row2[14] = r.choice(["4", "5", "3"])
            batches.setdefault(later.strftime("%Y_%m"), []).append(row2)
        evs = [("created", created)] + ([("first_response", first)] if first else []) + ([("resolved", resolved)] if resolved else [])
        for et, when in evs:
            events.setdefault(key, []).append({"event_id": f"E{t:06d}-{et}", "ticket_id": tid, "event_type": et,
                                               "event_ts": when.isoformat() + "Z", "actor": "customer" if et == "created" else "agent"})
    for k, rows in sorted(batches.items()):
        with open(os.path.join(a.out, "tickets", f"tickets_{k}.csv"), "w", newline="", encoding="utf-8") as f:
            w = csv.writer(f, quoting=csv.QUOTE_MINIMAL); w.writerow(cols); w.writerows(rows)
    for k, evs in sorted(events.items()):
        with open(os.path.join(a.out, "ticket_events", f"events_{k}.jsonl"), "w") as f:
            for e in evs: f.write(json.dumps(e) + "\n")
    print(f"Wrote data to {a.out} (seed={a.seed}): {sum(map(len, batches.values()))} ticket rows in {len(batches)} files")

if __name__ == "__main__":
    main()
