from django.conf import settings
from django.db import models


def video_upload_to(instance, filename):
    from django.utils import timezone

    sub = timezone.now().strftime('%Y/%m')
    folder = 'shorts' if instance.kind == VideoPost.Kind.SHORT else 'videos'
    return f'{folder}/{sub}/{filename}'


class VideoPost(models.Model):
    """Publication vidéo (long format) ou short (format court)."""

    class Kind(models.TextChoices):
        VIDEO = 'video', 'Vidéo'
        SHORT = 'short', 'Short'

    class Status(models.TextChoices):
        PENDING = 'pending', 'En attente'
        PUBLISHED = 'published', 'Publié'
        REJECTED = 'rejected', 'Refusé'

    class Category(models.TextChoices):
        SOLS = 'sols', 'Sols & agriculture'
        NASA = 'nasa', 'NASA & satellite'
        SIG = 'sig', 'SIG & cartographie'
        FORMATION = 'formation', 'Formation'
        AUTRE = 'autre', 'Autre'

    author = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='video_posts',
    )
    kind = models.CharField(max_length=10, choices=Kind.choices, db_index=True)
    category = models.CharField(
        max_length=20,
        choices=Category.choices,
        default=Category.SOLS,
        db_index=True,
    )
    title = models.CharField(max_length=200)
    tags = models.CharField(
        max_length=500,
        blank=True,
        help_text='Hashtags séparés par des virgules (ex: sols,nasa)',
    )
    description = models.TextField(blank=True)
    file = models.FileField(upload_to=video_upload_to)
    thumbnail = models.ImageField(
        upload_to='videos/thumbnails/%Y/%m/',
        blank=True,
    )
    status = models.CharField(
        max_length=12,
        choices=Status.choices,
        default=Status.PUBLISHED,
        db_index=True,
    )
    duration_seconds = models.PositiveIntegerField(
        null=True,
        blank=True,
        help_text='Durée indiquée par l’auteur (shorts ≤ 60 s recommandé)',
    )
    view_count = models.PositiveIntegerField(default=0)
    is_featured = models.BooleanField(
        default=False,
        help_text='Mise en avant par un administrateur',
    )
    rejection_reason = models.TextField(blank=True)
    moderated_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        null=True,
        blank=True,
        on_delete=models.SET_NULL,
        related_name='moderated_videos',
    )
    moderated_at = models.DateTimeField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True, db_index=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['-created_at']
        verbose_name = 'Publication vidéo'
        verbose_name_plural = 'Publications vidéo'
        indexes = [
            models.Index(fields=['kind', 'status', '-created_at']),
            models.Index(fields=['author', '-created_at']),
        ]

    def __str__(self):
        return f'{self.get_kind_display()}: {self.title}'


class VideoComment(models.Model):
    """Commentaire ou réponse sur une vidéo / short."""

    post = models.ForeignKey(
        VideoPost,
        on_delete=models.CASCADE,
        related_name='comments',
    )
    author = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='video_comments',
    )
    parent = models.ForeignKey(
        'self',
        null=True,
        blank=True,
        on_delete=models.CASCADE,
        related_name='replies',
    )
    text = models.TextField(max_length=2000)
    is_hidden = models.BooleanField(
        default=False,
        help_text='Masqué par modération admin',
    )
    created_at = models.DateTimeField(auto_now_add=True, db_index=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['created_at']
        verbose_name = 'Commentaire vidéo'
        verbose_name_plural = 'Commentaires vidéo'
        indexes = [
            models.Index(fields=['post', 'created_at']),
            models.Index(fields=['parent', 'created_at']),
        ]

    def __str__(self):
        return f'Commentaire #{self.pk} sur {self.post_id}'


class VideoPostLike(models.Model):
    post = models.ForeignKey(
        VideoPost,
        on_delete=models.CASCADE,
        related_name='post_likes',
    )
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='video_post_likes',
    )
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        constraints = [
            models.UniqueConstraint(
                fields=['post', 'user'],
                name='videos_unique_post_like',
            ),
        ]


class VideoCommentLike(models.Model):
    comment = models.ForeignKey(
        VideoComment,
        on_delete=models.CASCADE,
        related_name='comment_likes',
    )
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='video_comment_likes',
    )
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        constraints = [
            models.UniqueConstraint(
                fields=['comment', 'user'],
                name='videos_unique_comment_like',
            ),
        ]


class StoryPost(models.Model):
    """Story éphémère (24 h) — image ou courte vidéo."""

    author = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='stories',
    )
    media = models.FileField(upload_to='stories/%Y/%m/')
    caption = models.CharField(max_length=500, blank=True)
    expires_at = models.DateTimeField(db_index=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-created_at']
