"""Authentification WebSocket : JWT (subprotocol / header) ou session Django.

Préfère Sec-WebSocket-Protocol / Authorization pour éviter le JWT dans les logs
d'URL. Le query ?token= reste accepté en secours (anciens clients).
"""
from urllib.parse import parse_qs

from channels.auth import AuthMiddlewareStack
from channels.db import database_sync_to_async
from django.contrib.auth import get_user_model
from django.contrib.auth.models import AnonymousUser
from rest_framework_simplejwt.exceptions import InvalidToken, TokenError
from rest_framework_simplejwt.tokens import AccessToken

User = get_user_model()


@database_sync_to_async
def get_user_from_token(token: str):
    try:
        validated = AccessToken(token)
        return User.objects.get(pk=validated['user_id'])
    except (InvalidToken, TokenError, User.DoesNotExist, KeyError):
        return AnonymousUser()


def _headers_map(scope) -> dict[bytes, bytes]:
    return dict(scope.get('headers') or [])


def _token_from_scope(scope) -> str | None:
    headers = _headers_map(scope)

    # 1) Authorization: Bearer <jwt>
    auth = headers.get(b'authorization', b'').decode()
    if auth.lower().startswith('bearer '):
        tok = auth[7:].strip()
        if tok:
            return tok

    # 2) Sec-WebSocket-Protocol: jwt, <token>  (ou bearer.<token>)
    proto_raw = headers.get(b'sec-websocket-protocol', b'').decode()
    if proto_raw:
        parts = [p.strip() for p in proto_raw.split(',') if p.strip()]
        scope['ws_requested_protocols'] = parts
        if len(parts) >= 2 and parts[0].lower() in ('jwt', 'bearer', 'access_token'):
            return parts[1]
        for p in parts:
            if p.lower().startswith('bearer.'):
                return p.split('.', 1)[1]
            if p.count('.') >= 2 and len(p) > 40:
                # JWT brut passé comme seul subprotocol
                return p

    # 3) Fallback legacy ?token=
    query = parse_qs(scope.get('query_string', b'').decode())
    token = (query.get('token') or [None])[0]
    return token or None


class TokenOrSessionAuthMiddleware:
    """JWT via subprotocol/header (mobile/web) ; session cookie pour le site."""

    def __init__(self, inner):
        self.inner = inner
        self.session_stack = AuthMiddlewareStack(inner)

    async def __call__(self, scope, receive, send):
        if scope['type'] != 'websocket':
            return await self.inner(scope, receive, send)

        token = _token_from_scope(scope)
        if token:
            scope['user'] = await get_user_from_token(token)
            # Echo le premier protocole demandé si présent (handshake RFC6455)
            requested = scope.get('ws_requested_protocols') or []
            if requested:
                scope['subprotocol'] = requested[0]
            return await self.inner(scope, receive, send)

        return await self.session_stack(scope, receive, send)
