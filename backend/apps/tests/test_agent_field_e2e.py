"""
Parcours E2E agent terrain : création → pending → validation/rejet → carte filtrée.

Branches critiques du TdR :
- Anonymous ne peut pas créer
- Public ne peut pas créer (écriture Agent/Admin)
- Agent crée un point pending (invisible si is_validated=true)
- Agent ne peut pas valider
- Admin valide → point apparaît sur carte filtrée
- Admin rejette → hors pending + hors carte validée
- Liste light expose is_validated / validation_status
- Idempotence client_id (sync offline)
"""
import pytest

# Même payload que frontend/js/features.js et mobile OfflineQueueService
TERRAIN_POINT = {
    'type': 'Feature',
    'geometry': {'type': 'Point', 'coordinates': [1.27, 6.37]},
    'properties': {
        'ph': 6.4,
        'humidity_pct': 38,
        'soil_type': 'argileux',
        'collected_at': '2026-03-10',
        'source': 'terrain',
    },
}


def _ids_from_list(response):
    data = response.json()
    if 'results' in data:
        return {item['id'] for item in data['results']}
    if 'features' in data:
        return {
            (f.get('id') or f.get('properties', {}).get('id'))
            for f in data['features']
        }
    return {item['id'] for item in data} if isinstance(data, list) else set()


def _find_light(response, point_id):
    data = response.json()
    rows = data.get('results') or data.get('features') or data
    for row in rows:
        props = row.get('properties', row) if isinstance(row, dict) else {}
        rid = row.get('id') or props.get('id')
        if rid == point_id:
            return props if 'properties' in row else row
    return None


@pytest.mark.django_db
class TestAgentFieldE2E:
    """Flux complet collecte terrain → validation → affichage carte."""

    def test_anonymous_cannot_create(self, api_client):
        r = api_client.post('/api/v1/points/', TERRAIN_POINT, format='json')
        assert r.status_code in (401, 403)

    def test_public_cannot_create(self, public_client):
        r = public_client.post('/api/v1/points/', {
            **TERRAIN_POINT,
            'geometry': {'type': 'Point', 'coordinates': [1.29, 6.39]},
        }, format='json')
        assert r.status_code == 403

    def test_agent_cannot_validate_or_list_pending(self, auth_client):
        create = auth_client.post('/api/v1/points/', TERRAIN_POINT, format='json')
        assert create.status_code in (200, 201)
        point_id = create.json()['id']

        pending = auth_client.get('/api/v1/validation/pending/')
        assert pending.status_code == 403

        validate = auth_client.post(
            f'/api/v1/points/{point_id}/validate_point/',
            {'action': 'validate'},
            format='json',
        )
        assert validate.status_code == 403

    def test_create_pending_hidden_then_validated_on_map(
        self, api_client, auth_client, admin_client,
    ):
        create = auth_client.post('/api/v1/points/', TERRAIN_POINT, format='json')
        assert create.status_code in (200, 201)
        body = create.json()
        point_id = body['id']
        props = body.get('properties', body)
        assert props.get('is_validated') is False
        assert props.get('validation_status', 'pending') == 'pending'

        validated_map = api_client.get('/api/v1/points/?light=1&is_validated=true')
        assert validated_map.status_code == 200
        assert point_id not in _ids_from_list(validated_map)

        all_map = api_client.get('/api/v1/points/?light=1')
        assert point_id in _ids_from_list(all_map)
        light = _find_light(all_map, point_id)
        assert light is not None
        assert light.get('is_validated') is False
        assert light.get('validation_status') == 'pending'

        pending = admin_client.get('/api/v1/validation/pending/')
        assert pending.status_code == 200
        assert pending.json()['count'] >= 1
        assert point_id in _ids_from_list(pending)

        done = admin_client.post(
            f'/api/v1/points/{point_id}/validate_point/',
            {'action': 'validate'},
            format='json',
        )
        assert done.status_code == 200
        assert done.json()['validation_status'] == 'validated'

        validated_map2 = api_client.get('/api/v1/points/?light=1&is_validated=true')
        assert point_id in _ids_from_list(validated_map2)
        light2 = _find_light(validated_map2, point_id)
        assert light2.get('is_validated') is True
        assert light2.get('validation_status') == 'validated'

        pending2 = admin_client.get('/api/v1/validation/pending/')
        assert point_id not in _ids_from_list(pending2)

    def test_reject_leaves_validated_map_and_pending(
        self, api_client, auth_client, admin_client,
    ):
        create = auth_client.post('/api/v1/points/', {
            **TERRAIN_POINT,
            'geometry': {'type': 'Point', 'coordinates': [1.28, 6.38]},
            'properties': {
                **TERRAIN_POINT['properties'],
                'ph': 5.1,
            },
        }, format='json')
        assert create.status_code in (200, 201)
        point_id = create.json()['id']

        rejected = admin_client.post(
            f'/api/v1/points/{point_id}/validate_point/',
            {'action': 'reject'},
            format='json',
        )
        assert rejected.status_code == 200
        assert rejected.json()['validation_status'] == 'rejected'

        assert point_id not in _ids_from_list(
            api_client.get('/api/v1/points/?light=1&is_validated=true'),
        )
        assert point_id not in _ids_from_list(
            admin_client.get('/api/v1/validation/pending/'),
        )

        light = _find_light(
            api_client.get('/api/v1/points/?light=1&validation_status=rejected'),
            point_id,
        )
        assert light is not None
        assert light.get('is_validated') is False
        assert light.get('validation_status') == 'rejected'

    def test_offline_client_id_idempotent(self, auth_client):
        """Double POST sync offline → un seul point (client_id)."""
        payload = {
            **TERRAIN_POINT,
            'geometry': {'type': 'Point', 'coordinates': [1.265, 6.365]},
            'properties': {
                **TERRAIN_POINT['properties'],
                'client_id': 'e2e-client-key-001',
            },
        }
        r1 = auth_client.post('/api/v1/points/', payload, format='json')
        assert r1.status_code in (200, 201)
        r2 = auth_client.post('/api/v1/points/', payload, format='json')
        assert r2.status_code == 200
        assert r1.json()['id'] == r2.json()['id']
