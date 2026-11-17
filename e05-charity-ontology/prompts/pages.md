# Page drafts for Discover > Pages (Unity Catalog semantics)

Pages belong to a domain, so create a "Charity Lens" domain first (built on a governed tag). Domain metadata, tags and Page text are replicated globally: no personal data in any of them. If Pages or domains are not available on Free Edition, paste these texts into the Genie Agent instructions instead and say so in the post.
Related assets for every Page: `ont_jurisdiction`, `ont_charity`, the relevant metric view. Sources: the register pages listed in `ont_jurisdiction.source_url`.

---
## Charity (Charity Lens)
**Synonyms:** charity, nonprofit, non-profit, NGO, registered charity, 501(c)(3), OPP
**Description:** What one organisation row means in each of the five registers. The word "charity" is not the same legal thing in every country.

- **England and Wales (GB-EAW):** a charity registered with the Charity Commission under the Charities Act 2011. Scotland and Northern Ireland have their own regulators and are not included.
- **Canada (CA):** a charity registered with the Canada Revenue Agency under the Income Tax Act: a charitable organisation, a public foundation or a private foundation.
- **Australia (AU):** a charity registered with the ACNC under the Charities Act 2013 (Cth).
- **United States (US):** an organisation recognised as tax-exempt under section 501(c)(3) in the IRS Exempt Organizations Business Master File. This is a list of tax exemptions, not a charity register.
- **Poland (PL):** there is no legal charity category. A public benefit organisation (OPP) is a status granted to NGOs; OPPs on the NIW-CRSO list can receive 1.5% of personal income tax.

Compare counts and shares between countries only with these definitions in view. See `ont_jurisdiction.charity_definition`.

---
## Public benefit organisation (OPP)
**Synonyms:** OPP, organizacja pożytku publicznego, 1.5% organisation, Polish charity
**Description:** The Polish status used in Charity Lens in place of "charity".

OPP status is granted under the Act of 24 April 2003 on public benefit activity and volunteering. Charity Lens uses the NIW-CRSO list of OPPs eligible for 1.5% of income tax. The list has no financial figures, so Polish rows have no income (`income_status = not_available`). Legal form and activity codes exist only for a 200-organisation sample from the KRS register.

---
## Programme country
**Synonyms:** country of operation, where they work, area of operation, overseas activity
**Description:** A country where an organisation says it carries out activities, normalised to ISO 3166-1 alpha-2.

Only three registers publish it, each in its own format: England and Wales (country names), Canada (T3010 Schedule 2: ISO codes plus CRA region codes such as "Other countries in Africa") and Australia (ISO alpha-3 codes). The US and Polish data used here have no programme countries. Regions and values without an ISO code are kept as `region` or `unmapped`, never guessed. See `mv_programme_reach`.

---
## Median income (local currency)
**Synonyms:** typical income, median revenue, typical charity size
**Description:** The middle income value among organisations with income above zero, in the register's own currency.

Organisations with no income figure or with zero or negative income are excluded and counted separately (`organisations_with_income`, `share_zero_or_missing_income`). Amounts are never converted or combined across currencies; a result that mixes currencies returns no value. Income definitions differ: UK latest income, Canada T3010 line 4700, Australia AIS total revenue, US Form 990 or BMF revenue amount. See `mv_charity_finance`.
