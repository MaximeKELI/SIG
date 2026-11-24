import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/i18n/locale_service.dart';
import '../../core/theme/app_theme.dart';
import '../help/gallery_catalog.dart';

/// Accueil — hero photo plein écran + galerie immersive.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final i18n = context.watch<LocaleService>();
    final top = MediaQuery.paddingOf(context).top;

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.78,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(
                  GalleryCatalog.graine.first.asset,
                  fit: BoxFit.cover,
                  alignment: const Alignment(0, -0.25),
                  errorBuilder: (_, __, ___) => Container(
                    color: AppTheme.emerald950,
                  ),
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        AppTheme.emerald950.withValues(alpha: 0.88),
                        AppTheme.emerald950.withValues(alpha: 0.45),
                        Colors.transparent,
                      ],
                      stops: const [0, 0.45, 0.9],
                    ),
                  ),
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        AppTheme.emerald950.withValues(alpha: 0.8),
                        Colors.transparent,
                      ],
                      stops: const [0, 0.45],
                    ),
                  ),
                ),
                Positioned(
                  left: 20,
                  right: 20,
                  bottom: 36,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(height: top + 8),
                      Row(
                        children: [
                          _BrandBadge(
                            asset: 'assets/images/logo-dusol.png',
                            round: true,
                          ),
                          const SizedBox(width: 10),
                          _BrandBadge(
                            asset: 'assets/images/logo-sig-sol.png',
                            round: false,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'DUSOL · DISIA · Région Maritime',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: AppTheme.gold300,
                          letterSpacing: 1.6,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'SIG Sols Togo',
                        style: theme.textTheme.displaySmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          height: 0.98,
                          fontSize: 42,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Les sols de la Maritime, cartographiés et partagés — du terrain à la carte.',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: Colors.white.withValues(alpha: 0.9),
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 20),
                      FilledButton(
                        onPressed: () => context.go('/map'),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.gold500,
                          foregroundColor: AppTheme.emerald950,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 22,
                            vertical: 14,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        child: Text(i18n.t('nav.map')),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: ColoredBox(
            color: theme.scaffoldBackgroundColor,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 28),
                _GalleryBand(
                  eyebrow: 'Mémoire visuelle',
                  title: 'Graine d’espoir',
                  subtitle: 'Formations terrain — planches, pépinières et semences.',
                  photos: GalleryCatalog.graine,
                ),
                const SizedBox(height: 8),
                Divider(
                  height: 1,
                  thickness: 1,
                  color: AppTheme.gold500.withValues(alpha: 0.22),
                ),
                const SizedBox(height: 20),
                _GalleryBand(
                  eyebrow: 'Soirée',
                  title: 'Cinéma DuSol',
                  subtitle: 'Ouverture, projection, table ronde et networking.',
                  photos: GalleryCatalog.cinema,
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _BrandBadge extends StatelessWidget {
  const _BrandBadge({required this.asset, required this.round});

  final String asset;
  final bool round;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(round ? 999 : 12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.28),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Image.asset(
        asset,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => Icon(
          round ? Icons.eco : Icons.map,
          color: AppTheme.emerald800,
        ),
      ),
    );
  }
}

class _GalleryBand extends StatelessWidget {
  const _GalleryBand({
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.photos,
  });

  final String eyebrow;
  final String title;
  final String subtitle;
  final List<GalleryPhoto> photos;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                eyebrow.toUpperCase(),
                style: theme.textTheme.labelSmall?.copyWith(
                  letterSpacing: 1.6,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.gold600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppTheme.emerald900,
                  height: 1.05,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 280,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: photos.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final p = photos[i];
              final wide = i % 3 == 0;
              return GestureDetector(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => _PhotoViewer(
                        photos: photos,
                        initialIndex: i,
                      ),
                    ),
                  );
                },
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: Stack(
                    children: [
                      Image.asset(
                        p.asset,
                        width: wide ? 340 : 220,
                        height: 280,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: wide ? 340 : 220,
                          height: 280,
                          color: theme.colorScheme.surfaceContainerHighest,
                          child: const Icon(Icons.image_not_supported_outlined),
                        ),
                      ),
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(12, 36, 12, 12),
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Colors.transparent, Colors.black87],
                            ),
                          ),
                          child: Text(
                            p.caption,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _PhotoViewer extends StatefulWidget {
  const _PhotoViewer({required this.photos, required this.initialIndex});

  final List<GalleryPhoto> photos;
  final int initialIndex;

  @override
  State<_PhotoViewer> createState() => _PhotoViewerState();
}

class _PhotoViewerState extends State<_PhotoViewer> {
  late final PageController _controller;
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _controller = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final photo = widget.photos[_index];
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(photo.caption, style: const TextStyle(fontSize: 14)),
      ),
      body: PageView.builder(
        controller: _controller,
        itemCount: widget.photos.length,
        onPageChanged: (i) => setState(() => _index = i),
        itemBuilder: (context, i) {
          return InteractiveViewer(
            child: Center(
              child: Image.asset(
                widget.photos[i].asset,
                fit: BoxFit.contain,
              ),
            ),
          );
        },
      ),
    );
  }
}
