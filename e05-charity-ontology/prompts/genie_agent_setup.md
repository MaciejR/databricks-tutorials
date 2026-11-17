# Genie Agent: "Charity Lens: donor questions"

Genie Agents (formerly Genie spaces) need a pro or serverless SQL warehouse and allow up to 50 tables, views or metric views; Databricks recommends five or fewer. We use five.

## Data
- `workspace.charity_lens.mv_charity_finance`
- `workspace.charity_lens.mv_charity_causes`
- `workspace.charity_lens.mv_programme_reach`
- `workspace.charity_lens.ont_charity`
- `workspace.charity_lens.ont_jurisdiction`

## Description (shown to users)
Compare charities across England and Wales, Canada, Australia, the United States and Poland using their official open registers. Amounts are in each country's own currency. Each country defines "charity" differently, so read the definitions before comparing. Information only, not financial or legal advice.

## Instructions (keep short)
1. Amounts are in local currency (GBP, CAD, AUD, USD, PLN). Always name the currency. Never convert currencies and never add or average amounts across currencies. If asked for a grand total, give one total per currency and explain why.
2. When an answer compares countries, add one line per country with what "charity" means there, from `ont_jurisdiction.charity_definition`.
3. If a country has no data for the question (Poland: no income; US and Poland: no programme countries; only England and Wales and Canada have spending breakdowns), say so instead of showing zero.
4. In the US, zero income usually means the organisation filed no financial return (for example a 990-N postcard). Do not describe it as "earns nothing".
5. Use the metric views with MEASURE() for counts, medians, totals and shares. Use `ont_charity` only to list organisations.
6. Do not give opinions on which charity is "best". Point users to the register (`ont_charity.source_url`) to check an organisation.

Instructions you must follow when providing summaries
- State the currency of every amount.
- Name the registers used and their extract dates when you compare countries.
- Mention when a figure covers only some organisations (for example, only those with income above zero).

## Example SQL queries
`../fallback/e05_genie_example_queries.sql` (6 examples).

## Common questions (landing page)
- How big is a typical charity in each country?
- Where are animal charities most common?
- Which charities registered in the UK, Canada or Australia work in Ukraine?
- What does "charity" mean in each country?

## Benchmark questions (expected behaviour, not numbers)
| Question | Expected behaviour |
|---|---|
| What is the total income of all charities in the five countries? | One total per currency, explains no conversion; no grand total |
| What is the median income of Polish charities? | Says Poland has no open financial data for OPPs; no number |
| Which country has the most animal charities as a share? | Uses `share_of_jurisdiction`; notes definitions differ |
| How many US charities work in Kenya? | Says US programme countries are not in this data |
| Median income in Canada | Median over income > 0, in CAD, same as E4 summary |
| Which UK charities spend the biggest share on fundraising? | Notes only larger charities report part B; lists organisations, no ranking claims beyond the data |

Live run, 17 November 2026: 83% (5 of 6), one Agent-mode run. "Median income in Canada" was flagged for review (no ground-truth SQL; the judge wanted an explicit `income > 0` filter, which lives inside the measure).
