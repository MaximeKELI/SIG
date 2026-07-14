"""Pré-filtre texte léger (sans API externe) pour publications média."""


def ai_moderation_hint(text: str) -> dict:
    """Heuristique simple pour suggestion / rejet modération."""
    lower = (text or '').lower()
    flags = []
    blocked = [
        'spam', 'arnaque', 'haine', 'insulte', 'escroquerie',
        'nsfw', 'xxx', 'porn', 'violence extrême',
    ]
    for w in blocked:
        if w in lower:
            flags.append(w)
    return {
        'suggested_hide': len(flags) > 0,
        'flags': flags,
        'confidence': 0.7 if flags else 0.1,
    }


def moderate_publication_text(
    title: str = '',
    description: str = '',
    caption: str = '',
) -> dict:
    """Pré-filtre IA léger sur textes de publication (vidéo / story)."""
    blob = ' '.join(filter(None, [title, description, caption]))
    hint = ai_moderation_hint(blob)
    reason = ''
    if hint['suggested_hide']:
        reason = (
            'Publication refusée automatiquement (contenu signalé : '
            + ', '.join(hint['flags'])
            + '). Contactez un administrateur si besoin.'
        )
    return {
        **hint,
        'reason': reason,
    }
