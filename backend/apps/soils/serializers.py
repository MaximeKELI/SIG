from rest_framework import serializers
from rest_framework_gis.serializers import GeoFeatureModelSerializer

from .models import AdministrativeZone, SoilPoint, SoilPointNasaSnapshot
from .validators import validate_soil_point_quality


class AdministrativeZoneSerializer(GeoFeatureModelSerializer):
    class Meta:
        model = AdministrativeZone
        geo_field = 'geometry'
        fields = (
            'id', 'name', 'code', 'zone_type', 'parent',
            'metadata', 'created_at', 'updated_at',
        )


class SoilPointSerializer(GeoFeatureModelSerializer):
    ph_color = serializers.ReadOnlyField()
    nasa_snapshots = serializers.SerializerMethodField()

    class Meta:
        model = SoilPoint
        geo_field = 'location'
        fields = (
            'id', 'location', 'ph', 'humidity_pct', 'soil_type',
            'fertility_class', 'fertility_score', 'photo', 'slope_pct',
            'ndvi_3m_avg', 'smap_moisture_avg', 'elevation_m', 'notes',
            'source', 'producer', 'collected_at', 'zone', 'is_validated',
            'validation_status', 'parent_point', 'ph_color', 'nasa_snapshots',
            'created_at',
        )
        read_only_fields = ('created_at', 'ph_color', 'validation_status')

    def get_nasa_snapshots(self, obj):
        qs = obj.nasa_snapshots.order_by('-observed_at')[:12]
        return SoilPointNasaSnapshotSerializer(qs, many=True).data

    def validate(self, attrs):
        instance = self.instance
        data = {**attrs}
        if instance:
            for f in ['ph', 'humidity_pct', 'soil_type', 'location']:
                if f not in data:
                    data[f] = getattr(instance, f)
        errors = validate_soil_point_quality(data)
        if errors:
            raise serializers.ValidationError(errors)
        return attrs


class SoilPointNasaSnapshotSerializer(serializers.ModelSerializer):
    class Meta:
        model = SoilPointNasaSnapshot
        fields = '__all__'


class SoilPointListSerializer(serializers.ModelSerializer):
    """Lightweight list for map performance (<2s for 500 points)."""
    ph_color = serializers.ReadOnlyField()
    lat = serializers.SerializerMethodField()
    lon = serializers.SerializerMethodField()

    class Meta:
        model = SoilPoint
        fields = (
            'id', 'ph', 'humidity_pct', 'soil_type', 'ph_color',
            'fertility_class', 'lat', 'lon', 'ndvi_3m_avg', 'smap_moisture_avg',
            # Statut validation — requis carte web/mobile (popup + filtres)
            'is_validated', 'validation_status',
        )

    def get_lat(self, obj):
        return obj.location.y

    def get_lon(self, obj):
        return obj.location.x
