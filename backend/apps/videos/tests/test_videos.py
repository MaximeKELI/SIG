from django.core.files.uploadedfile import SimpleUploadedFile
from django.urls import reverse
from rest_framework import status
from rest_framework.test import APITestCase

from accounts.models import User
from videos.models import VideoPost


class VideoPostAPITest(APITestCase):
    def setUp(self):
        self.public = User.objects.create_user(
            username='vid_public',
            password='pass12345',
            role=User.Role.PUBLIC,
        )
        self.admin = User.objects.create_user(
            username='vid_admin',
            password='pass12345',
            role=User.Role.ADMIN,
        )
        self.video_file = SimpleUploadedFile(
            'clip.mp4',
            b'fake-video-bytes',
            content_type='video/mp4',
        )

    def _url(self, name, **kwargs):
        return reverse(name, kwargs=kwargs)

    def test_public_upload_pending(self):
        self.client.force_authenticate(self.public)
        res = self.client.post(
            self._url('video-post-list'),
            {
                'kind': 'video',
                'title': 'Mon terrain',
                'description': 'Sol argileux',
                'file': self.video_file,
            },
            format='multipart',
        )
        self.assertEqual(res.status_code, status.HTTP_201_CREATED)
        self.assertEqual(res.data['status'], 'pending')

    def test_admin_upload_pending(self):
        self.client.force_authenticate(self.admin)
        res = self.client.post(
            self._url('video-post-list'),
            {
                'kind': 'short',
                'title': 'Short admin',
                'file': SimpleUploadedFile(
                    's.mp4', b'x', content_type='video/mp4',
                ),
                'duration_seconds': 30,
            },
            format='multipart',
        )
        self.assertEqual(res.status_code, status.HTTP_201_CREATED)
        self.assertEqual(res.data['status'], 'pending')

    def test_agent_upload_pending(self):
        agent = User.objects.create_user(
            username='vid_agent',
            password='pass12345',
            role=User.Role.AGENT,
        )
        self.client.force_authenticate(agent)
        res = self.client.post(
            self._url('video-post-list'),
            {
                'kind': 'video',
                'title': 'Terrain agent',
                'file': SimpleUploadedFile(
                    'agent.mp4', b'x', content_type='video/mp4',
                ),
            },
            format='multipart',
        )
        self.assertEqual(res.status_code, status.HTTP_201_CREATED)
        self.assertEqual(res.data['status'], 'pending')

    def test_anon_lists_only_published(self):
        VideoPost.objects.create(
            author=self.public,
            kind=VideoPost.Kind.VIDEO,
            title='Pending',
            file=SimpleUploadedFile('a.mp4', b'1', content_type='video/mp4'),
            status=VideoPost.Status.PENDING,
        )
        VideoPost.objects.create(
            author=self.admin,
            kind=VideoPost.Kind.VIDEO,
            title='Live',
            file=SimpleUploadedFile('b.mp4', b'2', content_type='video/mp4'),
            status=VideoPost.Status.PUBLISHED,
        )
        res = self.client.get(self._url('video-post-list'), {'kind': 'video'})
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        titles = [r['title'] for r in res.data['results']]
        self.assertEqual(titles, ['Live'])

    def test_admin_approve(self):
        post = VideoPost.objects.create(
            author=self.public,
            kind=VideoPost.Kind.SHORT,
            title='A modérer',
            file=SimpleUploadedFile('c.mp4', b'3', content_type='video/mp4'),
            status=VideoPost.Status.PENDING,
        )
        self.client.force_authenticate(self.admin)
        res = self.client.post(self._url('video-post-approve', pk=post.pk))
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        post.refresh_from_db()
        self.assertEqual(post.status, VideoPost.Status.PUBLISHED)

    def test_comment_reply_and_likes(self):
        post = VideoPost.objects.create(
            author=self.admin,
            kind=VideoPost.Kind.VIDEO,
            title='Publiée',
            file=SimpleUploadedFile('d.mp4', b'4', content_type='video/mp4'),
            status=VideoPost.Status.PUBLISHED,
        )
        self.client.force_authenticate(self.public)
        c1 = self.client.post(
            self._url('video-post-comments', pk=post.pk),
            {'text': 'Super vidéo !'},
            format='json',
        )
        self.assertEqual(c1.status_code, status.HTTP_201_CREATED)
        parent_id = c1.data['id']
        c2 = self.client.post(
            self._url('video-post-comments', pk=post.pk),
            {'text': 'Merci !', 'parent_id': parent_id},
            format='json',
        )
        self.assertEqual(c2.status_code, status.HTTP_201_CREATED)
        self.assertEqual(c2.data['parent_id'], parent_id)

        like_post = self.client.post(
            self._url('video-post-toggle-like', pk=post.pk),
        )
        self.assertEqual(like_post.status_code, status.HTTP_200_OK)
        self.assertTrue(like_post.data['liked'])
        self.assertEqual(like_post.data['like_count'], 1)

        like_c = self.client.post(
            f'/api/v1/videos/comments/{parent_id}/toggle_like/',
        )
        self.assertEqual(like_c.status_code, status.HTTP_200_OK)
        self.assertTrue(like_c.data['liked'])

    def test_author_can_delete_own_video(self):
        post = VideoPost.objects.create(
            author=self.public,
            kind=VideoPost.Kind.VIDEO,
            title='À supprimer',
            file=SimpleUploadedFile('d.mp4', b'4', content_type='video/mp4'),
            status=VideoPost.Status.PENDING,
        )
        self.client.force_authenticate(self.public)
        res = self.client.delete(self._url('video-post-detail', pk=post.pk))
        self.assertEqual(res.status_code, status.HTTP_204_NO_CONTENT)
        self.assertFalse(VideoPost.objects.filter(pk=post.pk).exists())

    def test_other_user_cannot_delete_video(self):
        post = VideoPost.objects.create(
            author=self.public,
            kind=VideoPost.Kind.SHORT,
            title='Protégé',
            file=SimpleUploadedFile('e.mp4', b'5', content_type='video/mp4'),
            status=VideoPost.Status.PUBLISHED,
        )
        other = User.objects.create_user(
            username='vid_other',
            password='pass12345',
            role=User.Role.PUBLIC,
        )
        self.client.force_authenticate(other)
        res = self.client.delete(self._url('video-post-detail', pk=post.pk))
        self.assertEqual(res.status_code, status.HTTP_403_FORBIDDEN)
        self.assertTrue(VideoPost.objects.filter(pk=post.pk).exists())

    def test_admin_can_delete_any_video(self):
        post = VideoPost.objects.create(
            author=self.public,
            kind=VideoPost.Kind.VIDEO,
            title='Modéré',
            file=SimpleUploadedFile('f.mp4', b'6', content_type='video/mp4'),
            status=VideoPost.Status.PUBLISHED,
        )
        self.client.force_authenticate(self.admin)
        res = self.client.delete(self._url('video-post-detail', pk=post.pk))
        self.assertEqual(res.status_code, status.HTTP_204_NO_CONTENT)

    def test_author_can_delete_own_story(self):
        from django.utils import timezone
        from videos.models import StoryPost

        story = StoryPost.objects.create(
            author=self.public,
            media=SimpleUploadedFile('s.jpg', b'img', content_type='image/jpeg'),
            caption='story test',
            expires_at=timezone.now() + timezone.timedelta(hours=20),
        )
        self.client.force_authenticate(self.public)
        res = self.client.delete(f'/api/v1/videos/stories/{story.pk}/')
        self.assertEqual(res.status_code, status.HTTP_204_NO_CONTENT)
        self.assertFalse(StoryPost.objects.filter(pk=story.pk).exists())

    def test_is_mine_flag_on_list(self):
        VideoPost.objects.create(
            author=self.public,
            kind=VideoPost.Kind.VIDEO,
            title='Mine',
            file=SimpleUploadedFile('g.mp4', b'7', content_type='video/mp4'),
            status=VideoPost.Status.PUBLISHED,
        )
        self.client.force_authenticate(self.public)
        res = self.client.get(self._url('video-post-list'), {'kind': 'video'})
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        mine = [r for r in res.data['results'] if r['title'] == 'Mine'][0]
        self.assertTrue(mine['is_mine'])
