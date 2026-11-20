"""Contrôle de santé (probes) + détail réservé au staff / DEBUG."""
from django.conf import settings
from django.contrib.auth.models import AnonymousUser
from django.db import connection
from django.http import JsonResponse


def health_check(request):
    detail = request.GET.get('detail') == '1'
    payload = {
        'status': 'ok',
        'project': 'SIG-SOLS-TOGO-2026-01',
    }
    if not detail:
        return JsonResponse(payload)

    user = getattr(request, 'user', None)
    allow_detail = settings.DEBUG or (
        user is not None
        and not isinstance(user, AnonymousUser)
        and getattr(user, 'is_staff', False)
    )
    if not allow_detail:
        return JsonResponse(
            {
                'status': 'ok',
                'project': 'SIG-SOLS-TOGO-2026-01',
                'detail': 'authentification staff requise',
            },
            status=200,
        )

    checks = {}
    db_cfg = settings.DATABASES['default']
    engine = db_cfg.get('ENGINE', '')
    if 'postgis' in engine:
        backend_label = 'postgis'
    elif 'sqlite' in engine or 'spatialite' in engine:
        backend_label = 'sqlite'
    else:
        backend_label = engine.rsplit('.', 1)[-1] if engine else 'unknown'

    try:
        with connection.cursor() as cursor:
            cursor.execute('SELECT 1')
        checks['database'] = 'ok'
        checks['database_info'] = {
            'backend': backend_label,
            'name': db_cfg.get('NAME', ''),
            'host': db_cfg.get('HOST') or 'local',
            'clients': 'web,mobile',
            'note': (
                "Site web et app mobile partagent cette base via l'API Django."
            ),
        }
    except Exception as exc:
        checks['database'] = str(exc)
        checks['database_info'] = {
            'backend': backend_label,
            'name': db_cfg.get('NAME', ''),
            'host': db_cfg.get('HOST') or 'local',
        }
        payload['status'] = 'degraded'

    try:
        import redis
        r = redis.from_url(settings.REDIS_URL)
        r.ping()
        checks['redis'] = 'ok'
    except Exception as exc:
        checks['redis'] = str(exc)
        payload['status'] = 'degraded'

    payload['checks'] = checks
    status_code = 200 if payload['status'] == 'ok' else 503
    return JsonResponse(payload, status=status_code)
