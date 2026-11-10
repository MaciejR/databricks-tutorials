#!/usr/bin/env python3
"""E2 Support Copilot ticket attachments generator (synthetic, no personal data).

Reads E1 tickets/customers, picks billing/technical tickets and renders realistic PDFs:
  - invoices (EN/PL/DE, PLN/EUR/GBP/USD, varied date + number formats)
  - refund request forms (some amounts disagree with the invoice on purpose)
  - error reports: app "screenshots" rendered as images, embedded in a PDF (no text layer -> needs OCR)
Outputs:
  <out>/attachments/ATT-xxxx.pdf          neutral names, so classification has to read the doc
  <out>/attachments_index/attachments_index.csv  helpdesk export: attachment_id, ticket_id, file_name, uploaded_at
  ground_truth.csv (next to this script by default) expected doc_type + key fields, for checking extraction
Usage: python generate_attachments.py --e1 ../../e01-genie-code-pipeline/raw_data --out ./out --seed 42 [--n 48]
Needs: reportlab, pillow.
"""
import argparse, csv, glob, io, os, random
from datetime import datetime, timedelta
from PIL import Image, ImageDraw, ImageFont, ImageFilter
from reportlab.lib.pagesizes import A4
from reportlab.lib.units import mm
from reportlab.lib.utils import ImageReader
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.pdfgen import canvas

FONT_DIR = "/usr/share/fonts/truetype/dejavu/"
for n, f in [("DV", "DejaVuSans.ttf"), ("DVB", "DejaVuSans-Bold.ttf"), ("DVM", "DejaVuSansMono.ttf")]:
    p = os.path.join(FONT_DIR, f)
    if os.path.exists(p):
        pdfmetrics.registerFont(TTFont(n, p))
F, FB = ("DV", "DVB") if "DV" in pdfmetrics.getRegisteredFontNames() else ("Helvetica", "Helvetica-Bold")

VENDOR = {"name": "Northwind Cloud Software Ltd. (fictional)", "addr": "1 Example Street, Example City", "vat": "XX000000000"}
PLANS = {"Free": 0, "Pro": 29, "Business": 99, "Enterprise": 499}
CUR = {"PL": "PLN", "DE": "EUR", "FR": "EUR", "GB": "GBP", "US": "USD", "CA": "USD", "AU": "USD"}
FX = {"PLN": 4.0, "EUR": 0.92, "GBP": 0.79, "USD": 1.0}
COUNTRY = {"polska": "PL", "poland": "PL", "pl": "PL", "germany": "DE", "deutschland": "DE", "de": "DE",
           "uk": "GB", "united kingdom": "GB", "gb": "GB", "usa": "US", "us": "US", "united states": "US",
           "france": "FR", "fr": "FR", "canada": "CA", "ca": "CA", "australia": "AU", "au": "AU"}
ERRORS = {
    "401 error": ("HTTP 401 Unauthorized", "Token expired or invalid. Request id: {rid}"),
    "crash": ("The app quit unexpectedly", "Exception: NullReferenceException at Dashboard.Render() build {build}"),
    "slow page": ("Gateway Timeout (504)", "Upstream did not respond within 30s. Trace {rid}"),
    "login": ("Sign-in failed", "Error AUTH-1042: too many attempts, try again in 15 min"),
    "export": ("Export failed", "CSV export job {rid} failed: row limit 100000 exceeded"),
    "SSO": ("SAML response invalid", "AADSTS50011: reply URL mismatch. Correlation {rid}"),
    "rate limit": ("429 Too Many Requests", "Rate limit 600/min exceeded for API key ****{k4}"),
    "webhook": ("Webhook delivery failed", "POST https://hooks.example.com/... -> 502 after 3 retries"),
}

def money(v, cur, lang):
    s = f"{v:,.2f}"
    if lang in ("pl", "de"):
        s = s.replace(",", " " if lang == "pl" else ".").replace(".", ",", 1) if lang == "pl" else s.replace(",", "X").replace(".", ",").replace("X", ".")
    sym = {"PLN": "zł", "EUR": "€", "GBP": "£", "USD": "$"}[cur]
    return f"{s} {sym}" if cur in ("PLN", "EUR") and lang != "en" else f"{sym}{s}" if cur != "PLN" else f"{s} PLN"

def fmt_date(d, style):
    return {0: d.strftime("%Y-%m-%d"), 1: d.strftime("%d.%m.%Y"), 2: d.strftime("%d %B %Y"), 3: d.strftime("%m/%d/%Y")}[style]

def load(e1):
    cust = {}
    for r in csv.DictReader(open(os.path.join(e1, "customers/customers.csv"), encoding="utf-8")):
        cust.setdefault(r["customer_id"], r)
    tix = {}
    for f in sorted(glob.glob(os.path.join(e1, "tickets/*.csv"))):
        for r in csv.DictReader(open(f, encoding="utf-8")):
            t = tix.get(r["ticket_id"])
            if t is None or r["updated_at"] > t["updated_at"]:
                tix[r["ticket_id"]] = r
    def ok(t):
        r = t["resolved_at"]
        return (t["customer_id"] in cust and t["created_at"][:4] == "2026" and t["created_at"].endswith("Z")
                and (not r or (r.endswith("Z") and r >= t["created_at"])))
    return cust, [t for t in tix.values() if ok(t)]

def lines_for(tier, rng, cur):
    base = PLANS.get(tier, 29) or 29
    seats = rng.choice([1, 3, 5, 10, 25])
    items = [(f"{tier if tier != 'Free' else 'Pro'} plan, monthly, per seat", seats, round(base * FX[cur], 2))]
    if rng.random() < 0.5:
        items.append(("Additional API calls (100k)", rng.randint(1, 4), round(15 * FX[cur], 2)))
    if rng.random() < 0.3:
        items.append(("Premium support add-on", 1, round(49 * FX[cur], 2)))
    return items

def invoice_pdf(path, t, c, rng, dup=False):
    cc = COUNTRY.get(c["country"].strip().lower(), "US"); cur = CUR.get(cc, "USD")
    lang = {"PL": "pl", "DE": "de"}.get(cc, "en") if rng.random() < 0.6 else "en"
    L = {"en": ("INVOICE", "Invoice no.", "Issue date", "Due date", "Bill to", "Description", "Qty", "Unit price", "Amount", "Subtotal", "VAT", "Total due"),
         "pl": ("FAKTURA VAT", "Nr faktury", "Data wystawienia", "Termin płatności", "Nabywca", "Opis", "Ilość", "Cena jedn.", "Wartość", "Netto", "VAT", "Do zapłaty"),
         "de": ("RECHNUNG", "Rechnungsnr.", "Rechnungsdatum", "Fällig am", "Rechnungsempfänger", "Beschreibung", "Menge", "Einzelpreis", "Betrag", "Zwischensumme", "MwSt.", "Gesamtbetrag")}[lang]
    created = datetime.fromisoformat(t["created_at"].replace("Z", ""))
    issue = created - timedelta(days=rng.randint(1, 20)); due = issue + timedelta(days=14)
    inv_no = f"INV-{issue:%Y%m}-{rng.randint(1000, 9999)}"
    items = lines_for(c["tier"], rng, cur)
    sub = round(sum(q * p for _, q, p in items), 2); vat_rate = {"PL": .23, "DE": .19, "GB": .20}.get(cc, 0.0)
    vat = round(sub * vat_rate, 2); total = round(sub + vat, 2)
    ds = rng.choice([0, 1, 2, 3])
    cv = canvas.Canvas(path, pagesize=A4); W, H = A4
    cv.setFillColorRGB(.12, .25, .45); cv.rect(0, H - 30 * mm, W, 30 * mm, fill=1, stroke=0)
    cv.setFillColorRGB(1, 1, 1); cv.setFont(FB, 20); cv.drawString(20 * mm, H - 18 * mm, L[0] + (" (DUPLICATE)" if dup else ""))
    cv.setFont(F, 9); cv.drawRightString(W - 20 * mm, H - 14 * mm, VENDOR["name"]); cv.drawRightString(W - 20 * mm, H - 19 * mm, VENDOR["addr"])
    cv.setFillColorRGB(0, 0, 0); y = H - 45 * mm; cv.setFont(F, 10)
    for k, v in [(L[1], inv_no), (L[2], fmt_date(issue, ds)), (L[3], fmt_date(due, ds)), ("Customer ID", t["customer_id"]), ("Ref. ticket", t["ticket_id"] if rng.random() < .7 else "")]:
        if v: cv.drawString(20 * mm, y, f"{k}: {v}"); y -= 6 * mm
    cv.setFont(FB, 10); cv.drawString(120 * mm, H - 45 * mm, L[4]); cv.setFont(F, 10)
    cv.drawString(120 * mm, H - 51 * mm, c["company_name"].strip()); cv.drawString(120 * mm, H - 57 * mm, f"Accounts payable, {cc}")
    y -= 8 * mm; cv.setFont(FB, 9)
    for x, h in [(20, L[5]), (110, L[6]), (130, L[7]), (165, L[8])]: cv.drawString(x * mm, y, h)
    cv.line(20 * mm, y - 2 * mm, W - 20 * mm, y - 2 * mm); y -= 8 * mm; cv.setFont(F, 9)
    for d, q, p in items:
        cv.drawString(20 * mm, y, d); cv.drawString(110 * mm, y, str(q)); cv.drawString(130 * mm, y, money(p, cur, lang)); cv.drawString(165 * mm, y, money(q * p, cur, lang)); y -= 6 * mm
    y -= 4 * mm
    for k, v, b in [(L[9], sub, F), (f"{L[10]} {int(vat_rate * 100)}%", vat, F), (L[11], total, FB)]:
        cv.setFont(b, 10); cv.drawString(130 * mm, y, k); cv.drawString(165 * mm, y, money(v, cur, lang)); y -= 6 * mm
    cv.setFont(F, 7); cv.setFillColorRGB(.4, .4, .4)
    cv.drawString(20 * mm, 15 * mm, "Synthetic document generated for a Databricks tutorial. Fictional company, no real transaction.")
    cv.save()
    return dict(doc_type="invoice", invoice_number=inv_no, document_date=issue.date().isoformat(), currency=cur, amount=total, language=lang)

def refund_pdf(path, t, c, rng, inv):
    cur = inv["currency"] if inv else CUR.get(COUNTRY.get(c["country"].strip().lower(), "US"), "USD")
    amt = inv["amount"] if inv else round(rng.uniform(20, 600), 2)
    mismatch = rng.random() < 0.25
    req = round(amt * rng.choice([1.1, 2, 0.5]), 2) if mismatch else amt
    reason = rng.choice(["Charged twice for the same billing period", "Downgraded plan but billed at old price",
                         "Cancelled before renewal, still charged", "Service outage longer than SLA allows"])
    d = datetime.fromisoformat(t["created_at"].replace("Z", "")) - timedelta(minutes=rng.randint(5, 300))
    cv = canvas.Canvas(path, pagesize=A4); W, H = A4
    cv.setFont(FB, 16); cv.drawString(20 * mm, H - 25 * mm, "Refund Request Form")
    cv.setFont(F, 9); cv.drawString(20 * mm, H - 31 * mm, "Please complete all fields. Incomplete forms delay processing.")
    rows = [("Company", c["company_name"].strip()), ("Customer ID", t["customer_id"]), ("Support ticket", t["ticket_id"]),
            ("Related invoice", inv["invoice_number"] if inv else "unknown / not attached"), ("Date of request", fmt_date(d, rng.choice([0, 1, 2]))),
            ("Amount requested", money(req, cur, "en")), ("Refund method", rng.choice(["Original payment method", "Bank transfer", "Account credit"])),
            ("Reason", reason)]
    y = H - 45 * mm
    for k, v in rows:
        cv.rect(20 * mm, y - 3 * mm, 170 * mm, 9 * mm); cv.setFont(FB, 9); cv.drawString(23 * mm, y, k); cv.setFont(F, 10); cv.drawString(75 * mm, y, v); y -= 11 * mm
    cv.setFont(F, 9); cv.drawString(20 * mm, y - 5 * mm, "Comments:")
    cv.drawString(20 * mm, y - 11 * mm, rng.choice(["Please process asap, our finance team closes the month on Friday.", "See attached invoice.", "Second request, first one was ignored.", ""]))
    cv.drawString(20 * mm, y - 30 * mm, "Signed: Accounts payable (signature on file)")
    cv.setFont(F, 7); cv.drawString(20 * mm, 15 * mm, "Synthetic document generated for a Databricks tutorial. Fictional company.")
    cv.save()
    return dict(doc_type="refund_request", invoice_number=inv["invoice_number"] if inv else "", document_date=d.date().isoformat(),
                currency=cur, amount=req, language="en", amount_mismatch=mismatch)

def screenshot_pdf(path, t, rng):
    title, msg = ERRORS.get(t["category"], ERRORS["crash"])
    msg = msg.format(rid=f"{rng.getrandbits(48):012x}", build=f"4.{rng.randint(1, 9)}.{rng.randint(0, 30)}", k4=f"{rng.randint(1000, 9999)}")
    W, H = 1400, 860
    im = Image.new("RGB", (W, H), (245, 246, 248)); d = ImageDraw.Draw(im)
    def font(sz, b=False):
        try: return ImageFont.truetype(FONT_DIR + ("DejaVuSans-Bold.ttf" if b else "DejaVuSans.ttf"), sz)
        except Exception: return ImageFont.load_default()
    d.rectangle([0, 0, W, 50], fill=(32, 33, 36)); [d.ellipse([15 + i * 25, 17, 31 + i * 25, 33], fill=c) for i, c in enumerate([(255, 95, 86), (255, 189, 46), (39, 201, 63)])]
    d.rectangle([110, 12, W - 30, 38], fill=(60, 64, 67)); d.text((125, 16), f"https://app.example.com/{t['product'].lower().replace(' ', '-')}", fill=(200, 200, 200), font=font(16))
    d.rectangle([0, 50, 240, H], fill=(255, 255, 255)); [d.text((25, 90 + i * 45), s, fill=(90, 90, 90), font=font(18)) for i, s in enumerate(["Dashboard", "Integrations", "Billing", "Settings"])]
    d.rounded_rectangle([380, 220, 1220, 560], 14, fill=(255, 255, 255), outline=(220, 53, 69), width=3)
    d.text((420, 255), "⚠ " + title, fill=(220, 53, 69), font=font(30, True)); d.text((420, 320), msg, fill=(40, 40, 40), font=font(18))
    ts = datetime.fromisoformat(t["created_at"].replace("Z", "")) - timedelta(minutes=rng.randint(2, 90))
    d.text((420, 370), f"Time: {ts:%Y-%m-%d %H:%M} UTC   Product: {t['product']}", fill=(110, 110, 110), font=font(16))
    d.rounded_rectangle([420, 470, 560, 520], 8, fill=(13, 110, 253)); d.text((452, 483), "Retry", fill=(255, 255, 255), font=font(18))
    if rng.random() < .4:  # phone photo / low-quality capture
        im = im.rotate(rng.uniform(-3, 3), expand=True, fillcolor=(30, 30, 30)).filter(ImageFilter.GaussianBlur(1.1))
    buf = io.BytesIO(); im.save(buf, "JPEG", quality=rng.choice([55, 70, 85])); buf.seek(0)
    cv = canvas.Canvas(path, pagesize=(W * .5, H * .5 + 40)); cv.drawImage(ImageReader(buf), 0, 0, W * .5, H * .5)
    cv.save()  # image only: no text layer on purpose
    return dict(doc_type="error_report", invoice_number="", document_date=ts.date().isoformat(), currency="", amount="", language="en", error_title=title)

def main():
    ap = argparse.ArgumentParser(); here = os.path.dirname(os.path.abspath(__file__))
    ap.add_argument("--e1", default=os.path.join(here, "../../e01-genie-code-pipeline/raw_data"))
    ap.add_argument("--out", default=os.path.join(here, "../raw_data")); ap.add_argument("--seed", type=int, default=42); ap.add_argument("--n", type=int, default=48)
    ap.add_argument("--truth", default=os.path.join(here, "ground_truth.csv")); a = ap.parse_args()
    rng = random.Random(a.seed); cust, tix = load(a.e1)
    billing = sorted([t for t in tix if t["category"] in ("invoice", "double charge", "refund", "plan change")], key=lambda t: t["ticket_id"])
    tech = sorted([t for t in tix if t["category"] in ERRORS], key=lambda t: t["ticket_id"])
    n_bill = a.n * 2 // 3 // 2  # tickets that get invoice (+ maybe refund)
    att_dir = os.path.join(a.out, "attachments"); idx_dir = os.path.join(a.out, "attachments_index")
    os.makedirs(att_dir, exist_ok=True); os.makedirs(idx_dir, exist_ok=True)
    index, truth, k = [], [], 0
    def add(t, fn_meta):
        nonlocal k; k += 1; aid = f"ATT-{k:04d}"; fn = f"{aid}.pdf"; meta = fn_meta(os.path.join(att_dir, fn))
        up = datetime.fromisoformat(t["created_at"].replace("Z", "")) + timedelta(minutes=rng.randint(0, 30))
        index.append(dict(attachment_id=aid, ticket_id=t["ticket_id"], file_name=fn, uploaded_at=up.strftime("%Y-%m-%dT%H:%M:%SZ")))
        truth.append(dict(attachment_id=aid, ticket_id=t["ticket_id"], **{x: meta.get(x, "") for x in ["doc_type", "invoice_number", "document_date", "currency", "amount", "language", "amount_mismatch", "error_title"]}))
        return meta
    for t in rng.sample(billing, n_bill):
        c = cust[t["customer_id"]]; inv = add(t, lambda p: invoice_pdf(p, t, c, rng))
        if t["category"] in ("refund", "double charge") or rng.random() < .5:
            add(t, lambda p: refund_pdf(p, t, c, rng, inv))
        if t["category"] == "double charge" and rng.random() < .5:
            add(t, lambda p: invoice_pdf(p, t, c, rng, dup=True))
    for t in rng.sample(tech, max(0, a.n - k)):
        add(t, lambda p: screenshot_pdf(p, t, rng))
    rng.shuffle(index)
    with open(os.path.join(idx_dir, "attachments_index.csv"), "w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=list(index[0])); w.writeheader(); w.writerows(sorted(index, key=lambda r: r["uploaded_at"]))
    with open(a.truth, "w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=list(truth[0])); w.writeheader(); w.writerows(truth)
    from collections import Counter
    print(f"{len(index)} attachments for {len({r['ticket_id'] for r in index})} tickets:", dict(Counter(r["doc_type"] for r in truth)))

if __name__ == "__main__":
    main()
