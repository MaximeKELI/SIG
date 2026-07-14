import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import 'dusol_ui.dart';

class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return DusolEmptyState(
      title: 'Une erreur est survenue',
      message: message,
      icon: Icons.cloud_off_outlined,
      actionLabel: onRetry != null ? 'Réessayer' : null,
      onAction: onRetry,
    );
  }
}

/// Alias historique — certains imports utilisent EmptyView.
class EmptyView extends DusolEmptyState {
  const EmptyView({
    super.key,
    required super.title,
    super.message,
    super.icon,
    super.actionLabel,
    super.onAction,
  });
}

/// Petit wrapper pour garder AppTheme dans error accents si besoin.
Color get dusolErrorAccent => AppTheme.gold500;
