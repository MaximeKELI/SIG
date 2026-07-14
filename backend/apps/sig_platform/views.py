from datetime import timedelta

from django.conf import settings
from django.contrib.auth import get_user_model
from django.core.mail import send_mail
from django.http import HttpResponse
from django.template.loader import render_to_string
from django.db.models import Avg
from django.utils import timezone
from rest_framework import generics
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from accounts.permissions import IsAdministrator
from config.admin_large_table import pg_table_row_estimate
from soils.models import AdministrativeZone, SoilPoint

from .models import AuditLog, DroughtAlert, Notification, PasswordResetToken, UserActivityEvent
from .serializers import (
    ActivityBatchSerializer,
    AuditLogSerializer,
    DroughtAlertSerializer,
    NotificationSerializer,
    PasswordResetConfirmSerializer,
    PasswordResetRequestSerializer,
    UserActivityEventSerializer,
)
from .activity import analytics_summary, ingest_activity_events, user_activity_summary

User = get_user_model()


class AdminDashboardView(APIView):
    permission_classes = [IsAdministrator]

    def get(self, request):
        from accounts.models import UserLocation
        from nasa.models import NasaLayerCatalog
        from ml_predict.models import FertilityModelRun

        users_est = pg_table_row_estimate(User)
        users_total = users_est if users_est is not None else User.objects.count()
        users_active = User.objects.filter(is_active=True).count()
        if users_est is not None and users_active > users_total:
            users_active = users_total

        return Response({
            'users_total': users_total,
            'users_total_estimated': users_est is not None,
            'users_active': users_active,
            'soil_points': SoilPoint.objects.count(),
            'pending_validation': SoilPoint.objects.filter(
                validation_status=SoilPoint.ValidationStatus.PENDING,
            ).count(),
            'live_agents': UserLocation.objects.filter(
                updated_at__gte=timezone.now() - timedelta(minutes=5),
                is_sharing=True,
            ).count(),
            'nasa_layers': NasaLayerCatalog.objects.count(),
            'active_alerts': DroughtAlert.objects.filter(is_active=True).count(),
            'ml_model': FertilityModelRun.objects.filter(is_active=True).values(
                'algorithm', 'f1_macro', 'trained_at',
            ).first(),
            'recent_audit': AuditLogSerializer(
                AuditLog.objects.all()[:15], many=True,
            ).data,
        })


class AdminCockpitView(APIView):
    """Cockpit admin unifié — stats + files + activité (web + mobile)."""

    permission_classes = [IsAdministrator]

    def get(self, request):
        from django.db.models import Count

        from accounts.models import UserLocation
        from accounts.serializers import UserSerializer
        from education.models import QuizSession
        from ml_predict.models import FertilityModelRun
        from nasa.models import NasaLayerCatalog
        from videos.models import VideoComment, VideoPost
        from videos.serializers import VideoCommentSerializer, VideoPostSerializer
        from soils.serializers import SoilPointListSerializer

        days = min(int(request.query_params.get('days', 30)), 365)
        since = timezone.now() - timedelta(days=days)
        live_cutoff = timezone.now() - timedelta(minutes=5)

        users_total = User.objects.count()
        users_active = User.objects.filter(is_active=True).count()
        users_by_role = list(
            User.objects.values('role').annotate(count=Count('id')).order_by('role'),
        )
        recent_users = User.objects.order_by('-date_joined')[:25]

        pending_soils_qs = SoilPoint.objects.filter(
            validation_status=SoilPoint.ValidationStatus.PENDING,
        ).select_related('created_by', 'zone').order_by('-created_at')
        pending_videos_qs = VideoPost.objects.filter(
            status=VideoPost.Status.PENDING,
        ).select_related('author').order_by('-created_at')
        comments_qs = VideoComment.objects.filter(
            is_hidden=False,
        ).select_related('author', 'post').order_by('-created_at')

        validated_points = SoilPoint.objects.filter(is_validated=True)
        soil_stats = {
            'total_points': validated_points.count(),
            'avg_ph': round(
                validated_points.aggregate(v=Avg('ph'))['v'] or 0, 2,
            ),
            'avg_humidity': round(
                validated_points.aggregate(v=Avg('humidity_pct'))['v'] or 0, 2,
            ),
            'avg_ndvi': round(
                validated_points.aggregate(v=Avg('ndvi_3m_avg'))['v'] or 0, 3,
            ),
            'by_soil_type': list(
                validated_points.values('soil_type')
                .annotate(count=Count('id'))
                .order_by('-count')[:12],
            ),
            'degraded_zones_count': AdministrativeZone.objects.filter(
                zone_type='degraded',
            ).count(),
            'fertility_distribution': list(
                validated_points.exclude(fertility_class='')
                .values('fertility_class')
                .annotate(count=Count('id')),
            ),
        }

        live_qs = UserLocation.objects.filter(
            updated_at__gte=live_cutoff,
            is_sharing=True,
        ).select_related('user').order_by('-updated_at')[:50]
        alerts_qs = DroughtAlert.objects.filter(is_active=True).select_related(
            'soil_point', 'zone',
        )[:50]

        analytics = analytics_summary(days=days)
        audit = AuditLog.objects.select_related('user').all()[:50]
        activity = UserActivityEvent.objects.select_related('user').all()[:40]

        videos_published = VideoPost.objects.filter(
            status=VideoPost.Status.PUBLISHED,
        ).count()
        videos_period = VideoPost.objects.filter(created_at__gte=since).count()
        quizzes_completed = QuizSession.objects.filter(
            completed=True, finished_at__gte=since,
        ).count()

        overview = {
            'period_days': days,
            'users_total': users_total,
            'users_active': users_active,
            'users_by_role': users_by_role,
            'soil_points': SoilPoint.objects.count(),
            'pending_validation': pending_soils_qs.count(),
            'pending_videos': pending_videos_qs.count(),
            'comments_visible': comments_qs.count(),
            'videos_published': videos_published,
            'videos_created_period': videos_period,
            'quizzes_completed_period': quizzes_completed,
            'live_agents': live_qs.count(),
            'active_alerts': DroughtAlert.objects.filter(is_active=True).count(),
            'nasa_layers': NasaLayerCatalog.objects.count(),
            'events_total': analytics.get('events_total'),
            'events_today': analytics.get('events_today'),
            'map_zoom_total': analytics.get('map_zoom_total'),
            'map_pan_total': analytics.get('map_pan_total'),
            'ml_model': FertilityModelRun.objects.filter(is_active=True).values(
                'algorithm', 'f1_macro', 'trained_at',
            ).first(),
        }

        return Response({
            'overview': overview,
            'soil_stats': soil_stats,
            'queues': {
                'pending_soils': SoilPointListSerializer(
                    pending_soils_qs[:40], many=True,
                ).data,
                'pending_videos': VideoPostSerializer(
                    pending_videos_qs[:40],
                    many=True,
                    context={'request': request},
                ).data,
                'comments': VideoCommentSerializer(
                    comments_qs[:40],
                    many=True,
                    context={'request': request},
                ).data,
            },
            'users': {
                'by_role': users_by_role,
                'recent': UserSerializer(recent_users, many=True).data,
            },
            'analytics': analytics,
            'terrain': {
                'live_agents': [
                    {
                        'user_id': loc.user_id,
                        'username': loc.user.username,
                        'display_name': (
                            loc.user.get_full_name() or loc.user.username
                        ),
                        'role': loc.user.role,
                        'lat': loc.location.y if loc.location else None,
                        'lon': loc.location.x if loc.location else None,
                        'updated_at': loc.updated_at,
                    }
                    for loc in live_qs
                ],
                'drought_alerts': DroughtAlertSerializer(
                    alerts_qs, many=True,
                ).data,
            },
            'audit': AuditLogSerializer(audit, many=True).data,
            'activity_recent': UserActivityEventSerializer(
                activity, many=True,
            ).data,
        })


class NotificationListView(generics.ListAPIView):
    serializer_class = NotificationSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        return Notification.objects.filter(user=self.request.user)[:50]


class NotificationMarkReadView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request, pk):
        n = Notification.objects.filter(user=request.user, pk=pk).first()
        if not n:
            return Response({'error': 'Introuvable'}, status=404)
        n.is_read = True
        n.save(update_fields=['is_read'])
        return Response({'ok': True})


class DroughtAlertListView(generics.ListAPIView):
    queryset = DroughtAlert.objects.filter(is_active=True).select_related(
        'soil_point', 'zone',
    )[:100]
    serializer_class = DroughtAlertSerializer
    permission_classes = [IsAuthenticated]


class AuditLogListView(generics.ListAPIView):
    queryset = AuditLog.objects.select_related('user').all()[:200]
    serializer_class = AuditLogSerializer
    permission_classes = [IsAdministrator]


class ActivityIngestView(APIView):
    """Réception des événements front (carte, navigation, quiz…)."""
    permission_classes = [AllowAny]

    def post(self, request):
        ser = ActivityBatchSerializer(data=request.data)
        ser.is_valid(raise_exception=True)
        user = request.user if request.user.is_authenticated else None
        if user and not user.consent_analytics:
            return Response({'accepted': 0, 'detail': 'Consentement analytics absent.'})
        ip = request.META.get('HTTP_X_FORWARDED_FOR', '').split(',')[0].strip() or request.META.get('REMOTE_ADDR')
        ua = request.META.get('HTTP_USER_AGENT', '')
        n = ingest_activity_events(
            user,
            ser.validated_data['session_id'],
            ser.validated_data['events'],
            ip=ip or None,
            user_agent=ua,
        )
        return Response({'accepted': n})


class ActivityListView(generics.ListAPIView):
    serializer_class = UserActivityEventSerializer
    permission_classes = [IsAdministrator]

    def get_queryset(self):
        qs = UserActivityEvent.objects.select_related('user').all()
        uid = self.request.query_params.get('user_id')
        et = self.request.query_params.get('event_type')
        if uid:
            qs = qs.filter(user_id=uid)
        if et:
            qs = qs.filter(event_type=et)
        limit = min(int(self.request.query_params.get('limit', 200)), 1000)
        return qs[:limit]


class AnalyticsSummaryView(APIView):
    permission_classes = [IsAdministrator]

    def get(self, request):
        days = min(int(request.query_params.get('days', 30)), 365)
        return Response(analytics_summary(days=days))


class UserActivityDetailView(APIView):
    permission_classes = [IsAdministrator]

    def get(self, request, user_id):
        days = min(int(request.query_params.get('days', 90)), 365)
        return Response(user_activity_summary(user_id, days=days))


class PasswordResetRequestView(APIView):
    permission_classes = [AllowAny]

    def post(self, request):
        ser = PasswordResetRequestSerializer(data=request.data)
        ser.is_valid(raise_exception=True)
        email = ser.validated_data['email']
        user = User.objects.filter(email__iexact=email).first()
        if user:
            prt = PasswordResetToken.create_for_user(user)
            reset_url = (
                f'{request.build_absolute_uri("/frontend/reset-password.html")}'
                f'?token={prt.token}'
            )
            send_mail(
                subject='SIG Sols Togo — Réinitialisation mot de passe',
                message=f'Utilisez ce lien (24 h): {reset_url}',
                from_email=settings.DEFAULT_FROM_EMAIL,
                recipient_list=[user.email],
                fail_silently=True,
            )
        return Response({
            'detail': 'Si un compte existe, un email a été envoyé.',
        })


class PasswordResetConfirmView(APIView):
    permission_classes = [AllowAny]

    def post(self, request):
        ser = PasswordResetConfirmSerializer(data=request.data)
        ser.is_valid(raise_exception=True)
        prt = PasswordResetToken.objects.filter(
            token=ser.validated_data['token'], used=False,
        ).first()
        if not prt or not prt.is_valid():
            return Response({'error': 'Token invalide ou expiré.'}, status=400)
        prt.user.set_password(ser.validated_data['new_password'])
        prt.user.save()
        prt.used = True
        prt.save(update_fields=['used'])
        return Response({'detail': 'Mot de passe réinitialisé.'})


class ZoneReportView(APIView):
    """Rapport HTML zone (impression PDF via navigateur)."""

    permission_classes = [IsAuthenticated]

    def get(self, request, zone_code):
        zone = AdministrativeZone.objects.filter(code=zone_code).first()
        if not zone:
            return Response({'error': 'Zone introuvable'}, status=404)
        points = SoilPoint.objects.filter(zone=zone, is_validated=True)
        html = render_to_string('reports/zone_report.html', {
            'zone': zone,
            'points': points[:500],
            'point_count': points.count(),
            'avg_ph': points.aggregate(v=Avg('ph'))['v'] if points.exists() else None,
            'generated_at': timezone.now(),
        })
        return HttpResponse(html)
