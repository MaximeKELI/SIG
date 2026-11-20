"""
SIG-SOLS-TOGO-2026-01 — Django settings
DISIA / DUSOL — GeoDjango + PostGIS / SpatiaLite
"""
import ctypes.util
import os
from datetime import timedelta
from pathlib import Path

from dotenv import load_dotenv

BASE_DIR = Path(__file__).resolve().parent.parent

# .env projet (racine DUSOL_PROJET) — monté dans Docker en /opt/dusol.env
for _env_path in (
    Path('/opt/dusol.env'),
    Path('/tmp/dusol.env'),
    BASE_DIR.parent / '.env',
    BASE_DIR / '.env',
):
    if _env_path.is_file():
        load_dotenv(_env_path, override=True)

_SECRET_DEFAULT = 'dev-only-change-in-production'
SECRET_KEY = os.environ.get('SECRET_KEY', _SECRET_DEFAULT)
DEBUG = os.environ.get('DEBUG', '1') == '1'

if not DEBUG:
    if not SECRET_KEY or SECRET_KEY == _SECRET_DEFAULT or len(SECRET_KEY) < 32:
        raise RuntimeError(
            'Production (DEBUG=0) : définir SECRET_KEY fort '
            '(ex. openssl rand -hex 32), min. 32 caractères.'
        )

_DEFAULT_CSRF_ORIGINS_DEBUG = (
    'http://localhost:8081',
    'http://127.0.0.1:8081',
    'http://localhost',
    'http://127.0.0.1',
)
_env_csrf = os.environ.get('CSRF_TRUSTED_ORIGINS', '').strip()
if DEBUG:
    CSRF_TRUSTED_ORIGINS = list(_DEFAULT_CSRF_ORIGINS_DEBUG)
    if _env_csrf:
        CSRF_TRUSTED_ORIGINS.extend(
            o.strip() for o in _env_csrf.split(',') if o.strip()
        )
else:
    if not _env_csrf:
        raise RuntimeError(
            'Production (DEBUG=0) : CSRF_TRUSTED_ORIGINS obligatoire '
            '(ex. https://sig.example.tg).'
        )
    CSRF_TRUSTED_ORIGINS = [
        o.strip() for o in _env_csrf.split(',') if o.strip()
    ]
CSRF_TRUSTED_ORIGINS = list(dict.fromkeys(CSRF_TRUSTED_ORIGINS))

if DEBUG:
    ALLOWED_HOSTS = ['*']
else:
    _hosts = os.environ.get('ALLOWED_HOSTS', '').strip()
    if not _hosts:
        raise RuntimeError(
            'Production (DEBUG=0) : ALLOWED_HOSTS obligatoire '
            '(ex. sig.example.tg,www.sig.example.tg).'
        )
    ALLOWED_HOSTS = [h.strip() for h in _hosts.split(',') if h.strip()]

INSTALLED_APPS = [
    'channels',
    'django.contrib.admin',
    'django.contrib.auth',
    'django.contrib.contenttypes',
    'django.contrib.sessions',
    'django.contrib.messages',
    'django.contrib.staticfiles',
    'django.contrib.gis',
    'rest_framework',
    'rest_framework_gis',
    'rest_framework_simplejwt',
    'rest_framework_simplejwt.token_blacklist',
    'corsheaders',
    'django_filters',
    'accounts',
    'soils',
    'spatial',
    'nasa',
    'sentinel',
    'weather',
    'ml_predict',
    'education',
    'sig_platform',
    'assistant',
    'videos',
]

MIDDLEWARE = [
    'django.middleware.security.SecurityMiddleware',
    'config.rate_limit_middleware.GlobalRateLimitMiddleware',
    'corsheaders.middleware.CorsMiddleware',
    'django.contrib.sessions.middleware.SessionMiddleware',
    'django.middleware.common.CommonMiddleware',
    'django.middleware.csrf.CsrfViewMiddleware',
    'django.contrib.auth.middleware.AuthenticationMiddleware',
    'django.contrib.messages.middleware.MessageMiddleware',
    'django.middleware.clickjacking.XFrameOptionsMiddleware',
]

ROOT_URLCONF = 'config.urls'
WSGI_APPLICATION = 'config.wsgi.application'
ASGI_APPLICATION = 'config.asgi.application'

REDIS_URL = os.environ.get('REDIS_URL', 'redis://localhost:6379/0')
REDIS_CACHE_URL = os.environ.get('REDIS_CACHE_URL', REDIS_URL.replace('/0', '/1'))
REDIS_CHANNELS_URL = os.environ.get('REDIS_CHANNELS_URL', REDIS_URL.replace('/0', '/2'))

CHANNEL_LAYERS = {
    'default': {
        'BACKEND': 'channels_redis.core.RedisChannelLayer',
        'CONFIG': {
            'hosts': [REDIS_CHANNELS_URL],
            'capacity': int(os.environ.get('CHANNEL_CAPACITY', '1500')),
            'expiry': int(os.environ.get('CHANNEL_EXPIRY', '60')),
        },
    },
}

TEMPLATES = [
    {
        'BACKEND': 'django.template.backends.django.DjangoTemplates',
        'DIRS': [BASE_DIR / 'templates'],
        'APP_DIRS': True,
        'OPTIONS': {
            'context_processors': [
                'django.template.context_processors.debug',
                'django.template.context_processors.request',
                'django.contrib.auth.context_processors.auth',
                'django.contrib.messages.context_processors.messages',
            ],
        },
    },
]

# Base de données : SQLite/SpatiaLite (temporaire) ou PostGIS.
DB_BACKEND = os.environ.get('DB_BACKEND', 'postgis').strip().lower()

if DB_BACKEND in {'sqlite', 'sqlite3', 'spatialite'}:
    _spatialite_default = (
        ctypes.util.find_library('mod_spatialite')
        or '/usr/lib/x86_64-linux-gnu/mod_spatialite.so'
    )
    SPATIALITE_LIBRARY_PATH = (
        os.environ.get('SPATIALITE_LIBRARY_PATH')
        or _spatialite_default
        or ctypes.util.find_library('spatialite')
        or 'mod_spatialite'
    )
    sqlite_name = os.environ.get('SQLITE_NAME', '').strip()
    DATABASES = {
        'default': {
            'ENGINE': 'django.contrib.gis.db.backends.spatialite',
            'NAME': sqlite_name or str(BASE_DIR / 'db.sqlite3'),
        }
    }
else:
    _db_name = os.environ.get('DB_NAME', os.environ.get('POSTGRES_DB', 'sig_sols'))
    _db_user = os.environ.get('DB_USER', os.environ.get('POSTGRES_USER', 'sig_sols'))
    _db_password = os.environ.get(
        'DB_PASSWORD',
        os.environ.get('POSTGRES_PASSWORD', 'sig_sols_secret'),
    )
    _db_host = os.environ.get('DB_HOST', os.environ.get('POSTGRES_HOST', 'localhost'))
    _db_port = os.environ.get('DB_PORT', os.environ.get('POSTGRES_PORT', '5432'))
    _db_options = {
        'connect_timeout': int(os.environ.get('DB_CONNECT_TIMEOUT', '10')),
        'options': os.environ.get('DB_OPTIONS', '-c statement_timeout=30000'),
    }
    if os.environ.get('DB_SSLMODE'):
        _db_options['sslmode'] = os.environ['DB_SSLMODE']

    DATABASES = {
        'default': {
            'ENGINE': 'django.contrib.gis.db.backends.postgis',
            'NAME': _db_name,
            'USER': _db_user,
            'PASSWORD': _db_password,
            'HOST': _db_host,
            'PORT': _db_port,
            'CONN_MAX_AGE': int(os.environ.get('DB_CONN_MAX_AGE', '60')),
            'CONN_HEALTH_CHECKS': True,
            'OPTIONS': _db_options,
        }
    }

# Réplique lecture seule (production à grande échelle)
_replica_host = os.environ.get(
    'DB_REPLICA_HOST',
    os.environ.get('POSTGRES_REPLICA_HOST', ''),
).strip()
if _replica_host:
    DATABASES['replica'] = {
        **DATABASES['default'],
        'HOST': _replica_host,
        'PORT': os.environ.get(
            'DB_REPLICA_PORT',
            os.environ.get('POSTGRES_REPLICA_PORT', DATABASES['default']['PORT']),
        ),
    }
    DATABASE_ROUTERS = ['config.db_router.ReadReplicaRouter']

if os.environ.get('DJANGO_TEST', '0') == '1':
    CACHES = {
        'default': {
            'BACKEND': 'django.core.cache.backends.locmem.LocMemCache',
            'LOCATION': 'sigsols-test',
        },
    }
else:
    CACHES = {
        'default': {
            'BACKEND': 'django.core.cache.backends.redis.RedisCache',
            'LOCATION': REDIS_CACHE_URL,
            'KEY_PREFIX': os.environ.get('CACHE_KEY_PREFIX', 'sigsols'),
            'TIMEOUT': int(os.environ.get('CACHE_DEFAULT_TIMEOUT', '300')),
            'OPTIONS': {
                'max_connections': int(os.environ.get('REDIS_MAX_CONNECTIONS', '100')),
            },
        },
    }

AUTH_USER_MODEL = 'accounts.User'

AUTH_PASSWORD_VALIDATORS = [
    {'NAME': 'django.contrib.auth.password_validation.UserAttributeSimilarityValidator'},
    {'NAME': 'django.contrib.auth.password_validation.MinimumLengthValidator'},
    {'NAME': 'django.contrib.auth.password_validation.CommonPasswordValidator'},
    {'NAME': 'django.contrib.auth.password_validation.NumericPasswordValidator'},
]

LANGUAGE_CODE = 'fr-fr'
TIME_ZONE = 'Africa/Lome'
USE_I18N = True
USE_TZ = True

STATIC_URL = '/static/'
STATIC_ROOT = BASE_DIR / 'staticfiles'
MEDIA_URL = '/media/'
MEDIA_ROOT = BASE_DIR / 'media'
VIDEO_MAX_UPLOAD_BYTES = int(
    os.environ.get('VIDEO_MAX_UPLOAD_BYTES', str(48 * 1024 * 1024)),
)

DEFAULT_AUTO_FIELD = 'django.db.models.BigAutoField'

# GDAL
if os.environ.get('GDAL_LIBRARY_PATH'):
    GDAL_LIBRARY_PATH = os.environ['GDAL_LIBRARY_PATH']
if os.environ.get('GEOS_LIBRARY_PATH'):
    GEOS_LIBRARY_PATH = os.environ['GEOS_LIBRARY_PATH']

# REST Framework
REST_FRAMEWORK = {
    'DEFAULT_AUTHENTICATION_CLASSES': (
        'rest_framework_simplejwt.authentication.JWTAuthentication',
        'rest_framework.authentication.SessionAuthentication',
    ),
    'DEFAULT_PERMISSION_CLASSES': (
        'rest_framework.permissions.IsAuthenticatedOrReadOnly',
    ),
    'DEFAULT_FILTER_BACKENDS': (
        'django_filters.rest_framework.DjangoFilterBackend',
        'rest_framework.filters.SearchFilter',
        'rest_framework.filters.OrderingFilter',
    ),
    'DEFAULT_PAGINATION_CLASS': 'config.pagination.StandardResultsPagination',
    'PAGE_SIZE': 50,
    'DEFAULT_THROTTLE_CLASSES': [
        'config.throttling.BurstAnonThrottle',
        'config.throttling.BurstUserThrottle',
    ],
    'DEFAULT_THROTTLE_RATES': {
        'anon_burst': os.environ.get('THROTTLE_ANON', '200/min'),
        'user_burst': os.environ.get('THROTTLE_USER', '1000/min'),
        'auth': os.environ.get('THROTTLE_AUTH', '20/min'),
        'location': os.environ.get('THROTTLE_LOCATION', '120/min'),
        'quiz': os.environ.get('THROTTLE_QUIZ', '60/min'),
        'assistant': os.environ.get('THROTTLE_ASSISTANT', '30/min'),
        'video_upload': os.environ.get('THROTTLE_VIDEO_UPLOAD', '10/hour'),
    },
}

GEMINI_API_KEY = os.environ.get('GEMINI_API_KEY', '')
GEMINI_MODEL = os.environ.get('GEMINI_MODEL', 'gemini-2.5-flash-lite')

JWT_ACCESS_MINUTES = int(os.environ.get('JWT_ACCESS_TOKEN_LIFETIME_MINUTES', '60'))
SIMPLE_JWT = {
    'ACCESS_TOKEN_LIFETIME': timedelta(minutes=JWT_ACCESS_MINUTES),
    'REFRESH_TOKEN_LIFETIME': timedelta(days=7),
    'ROTATE_REFRESH_TOKENS': True,
    'BLACKLIST_AFTER_ROTATION': True,
}

_cors_default = (
    'http://localhost,http://127.0.0.1,http://localhost:8081'
    if DEBUG
    else ''
)
_cors_env = os.environ.get('CORS_ALLOWED_ORIGINS', _cors_default).strip()
if not DEBUG and not _cors_env:
    raise RuntimeError(
        'Production (DEBUG=0) : CORS_ALLOWED_ORIGINS obligatoire '
        '(ex. https://sig.example.tg).'
    )
CORS_ALLOWED_ORIGINS = [o.strip() for o in _cors_env.split(',') if o.strip()]
CORS_ALLOW_CREDENTIALS = True

# Celery
CELERY_BROKER_URL = os.environ.get('CELERY_BROKER_URL', 'redis://localhost:6379/0')
CELERY_RESULT_BACKEND = CELERY_BROKER_URL
CELERY_ACCEPT_CONTENT = ['json']
CELERY_TASK_SERIALIZER = 'json'
CELERY_RESULT_SERIALIZER = 'json'
CELERY_TIMEZONE = TIME_ZONE

# NASA Earthdata — username/password OU token JWT (EDL)
NASA_EARTHDATA_USERNAME = os.environ.get('NASA_EARTHDATA_USERNAME', '')
NASA_EARTHDATA_PASSWORD = os.environ.get('NASA_EARTHDATA_PASSWORD', '')
NASA_EARTHDATA_TOKEN = os.environ.get('NASA_EARTHDATA_TOKEN', '')
NASA_CACHE_DIR = BASE_DIR / 'data' / 'nasa_cache'
NASA_CACHE_RETENTION_DAYS = 365

# Sentinel Hub — https://www.sentinel-hub.com/
# OAuth : client_id + client_secret depuis le tableau de bord (Apps).
SENTINEL_HUB_CLIENT_ID = os.environ.get('SENTINEL_HUB_CLIENT_ID', '')
SENTINEL_HUB_CLIENT_SECRET = os.environ.get(
    'SENTINEL_HUB_CLIENT_SECRET',
    os.environ.get('SENTINEL_HUB_API_KEY', ''),
)
SENTINEL_HUB_USER_ID = os.environ.get('SENTINEL_HUB_USER_ID', '')
SENTINEL_HUB_ACCOUNT_ID = os.environ.get('SENTINEL_HUB_ACCOUNT_ID', '')
SENTINEL_HUB_BASE_URL = os.environ.get(
    'SENTINEL_HUB_BASE_URL',
    'https://services.sentinel-hub.com',
)
SENTINEL_HUB_TOKEN_URL = os.environ.get(
    'SENTINEL_HUB_TOKEN_URL',
    'https://services.sentinel-hub.com/auth/realms/main/protocol/openid-connect/token',
)

# OpenWeather — https://openweathermap.org/api
OPENWEATHER_API_KEY = os.environ.get('OPENWEATHER_API_KEY', '')
OPENWEATHER_CACHE_SECONDS = int(os.environ.get('OPENWEATHER_CACHE_SECONDS', '600'))

# ML
ML_ARTIFACTS_DIR = BASE_DIR / 'apps' / 'ml_predict' / 'artifacts'
ML_MIN_TRAINING_SAMPLES = 200
ML_RETRAIN_NEW_SAMPLES = 50

# Maritime region bbox (WGS84) — Togo Région Maritime approx.
REGION_MARITIME_BBOX = (0.9, 6.0, 1.8, 6.8)  # min_lon, min_lat, max_lon, max_lat

# Géolocalisation utilisateurs (temps réel) — millions d'utilisateurs
LOCATION_STALE_MINUTES = int(os.environ.get('LOCATION_STALE_MINUTES', '5'))
LOCATION_UPDATE_INTERVAL_MS = int(os.environ.get('LOCATION_UPDATE_INTERVAL_MS', '10000'))
LOCATION_POLL_INTERVAL_MS = int(os.environ.get('LOCATION_POLL_INTERVAL_MS', '8000'))
LOCATION_HISTORY_MIN_INTERVAL_SEC = int(os.environ.get('LOCATION_HISTORY_MIN_INTERVAL_SEC', '120'))
LOCATION_HISTORY_MIN_DISTANCE_M = float(os.environ.get('LOCATION_HISTORY_MIN_DISTANCE_M', '75'))
LOCATION_HISTORY_RETENTION_DAYS = int(os.environ.get('LOCATION_HISTORY_RETENTION_DAYS', '90'))
LIVE_LOCATIONS_CACHE_SECONDS = int(os.environ.get('LIVE_LOCATIONS_CACHE_SECONDS', '15'))
LEADERBOARD_CACHE_SECONDS = int(os.environ.get('LEADERBOARD_CACHE_SECONDS', '60'))
QUIZ_STATS_CACHE_SECONDS = int(os.environ.get('QUIZ_STATS_CACHE_SECONDS', '3600'))

# Celery — tâches lourdes hors requête HTTP
CELERY_TASK_ALWAYS_EAGER = os.environ.get('CELERY_TASK_ALWAYS_EAGER', '0') == '1'
CELERY_TASK_ACKS_LATE = True
CELERY_WORKER_PREFETCH_MULTIPLIER = int(os.environ.get('CELERY_PREFETCH', '4'))
CELERY_BROKER_CONNECTION_RETRY_ON_STARTUP = True

EMAIL_BACKEND = os.environ.get(
    'EMAIL_BACKEND', 'django.core.mail.backends.console.EmailBackend',
)
DEFAULT_FROM_EMAIL = os.environ.get('DEFAULT_FROM_EMAIL', 'sig-sols@disia.tg')

CELERY_BEAT_SCHEDULE = {
    'check-drought-alerts': {
        'task': 'sig_platform.tasks.check_drought_alerts',
        'schedule': 3600.0,
    },
    'purge-old-location-history': {
        'task': 'accounts.tasks.purge_old_location_history',
        'schedule': 86400.0,
    },
    'refresh-leaderboard-cache': {
        'task': 'education.tasks.refresh_leaderboard_cache',
        'schedule': float(LEADERBOARD_CACHE_SECONDS),
    },
}

# Security (production) — derrière nginx / reverse-proxy TLS
USE_X_FORWARDED_HOST = True
SECURE_PROXY_SSL_HEADER = ('HTTP_X_FORWARDED_PROTO', 'https')

if not DEBUG:
    SECURE_SSL_REDIRECT = os.environ.get('SECURE_SSL_REDIRECT', '1') == '1'
    SESSION_COOKIE_SECURE = True
    CSRF_COOKIE_SECURE = True
    SECURE_BROWSER_XSS_FILTER = True
    SECURE_CONTENT_TYPE_NOSNIFF = True
    SECURE_REFERRER_POLICY = 'same-origin'
    SECURE_HSTS_SECONDS = int(os.environ.get('SECURE_HSTS_SECONDS', '31536000'))
    SECURE_HSTS_INCLUDE_SUBDOMAINS = (
        os.environ.get('SECURE_HSTS_INCLUDE_SUBDOMAINS', '1') == '1'
    )
    SESSION_COOKIE_HTTPONLY = True
    CSRF_COOKIE_HTTPONLY = False  # JS front may need CSRF cookie if used
    SESSION_COOKIE_SAMESITE = 'Lax'
    CSRF_COOKIE_SAMESITE = 'Lax'

LOGGING = {
    'version': 1,
    'disable_existing_loggers': False,
    'handlers': {
        'console': {'class': 'logging.StreamHandler'},
    },
    'root': {
        'handlers': ['console'],
        'level': 'INFO',
    },
}
