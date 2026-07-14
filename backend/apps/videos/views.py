from django.db.models import F, Q
from django.utils import timezone
from rest_framework import mixins, status, viewsets
from rest_framework.decorators import action
from rest_framework.parsers import FormParser, JSONParser, MultiPartParser
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response

from accounts.models import User

from .models import VideoComment, VideoPost
from .permissions import VideoCommentPermission, VideoPostPermission
from .serializers import (
    VideoCommentSerializer,
    VideoPostCreateSerializer,
    VideoPostSerializer,
)
from sig_platform.notify import notify_user

from .services import (
    annotate_comment_engagement,
    annotate_post_engagement,
    toggle_comment_like,
    toggle_post_like,
    user_can_view_post,
)


class VideoPostViewSet(viewsets.ModelViewSet):
    """Publications vidéo et shorts — upload, lecture, likes, commentaires."""

    permission_classes = [VideoPostPermission]
    parser_classes = [MultiPartParser, FormParser, JSONParser]
    filterset_fields = ['kind', 'status', 'is_featured', 'category']
    search_fields = ['title', 'description']
    ordering_fields = ['created_at', 'view_count']
    ordering = ['-created_at']
    http_method_names = ['get', 'post', 'patch', 'delete', 'head', 'options']

    def get_serializer_class(self):
        if self.action == 'create':
            return VideoPostCreateSerializer
        return VideoPostSerializer

    def get_queryset(self):
        qs = VideoPost.objects.select_related('author')
        user = self.request.user
        if isinstance(user, User) and user.is_authenticated:
            if user.is_administrator:
                base = qs
            else:
                base = qs.filter(
                    Q(status=VideoPost.Status.PUBLISHED) | Q(author=user),
                )
        else:
            base = qs.filter(status=VideoPost.Status.PUBLISHED)
        tag = self.request.query_params.get('tag', '').strip().lstrip('#')
        if tag:
            base = base.filter(tags__icontains=tag)
        category = self.request.query_params.get('category', '').strip()
        if category:
            base = base.filter(category=category)
        return annotate_post_engagement(base, user)

    def perform_create(self, serializer):
        serializer.save()
        # Plus de file d'attente admin : publication directe (sauf rejet filtre IA).

    def perform_destroy(self, instance):
        """Suppression auteur/admin + fichiers média associés."""
        if instance.file:
            instance.file.delete(save=False)
        if instance.thumbnail:
            instance.thumbnail.delete(save=False)
        instance.delete()

    def _notify_admins_pending(self, post):
        link = '/?view=admin'
        title = 'Vidéo à modérer'
        message = (
            f'{post.author.username} a envoyé « {post.title} » '
            f'({post.get_kind_display()}).'
        )
        for admin in User.objects.filter(role=User.Role.ADMIN, is_active=True):
            notify_user(admin, title, message, link=link, level='warning')

    def retrieve(self, request, *args, **kwargs):
        instance = self.get_object()
        if instance.status == VideoPost.Status.PUBLISHED:
            VideoPost.objects.filter(pk=instance.pk).update(
                view_count=F('view_count') + 1,
            )
            instance.refresh_from_db(fields=['view_count'])
        serializer = self.get_serializer(instance)
        return Response(serializer.data)

    @action(detail=True, methods=['post'], permission_classes=[IsAuthenticated])
    def toggle_like(self, request, pk=None):
        post = self.get_object()
        if not user_can_view_post(post, request.user):
            return Response({'detail': 'Publication inaccessible.'}, status=403)
        liked, count = toggle_post_like(post, request.user)
        if liked and post.author_id != request.user.pk:
            who = request.user.get_full_name() or request.user.username
            notify_user(
                post.author,
                'Nouveau like',
                f'{who} a aimé « {post.title} ».',
                link=f'/?view=videos&video={post.pk}',
            )
        return Response({'liked': liked, 'like_count': count})

    @action(detail=True, methods=['get', 'post'], url_path='comments')
    def comments(self, request, pk=None):
        post = self.get_object()
        if not user_can_view_post(post, request.user):
            return Response({'detail': 'Publication inaccessible.'}, status=403)

        if request.method == 'GET':
            qs = annotate_comment_engagement(
                VideoComment.objects.filter(
                    post=post,
                    is_hidden=False,
                ).select_related('author', 'parent'),
                request.user,
            )
            ser = VideoCommentSerializer(
                qs, many=True, context={'request': request},
            )
            return Response(ser.data)

        ser = VideoCommentSerializer(
            data=request.data,
            context={'request': request},
        )
        ser.is_valid(raise_exception=True)
        parent = ser.validated_data.get('parent')
        comment = VideoComment.objects.create(
            post=post,
            author=request.user,
            parent=parent,
            text=ser.validated_data['text'],
        )
        who = request.user.get_full_name() or request.user.username
        link = f'/?view=videos&video={post.pk}'
        if parent is not None:
            if parent.author_id != request.user.pk:
                notify_user(
                    parent.author,
                    'Réponse à votre commentaire',
                    f'{who} a répondu à votre commentaire sur « {post.title} ».',
                    link=link,
                )
            if (
                post.author_id != request.user.pk
                and post.author_id != parent.author_id
            ):
                notify_user(
                    post.author,
                    'Nouveau commentaire',
                    f'{who} a commenté « {post.title} ».',
                    link=link,
                )
        elif post.author_id != request.user.pk:
            notify_user(
                post.author,
                'Nouveau commentaire',
                f'{who} a commenté « {post.title} ».',
                link=link,
            )
        out = annotate_comment_engagement(
            VideoComment.objects.filter(pk=comment.pk).select_related('author'),
            request.user,
        ).first()
        return Response(
            VideoCommentSerializer(out, context={'request': request}).data,
            status=status.HTTP_201_CREATED,
        )

    @action(detail=True, methods=['post'])
    def approve(self, request, pk=None):
        post = self.get_object()
        post.status = VideoPost.Status.PUBLISHED
        post.rejection_reason = ''
        post.moderated_by = request.user
        post.moderated_at = timezone.now()
        post.save(
            update_fields=[
                'status', 'rejection_reason', 'moderated_by',
                'moderated_at', 'updated_at',
            ],
        )
        notify_user(
            post.author,
            'Vidéo publiée',
            f'Votre vidéo « {post.title} » est en ligne.',
            link='/?view=videos',
            level='info',
        )
        refreshed = self.get_queryset().filter(pk=post.pk).first()
        return Response(self.get_serializer(refreshed).data)

    @action(detail=True, methods=['post'])
    def reject(self, request, pk=None):
        post = self.get_object()
        reason = (request.data.get('reason') or '').strip()[:500]
        post.status = VideoPost.Status.REJECTED
        post.rejection_reason = reason or 'Contenu non conforme.'
        post.moderated_by = request.user
        post.moderated_at = timezone.now()
        post.save(
            update_fields=[
                'status', 'rejection_reason', 'moderated_by',
                'moderated_at', 'updated_at',
            ],
        )
        notify_user(
            post.author,
            'Vidéo refusée',
            f'« {post.title} » : {post.rejection_reason}',
            link='/?view=videos',
            level='warning',
        )
        refreshed = self.get_queryset().filter(pk=post.pk).first()
        return Response(self.get_serializer(refreshed).data)

    @action(detail=True, methods=['post'])
    def feature(self, request, pk=None):
        post = self.get_object()
        post.is_featured = bool(request.data.get('featured', True))
        post.save(update_fields=['is_featured', 'updated_at'])
        refreshed = self.get_queryset().filter(pk=post.pk).first()
        return Response(self.get_serializer(refreshed).data)

    @action(detail=False, methods=['get'], url_path='pending')
    def pending_list(self, request):
        if not request.user.is_administrator:
            return Response(
                {'detail': 'Accès réservé aux administrateurs.'},
                status=403,
            )
        qs = annotate_post_engagement(
            VideoPost.objects.filter(
                status=VideoPost.Status.PENDING,
            ).select_related('author').order_by('-created_at'),
            request.user,
        )
        page = self.paginate_queryset(qs)
        ser = VideoPostSerializer(
            page if page is not None else qs,
            many=True,
            context={'request': request},
        )
        if page is not None:
            return self.get_paginated_response(ser.data)
        return Response(ser.data)


class VideoCommentViewSet(
    mixins.DestroyModelMixin,
    viewsets.GenericViewSet,
):
    """Suppression, like et modération des commentaires."""

    permission_classes = [VideoCommentPermission]
    serializer_class = VideoCommentSerializer
    queryset = VideoComment.objects.select_related('post', 'author')

    def get_queryset(self):
        return annotate_comment_engagement(
            super().get_queryset(),
            self.request.user,
        )

    @action(detail=True, methods=['post'], permission_classes=[IsAuthenticated])
    def toggle_like(self, request, pk=None):
        comment = self.get_object()
        if not user_can_view_post(comment.post, request.user):
            return Response({'detail': 'Publication inaccessible.'}, status=403)
        liked, count = toggle_comment_like(comment, request.user)
        if liked and comment.author_id != request.user.pk:
            who = request.user.get_full_name() or request.user.username
            notify_user(
                comment.author,
                'Like sur commentaire',
                f'{who} a aimé votre commentaire.',
                link=f'/?view=videos&video={comment.post_id}',
            )
        return Response({'liked': liked, 'like_count': count})

    @action(detail=True, methods=['post'], url_path='ai-check')
    def ai_check(self, request, pk=None):
        if not request.user.is_administrator:
            return Response({'detail': 'Admin requis.'}, status=403)
        from .extended_views import ai_moderation_hint
        comment = self.get_object()
        return Response(ai_moderation_hint(comment.text))

    @action(detail=True, methods=['post'])
    def hide(self, request, pk=None):
        if not request.user.is_administrator:
            return Response({'detail': 'Admin requis.'}, status=403)
        comment = self.get_object()
        comment.is_hidden = True
        comment.save(update_fields=['is_hidden'])
        return Response({'hidden': True})

    @action(detail=False, methods=['get'], url_path='moderation')
    def moderation_list(self, request):
        if not request.user.is_administrator:
            return Response({'detail': 'Admin requis.'}, status=403)
        qs = self.get_queryset().filter(is_hidden=False).order_by('-created_at')[:100]
        return Response(VideoCommentSerializer(qs, many=True).data)
