#!/usr/bin/env bash
# Regenerates og-image.jpg — the 1200x630 social sharing card.
#
# It renders the real hero section from index.html in headless Chrome, so the
# card always matches the live hero. Re-run this after changing hero copy,
# colours, or the chat mockup:
#
#   ./make-og.sh
#
set -euo pipefail

cd "$(dirname "$0")"

CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
[ -x "$CHROME" ] || { echo "Google Chrome not found at $CHROME" >&2; exit 1; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# Build a throwaway copy of the page: hero only, frozen animations, 1200x630.
python3 - "$TMP/og.html" <<'PY'
import sys, pathlib

src = pathlib.Path("index.html").read_text(encoding="utf-8")

overrides = """
<style id="og-card">
  /* --- social card framing: hero only, 1200x630, animations frozen --- */
  html, body { width:1200px; height:630px; overflow:hidden; background:var(--ink-navy); }
  body > *:not(nav.nav):not(header.hero) { display:none !important; }

  .nav { position:static; background:transparent; backdrop-filter:none; border-bottom:none; }
  .nav .wrap { padding-top:30px; padding-bottom:0; }
  .nav-links, .nav-cta { display:none; }
  .nav-mark { font-size:1.45rem; }
  .nav-logo { width:36px; height:36px; }

  .hero { padding:30px 0 0; height:552px; display:flex; align-items:center; }
  .hero::before { mask-image: radial-gradient(ellipse 70% 70% at 30% 30%, black 0%, transparent 78%); }
  .hero .wrap { width:100%; gap:52px; align-items:center; }
  .hero h1 { font-size:3.5rem; margin:16px 0 20px; }
  .hero p.lede { font-size:1.02rem; line-height:1.55; max-width:42ch; margin-bottom:28px; }
  .cta-row { gap:16px; }
  .btn-ghost { display:none; }

  /* chat bubbles normally fade in over ~4s — show them settled */
  .bubble { opacity:1; transform:none; animation:none; }
  .chat { min-height:0; gap:9px; }
  .phone { max-width:404px; }
</style>
"""

out = src.replace("</head>", overrides + "</head>", 1)
pathlib.Path(sys.argv[1]).write_text(out, encoding="utf-8")
PY

"$CHROME" \
  --headless=new \
  --disable-gpu \
  --hide-scrollbars \
  --force-device-scale-factor=1 \
  --window-size=1200,630 \
  --virtual-time-budget=8000 \
  --screenshot="$TMP/og.png" \
  "file://$TMP/og.html" >/dev/null 2>&1

[ -s "$TMP/og.png" ] || { echo "Chrome produced no screenshot" >&2; exit 1; }

# JPEG keeps the card well under the ~300KB that WhatsApp/LinkedIn prefer.
sips -s format jpeg -s formatOptions 82 "$TMP/og.png" --out og-image.jpg >/dev/null

echo "Wrote og-image.jpg ($(du -h og-image.jpg | cut -f1))"
