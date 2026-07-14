from django.utils import timezone
from rest_framework import status, viewsets
from rest_framework.permissions import BasePermission, SAFE_METHODS
from rest_framework.response import Response

from accounts.models import User
from .models import StoryPost
from .serializers import VideoPostSerializer


class StoryPermission(BasePermission):
    """Liste/création authentifiées ; suppression = auteur ou admin."""

    def has_permission(self, request, view):
        if request.method in SAFE_METHODS:
            return True
        user = request.user
        return isinstance(user, User) and user.is_authenticated

    def has_object_permission(self, request, view, obj):
        user = request.user
        if request.method in SAFE_METHODS:
            return True
        if not isinstance(user, User) or not user.is_authenticated:
            return False
        if request.method == 'DELETE':
            return obj.author_id == user.pk or user.is_administrator
        return obj.author_id == user.pk or user.is_administrator


class StoryViewSet(viewsets.ModelViewSet):
    """Stories éphémères (24 h) — lecture publique, création/suppression auth."""

    permission_classes = [StoryPermission]
    http_method_names = ['get', 'post', 'delete', 'head', 'options']

    def get_queryset(self):
        user = self.request.user
        if self.action == 'destroy':
            if isinstance(user, User) and user.is_authenticated:
                if user.is_administrator:
                    return StoryPost.objects.all().select_related('author')
                return StoryPost.objects.filter(author=user).select_related('author')
            return StoryPost.objects.none()
        cutoff = timezone.now() - timezone.timedelta(hours=24)
        return StoryPost.objects.filter(
            created_at__gte=cutoff,
        ).select_related('author').order_by('-created_at')

    def get_serializer_class(self):
        return VideoPostSerializer

    def list(self, request, *args, **kwargs):
        qs = self.get_queryset()
        user = request.user
        uid = getattr(user, 'pk', None) if getattr(user, 'is_authenticated', False) else None
        data = [
            {
                'id': s.id,
                'author': s.author_id,
                'author_username': s.author.username,
                'author_display': s.author.get_full_name() or s.author.username,
                'media_url': s.media.url if s.media else None,
                'caption': s.caption,
                'expires_at': s.expires_at,
                'created_at': s.created_at,
                'is_mine': uid is not None and s.author_id == uid,
            }
            for s in qs[:50]
        ]
        return Response(data)

    def create(self, request, *args, **kwargs):
        media = request.FILES.get('media')
        if not media:
            return Response({'detail': 'Fichier média requis.'}, status=400)
        story = StoryPost.objects.create(
            author=request.user,
            media=media,
            caption=(request.data.get('caption') or '')[:500],
            expires_at=timezone.now() + timezone.timedelta(hours=24),
        )
        return Response(
            {
                'id': story.id,
                'is_mine': True,
                'author_username': request.user.username,
            },
            status=status.HTTP_201_CREATED,
        )

    def perform_destroy(self, instance):
        if instance.media:
            instance.media.delete(save=False)
        instance.delete()


def ai_moderation_hint(text: str) -> dict:
    """Heuristique simple (sans API externe) pour suggestion modération."""
    lower = (text or '').lower()
    flags = []
    blocked = ['spam', 'arnaque', 'haine', 'insulte']
    for w in blocked:
        if w in lower:
            flags.append(w)
    return {
        'suggested_hide': len(flags) > 0,
        'flags': flags,
        'confidence': 0.7 if flags else 0.1,
    }
