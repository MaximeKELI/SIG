"""Certificat PDF cérémonial luxe — SIG Sols Togo / DISIA · DUSOL."""
from __future__ import annotations

import hashlib
import math
from datetime import date
from io import BytesIO

from reportlab.lib.colors import Color, HexColor, white
from reportlab.lib.pagesizes import A4, landscape
from reportlab.lib.units import cm, mm
from reportlab.pdfgen import canvas

# Palette institutionnelle émeraude · or champagne · ivoire
IVORY = HexColor('#F7F1E3')
IVORY_DEEP = HexColor('#EDE4D0')
EMERALD_950 = HexColor('#061a10')
EMERALD_900 = HexColor('#0d2818')
EMERALD_800 = HexColor('#134e2a')
EMERALD_700 = HexColor('#1a5c3a')
GOLD_700 = HexColor('#8B6914')
GOLD_600 = HexColor('#A8863F')
GOLD_500 = HexColor('#C9A962')
GOLD_400 = HexColor('#D4B872')
GOLD_200 = HexColor('#E8D5A3')
INK = HexColor('#14201A')
MUTED = HexColor('#5A6B62')
SOFT_GOLD = Color(0.79, 0.66, 0.38, alpha=0.14)


def certificate_verify_token(session) -> str:
    digest = hashlib.sha256(
        f'{session.id}-{session.user_id}-{session.score}'.encode(),
    ).hexdigest()[:16]
    return f'{session.id}-{digest}'


def _registry_number(session) -> str:
    token = certificate_verify_token(session)
    return f'SST-{date.today().year}-{session.pk:05d}-{token[-6:].upper()}'


def _draw_guilloche(c: canvas.Canvas, w: float, h: float) -> None:
    """Motif guilloché discret (fond de sécurité)."""
    c.saveState()
    c.setStrokeColor(Color(0.79, 0.66, 0.38, alpha=0.11))
    c.setLineWidth(0.35)
    cx, cy = w / 2, h / 2
    for i in range(18):
        r = 2.2 * cm + i * 0.45 * cm
        path = c.beginPath()
        for j in range(0, 361, 3):
            a = math.radians(j + i * 7)
            wobble = 0.18 * cm * math.sin(j / 18 + i)
            x = cx + (r + wobble) * math.cos(a)
            y = cy + (r + wobble) * math.sin(a) * 0.72
            if j == 0:
                path.moveTo(x, y)
            else:
                path.lineTo(x, y)
        c.drawPath(path, stroke=1, fill=0)
    c.restoreState()


def _draw_watermark(c: canvas.Canvas, w: float, h: float) -> None:
    c.saveState()
    c.setFillColor(Color(0.13, 0.31, 0.18, alpha=0.045))
    c.setFont('Times-Bold', 64)
    c.translate(w / 2, h / 2)
    c.rotate(28)
    c.drawCentredString(0, 0, 'SIG SOLS TOGO')
    c.restoreState()


def _draw_corner_flourish(
    c: canvas.Canvas,
    x: float,
    y: float,
    flip_x: int,
    flip_y: int,
) -> None:
    """Ornement de coin style diplôme royal."""
    c.saveState()
    c.setStrokeColor(GOLD_500)
    c.setFillColor(GOLD_500)
    c.setLineWidth(1.8)
    # Grand L
    c.line(x, y, x + flip_x * 2.4 * cm, y)
    c.line(x, y, x, y + flip_y * 2.4 * cm)
    c.setLineWidth(0.9)
    inset = 3.5 * mm
    c.line(x + flip_x * inset, y + flip_y * inset, x + flip_x * 1.7 * cm, y + flip_y * inset)
    c.line(x + flip_x * inset, y + flip_y * inset, x + flip_x * inset, y + flip_y * 1.7 * cm)
    # Arc décoratif
    c.setLineWidth(1.1)
    r = 0.55 * cm
    c.circle(x + flip_x * 0.95 * cm, y + flip_y * 0.95 * cm, r, fill=0, stroke=1)
    c.setLineWidth(0.5)
    c.circle(x + flip_x * 0.95 * cm, y + flip_y * 0.95 * cm, r - 2.2, fill=0, stroke=1)
    # Petite fleur
    fx, fy = x + flip_x * 0.95 * cm, y + flip_y * 0.95 * cm
    for a in range(0, 360, 45):
        rad = math.radians(a)
        c.line(
            fx + 2 * math.cos(rad),
            fy + 2 * math.sin(rad),
            fx + 7 * math.cos(rad),
            fy + 7 * math.sin(rad),
        )
    c.restoreState()


def _draw_double_frame(c: canvas.Canvas, w: float, h: float) -> None:
    # Bande latérale émeraude
    c.setFillColor(EMERALD_950)
    c.rect(0, 0, 0.55 * cm, h, fill=1, stroke=0)
    c.rect(w - 0.55 * cm, 0, 0.55 * cm, h, fill=1, stroke=0)
    c.setFillColor(GOLD_500)
    c.rect(0.55 * cm, 0, 0.12 * cm, h, fill=1, stroke=0)
    c.rect(w - 0.67 * cm, 0, 0.12 * cm, h, fill=1, stroke=0)

    margin = 1.05 * cm
    # Cadre or épais
    c.setStrokeColor(GOLD_600)
    c.setLineWidth(3.2)
    c.rect(margin, margin, w - 2 * margin, h - 2 * margin, fill=0, stroke=1)
    # Cadre émeraude fin
    c.setStrokeColor(EMERALD_800)
    c.setLineWidth(1.0)
    m2 = margin + 0.28 * cm
    c.rect(m2, m2, w - 2 * m2, h - 2 * m2, fill=0, stroke=1)
    # Filet or intérieur
    c.setStrokeColor(GOLD_400)
    c.setLineWidth(0.6)
    m3 = margin + 0.48 * cm
    c.rect(m3, m3, w - 2 * m3, h - 2 * m3, fill=0, stroke=1)


def _draw_seal(c: canvas.Canvas, cx: float, cy: float, radius: float, score: int) -> None:
    c.saveState()
    # Ombre douce
    c.setFillColor(Color(0, 0, 0, alpha=0.12))
    c.circle(cx + 2, cy - 2, radius, fill=1, stroke=0)

    c.setFillColor(EMERALD_950)
    c.circle(cx, cy, radius, fill=1, stroke=0)
    c.setStrokeColor(GOLD_500)
    c.setLineWidth(2.6)
    c.circle(cx, cy, radius - 1.5, fill=0, stroke=1)
    c.setLineWidth(1.0)
    c.circle(cx, cy, radius - 5.5, fill=0, stroke=1)
    c.setLineWidth(0.55)
    c.circle(cx, cy, radius - 9, fill=0, stroke=1)

    # Rayons
    n = 32
    for i in range(n):
        a = (2 * math.pi * i) / n
        r0, r1 = radius - 12, radius - 7
        c.setStrokeColor(GOLD_400 if i % 2 == 0 else GOLD_200)
        c.setLineWidth(0.7 if i % 2 == 0 else 0.4)
        c.line(
            cx + r0 * math.cos(a),
            cy + r0 * math.sin(a),
            cx + r1 * math.cos(a),
            cy + r1 * math.sin(a),
        )

    # Étoile centrale
    c.setFillColor(GOLD_500)
    c.setStrokeColor(GOLD_200)
    star = c.beginPath()
    for i in range(10):
        ang = math.radians(-90 + i * 36)
        r = 9 if i % 2 == 0 else 4
        px, py = cx + r * math.cos(ang), cy + 8 + r * math.sin(ang)
        if i == 0:
            star.moveTo(px, py)
        else:
            star.lineTo(px, py)
    star.close()
    c.drawPath(star, fill=1, stroke=0)

    c.setFillColor(GOLD_200)
    c.setFont('Helvetica-Bold', 8)
    c.drawCentredString(cx, cy - 2, 'SIG SOLS')
    c.setFont('Helvetica', 6.5)
    c.drawCentredString(cx, cy - 10, 'EXCELLENCE')
    c.setFillColor(white)
    c.setFont('Helvetica-Bold', 12)
    c.drawCentredString(cx, cy - 24, f'{score} pts')
    c.restoreState()


def _draw_ribbon(c: canvas.Canvas, w: float, y: float) -> None:
    """Bandeau titre type ruban."""
    c.saveState()
    band_h = 1.55 * cm
    c.setFillColor(EMERALD_900)
    c.rect(2.2 * cm, y, w - 4.4 * cm, band_h, fill=1, stroke=0)
    # Pointes
    c.setFillColor(EMERALD_800)
    path_l = c.beginPath()
    path_l.moveTo(2.2 * cm, y)
    path_l.lineTo(1.2 * cm, y + band_h / 2)
    path_l.lineTo(2.2 * cm, y + band_h)
    path_l.close()
    c.drawPath(path_l, fill=1, stroke=0)
    path_r = c.beginPath()
    path_r.moveTo(w - 2.2 * cm, y)
    path_r.lineTo(w - 1.2 * cm, y + band_h / 2)
    path_r.lineTo(w - 2.2 * cm, y + band_h)
    path_r.close()
    c.drawPath(path_r, fill=1, stroke=0)
    c.setStrokeColor(GOLD_500)
    c.setLineWidth(1.3)
    c.line(2.4 * cm, y + 3, w - 2.4 * cm, y + 3)
    top_line = y + band_h - 3
    c.line(2.4 * cm, top_line, w - 2.4 * cm, top_line)
    c.restoreState()


def build_quiz_certificate_bytes(session, user) -> bytes:
    """Génère un certificat paysage cérémonial (émeraude / or / ivoire)."""
    buf = BytesIO()
    page = landscape(A4)
    w, h = page
    c = canvas.Canvas(buf, pagesize=page)

    # Fond ivoire
    c.setFillColor(IVORY)
    c.rect(0, 0, w, h, fill=1, stroke=0)
    # Vignette douce
    c.setFillColor(IVORY_DEEP)
    c.rect(0, 0, w, 1.8 * cm, fill=1, stroke=0)
    c.rect(0, h - 2.1 * cm, w, 2.1 * cm, fill=1, stroke=0)

    _draw_guilloche(c, w, h)
    _draw_watermark(c, w, h)
    _draw_double_frame(c, w, h)

    margin = 1.05 * cm
    _draw_corner_flourish(c, margin + 0.55 * cm, h - margin - 0.55 * cm, 1, -1)
    _draw_corner_flourish(c, w - margin - 0.55 * cm, h - margin - 0.55 * cm, -1, -1)
    _draw_corner_flourish(c, margin + 0.55 * cm, margin + 0.55 * cm, 1, 1)
    _draw_corner_flourish(c, w - margin - 0.55 * cm, margin + 0.55 * cm, -1, 1)

    # En-tête institutionnel
    c.setFillColor(EMERALD_950)
    c.setFont('Helvetica', 8)
    c.drawCentredString(
        w / 2,
        h - 1.15 * cm,
        'RÉPUBLIQUE TOGOLAISE  ·  MINISTÈRE DE L’AGRICULTURE  ·  DISIA  ·  DUSOL',
    )
    c.setFillColor(GOLD_700)
    c.setFont('Helvetica-Bold', 11)
    c.drawCentredString(w / 2, h - 1.65 * cm, 'SIG SOLS TOGO — RÉGION MARITIME')

    # Ruban + titre
    ribbon_y = h - 5.05 * cm
    _draw_ribbon(c, w, ribbon_y)
    c.setFillColor(GOLD_200)
    c.setFont('Times-Bold', 22)
    c.drawCentredString(w / 2, ribbon_y + 0.55 * cm, 'CERTIFICAT D’EXCELLENCE')

    c.setFillColor(EMERALD_900)
    c.setFont('Times-BoldItalic', 13)
    c.drawCentredString(w / 2, h - 5.75 * cm, 'Pédagogie des sols & observation de la Terre')

    # Filets or
    c.setStrokeColor(GOLD_500)
    c.setLineWidth(1.15)
    c.line(w / 2 - 6 * cm, h - 6.05 * cm, w / 2 + 6 * cm, h - 6.05 * cm)
    c.setLineWidth(0.4)
    c.line(w / 2 - 4 * cm, h - 6.18 * cm, w / 2 + 4 * cm, h - 6.18 * cm)

    c.setFillColor(MUTED)
    c.setFont('Helvetica-Oblique', 11)
    c.drawCentredString(w / 2, h - 6.7 * cm, 'Le présent document atteste que')

    name = (user.get_full_name() or '').strip() or user.username
    c.setFillColor(EMERALD_950)
    c.setFont('Times-BoldItalic', 30)
    c.drawCentredString(w / 2, h - 7.85 * cm, name)

    name_w = c.stringWidth(name, 'Times-BoldItalic', 30)
    c.setStrokeColor(GOLD_500)
    c.setLineWidth(1.35)
    c.line(
        w / 2 - name_w / 2 - 0.4 * cm,
        h - 8.15 * cm,
        w / 2 + name_w / 2 + 0.4 * cm,
        h - 8.15 * cm,
    )
    c.setLineWidth(0.5)
    c.line(
        w / 2 - name_w / 2 - 0.15 * cm,
        h - 8.28 * cm,
        w / 2 + name_w / 2 + 0.15 * cm,
        h - 8.28 * cm,
    )

    level = str(getattr(session, 'difficulty', '—')).capitalize()
    exam = ' en mode examen' if getattr(session, 'exam_mode', False) else ''
    c.setFillColor(INK)
    c.setFont('Helvetica', 11)
    c.drawCentredString(
        w / 2,
        h - 9.05 * cm,
        f'a validé avec distinction le quiz pédagogique — niveau « {level} »{exam}.',
    )
    c.setFont('Helvetica', 10)
    c.drawCentredString(
        w / 2,
        h - 9.55 * cm,
        (
            f'Score obtenu : {session.score} points   ·   '
            f'Questions traitées : {session.questions_answered}   ·   '
            f'Session n° {session.pk}'
        ),
    )

    # Sceau
    _draw_seal(c, w - 4.35 * cm, 4.55 * cm, 2.25 * cm, int(session.score or 0))

    # Signatures
    y_sig = 3.35 * cm
    c.setStrokeColor(GOLD_600)
    c.setLineWidth(0.75)
    c.line(2.6 * cm, y_sig, 7.6 * cm, y_sig)
    c.line(9.2 * cm, y_sig, 14.2 * cm, y_sig)
    c.setFillColor(EMERALD_900)
    c.setFont('Helvetica-Bold', 8)
    c.drawCentredString(5.1 * cm, y_sig - 0.4 * cm, 'Direction DUSOL')
    c.drawCentredString(11.7 * cm, y_sig - 0.4 * cm, 'Coordination pédagogique DISIA')
    c.setFillColor(MUTED)
    c.setFont('Helvetica-Oblique', 7)
    c.drawCentredString(5.1 * cm, y_sig - 0.75 * cm, 'Signature & cachet')
    c.drawCentredString(11.7 * cm, y_sig - 0.75 * cm, 'Signature & cachet')

    registry = _registry_number(session)
    token = certificate_verify_token(session)
    issued = date.today().strftime('%d / %m / %Y')
    c.setFillColor(MUTED)
    c.setFont('Helvetica', 7.5)
    c.drawString(2.6 * cm, 1.85 * cm, f'Délivré à Lomé — Région Maritime, le {issued}')
    c.setFont('Helvetica-Bold', 7.5)
    c.setFillColor(EMERALD_800)
    c.drawString(2.6 * cm, 1.45 * cm, f'N° d’enregistrement : {registry}')
    c.setFillColor(MUTED)
    c.setFont('Helvetica', 6.5)
    c.drawString(2.6 * cm, 1.1 * cm, f'Vérification sécurisée : /api/v1/education/quiz/verify/{token}/')

    # Bandeau bas officiel
    c.setFillColor(EMERALD_950)
    c.rect(0, 0, w, 0.78 * cm, fill=1, stroke=0)
    c.setFillColor(GOLD_500)
    c.rect(0, 0.78 * cm, w, 0.1 * cm, fill=1, stroke=0)
    c.setFillColor(GOLD_200)
    c.setFont('Helvetica', 6.5)
    c.drawCentredString(
        w / 2,
        0.28 * cm,
        'Document officiel SIG Sols Togo — valeur pédagogique · non falsifiable · crédit imagery NASA Earth Science (domaine public)',
    )

    c.showPage()
    c.save()
    return buf.getvalue()
