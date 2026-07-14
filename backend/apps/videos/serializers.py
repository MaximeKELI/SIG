import os

from django.conf import settings
from rest_framework import serializers

from .models import VideoComment, VideoPost

ALLOWED_VIDEO_EXTENSIONS = {'.mp4', '.webm', '.mov', '.mkv', '.m4v'}
ALLOWED_THUMB_EXTENSIONS = {'.jpg', '.jpeg', '.png', '.webp'}


def _ext(name):
    return os.path.splitext(name or '')[1].lower()


def _author_photo_url(author):
    if author and author.profile_photo:
        return author.profile_photo.url
    return None


class VideoPostSerializer(serializers.ModelSerializer):
    author_username = serializers.CharField(source='author.username', read_only=True)
    author_display = serializers.SerializerMethodField()
    author_profile_photo_url = serializers.SerializerMethodField()
    file_url = serializers.SerializerMethodField()
    thumbnail_url = serializers.SerializerMethodField()
    can_moderate = serializers.SerializerMethodField()
    is_mine = serializers.SerializerMethodField()
    like_count = serializers.IntegerField(read_only=True, default=0)
    comment_count = serializers.IntegerField(read_only=True, default=0)
    liked_by_me = serializers.BooleanField(read_only=True, default=False)

    class Meta:
        model = VideoPost
        fields = (
            'id', 'kind', 'category', 'title', 'tags', 'description', 'status',
            'duration_seconds', 'view_count', 'is_featured',
            'like_count', 'comment_count', 'liked_by_me', 'is_mine',
            'author', 'author_username', 'author_display',
            'author_profile_photo_url',
            'file_url', 'thumbnail_url', 'rejection_reason',
            'created_at', 'updated_at', 'can_moderate',
        )
        read_only_fields = (
            'id', 'status', 'view_count', 'author', 'author_username',
            'author_display', 'file_url', 'thumbnail_url',
            'rejection_reason', 'created_at', 'updated_at', 'can_moderate',
            'like_count', 'comment_count', 'liked_by_me', 'is_mine',
        )

    def get_author_display(self, obj):
        return obj.author.get_full_name() or obj.author.username

    def get_author_profile_photo_url(self, obj):
        return _author_photo_url(obj.author)

    def get_is_mine(self, obj):
        request = self.context.get('request')
        user = getattr(request, 'user', None) if request else None
        return bool(
            user
            and getattr(user, 'is_authenticated', False)
            and obj.author_id == getattr(user, 'pk', None)
        )

    def get_file_url(self, obj):
        return obj.file.url if obj.file else None

    def get_thumbnail_url(self, obj):
        return obj.thumbnail.url if obj.thumbnail else None

    def get_can_moderate(self, obj):
        request = self.context.get('request')
        user = getattr(request, 'user', None) if request else None
        return bool(
            user
            and getattr(user, 'is_authenticated', False)
            and user.is_administrator
        )


class VideoPostCreateSerializer(serializers.ModelSerializer):
    file = serializers.FileField()
    thumbnail = serializers.ImageField(required=False, allow_null=True)
    status = serializers.CharField(read_only=True)

    class Meta:
        model = VideoPost
        fields = (
            'id', 'kind', 'category', 'title', 'tags', 'description', 'file', 'thumbnail',
            'duration_seconds', 'status',
        )
        read_only_fields = ('id', 'status')

    def validate_kind(self, value):
        if value not in (VideoPost.Kind.VIDEO, VideoPost.Kind.SHORT):
            raise serializers.ValidationError('Type invalide.')
        return value

    def validate_file(self, file_obj):
        ext = _ext(file_obj.name)
        if ext not in ALLOWED_VIDEO_EXTENSIONS:
            raise serializers.ValidationError(
                'Format vidéo non supporté (mp4, webm, mov, mkv, m4v).',
            )
        max_bytes = getattr(settings, 'VIDEO_MAX_UPLOAD_BYTES', 50 * 1024 * 1024)
        if file_obj.size > max_bytes:
            mb = max_bytes // (1024 * 1024)
            raise serializers.ValidationError(
                f'Fichier trop volumineux (max {mb} Mo).',
            )
        return file_obj

    def validate_thumbnail(self, thumb):
        if not thumb:
            return thumb
        if _ext(thumb.name) not in ALLOWED_THUMB_EXTENSIONS:
            raise serializers.ValidationError(
                'Miniature : jpg, png ou webp uniquement.',
            )
        return thumb

    def validate(self, attrs):
        kind = attrs.get('kind')
        duration = attrs.get('duration_seconds')
        if kind == VideoPost.Kind.SHORT and duration and duration > 60:
            raise serializers.ValidationError({
                'duration_seconds': 'Un short ne doit pas dépasser 60 secondes.',
            })
        return attrs

    def create(self, validated_data):
        request = self.context['request']
        validated_data['author'] = request.user
        # Toute publication doit être validée par un administrateur.
        validated_data['status'] = VideoPost.Status.PENDING
        return super().create(validated_data)


class VideoCommentSerializer(serializers.ModelSerializer):
    author_username = serializers.CharField(source='author.username', read_only=True)
    author_display = serializers.SerializerMethodField()
    author_profile_photo_url = serializers.SerializerMethodField()
    like_count = serializers.IntegerField(read_only=True, default=0)
    reply_count = serializers.IntegerField(read_only=True, default=0)
    liked_by_me = serializers.BooleanField(read_only=True, default=False)
    parent_id = serializers.PrimaryKeyRelatedField(
        queryset=VideoComment.objects.all(),
        source='parent',
        required=False,
        allow_null=True,
    )

    class Meta:
        model = VideoComment
        fields = (
            'id', 'post', 'parent_id', 'text',
            'author', 'author_username', 'author_display',
            'author_profile_photo_url',
            'like_count', 'reply_count', 'liked_by_me',
            'created_at', 'updated_at',
        )
        read_only_fields = (
            'id', 'post', 'author', 'author_username', 'author_display',
            'like_count', 'reply_count', 'liked_by_me',
            'created_at', 'updated_at',
        )

    def get_author_display(self, obj):
        return obj.author.get_full_name() or obj.author.username

    def get_author_profile_photo_url(self, obj):
        return _author_photo_url(obj.author)

    def validate_text(self, value):
        text = (value or '').strip()
        if len(text) < 1:
            raise serializers.ValidationError('Le commentaire ne peut pas être vide.')
        if len(text) > 2000:
            raise serializers.ValidationError('2000 caractères maximum.')
        return text

    def validate(self, attrs):
        parent = attrs.get('parent')
        post = attrs.get('post') or getattr(self.instance, 'post', None)
        if parent and post and parent.post_id != post.pk:
            raise serializers.ValidationError({
                'parent_id': 'La réponse doit appartenir au même fil.',
            })
        if parent and parent.parent_id is not None:
            raise serializers.ValidationError({
                'parent_id': 'Réponse uniquement au commentaire principal.',
            })
        return attrs

    def create(self, validated_data):
        validated_data['author'] = self.context['request'].user
        return super().create(validated_data)
