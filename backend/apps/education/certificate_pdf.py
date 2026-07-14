"""Certificat PDF premium — SIG Sols Togo / DISIA · DUSOL."""
from __future__ import annotations

import hashlib
from datetime import date
from io import BytesIO

from reportlab.lib.colors import HexColor, white
from reportlab.lib.pagesizes import A4, landscape
from reportlab.lib.units import cm, mm
from reportlab.pdfgen import canvas

# Palette institutionnelle émeraude · or champagne
EMERALD_950 = HexColor('#061a10')
EMERALD_900 = HexColor('#0d2818')
EMERALD_700 = HexColor('#1a5c3a')
EMERALD_500 = HexColor('#2d8a55')
GOLD_600 = HexColor('#a8863f')
GOLD_400 = HexColor('#c9a962')
GOLD_200 = HexColor('#e8d5a3')
CREAM = HexColor('#faf8f3')
INK = HexColor('#1a2332')
MUTED = HexColor('#5c6b7a')


def certificate_verify_token(session) -> str:
    digest = hashlib.sha256(
        f'{session.id}-{session.user_id}-{session.score}'.encode(),
    ).hexdigest()[:16]
    return f'{session.id}-{digest}'


def _draw_corner_ornament(c: canvas.Canvas, x: float, y: float, size: float, flip_x: int, flip_y: int):
    """Ornement de coin style diplôme."""
    c.saveState()
    c.setStrokeColor(GOLD_400)
    c.setLineWidth(1.4)
    c.line(x, y, x + flip_x * size, y)
    c.line(x, y, x, y + flip_y * size)
    c.setLineWidth(0.7)
    inset = 3 * mm
    c.line(x + flip_x * inset, y + flip_y * inset, x + flip_x * size * 0.55, y + flip_y * inset)
    c.line(x + flip_x * inset, y + flip_y * inset, x + flip_x * inset, y + flip_y * size * 0.55)
    c.restoreState()


def _draw_seal(c: canvas.Canvas, cx: float, cy: float, radius: float, score: int):
    import math

    c.saveState()
    c.setFillColor(EMERALD_900)
    c.circle(cx, cy, radius, fill=1, stroke=0)
    c.setStrokeColor(GOLD_400)
    c.setLineWidth(2.2)
    c.circle(cx, cy, radius - 2, fill=0, stroke=1)
    c.setLineWidth(0.8)
    c.circle(cx, cy, radius - 6, fill=0, stroke=1)
    n = 24
    for i in range(n):
        a = (2 * math.pi * i) / n
        r0, r1 = radius - 9, radius - 5
        c.line(
            cx + r0 * math.cos(a),
            cy + r0 * math.sin(a),
            cx + r1 * math.cos(a),
            cy + r1 * math.sin(a),
        )
    c.setFillColor(GOLD_200)
    c.setFont('Helvetica-Bold', 9)
    c.drawCentredString(cx, cy + 6, 'SIG SOLS')
    c.setFont('Helvetica', 7)
    c.drawCentredString(cx, cy - 2, 'TOGO')
    c.setFont('Helvetica-Bold', 11)
    c.setFillColor(white)
    c.drawCentredString(cx, cy - 14, f'{score} pts')
    c.restoreState()


def build_quiz_certificate_bytes(session, user) -> bytes:
    """Génère un certificat paysage élégant (émeraude / or)."""
    buf = BytesIO()
    page = landscape(A4)
    w, h = page
    c = canvas.Canvas(buf, pagesize=page)

    # Fond crème
    c.setFillColor(CREAM)
    c.rect(0, 0, w, h, fill=1, stroke=0)

    # Bandeau haut émeraude
    c.setFillColor(EMERALD_950)
    c.rect(0, h - 2.4 * cm, w, 2.4 * cm, fill=1, stroke=0)
    c.setFillColor(GOLD_400)
    c.rect(0, h - 2.55 * cm, w, 0.15 * cm, fill=1, stroke=0)

    # Cadre double
    margin = 1.1 * cm
    c.setStrokeColor(GOLD_600)
    c.setLineWidth(2.8)
    c.rect(margin, margin, w - 2 * margin, h - 2 * margin, fill=0, stroke=1)
    c.setStrokeColor(EMERALD_700)
    c.setLineWidth(0.9)
    inner = margin + 0.35 * cm
    c.rect(inner, inner, w - 2 * inner, h - 2 * inner, fill=0, stroke=1)

    # Ornements coins
    o = 1.6 * cm
    _draw_corner_ornament(c, margin + 0.5 * cm, h - margin - 0.5 * cm, o, 1, -1)
    _draw_corner_ornament(c, w - margin - 0.5 * cm, h - margin - 0.5 * cm, o, -1, -1)
    _draw_corner_ornament(c, margin + 0.5 * cm, margin + 0.5 * cm, o, 1, 1)
    _draw_corner_ornament(c, w - margin - 0.5 * cm, margin + 0.5 * cm, o, -1, 1)

    # En-tête institutionnel
    c.setFillColor(GOLD_200)
    c.setFont('Helvetica', 9)
    c.drawCentredString(w / 2, h - 1.05 * cm, 'MINISTÈRE DE L’AGRICULTURE · DISIA · DUSOL')
    c.setFont('Helvetica-Bold', 16)
    c.setFillColor(white)
    c.drawCentredString(w / 2, h - 1.75 * cm, 'SIG Sols Togo')

    # Titre
    c.setFillColor(EMERALD_900)
    c.setFont('Times-Bold', 28)
    c.drawCentredString(w / 2, h - 4.2 * cm, 'Certificat de réussite')

    c.setStrokeColor(GOLD_400)
    c.setLineWidth(1.2)
    c.line(w / 2 - 5 * cm, h - 4.55 * cm, w / 2 + 5 * cm, h - 4.55 * cm)
    c.setLineWidth(0.4)
    c.line(w / 2 - 3.5 * cm, h - 4.7 * cm, w / 2 + 3.5 * cm, h - 4.7 * cm)

    c.setFillColor(MUTED)
    c.setFont('Helvetica-Oblique', 12)
    c.drawCentredString(
        w / 2,
        h - 5.4 * cm,
        'Quiz pédagogique · Sols, agriculture & observation de la Terre',
    )

    c.setFillColor(INK)
    c.setFont('Helvetica', 12)
    c.drawCentredString(w / 2, h - 6.5 * cm, 'est décerné à')

    name = (user.get_full_name() or '').strip() or user.username
    c.setFillColor(EMERALD_900)
    c.setFont('Times-BoldItalic', 26)
    c.drawCentredString(w / 2, h - 7.6 * cm, name)

    # Soulignement or du nom
    name_w = c.stringWidth(name, 'Times-BoldItalic', 26)
    c.setStrokeColor(GOLD_400)
    c.setLineWidth(1.0)
    c.line(w / 2 - name_w / 2 - 0.3 * cm, h - 7.85 * cm, w / 2 + name_w / 2 + 0.3 * cm, h - 7.85 * cm)

    level = str(getattr(session, 'difficulty', '—')).capitalize()
    exam = ' · Mode examen' if getattr(session, 'exam_mode', False) else ''
    c.setFillColor(INK)
    c.setFont('Helvetica', 11)
    c.drawCentredString(
        w / 2,
        h - 8.8 * cm,
        f'pour avoir complété avec succès le quiz niveau « {level} »{exam}',
    )
    c.drawCentredString(
        w / 2,
        h - 9.45 * cm,
        f'Score : {session.score} points  ·  Questions : {session.questions_answered}  ·  Session #{session.pk}',
    )

    # Sceau
    _draw_seal(c, w - 4.2 * cm, 4.8 * cm, 2.1 * cm, int(session.score or 0))

    # Signatures
    y_sig = 3.6 * cm
    c.setStrokeColor(MUTED)
    c.setLineWidth(0.6)
    c.line(2.8 * cm, y_sig, 7.8 * cm, y_sig)
    c.line(9.5 * cm, y_sig, 14.5 * cm, y_sig)
    c.setFillColor(MUTED)
    c.setFont('Helvetica', 8)
    c.drawCentredString(5.3 * cm, y_sig - 0.45 * cm, 'Direction DUSOL')
    c.drawCentredString(12 * cm, y_sig - 0.45 * cm, 'Équipe pédagogique DISIA')

    token = certificate_verify_token(session)
    issued = date.today().strftime('%d/%m/%Y')
    c.setFillColor(MUTED)
    c.setFont('Helvetica', 8)
    c.drawString(2.8 * cm, 1.7 * cm, f'Délivré le {issued} · Région Maritime — Togo')
    c.setFont('Helvetica', 7)
    c.drawString(2.8 * cm, 1.25 * cm, f'Vérification : /api/v1/education/quiz/verify/{token}/')

    # Bandeau bas
    c.setFillColor(EMERALD_950)
    c.rect(0, 0, w, 0.85 * cm, fill=1, stroke=0)
    c.setFillColor(GOLD_400)
    c.rect(0, 0.85 * cm, w, 0.08 * cm, fill=1, stroke=0)
    c.setFillColor(GOLD_200)
    c.setFont('Helvetica', 7)
    c.drawCentredString(
        w / 2,
        0.32 * cm,
        'Document officiel SIG Sols Togo — données NASA domaine public · crédit NASA Earth Science',
    )

    c.showPage()
    c.save()
    return buf.getvalue()
