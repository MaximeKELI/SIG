from django.contrib.auth import get_user_model
from django.utils import timezone
from rest_framework import generics, status
from rest_framework.parsers import FormParser, JSONParser, MultiPartParser
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework_simplejwt.views import TokenObtainPairView

from .permissions import IsAdministrator
from .serializers import (
    ChangePasswordSerializer,
    ProfilePhotoSerializer,
    UserLocationSerializer,
    UserLocationUpdateSerializer,
    UserRegistrationSerializer,
    UserSerializer,
)
from config.pagination import LargeTableCursorPagination
from config.throttling import AuthAnonThrottle, LocationUserThrottle

from .location_cache import get_cached_live_locations
from .tokens import CustomTokenObtainPairSerializer
from .models import UserLocation
from .services import upsert_user_location

User = get_user_model()


class RegisterView(generics.CreateAPIView):
    queryset = User.objects.all()
    serializer_class = UserRegistrationSerializer
    permission_classes = [AllowAny]
    throttle_classes = [AuthAnonThrottle]

    def create(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        user = serializer.save()
        return Response({
            'user': UserSerializer(user).data,
            'detail': 'Compte créé. Connectez-vous avec vos identifiants.',
        }, status=status.HTTP_201_CREATED)


class ProfileView(generics.RetrieveUpdateAPIView):
    serializer_class = UserSerializer
    permission_classes = [IsAuthenticated]
    parser_classes = [JSONParser, MultiPartParser, FormParser]

    def get_object(self):
        return self.request.user


class ProfilePhotoView(APIView):
    """Téléverser ou supprimer la photo de profil."""

    permission_classes = [IsAuthenticated]
    parser_classes = [MultiPartParser, FormParser]

    def post(self, request):
        ser = ProfilePhotoSerializer(data=request.data)
        ser.is_valid(raise_exception=True)
        ser.save(request.user)
        return Response(UserSerializer(request.user).data)

    def delete(self, request):
        user = request.user
        if user.profile_photo:
            user.profile_photo.delete(save=False)
            user.profile_photo = None
            user.save(update_fields=['profile_photo'])
        return Response(UserSerializer(user).data)


class UserListView(generics.ListAPIView):
    queryset = User.objects.only(
        'id', 'username', 'email', 'role', 'organization', 'is_active', 'date_joined',
    ).order_by('id')
    serializer_class = UserSerializer
    permission_classes = [IsAdministrator]
    pagination_class = LargeTableCursorPagination


class TokenObtainView(TokenObtainPairView):
    permission_classes = [AllowAny]
    serializer_class = CustomTokenObtainPairSerializer


class ChangePasswordView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        ser = ChangePasswordSerializer(data=request.data)
        ser.is_valid(raise_exception=True)
        if not request.user.check_password(ser.validated_data['old_password']):
            return Response(
                {'old_password': ['Mot de passe actuel incorrect.']},
                status=status.HTTP_400_BAD_REQUEST,
            )
        request.user.set_password(ser.validated_data['new_password'])
        request.user.save()
        return Response({'detail': 'Mot de passe mis à jour.'})


class LogoutView(APIView):
    """Invalide le refresh token (blacklist) ; le client doit aussi jeter l'access."""

    permission_classes = [IsAuthenticated]

    def post(self, request):
        from rest_framework_simplejwt.exceptions import TokenError
        from rest_framework_simplejwt.tokens import RefreshToken

        refresh = request.data.get('refresh')
        if refresh:
            try:
                token = RefreshToken(refresh)
                token.blacklist()
            except TokenError:
                pass
        return Response({'detail': 'Déconnexion réussie.'}, status=status.HTTP_200_OK)


class MyLocationView(APIView):
    """Publier / mettre à jour sa position GPS (temps réel)."""

    permission_classes = [IsAuthenticated]
    throttle_classes = [LocationUserThrottle]

    def get(self, request):
        loc = getattr(request.user, 'live_location', None)
        if not loc:
            return Response({'detail': 'Aucune position enregistrée.'}, status=404)
        return Response(UserLocationSerializer(loc).data)

    def post(self, request):
        ser = UserLocationUpdateSerializer(data=request.data)
        ser.is_valid(raise_exception=True)
        data = ser.validated_data
        try:
            loc = upsert_user_location(
                request.user,
                data['lon'],
                data['lat'],
                accuracy_m=data.get('accuracy_m'),
                heading=data.get('heading'),
                is_sharing=data.get('is_sharing', True),
            )
        except ValueError as exc:
            return Response({'error': str(exc)}, status=400)
        if data.get('is_sharing', True):
            from .ws_broadcast import broadcast_live_location

            broadcast_live_location(
                user=request.user,
                lat=data['lat'],
                lon=data['lon'],
            )
        return Response(UserLocationSerializer(loc).data, status=status.HTTP_200_OK)

    def delete(self, request):
        UserLocation.objects.filter(user=request.user).delete()
        return Response(status=status.HTTP_204_NO_CONTENT)


class UserTrajectoryView(APIView):
    """Historique GPS d'un utilisateur (trajectoire journée)."""

    permission_classes = [IsAuthenticated]

    def get(self, request, user_id=None):
        from .models import UserLocationHistory
        uid = user_id or request.user.pk
        if uid != request.user.pk and not request.user.is_administrator:
            return Response({'error': 'Non autorisé'}, status=403)
        from datetime import timedelta

        hours = int(request.query_params.get('hours', 24))
        since = timezone.now() - timedelta(hours=hours)
        trail = UserLocationHistory.objects.filter(
            user_id=uid, recorded_at__gte=since,
        ).order_by('recorded_at')[:500]
        return Response({
            'user_id': uid,
            'points': [
                {
                    'lat': h.location.y,
                    'lon': h.location.x,
                    'recorded_at': h.recorded_at.isoformat(),
                }
                for h in trail
            ],
        })


class LiveLocationsView(APIView):
    """Positions partagées des utilisateurs actifs (agents sur le terrain)."""

    permission_classes = [IsAuthenticated]

    def get(self, request):
        include_self = request.query_params.get('include_self', '0') == '1'
        exclude = None if include_self else request.user
        return Response(get_cached_live_locations(exclude_user=exclude))
