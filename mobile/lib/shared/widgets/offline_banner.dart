import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/i18n/locale_service.dart';
import '../../core/offline/offline_sync_service.dart';
import '../../core/theme/app_theme.dart';

class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final sync = context.watch<OfflineSyncService>();
    final i18n = context.watch<LocaleService>();
    final show = !sync.isOnline || sync.pendingCount > 0 || sync.isSyncing;
    if (!show) return const SizedBox.shrink();

    final text = sync.isSyncing
        ? i18n.t('offline.syncing')
        : !sync.isOnline
            ? sync.pendingCount > 0
                ? i18n.t('offline.pending', vars: {'n': '${sync.pendingCount}'})
                : i18n.t('offline.banner')
            : i18n.t('offline.queue', vars: {'n': '${sync.pendingCount}'});

    final offline = !sync.isOnline;

    return Material(
      color: offline ? AppTheme.emerald800 : AppTheme.surface,
      child: InkWell(
        onTap: sync.isSyncing ? null : () => sync.sync(),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: AppTheme.gold500.withValues(alpha: 0.35),
              ),
            ),
          ),
          child: Row(
            children: [
              Icon(
                sync.isOnline ? Icons.cloud_upload_outlined : Icons.cloud_off_outlined,
                color: AppTheme.gold300,
                size: 18,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  text,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.cream,
                        fontWeight: FontWeight.w500,
                      ),
                ),
              ),
              if (sync.isOnline && sync.pendingCount > 0 && !sync.isSyncing)
                const Icon(Icons.sync, color: AppTheme.gold300, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}
