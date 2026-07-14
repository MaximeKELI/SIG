import 'dart:io' show Platform;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/config/env.dart';
import '../../core/theme/app_theme.dart';

bool get dusolAnimationsEnabled => !Platform.environment.containsKey('FLUTTER_TEST');

/// Entrée soft fade + slide — à appliquer sur listes / blocs.
extension DusolAnimateX on Widget {
  Widget dusolEnter({int index = 0, bool enabled = true}) {
    if (!enabled || !dusolAnimationsEnabled) return this;
    return animate(delay: (40 * index).ms)
        .fadeIn(duration: AppMotion.normal, curve: AppMotion.easeOut)
        .slideY(begin: 0.06, end: 0, duration: AppMotion.normal, curve: AppMotion.easeOut);
  }

  Widget dusolPop({bool enabled = true}) {
    if (!enabled || !dusolAnimationsEnabled) return this;
    return animate()
        .fadeIn(duration: AppMotion.fast, curve: AppMotion.easeOut)
        .scale(
          begin: const Offset(0.96, 0.96),
          end: const Offset(1, 1),
          duration: AppMotion.normal,
          curve: AppMotion.spring,
        );
  }
}

/// Hero de section — dégradé émeraude / bordure or.
class DusolHeroHeader extends StatelessWidget {
  const DusolHeroHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.padding,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: padding ??
          const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.lg - 4,
            AppSpacing.sm,
            AppSpacing.md,
          ),
      decoration: BoxDecoration(
        borderRadius: AppRadius.hero,
        gradient: AppTheme.heroGradient,
        border: Border.all(color: AppTheme.gold500.withValues(alpha: 0.35)),
        boxShadow: AppTheme.softShadow,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        color: AppTheme.gold300,
                      ),
                ),
                if (subtitle != null && subtitle!.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    subtitle!,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.78),
                        ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    ).dusolPop();
  }
}

/// Titre de section typographique.
class DusolSectionTitle extends StatelessWidget {
  const DusolSectionTitle(this.text, {super.key, this.action});

  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm, bottom: AppSpacing.xs),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    letterSpacing: 0.2,
                  ),
            ),
          ),
          if (action != null) action!,
        ],
      ),
    );
  }
}

/// Carte KPI compacte.
class DusolKpiTile extends StatelessWidget {
  const DusolKpiTile({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.onTap,
  });

  final String label;
  final String value;
  final IconData? icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerHighest.withValues(alpha: 0.65),
      borderRadius: AppRadius.card,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.card,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: AppRadius.card,
            border: Border.all(color: AppTheme.gold500.withValues(alpha: 0.18)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 20, color: AppTheme.gold400),
                const SizedBox(height: AppSpacing.xs),
              ],
              Text(
                value,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppTheme.gold300,
                    ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// État vide soigné.
class DusolEmptyState extends StatelessWidget {
  const DusolEmptyState({
    super.key,
    required this.title,
    this.message,
    this.icon = Icons.inbox_outlined,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? message;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppTheme.heroGradient,
                border: Border.all(color: AppTheme.gold500.withValues(alpha: 0.4)),
              ),
              child: Icon(icon, size: 34, color: AppTheme.gold300),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            if (message != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: AppSpacing.lg),
              FilledButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    ).dusolPop();
  }
}

/// Fond atmosphérique émeraude / or (login, splash).
class DusolAtmosphere extends StatelessWidget {
  const DusolAtmosphere({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: dark
            ? AppTheme.ambientDark
            : const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFF7F4EC), AppTheme.cream, Color(0xFFE8EFE8)],
              ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -80,
            left: -60,
            child: _blob(180, AppTheme.emerald600.withValues(alpha: dark ? 0.18 : 0.12)),
          ),
          Positioned(
            top: 120,
            right: -40,
            child: _blob(140, AppTheme.gold500.withValues(alpha: dark ? 0.12 : 0.1)),
          ),
          Positioned(
            bottom: -40,
            left: 40,
            child: _blob(160, AppTheme.emerald800.withValues(alpha: dark ? 0.22 : 0.08)),
          ),
          child,
        ],
      ),
    );
  }

  Widget _blob(double size, Color color) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
        ),
      ),
    );
  }
}

/// Avatar circulaire avec fallback lettre (évite le cercle vide si l’image échoue).
class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    required this.label,
    this.photoUrl,
    this.radius = 22,
    this.cacheBust,
    this.onTap,
  });

  final String label;
  final String? photoUrl;
  final double radius;
  final Object? cacheBust;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final resolved = Env.resolveMediaUrl(photoUrl);
    final initial =
        label.trim().isNotEmpty ? label.trim()[0].toUpperCase() : '?';
    final placeholder = ColoredBox(
      color: AppTheme.emerald800,
      child: Center(
        child: Text(
          initial,
          style: TextStyle(
            color: AppTheme.gold300,
            fontSize: radius * 0.85,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );

    final image =
        resolved.isEmpty
            ? placeholder
            : CachedNetworkImage(
              imageUrl: resolved,
              cacheKey: cacheBust == null ? resolved : '$resolved|$cacheBust',
              fit: BoxFit.cover,
              width: radius * 2,
              height: radius * 2,
              fadeInDuration: const Duration(milliseconds: 180),
              placeholder: (_, __) => placeholder,
              errorWidget: (_, __, ___) => placeholder,
            );

    final avatar = ClipOval(
      child: SizedBox(width: radius * 2, height: radius * 2, child: image),
    );

    if (onTap == null) return avatar;
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: avatar,
    );
  }
}
