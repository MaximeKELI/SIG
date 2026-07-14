from rest_framework.permissions import SAFE_METHODS, BasePermission

from .models import User


class IsAdministrator(BasePermission):
    def has_permission(self, request, view):
        user = request.user
        if not isinstance(user, User) or not user.is_authenticated:
            return False
        return user.is_administrator


class IsAgentOrAdmin(BasePermission):
    def has_permission(self, request, view):
        user = request.user
        if not isinstance(user, User) or not user.is_authenticated:
            return False
        return user.is_agent


class IsAgentOrAdminOrReadOnly(BasePermission):
    """Lecture publique ; écriture réservée Agent / Admin (TdR)."""

    def has_permission(self, request, view):
        if request.method in SAFE_METHODS:
            return True
        user = request.user
        if not isinstance(user, User) or not user.is_authenticated:
            return False
        return user.is_agent
