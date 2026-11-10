#!/usr/bin/env python3
"""Stage the PII-safe Charity Lens files for upload to a UC volume (E4).

Copies ONLY the allow-listed files from charity-lens/data/raw/ into
charity-lens/upload/<country>/, derives two org-level files (US 990 sample,
PL KRS sample) and writes SHA256SUMS + upload_manifest_staged.csv.
Hard-fails if any deny-listed file would be staged. Touches nothing outside
charity-lens/upload/. No network, no Databricks.
"""
import csv, hashlib, json, shutil, sys, xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3] / "charity-lens"
RAW, OUT = ROOT / "data" / "raw", ROOT / "upload"

COPY = {  # country -> files copied byte-for-byte
    "uk": ["publicextract.charity.nopii.txt",
           "publicextract.charity_annual_return_history.txt",
           "publicextract.charity_annual_return_partb.txt",
           "publicextract.charity_classification.txt",
           "publicextract.charity_area_of_operation.txt"],
    "au": ["datadotgov_main.nopii.csv", "datadotgov_ais24.nopii.csv"],
    "us": ["index_2026.csv", "eo_bmf/eo_bmf_all.nopii.csv"],
    "pl": ["wykaz_opp_2025_w_2026_10_2026.xlsx"],
    "ca": ["ident_2024_updated.nopii.csv",
           "new_ongoing_programs_2024_updated.nopii.csv",
           "schedule_2_resources_2024_updated.nopii.csv",
           "weburl_2024_updated.nopii.csv",
           "financial_section_a_b_and_c_2024_updated.csv",
           "financial_d_and_schedule_6_2024_updated.csv",
           "qualified_donees_2024_updated.csv",
           "schedule_2_details_2024.csv",
           "schedule_2_countries_2024.csv",
           "schedule_2_goods_2024_updated.csv",
           "schedule_3_compensation_2024.csv"],
}
DENY = {"uk/publicextract.charity.zip", "uk/publicextract.charity.txt",
        "au/datadotgov_main.csv", "au/datadotgov_ais24.csv",
        "ca/ident_2024_updated.csv", "ca/new_ongoing_programs_2024_updated.csv",
        "ca/schedule_2_resources_2024_updated.csv", "ca/weburl_2024_updated.csv",
        "us/eo_bmf/eo1.csv", "us/eo_bmf/eo2.csv", "us/eo_bmf/eo3.csv", "us/eo_bmf/eo4.csv"}
DENY_DIRS = ("us/xml_sample/", "pl/krs_sample/")  # only derived org-level files leave these


def sha256(p):
    h = hashlib.sha256()
    with open(p, "rb") as f:
        for b in iter(lambda: f.read(1 << 20), b""):
            h.update(b)
    return h.hexdigest()


def us_990_org(dst):
    """Org-level fields only: no PersonNm, officers, preparers, phones, addresses, free text."""
    def first(el, *paths):
        for p in paths:
            x = el.find(p)
            if x is not None and x.text:
                return x.text.strip()
        return ""
    cols = ["object_id", "ein", "name", "state", "return_type", "tax_period_end",
            "total_revenue", "total_expenses", "total_employees", "website"]
    with open(dst, "w", newline="", encoding="utf-8") as f:
        w = csv.writer(f); w.writerow(cols)
        for x in sorted((RAW / "us/xml_sample").glob("*.xml")):
            r = ET.parse(x).getroot()
            for e in r.iter():  # drop namespace
                e.tag = e.tag.split("}")[-1]
            h, d = r.find("ReturnHeader"), r.find("ReturnData")
            w.writerow([x.stem.replace("_public", ""),
                        first(h, "Filer/EIN"), first(h, "Filer/BusinessName/BusinessNameLine1Txt"),
                        first(h, "Filer/USAddress/StateAbbreviationCd"), first(h, "ReturnTypeCd"),
                        first(h, "TaxPeriodEndDt"),
                        first(d, "IRS990/CYTotalRevenueAmt", "IRS990EZ/TotalRevenueAmt"),
                        first(d, "IRS990/CYTotalExpensesAmt", "IRS990EZ/TotalExpensesAmt"),
                        first(d, "IRS990/TotalEmployeeCnt"),
                        first(d, "IRS990/WebsiteAddressTxt", "IRS990EZ/WebsiteAddressTxt")])


def pl_krs_org(dst):
    """Org-level KRS fields; drops e-mail, website, representation free text."""
    cols = ["krs", "nazwa", "forma_prawna", "nip", "regon", "czy_opp", "data_rejestracji",
            "wojewodztwo", "powiat", "gmina", "miejscowosc", "cel_dzialania",
            "pkd_opp_codes", "ostatnie_sprawozdanie_okres"]
    with open(dst, "w", newline="", encoding="utf-8") as f:
        w = csv.writer(f); w.writerow(cols)
        for p in sorted((RAW / "pl/krs_sample").glob("*.json")):
            o = json.load(open(p, encoding="utf-8")).get("odpis", json.load(open(p, encoding="utf-8")))
            a, d = o.get("naglowekA", {}), o.get("dane", {})
            d1, d3 = d.get("dzial1", {}), d.get("dzial3", {})
            dp, s = d1.get("danePodmiotu", {}), d1.get("siedzibaIAdres", {}).get("siedziba", {})
            ids = dp.get("identyfikatory", {})
            cel = d3.get("celDzialaniaOrganizacji") or {}
            cel = cel.get("celDzialania", "") if isinstance(cel, dict) else str(cel)
            pkd = []
            for k, v in d3.get("przedmiotDzialalnosciOPP", {}).items() if isinstance(d3.get("przedmiotDzialalnosciOPP"), dict) else []:
                for i in (v if isinstance(v, list) else [v]):
                    if isinstance(i, dict) and i.get("kodDzial"):
                        pkd.append(f"{i.get('kodDzial')}.{i.get('kodKlasa','')}.{i.get('kodPodklasa','')}".rstrip("."))
            spr = d3.get("wzmiankiOZlozonychDokumentach", {}).get("wzmiankaOZlozeniuRocznegoSprawozdaniaFinansowego", [])
            w.writerow([a.get("numerKRS", p.stem), dp.get("nazwa", ""), dp.get("formaPrawna", ""),
                        ids.get("nip", ""), ids.get("regon", ""), dp.get("czyPosiadaStatusOPP", ""),
                        a.get("dataRejestracjiWKRS", ""), s.get("wojewodztwo", ""), s.get("powiat", ""),
                        s.get("gmina", ""), s.get("miejscowosc", ""), " ".join(cel.split())[:2000],
                        "|".join(dict.fromkeys(pkd)), spr[-1].get("zaOkresOdDo", "") if spr else ""])


def pl_wykaz_csv(dst):
    """Same rows as the CC0 XLSX, as UTF-8 CSV with KRS/NIP kept as text (header is on sheet row 4)."""
    import openpyxl
    ws = openpyxl.load_workbook(RAW / "pl/wykaz_opp_2025_w_2026_10_2026.xlsx", read_only=True).worksheets[0]
    rows = list(ws.iter_rows(min_row=4, values_only=True))
    def txt(v):
        if v is None: return ""
        if isinstance(v, float) and v.is_integer(): v = int(v)
        return str(v).strip()
    with open(dst, "w", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        w.writerow(["lp", "nr_krs", "nr_nip", "nazwa", "wojewodztwo", "powiat", "gmina", "miejscowosc"])
        for r in rows[1:]:
            if r and r[1] not in (None, ""):
                r = [txt(v) for v in r[:8]]
                r[1] = r[1].zfill(10)
                w.writerow(r)


def main():
    if OUT.exists():
        shutil.rmtree(OUT)
    staged = []
    for c, files in COPY.items():
        (OUT / c).mkdir(parents=True, exist_ok=True)
        for rel in files:
            key = f"{c}/{rel}"
            assert key not in DENY and not key.startswith(DENY_DIRS), f"deny-listed: {key}"
            dst = OUT / c / Path(rel).name
            shutil.copy2(RAW / c / rel, dst); staged.append((key, dst))
    us_990_org(OUT / "us/irs990_sample_org.nopii.csv"); staged.append(("derived from us/xml_sample", OUT / "us/irs990_sample_org.nopii.csv"))
    pl_wykaz_csv(OUT / "pl/wykaz_opp_2025_w_2026_10_2026.csv"); staged.append(("derived from pl/wykaz_opp_2025_w_2026_10_2026.xlsx", OUT / "pl/wykaz_opp_2025_w_2026_10_2026.csv"))
    pl_krs_org(OUT / "pl/krs_sample_org.nopii.csv"); staged.append(("derived from pl/krs_sample", OUT / "pl/krs_sample_org.nopii.csv"))
    (OUT / "ref").mkdir(exist_ok=True)
    for ref in ("cause_map.csv", "fx_rates_template.csv"):  # PII-free lookups from the tutorial repo
        dst = OUT / "ref" / ref
        shutil.copy2(Path(__file__).resolve().parents[1] / "fallback" / ref, dst); staged.append((f"tutorials/e04-five-registers/fallback/{ref}", dst))
    total = 0
    with open(OUT / "SHA256SUMS", "w") as s, open(OUT / "upload_manifest_staged.csv", "w", newline="") as m:
        mw = csv.writer(m); mw.writerow(["volume_path", "source", "bytes", "sha256"])
        for src, dst in staged:
            rel, size, h = dst.relative_to(OUT).as_posix(), dst.stat().st_size, sha256(dst)
            total += size; s.write(f"{h}  {rel}\n")
            mw.writerow([f"/Volumes/workspace/charity_lens/raw/{rel}", src, size, h])
    print(f"staged {len(staged)} files, {total:,} bytes ({total/1e6:.1f} MB) into {OUT}")


if __name__ == "__main__":
    sys.exit(main())
