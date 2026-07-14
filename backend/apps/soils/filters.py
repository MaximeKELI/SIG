import django_filters
from django.contrib.gis.geos import Polygon

from .models import SoilPoint


class SoilPointFilter(django_filters.FilterSet):
    ph_min = django_filters.NumberFilter(field_name='ph', lookup_expr='gte')
    ph_max = django_filters.NumberFilter(field_name='ph', lookup_expr='lte')
    soil_type = django_filters.CharFilter(field_name='soil_type')
    fertility_class = django_filters.CharFilter(field_name='fertility_class')
    collected_after = django_filters.DateFilter(field_name='collected_at', lookup_expr='gte')
    collected_before = django_filters.DateFilter(field_name='collected_at', lookup_expr='lte')
    is_validated = django_filters.BooleanFilter(field_name='is_validated')
    validation_status = django_filters.CharFilter(field_name='validation_status')
    bbox = django_filters.CharFilter(method='filter_bbox')

    class Meta:
        model = SoilPoint
        fields = ['soil_type', 'fertility_class', 'is_validated', 'validation_status', 'zone']

    def filter_bbox(self, queryset, _name, value):
        """bbox=min_lon,min_lat,max_lon,max_lat (WGS84) — chargement carte par fenêtre."""
        try:
            parts = [float(x.strip()) for x in value.split(',')]
            if len(parts) != 4:
                return queryset
            min_lon, min_lat, max_lon, max_lat = parts
            poly = Polygon.from_bbox((min_lon, min_lat, max_lon, max_lat))
            poly.srid = 4326
            return queryset.filter(location__within=poly)
        except (ValueError, TypeError):
            return queryset
