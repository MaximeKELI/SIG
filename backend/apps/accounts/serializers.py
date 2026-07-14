import os

from rest_framework import serializers
from rest_framework_gis.serializers import GeoFeatureModelSerializer

from .models import User, UserLocation

PROFILE_PHOTO_EXTENSIONS = {'.jpg', '.jpeg', '.png', '.webp', '.gif'}
PROFILE_PHOTO_MAX_BYTES = 5 * 1024 * 1024


class UserSerializer(serializers.ModelSerializer):
    profile_photo_url = serializers.SerializerMethodField()
    profile_stats = serializers.SerializerMethodField()

    class Meta:
        model = User
        fields = (
            'id', 'username', 'email', 'first_name', 'last_name',
            'role', 'organization', 'phone', 'pseudonym',
            'age', 'gender', 'city', 'region', 'profession',
            'education_level', 'motivation', 'consent_analytics',
            'bio', 'profile_photo_url', 'profile_stats', 'date_joined',
        )
        read_only_fields = ('id', 'date_joined', 'role', 'profile_photo_url', 'profile_stats')

    def get_profile_photo_url(self, obj):
        if obj.profile_photo:
            return obj.profile_photo.url
        return None

    def get_profile_stats(self, obj):
        from videos.models import VideoPost

        published = VideoPost.objects.filter(
            author=obj,
            status=VideoPost.Status.PUBLISHED,
        )
        return {
            'videos': published.filter(kind=VideoPost.Kind.VIDEO).count(),
            'shorts': published.filter(kind=VideoPost.Kind.SHORT).count(),
            'pending': VideoPost.objects.filter(
                author=obj,
                status=VideoPost.Status.PENDING,
            ).count(),
        }


class ProfilePhotoSerializer(serializers.Serializer):
    profile_photo = serializers.ImageField(required=False)

    def to_internal_value(self, data):
        # Compat mobile/web : profile_photo | photo | file | image
        mutable = {}
        if hasattr(data, 'items'):
            mutable = {k: v for k, v in data.items()}
        else:
            mutable = dict(data)
        raw = (
            mutable.get('profile_photo')
            or mutable.get('photo')
            or mutable.get('file')
            or mutable.get('image')
        )
        if raw is not None:
            mutable['profile_photo'] = raw
        return super().to_internal_value(mutable)

    def validate(self, attrs):
        if not attrs.get('profile_photo'):
            raise serializers.ValidationError({
                'profile_photo': 'Image requise (champ profile_photo, photo ou file).',
            })
        return attrs

    def validate_profile_photo(self, file_obj):
        if file_obj is None:
            return file_obj
        ext = os.path.splitext(file_obj.name or '')[1].lower()
        if ext not in PROFILE_PHOTO_EXTENSIONS:
            raise serializers.ValidationError(
                'Formats acceptés : jpg, png, webp, gif.',
            )
        if file_obj.size > PROFILE_PHOTO_MAX_BYTES:
            raise serializers.ValidationError('Image trop volumineuse (max 5 Mo).')
        return file_obj

    def save(self, user):
        photo = self.validated_data['profile_photo']
        if user.profile_photo:
            user.profile_photo.delete(save=False)
        user.profile_photo = photo
        user.save(update_fields=['profile_photo'])
        return user


class UserRegistrationSerializer(serializers.ModelSerializer):
    password = serializers.CharField(write_only=True, min_length=8)
    password_confirm = serializers.CharField(write_only=True, min_length=8)

    class Meta:
        model = User
        fields = (
            'username', 'email', 'password', 'password_confirm',
            'first_name', 'last_name', 'age', 'phone',
            'role', 'organization', 'pseudonym',
            'gender', 'city', 'region', 'profession',
            'education_level', 'motivation', 'consent_analytics',
        )

    def validate(self, attrs):
        if attrs['password'] != attrs['password_confirm']:
            raise serializers.ValidationError({
                'password_confirm': 'Les mots de passe ne correspondent pas.',
            })
        role = attrs.get('role', User.Role.PUBLIC)
        if role == User.Role.ADMIN:
            attrs['role'] = User.Role.PUBLIC
        age = attrs.get('age')
        if age is None or age < 13 or age > 120:
            raise serializers.ValidationError({'age': 'Âge requis (13–120 ans).'})
        if not attrs.get('first_name', '').strip():
            raise serializers.ValidationError({'first_name': 'Le prénom est requis.'})
        if not attrs.get('last_name', '').strip():
            raise serializers.ValidationError({'last_name': 'Le nom est requis.'})
        if not attrs.get('email', '').strip():
            raise serializers.ValidationError({'email': 'L’email est requis.'})
        if not attrs.get('consent_analytics'):
            raise serializers.ValidationError({
                'consent_analytics': 'Vous devez accepter le suivi statistique anonymisé.',
            })
        return attrs

    def create(self, validated_data):
        validated_data.pop('password_confirm')
        password = validated_data.pop('password')
        user = User(**validated_data)
        user.set_password(password)
        user.save()
        return user


class ChangePasswordSerializer(serializers.Serializer):
    old_password = serializers.CharField(write_only=True)
    new_password = serializers.CharField(write_only=True, min_length=8)
    new_password_confirm = serializers.CharField(write_only=True, min_length=8)

    def validate(self, attrs):
        if attrs['new_password'] != attrs['new_password_confirm']:
            raise serializers.ValidationError({
                'new_password_confirm': 'Les mots de passe ne correspondent pas.',
            })
        return attrs


class UserLocationUpdateSerializer(serializers.Serializer):
    lat = serializers.FloatField(min_value=-90, max_value=90)
    lon = serializers.FloatField(min_value=-180, max_value=180)
    accuracy_m = serializers.FloatField(required=False, allow_null=True, min_value=0)
    heading = serializers.FloatField(required=False, allow_null=True, min_value=0, max_value=360)
    is_sharing = serializers.BooleanField(required=False, default=True)


class UserLocationSerializer(serializers.ModelSerializer):
    user_id = serializers.IntegerField(source='user.id', read_only=True)
    username = serializers.CharField(source='user.username', read_only=True)
    display_name = serializers.CharField(source='user.display_name', read_only=True)
    role = serializers.CharField(source='user.role', read_only=True)
    profile_photo_url = serializers.SerializerMethodField()
    lat = serializers.SerializerMethodField()
    lon = serializers.SerializerMethodField()

    class Meta:
        model = UserLocation
        fields = (
            'user_id', 'username', 'display_name', 'role', 'profile_photo_url',
            'lat', 'lon', 'accuracy_m', 'heading', 'is_sharing', 'updated_at',
        )

    def get_profile_photo_url(self, obj):
        if obj.user.profile_photo:
            return obj.user.profile_photo.url
        return None

    def get_lat(self, obj):
        return obj.location.y

    def get_lon(self, obj):
        return obj.location.x


class UserLocationGeoSerializer(GeoFeatureModelSerializer):
    display_name = serializers.CharField(source='user.display_name', read_only=True)
    role = serializers.CharField(source='user.role', read_only=True)

    class Meta:
        model = UserLocation
        geo_field = 'location'
        fields = (
            'user', 'display_name', 'role',
            'accuracy_m', 'heading', 'is_sharing', 'updated_at',
        )
