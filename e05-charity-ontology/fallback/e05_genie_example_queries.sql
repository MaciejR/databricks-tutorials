-- E5: example SQL queries for the Genie Agent "Charity Lens: donor questions" (Configure > Instructions > SQL queries).
-- Each block = one example. Title goes in the Genie UI; the SQL below it is pasted as the answer.
-- Keep them few and focused (Databricks guidance: start small, prefer example SQL over long text instructions).

-- Title: How big is a typical charity in each country?
SELECT jurisdiction, currency,
       MEASURE(organisations) AS organisations,
       MEASURE(organisations_with_income) AS organisations_with_income,
       MEASURE(median_income_local) AS median_income_local
FROM workspace.charity_lens.mv_charity_finance
GROUP BY ALL ORDER BY jurisdiction;

-- Title: What is the total income of all charities in all five countries?
-- (Teaches the refusal: one total per currency, never a grand total.)
SELECT jurisdiction, currency, MEASURE(total_income_local) AS total_income_local
FROM workspace.charity_lens.mv_charity_finance
WHERE income_status = 'reported_positive'
GROUP BY ALL ORDER BY jurisdiction;

-- Title: Which countries have the highest share of animal charities?
SELECT jurisdiction, MEASURE(organisations) AS organisations, MEASURE(share_of_jurisdiction) AS share_of_jurisdiction
FROM workspace.charity_lens.mv_charity_causes
WHERE cause = 'animals'
GROUP BY ALL ORDER BY share_of_jurisdiction DESC;

-- Title: How much of their spending goes to charitable activities?
SELECT jurisdiction, charity_kind,
       MEASURE(organisations_with_spending_breakdown) AS organisations_with_breakdown,
       MEASURE(median_charitable_spending_share) AS median_charitable_share,
       MEASURE(median_fundraising_share) AS median_fundraising_share
FROM workspace.charity_lens.mv_charity_finance
WHERE jurisdiction IN ('GB-EAW', 'CA')
GROUP BY ALL ORDER BY jurisdiction, charity_kind;

-- Title: Which charities registered in the UK, Canada or Australia work in Ukraine?
SELECT c.jurisdiction, c.name, c.charity_kind, f.currency, f.income
FROM workspace.charity_lens.ont_charity_programme_area a
JOIN workspace.charity_lens.ont_charity c USING (charity_id)
JOIN workspace.charity_lens.ont_charity_finances f USING (charity_id)
WHERE a.iso2 = 'UA'
ORDER BY c.jurisdiction, f.income DESC NULLS LAST
LIMIT 30;

-- Title: What does "charity" mean in each country?
SELECT jurisdiction, jurisdiction_name, charity_concept, charity_definition, has_income, comparability_note
FROM workspace.charity_lens.ont_jurisdiction
ORDER BY jurisdiction;
