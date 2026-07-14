from django.contrib.auth import get_user_model
from rest_framework import status
from rest_framework.test import APITestCase

User = get_user_model()


class AdminCockpitAPITest(APITestCase):
    def setUp(self):
        self.admin = User.objects.create_user(
            username='cockpit_admin',
            password='pass12345',
            role=User.Role.ADMIN,
        )
        self.public = User.objects.create_user(
            username='cockpit_public',
            password='pass12345',
            role=User.Role.PUBLIC,
        )

    def test_cockpit_requires_admin(self):
        self.client.force_authenticate(self.public)
        res = self.client.get('/api/v1/platform/admin/cockpit/')
        self.assertEqual(res.status_code, status.HTTP_403_FORBIDDEN)

    def test_cockpit_returns_full_payload(self):
        self.client.force_authenticate(self.admin)
        res = self.client.get('/api/v1/platform/admin/cockpit/?days=30')
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        for key in (
            'overview',
            'soil_stats',
            'queues',
            'users',
            'analytics',
            'terrain',
            'audit',
            'activity_recent',
        ):
            self.assertIn(key, res.data)
        overview = res.data['overview']
        self.assertIn('users_total', overview)
        self.assertIn('videos_published', overview)
        self.assertIn('quizzes_completed_period', overview)
        self.assertIn('pending_soils', res.data['queues'])
        self.assertIn('pending_videos', res.data['queues'])
        self.assertIn('live_agents', res.data['terrain'])
        self.assertGreaterEqual(overview['users_total'], 2)
