from django.urls import path

from .export_views import AdminExportActivityCSVView, AdminExportUsersCSVView
from .features import (
    AlertsNearMeView,
    BulkUserImportView,
    GlobalSearchView,
    MinistryReportView,
    ModerationJournalView,
    NotificationMarkAllReadView,
    NotificationUnreadCountView,
    PersonalDashboardView,
)
from .views import (
    ActivityIngestView,
    ActivityListView,
    AdminCockpitView,
    AdminDashboardView,
    AnalyticsSummaryView,
    AuditLogListView,
    DroughtAlertListView,
    NotificationListView,
    NotificationMarkReadView,
    PasswordResetConfirmView,
    PasswordResetRequestView,
    UserActivityDetailView,
    ZoneReportView,
)

urlpatterns = [
    path('admin/dashboard/', AdminDashboardView.as_view(), name='admin-dashboard'),
    path('admin/cockpit/', AdminCockpitView.as_view(), name='admin-cockpit'),
    path('admin/analytics/', AnalyticsSummaryView.as_view(), name='admin-analytics'),
    path('admin/activity/', ActivityListView.as_view(), name='admin-activity-list'),
    path('admin/activity/users/<int:user_id>/', UserActivityDetailView.as_view(), name='admin-activity-user'),
    path('activity/', ActivityIngestView.as_view(), name='activity-ingest'),
    path('notifications/', NotificationListView.as_view(), name='notifications'),
    path('notifications/unread-count/', NotificationUnreadCountView.as_view(), name='notifications-unread'),
    path('notifications/mark-all-read/', NotificationMarkAllReadView.as_view(), name='notifications-mark-all'),
    path('notifications/<int:pk>/read/', NotificationMarkReadView.as_view(), name='notification-read'),
    path('search/', GlobalSearchView.as_view(), name='global-search'),
    path('me/dashboard/', PersonalDashboardView.as_view(), name='personal-dashboard'),
    path('moderation/journal/', ModerationJournalView.as_view(), name='moderation-journal'),
    path('reports/ministry/', MinistryReportView.as_view(), name='ministry-report'),
    path('admin/import/users/', BulkUserImportView.as_view(), name='admin-import-users'),
    path('alerts/near/', AlertsNearMeView.as_view(), name='alerts-near'),
    path('alerts/drought/', DroughtAlertListView.as_view(), name='drought-alerts'),
    path('audit/', AuditLogListView.as_view(), name='audit-log'),
    path('password/reset/', PasswordResetRequestView.as_view(), name='password-reset'),
    path('password/reset/confirm/', PasswordResetConfirmView.as_view(), name='password-reset-confirm'),
    path('reports/zone/<str:zone_code>/', ZoneReportView.as_view(), name='zone-report'),
    path('admin/export/users.csv', AdminExportUsersCSVView.as_view(), name='admin-export-users'),
    path('admin/export/activity.csv', AdminExportActivityCSVView.as_view(), name='admin-export-activity'),
]
