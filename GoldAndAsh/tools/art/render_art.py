#!/usr/bin/env python3
"""Re-render the GOLD & ASH (금빛과 재) key art with headless Chromium.

    python3 tools/art/render_art.py                 # all three images -> docs/
    python3 tools/art/render_art.py --only icon     # icon | icon_en | thumbnail
    python3 tools/art/render_art.py --out /tmp/art  # render somewhere else

Outputs (default: GoldAndAsh/docs/):
    icon.png       512x512   Korean title   (icon.html?lang=ko)
    icon_en.png    512x512   English title  (icon.html?lang=en)
    thumbnail.png  1920x1080                (thumbnail.html)

All artwork is procedural SVG drawn in icon.html / thumbnail.html / common.js.

Fonts (SIL OFL, Google Fonts) are NOT stored in the repo. They are cached in
    $GOLDASH_FONT_DIR   (default: ~/.cache/goldandash-fonts)
and downloaded from fonts.gstatic.com if missing. The script injects them into
the page through the FontFace API, so the HTML files can also be opened directly
in a browser (they then fall back to locally installed fonts of the same name).

Requires: pip install playwright   (a Chromium build; if Playwright's bundled
browser version does not match, set CHROME_PATH or keep one under
/opt/pw-browsers/chromium-*/chrome-linux/chrome).
"""
from __future__ import annotations

import argparse
import base64
import glob
import os
import sys
import urllib.request
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent.parent  # GoldAndAsh/

FONT_DIR = Path(os.environ.get("GOLDASH_FONT_DIR", Path.home() / ".cache" / "goldandash-fonts"))
# family name used in CSS -> (file name, URL). All SIL Open Font License.
FONTS = {
    "Black Han Sans": ("BlackHanSans.ttf", "https://fonts.gstatic.com/s/blackhansans/v24/ea8Aad44WunzF9a-dL6toA8r8nqV.ttf"),
    "Anton": ("Anton.ttf", "https://fonts.gstatic.com/s/anton/v27/1Ptgg87LROyAm0K0.ttf"),
    "Do Hyeon": ("DoHyeon.ttf", "https://fonts.gstatic.com/s/dohyeon/v21/TwMN-I8CRRU2zM86HFE3.ttf"),
}

JOBS = {
    "icon": ("icon.html", "lang=ko", 512, 512, "icon.png"),
    "icon_en": ("icon.html", "lang=en", 512, 512, "icon_en.png"),
    "thumbnail": ("thumbnail.html", "", 1920, 1080, "thumbnail.png"),
}


def ensure_fonts() -> dict[str, str]:
    FONT_DIR.mkdir(parents=True, exist_ok=True)
    out = {}
    for family, (fname, url) in FONTS.items():
        path = FONT_DIR / fname
        if not path.exists():
            print(f"downloading {family} -> {path}")
            req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
            with urllib.request.urlopen(req, timeout=60) as r:
                path.write_bytes(r.read())
        out[family] = base64.b64encode(path.read_bytes()).decode("ascii")
    return out


def find_chrome() -> str | None:
    if os.environ.get("CHROME_PATH"):
        return os.environ["CHROME_PATH"]
    hits = sorted(glob.glob("/opt/pw-browsers/chromium-*/chrome-linux/chrome"))
    return hits[-1] if hits else None


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--only", choices=sorted(JOBS), action="append")
    ap.add_argument("--out", default=str(ROOT / "docs"))
    args = ap.parse_args()

    from playwright.sync_api import sync_playwright

    fonts = ensure_fonts()
    out_dir = Path(args.out)
    out_dir.mkdir(parents=True, exist_ok=True)
    init = "window.__FONTS = " + repr(fonts).replace("'", '"') + ";"

    with sync_playwright() as p:
        try:
            browser = p.chromium.launch()
        except Exception:
            exe = find_chrome()
            if not exe:
                raise
            browser = p.chromium.launch(executable_path=exe)
        for key in args.only or list(JOBS):
            html, query, w, h, name = JOBS[key]
            page = browser.new_page(viewport={"width": w, "height": h}, device_scale_factor=1)
            page.add_init_script(init)
            url = (HERE / html).as_uri() + (("?" + query) if query else "")
            page.goto(url)
            page.wait_for_function("window.__ready === true", timeout=60000)
            dest = out_dir / name
            page.screenshot(path=str(dest), clip={"x": 0, "y": 0, "width": w, "height": h})
            print(f"wrote {dest} ({w}x{h})")
            page.close()
        browser.close()
    return 0


if __name__ == "__main__":
    sys.exit(main())
