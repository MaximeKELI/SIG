"""Vues étendues : validation, notes, heatmap, comparaison."""
from rest_framework import viewsets
from rest_framework.permissions import IsAuthenticated, IsAuthenticatedOrReadOnly
from rest_framework.response import Response
from rest_framework.views import APIView

from accounts.permissions import IsAdministrator

from .models import SoilPoint, SoilPointNote
from .serializers_notes import SoilPointNoteSerializer


class SoilPointNoteViewSet(viewsets.ModelViewSet):
    serializer_class = SoilPointNoteSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        qs = SoilPointNote.objects.select_related('author', 'soil_point')
        point_id = self.request.query_params.get('soil_point')
        if point_id:
            qs = qs.filter(soil_point_id=point_id)
        return qs.order_by('created_at')

    def perform_create(self, serializer):
        serializer.save(author=self.request.user)


class SoilPointPairCompareView(APIView):
    """Compare deux points par identifiants ?a=&b="""

    permission_classes = [IsAuthenticatedOrReadOnly]

    def get(self, request):
        a_id = request.query_params.get('a')
        b_id = request.query_params.get('b')
        if not a_id or not b_id:
            return Response({'error': 'Paramètres a et b requis'}, status=400)
        pa = SoilPoint.objects.filter(pk=a_id).first()
        pb = SoilPoint.objects.filter(pk=b_id).first()
        if not pa or not pb:
            return Response({'error': 'Point introuvable'}, status=404)
        from django.contrib.gis.db.models.functions import Distance
        dist = (
            SoilPoint.objects.filter(pk=pa.pk)
            .annotate(d=Distance('location', pb.location))
            .values_list('d', flat=True)
            .first()
        )
        return Response({
            'point_a': {'id': pa.id, 'ph': pa.ph, 'ndvi_3m_avg': pa.ndvi_3m_avg, 'soil_type': pa.soil_type},
            'point_b': {'id': pb.id, 'ph': pb.ph, 'ndvi_3m_avg': pb.ndvi_3m_avg, 'soil_type': pb.soil_type},
            'delta_ph': round(pa.ph - pb.ph, 2),
            'distance_m': round(dist.m, 1) if dist else None,
        })


class SoilPointPairCompareView(APIView):
    """Compare deux points par identifiant (?a=1&b=2)."""

    permission_classes = [IsAuthenticatedOrReadOnly]

    def get(self, request):
        from django.contrib.gis.db.models.functions import Distance

        a_id = request.query_params.get('a') or request.query_params.get('other_id')
        b_id = request.query_params.get('b')
        if not a_id or not b_id:
            return Response({'error': 'Paramètres a et b requis'}, status=400)
        pa = SoilPoint.objects.filter(pk=a_id).first()
        pb = SoilPoint.objects.filter(pk=b_id).first()
        if not pa or not pb:
            return Response({'error': 'Point introuvable'}, status=404)
        dist = (
            SoilPoint.objects.filter(pk=pa.pk)
            .annotate(d=Distance('location', pb.location))
            .values_list('d', flat=True)
            .first()
        )
        return Response({
            'point_a': {'id': pa.id, 'ph': pa.ph, 'ndvi_3m_avg': pa.ndvi_3m_avg, 'soil_type': pa.soil_type},
            'point_b': {'id': pb.id, 'ph': pb.ph, 'ndvi_3m_avg': pb.ndvi_3m_avg, 'soil_type': pb.soil_type},
            'delta_ph': round(pa.ph - pb.ph, 2),
            'distance_m': round(dist.m, 1) if dist else None,
        })


class SoilPointCompareView(APIView):
    permission_classes = [IsAuthenticatedOrReadOnly]

    def get(self, request, pk):
        point = SoilPoint.objects.filter(pk=pk).first()
        if not point:
            return Response({'error': 'Point introuvable'}, status=404)
        follow_ups = SoilPoint.objects.filter(parent_point=point).order_by('collected_at')
        history = list(
            SoilPoint.objects.filter(pk=point.pk).values(
                'id', 'ph', 'humidity_pct', 'ndvi_3m_avg', 'collected_at', 'validation_status',
            ),
        ) + list(follow_ups.values(
            'id', 'ph', 'humidity_pct', 'ndvi_3m_avg', 'collected_at', 'validation_status',
        ))
        return Response({'point_id': pk, 'history': history})


class HeatmapDataView(APIView):
    permission_classes = [IsAuthenticatedOrReadOnly]

    def get(self, request):
        field = request.query_params.get('field', 'ph')
        allowed = {'ph', 'humidity_pct', 'ndvi_3m_avg', 'fertility_score'}
        if field not in allowed:
            field = 'ph'
        points = SoilPoint.objects.filter(is_validated=True).exclude(
            **{f'{field}__isnull': True},
        )[:2000]
        data = [
            [p.location.y, p.location.x, getattr(p, field) or 0]
            for p in points
        ]
        return Response({'field': field, 'points': data})


class PendingValidationView(APIView):
    permission_classes = [IsAdministrator]

    def get(self, request):
        base = SoilPoint.objects.filter(
            validation_status=SoilPoint.ValidationStatus.PENDING,
        ).order_by('-created_at')
        total = base.count()
        page = list(base[:100])
        from .serializers import SoilPointListSerializer
        return Response({
            'count': total,
            'results': SoilPointListSerializer(page, many=True).data,
        })
