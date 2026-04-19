from rest_framework.permissions import BasePermission, SAFE_METHODS


class IsAdmin(BasePermission):
    """Only admin users."""

    def has_permission(self, request, view):
        return request.user.is_authenticated and request.user.role == "admin"


class IsAgentOrAdmin(BasePermission):
    """Agents and admins."""

    def has_permission(self, request, view):
        return (
            request.user.is_authenticated
            and request.user.role in ("agent", "admin")
        )


class IsOwnerOrStaff(BasePermission):
    """
    Object-level permission.
    - Admin / Agent: full access.
    - Client: can only access their own objects (obj.user == request.user).
    """

    def has_permission(self, request, view):
        return request.user.is_authenticated

    def has_object_permission(self, request, view, obj):
        if request.user.role in ("admin", "agent"):
            return True
        return obj.user == request.user


class IsAdminOrReadOnly(BasePermission):
    """Safe methods (GET, HEAD, OPTIONS) for all; write methods for admin only."""

    def has_permission(self, request, view):
        if request.method in SAFE_METHODS:
            return request.user.is_authenticated
        return request.user.is_authenticated and request.user.role == "admin"
