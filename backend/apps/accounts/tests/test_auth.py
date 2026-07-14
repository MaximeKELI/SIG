import base64

import pytest
from django.contrib.auth import get_user_model
from django.core.files.uploadedfile import SimpleUploadedFile

# PNG 1×1 valide
_TINY_PNG = base64.b64decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
)

User = get_user_model()


def _reg_payload(**overrides):
    data = {
        'username': 'newuser',
        'email': 'n@test.tg',
        'password': 'securepass123',
        'password_confirm': 'securepass123',
        'first_name': 'New',
        'last_name': 'User',
        'age': 25,
        'consent_analytics': True,
        'role': 'public',
    }
    data.update(overrides)
    return data


@pytest.mark.django_db
def test_register_and_token(api_client):
    r = api_client.post('/api/v1/auth/register/', _reg_payload(), format='json')
    assert r.status_code == 201
    assert r.json()['user']['username'] == 'newuser'
    r2 = api_client.post('/api/v1/auth/token/', {
        'username': 'newuser',
        'password': 'securepass123',
    })
    assert r2.status_code == 200
    assert 'access' in r2.json()


@pytest.mark.django_db
def test_register_cannot_self_assign_admin(api_client):
    r = api_client.post('/api/v1/auth/register/', _reg_payload(
        username='hacker',
        email='h@test.tg',
        role='admin',
    ), format='json')
    assert r.status_code == 201
    user = User.objects.get(username='hacker')
    assert user.role == User.Role.PUBLIC


@pytest.mark.django_db
def test_profile_authenticated(auth_client, agent_user):
    r = auth_client.get('/api/v1/auth/profile/')
    assert r.status_code == 200
    assert r.json()['username'] == 'test_agent'
    assert 'profile_photo_url' in r.json()
    assert 'bio' in r.json()
    assert 'profile_stats' in r.json()


@pytest.mark.django_db
def test_profile_photo_upload_and_delete(auth_client, agent_user):
    img = SimpleUploadedFile(
        'avatar.png',
        _TINY_PNG,
        content_type='image/png',
    )
    r = auth_client.post(
        '/api/v1/auth/profile/photo/',
        {'profile_photo': img},
        format='multipart',
    )
    assert r.status_code == 200
    assert r.json()['profile_photo_url']
    r2 = auth_client.delete('/api/v1/auth/profile/photo/')
    assert r2.status_code == 200
    assert r2.json()['profile_photo_url'] is None


@pytest.mark.django_db
def test_profile_photo_accepts_photo_alias(auth_client, agent_user):
    """Compat mobile : champ multipart `photo` au lieu de `profile_photo`."""
    img = SimpleUploadedFile(
        'avatar2.png',
        _TINY_PNG,
        content_type='image/png',
    )
    r = auth_client.post(
        '/api/v1/auth/profile/photo/',
        {'photo': img},
        format='multipart',
    )
    assert r.status_code == 200
    assert r.json()['profile_photo_url']


@pytest.mark.django_db
def test_user_list_requires_admin(api_client, agent_user, admin_user):
    from rest_framework_simplejwt.tokens import RefreshToken
    api_client.credentials(HTTP_AUTHORIZATION=f'Bearer {RefreshToken.for_user(agent_user).access_token}')
    assert api_client.get('/api/v1/auth/users/').status_code == 403
    api_client.credentials(HTTP_AUTHORIZATION=f'Bearer {RefreshToken.for_user(admin_user).access_token}')
    assert api_client.get('/api/v1/auth/users/').status_code == 200


@pytest.mark.django_db
def test_token_returns_user(api_client, agent_user):
    r = api_client.post('/api/v1/auth/token/', {
        'username': 'test_agent',
        'password': 'testpass123',
    })
    assert r.status_code == 200
    body = r.json()
    assert 'access' in body
    assert body['user']['role'] == 'agent'


@pytest.mark.django_db
def test_register_requires_consent(api_client):
    r = api_client.post('/api/v1/auth/register/', _reg_payload(consent_analytics=False), format='json')
    assert r.status_code == 400
    assert 'consent_analytics' in r.json()


@pytest.mark.django_db
def test_register_password_mismatch(api_client):
    r = api_client.post('/api/v1/auth/register/', _reg_payload(
        username='x',
        email='x@test.tg',
        password_confirm='different',
    ), format='json')
    assert r.status_code == 400


@pytest.mark.django_db
def test_change_password_mismatch(auth_client):
    r = auth_client.post('/api/v1/auth/password/change/', {
        'old_password': 'testpass123',
        'new_password': 'newpass12345',
        'new_password_confirm': 'different',
    }, format='json')
    assert r.status_code == 400


@pytest.mark.django_db
def test_change_password_wrong_old(auth_client):
    r = auth_client.post('/api/v1/auth/password/change/', {
        'old_password': 'wrong',
        'new_password': 'newpass12345',
        'new_password_confirm': 'newpass12345',
    }, format='json')
    assert r.status_code == 400
    assert 'old_password' in r.json()


@pytest.mark.django_db
def test_change_password(auth_client, agent_user):
    r = auth_client.post('/api/v1/auth/password/change/', {
        'old_password': 'testpass123',
        'new_password': 'newpass12345',
        'new_password_confirm': 'newpass12345',
    }, format='json')
    assert r.status_code == 200
    agent_user.refresh_from_db()
    assert agent_user.check_password('newpass12345')


@pytest.mark.django_db
def test_logout(auth_client):
    assert auth_client.post('/api/v1/auth/logout/').status_code == 200


@pytest.mark.django_db
def test_health():
    from django.test import Client
    c = Client()
    r = c.get('/health/')
    assert r.status_code == 200
    assert 'SIG-SOLS' in r.json()['project']
