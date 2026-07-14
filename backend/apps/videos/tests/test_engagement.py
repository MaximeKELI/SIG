from django.core.files.uploadedfile import SimpleUploadedFile
from django.urls import reverse
from rest_framework import status
from rest_framework.test import APITestCase

from accounts.models import User
from sig_platform.models import Notification
from videos.models import VideoComment, VideoPost, VideoPostLike


class VideoEngagementAPITest(APITestCase):
    def setUp(self):
        self.user = User.objects.create_user(
            username='eng_user',
            password='pass12345',
            role=User.Role.PUBLIC,
        )
        self.other = User.objects.create_user(
            username='eng_other',
            password='pass12345',
            role=User.Role.PUBLIC,
        )
        self.post = VideoPost.objects.create(
            author=self.user,
            kind=VideoPost.Kind.VIDEO,
            title='Publiée',
            file=SimpleUploadedFile('v.mp4', b'x', content_type='video/mp4'),
            status=VideoPost.Status.PUBLISHED,
        )

    def test_comment_reply_and_likes(self):
        self.client.force_authenticate(self.user)
        c_res = self.client.post(
            reverse('video-post-comments', kwargs={'pk': self.post.pk}),
            {'text': 'Super vidéo'},
            format='json',
        )
        self.assertEqual(c_res.status_code, status.HTTP_201_CREATED)
        comment_id = c_res.data['id']

        self.client.force_authenticate(self.other)
        r_res = self.client.post(
            reverse('video-post-comments', kwargs={'pk': self.post.pk}),
            {'text': 'Merci !', 'parent_id': comment_id},
            format='json',
        )
        self.assertEqual(r_res.status_code, status.HTTP_201_CREATED)

        like_post = self.client.post(
            reverse('video-post-toggle-like', kwargs={'pk': self.post.pk}),
        )
        self.assertEqual(like_post.status_code, status.HTTP_200_OK)
        self.assertTrue(like_post.data['liked'])
        self.assertEqual(like_post.data['like_count'], 1)

        like_c = self.client.post(
            reverse('video-comment-toggle-like', kwargs={'pk': comment_id}),
        )
        self.assertEqual(like_c.status_code, status.HTTP_200_OK)
        self.assertEqual(like_c.data['like_count'], 1)

        list_res = self.client.get(
            reverse('video-post-comments', kwargs={'pk': self.post.pk}),
        )
        self.assertEqual(len(list_res.data), 2)

    def test_list_includes_engagement_fields(self):
        VideoPostLike.objects.create(post=self.post, user=self.user)
        VideoComment.objects.create(
            post=self.post,
            author=self.user,
            text='Un commentaire',
        )
        res = self.client.get(reverse('video-post-list'), {'kind': 'video'})
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        row = res.data['results'][0]
        self.assertEqual(row['like_count'], 1)
        self.assertEqual(row['comment_count'], 1)
        self.assertFalse(row['liked_by_me'])

    def test_toggle_like_requires_auth(self):
        res = self.client.post(
            reverse('video-post-toggle-like', kwargs={'pk': self.post.pk}),
        )
        self.assertEqual(res.status_code, status.HTTP_401_UNAUTHORIZED)

    def test_reply_and_comment_like_notify_author(self):
        self.client.force_authenticate(self.user)
        c_res = self.client.post(
            reverse('video-post-comments', kwargs={'pk': self.post.pk}),
            {'text': 'Premier avis'},
            format='json',
        )
        self.assertEqual(c_res.status_code, status.HTTP_201_CREATED)
        comment_id = c_res.data['id']
        # Auteur de la vidéo ne reçoit pas de notif pour son propre commentaire.
        self.assertFalse(
            Notification.objects.filter(
                user=self.user,
                title='Nouveau commentaire',
            ).exists(),
        )

        self.client.force_authenticate(self.other)
        r_res = self.client.post(
            reverse('video-post-comments', kwargs={'pk': self.post.pk}),
            {'text': 'Je confirme', 'parent_id': comment_id},
            format='json',
        )
        self.assertEqual(r_res.status_code, status.HTTP_201_CREATED)
        self.assertTrue(
            Notification.objects.filter(
                user=self.user,
                title='Réponse à votre commentaire',
            ).exists(),
        )

        like_c = self.client.post(
            reverse('video-comment-toggle-like', kwargs={'pk': comment_id}),
        )
        self.assertEqual(like_c.status_code, status.HTTP_200_OK)
        self.assertTrue(
            Notification.objects.filter(
                user=self.user,
                title='Like sur commentaire',
            ).exists(),
        )

    def test_comment_payload_includes_author_identity(self):
        self.user.first_name = 'Afi'
        self.user.last_name = 'Mensah'
        self.user.save(update_fields=['first_name', 'last_name'])
        self.client.force_authenticate(self.user)
        c_res = self.client.post(
            reverse('video-post-comments', kwargs={'pk': self.post.pk}),
            {'text': 'Bon travail'},
            format='json',
        )
        self.assertEqual(c_res.status_code, status.HTTP_201_CREATED)
        self.assertEqual(c_res.data['author_username'], 'eng_user')
        self.assertEqual(c_res.data['author_display'], 'Afi Mensah')
        self.assertIn('author_profile_photo_url', c_res.data)
