import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/i18n/locale_service.dart';
import '../../core/theme/app_theme.dart';
import '../help/gallery_catalog.dart';

/// Accueil — présentation + galerie DUSOL (avant la carte).
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final i18n = context.watch<LocaleService>();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 22),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: AppTheme.heroGradient,
            boxShadow: AppTheme.softShadow,
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    'assets/images/logo-dusol.png',
                    height: 52,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.eco,
                      color: Colors.white,
                      size: 48,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Image.asset(
                    'assets/images/logo-sig-sol.png',
                    height: 52,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.map,
                      color: Colors.white,
                      size: 48,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                'DUSOL · DISIA · Région Maritime',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: AppTheme.gold300,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                i18n.t('welcome.title'),
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Cartographie des sols, NASA, IA et quiz pédagogique.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.88),
                ),
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                alignment: WrapAlignment.center,
                children: [
                  FilledButton(
                    onPressed: () => context.go('/map'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.gold500,
                      foregroundColor: AppTheme.emerald950,
                    ),
                    child: Text(i18n.t('nav.map')),
                  ),
                  OutlinedButton(
                    onPressed: () => context.go('/quiz'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white70),
                    ),
                    child: Text(i18n.t('nav.quiz')),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        _Pillar(
          title: 'Carte & sols',
          body: 'Points validés, pH, NDVI NASA / Sentinel et analyse de parcelles.',
        ),
        _Pillar(
          title: 'Formation',
          body: 'Quiz pédagogiques, fiches et parcours pour mieux lire les sols.',
        ),
        _Pillar(
          title: 'Communauté',
          body: 'Vidéos, shorts et échanges entre agents, formateurs et citoyens.',
        ),
        const SizedBox(height: 20),
        _GalleryRail(
          eyebrow: 'Mémoire visuelle',
          title: 'Graine d’espoir',
          subtitle: 'Formations terrain — planches, pépinières et semences.',
          photos: GalleryCatalog.graine,
        ),
        const SizedBox(height: 22),
        _GalleryRail(
          eyebrow: 'Soirée',
          title: 'Cinéma DuSol',
          subtitle: 'Ouverture, projection, table ronde et networking.',
          photos: GalleryCatalog.cinema,
        ),
      ],
    );
  }
}

class _Pillar extends StatelessWidget {
  const _Pillar({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(body),
          ],
        ),
      ),
    );
  }
}

class _GalleryRail extends StatelessWidget {
  const _GalleryRail({
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
        Text(
          eyebrow.toUpperCase(),
          style: theme.textTheme.labelSmall?.copyWith(
            letterSpacing: 1.4,
            fontWeight: FontWeight.w700,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: 4),
        Text(title, style: theme.textTheme.titleLarge),
        const SizedBox(height: 4),
        Text(subtitle, style: theme.textTheme.bodyMedium),
        const SizedBox(height: 12),
        SizedBox(
          height: 156,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: photos.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, i) {
              final p = photos[i];
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
                  borderRadius: BorderRadius.circular(16),
                  child: Stack(
                    children: [
                      Image.asset(
                        p.asset,
                        width: 220,
                        height: 156,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: 220,
                          height: 156,
                          color: theme.colorScheme.surfaceContainerHighest,
                          child: const Icon(Icons.image_not_supported_outlined),
                        ),
                      ),
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(10, 24, 10, 8),
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
