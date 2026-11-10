-- E4: licence and attribution as UC tags + comments. Run from a notebook (SQL cell) AFTER the pipeline run.
-- Tag keys are plain (non-governed) tags; create governed tags with the same keys first if you want an allowed-value list.
-- [VERIFY] SET TAGS on pipeline-managed materialized views on Free Edition (E3 runbook lists it as still to test).

ALTER VOLUME workspace.charity_lens.raw SET TAGS ('domain' = 'charity_lens', 'contains_pii' = 'false');
COMMENT ON VOLUME workspace.charity_lens.raw IS 'Charity Lens raw open data. Only PII-free (.nopii or org-level) files; see tutorials/e04-five-registers/upload/upload_manifest.md.';

-- UK
ALTER MATERIALIZED VIEW workspace.charity_lens.silver_uk_charities SET TAGS (
  'source' = 'Charity Commission for England and Wales', 'licence' = 'OGL-UK-3.0',
  'licence_url' = 'https://www.nationalarchives.gov.uk/doc/open-government-licence/version/3/',
  'attribution' = 'Contains public sector information licensed under the Open Government Licence v3.0.',
  'extract_date' = '2026-10-23', 'contains_pii' = 'false');
-- Canada
ALTER MATERIALIZED VIEW workspace.charity_lens.silver_ca_charities SET TAGS (
  'source' = 'Canada Revenue Agency T3010 2024', 'licence' = 'OGL-Canada-2.0', 'licence_verified' = 'true',
  'licence_url' = 'https://open.canada.ca/en/open-government-licence-canada',
  'attribution' = 'Contains information licensed under the Open Government Licence – Canada.',
  'extract_date' = '2026-10-26', 'contains_pii' = 'false');
-- Australia
ALTER MATERIALIZED VIEW workspace.charity_lens.silver_au_charities SET TAGS (
  'source' = 'ACNC Charity Register + 2024 AIS (data.gov.au)', 'licence' = 'CC-BY-3.0-AU',
  'licence_url' = 'https://creativecommons.org/licenses/by/3.0/au/',
  'attribution' = 'Source: Australian Charities and Not-for-profits Commission (ACNC), data.gov.au, CC BY 3.0 AU.',
  'extract_date' = '2026-10-23', 'contains_pii' = 'false');
-- US
ALTER MATERIALIZED VIEW workspace.charity_lens.silver_us_charities SET TAGS (
  'source' = 'IRS EO BMF + Form 990 e-file (TEOS)', 'licence' = 'US-Government-Work',
  'licence_url' = 'https://www.irs.gov/about-irs/use-of-content-from-irsgov',
  'attribution' = 'Source: U.S. Internal Revenue Service, irs.gov. Not endorsed by the IRS.',
  'extract_date' = '2026-10-24', 'contains_pii' = 'false');
-- Poland
-- OPP CC0 1.0 was verified via the dane.gov.pl API on 26 Oct 2026; a 10 Nov 2026 re-check failed (portal/API down).
-- KRS reuse terms verified 10 Nov 2026: Open Data Act (11 Aug 2021) + MoJ reuse conditions; no named CC/OGL licence.
ALTER MATERIALIZED VIEW workspace.charity_lens.silver_pl_charities SET TAGS (
  'source' = 'NIW-CRSO Wykaz OPP 1.5% (dane.gov.pl) + KRS API sample',
  'licence' = 'CC0-1.0 (wykaz); KRS Open Data Act reuse',
  'licence_url' = 'https://creativecommons.org/publicdomain/zero/1.0/',
  'licence_verified' = 'true',
  'attribution' = 'Źródło / Source: Narodowy Instytut Wolności – CRSO (dane.gov.pl), CC0 1.0; Ministerstwo Sprawiedliwości, Krajowy Rejestr Sądowy (Open API), processed sample obtained 25 Oct 2026.',
  'extract_date' = '2026-10-25', 'contains_pii' = 'false');
-- Gold
ALTER MATERIALIZED VIEW workspace.charity_lens.gold_charities SET TAGS (
  'licence' = 'mixed: see licence column per row', 'contains_pii' = 'false', 'layer' = 'gold');
