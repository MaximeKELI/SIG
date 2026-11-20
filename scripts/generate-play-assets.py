#!/usr/bin/env python3
"""Génère feature graphic + icône haute-rés Play Store."""
from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "mobile" / "store"
OUT.mkdir(parents=True, exist_ok=True)

EMERALD = (13, 40, 24)
EMERALD2 = (19, 78, 42)
GOLD = (201, 169, 98)
CREAM = (245, 230, 200)


def _font(size: int) -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
    candidates = [
        ROOT / "mobile/assets/fonts/Outfit-Bold.ttf",
        ROOT / "mobile/assets/fonts/Outfit-SemiBold.ttf",
        "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
    ]
    for p in candidates:
        if Path(p).is_file():
            return ImageFont.truetype(str(p), size=size)
    return ImageFont.load_default()


def feature_graphic() -> None:
    w, h = 1024, 500
    img = Image.new("RGB", (w, h), EMERALD)
    draw = ImageDraw.Draw(img)
    for y in range(h):
        t = y / h
        r = int(EMERALD[0] + (EMERALD2[0] - EMERALD[0]) * t)
        g = int(EMERALD[1] + (EMERALD2[1] - EMERALD[1]) * t)
        b = int(EMERALD[2] + (EMERALD2[2] - EMERALD[2]) * t)
        draw.line([(0, y), (w, y)], fill=(r, g, b))
    # bande or
    draw.rectangle([0, h - 8, w, h], fill=GOLD)
    title = _font(64)
    sub = _font(28)
    draw.text((64, 160), "SIG Sols Togo", fill=CREAM, font=title)
    draw.text((64, 250), "DUSOL · DISIA · Cartographie des sols", fill=GOLD, font=sub)
    # logo si dispo
    icon = ROOT / "frontend/icons/icon-512.png"
    if icon.is_file():
        logo = Image.open(icon).convert("RGBA").resize((220, 220))
        img.paste(logo, (760, 140), logo)
    path = OUT / "feature-graphic-1024x500.png"
    img.save(path, "PNG")
    print(f"OK → {path}")


def hi_res_icon() -> None:
    src = ROOT / "frontend/icons/icon-512.png"
    path = OUT / "icon-512.png"
    if src.is_file():
        Image.open(src).convert("RGBA").resize((512, 512)).save(path, "PNG")
    else:
        img = Image.new("RGBA", (512, 512), EMERALD + (255,))
        draw = ImageDraw.Draw(img)
        draw.ellipse([48, 48, 464, 464], fill=EMERALD2 + (255,), outline=GOLD + (255,), width=12)
        draw.text((140, 220), "SIG", fill=CREAM, font=_font(72))
        img.save(path, "PNG")
    print(f"OK → {path}")


def readme() -> None:
    text = """# Assets Play Store — SIG Sols Togo

| Fichier | Usage Play Console |
|---------|-------------------|
| `feature-graphic-1024x500.png` | Graphique de fonctionnalité |
| `icon-512.png` | Icône haute résolution |

Captures d'écran (à ajouter manuellement) :
- Téléphone : min. 2, 16:9 ou 9:16, entre 320px et 3840px
- Recommandé : carte, dashboard, quiz, parcelle GPS

Régénérer : `python3 scripts/generate-play-assets.py`
"""
    (OUT / "README.md").write_text(text, encoding="utf-8")
    print(f"OK → {OUT / 'README.md'}")


if __name__ == "__main__":
    feature_graphic()
    hi_res_icon()
    readme()
