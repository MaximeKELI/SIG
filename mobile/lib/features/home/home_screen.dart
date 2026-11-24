import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/i18n/locale_service.dart';
import '../../core/theme/app_theme.dart';
import '../help/gallery_catalog.dart';

/// Accueil — hero carrousel immersif + galerie animée.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _scroll = ScrollController();
  late final PageController _heroPage;
  Timer? _heroTimer;
  double _offset = 0;
  int _heroIndex = 0;

  List<GalleryPhoto> get _heroPhotos => GalleryCatalog.hero;

  @override
  void initState() {
    super.initState();
    _heroPage = PageController();
    _scroll.addListener(() {
      if (!mounted) return;
      setState(() => _offset = _scroll.offset);
    });
    _startHeroTimer();
  }

  void _startHeroTimer() {
    _heroTimer?.cancel();
    _heroTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted || !_heroPage.hasClients || _heroPhotos.isEmpty) return;
      final next = (_heroIndex + 1) % _heroPhotos.length;
      _heroPage.animateToPage(
        next,
        duration: const Duration(milliseconds: 900),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  @override
  void dispose() {
    _heroTimer?.cancel();
    _heroPage.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final i18n = context.watch<LocaleService>();
    final top = MediaQuery.paddingOf(context).top;
    final heroH = MediaQuery.sizeOf(context).height * 0.78;
    final progress = (_offset / heroH).clamp(0.0, 1.0);
    final parallax = _offset * 0.35;
    final caption = _heroPhotos.isEmpty
        ? ''
        : _heroPhotos[_heroIndex.clamp(0, _heroPhotos.length - 1)].caption;

    return CustomScrollView(
      controller: _scroll,
      slivers: [
        SliverToBoxAdapter(
          child: SizedBox(
            height: heroH,
            child: ClipRect(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Transform.translate(
                    offset: Offset(0, parallax),
                    child: Transform.scale(
                      scale: 1.08 + progress * 0.08,
                      child: PageView.builder(
                        controller: _heroPage,
                        itemCount: _heroPhotos.length,
                        onPageChanged: (i) {
                          setState(() => _heroIndex = i);
                          _startHeroTimer();
                        },
                        itemBuilder: (context, i) {
                          final photo = _heroPhotos[i];
                          return Image.asset(
                            photo.asset,
                            fit: BoxFit.cover,
                            alignment: const Alignment(0, -0.25),
                            errorBuilder: (_, __, ___) => Container(
                              color: AppTheme.emerald950,
                            ),
                          );
                        },
                      ),
                    ),
                  )
                      .animate()
                      .fadeIn(duration: 1200.ms, curve: Curves.easeOutCubic)
                      .blur(
                        begin: const Offset(12, 12),
                        end: Offset.zero,
                        duration: 1400.ms,
                        curve: Curves.easeOutCubic,
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
                    left: -40,
                    bottom: 40,
                    child: IgnorePointer(
                      child: Container(
                        width: 180,
                        height: 180,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              AppTheme.gold500.withValues(alpha: 0.28),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      )
                          .animate(onPlay: (c) => c.repeat(reverse: true))
                          .scale(
                            begin: const Offset(0.9, 0.9),
                            end: const Offset(1.15, 1.15),
                            duration: 4200.ms,
                            curve: Curves.easeInOut,
                          )
                          .fade(
                            begin: 0.45,
                            end: 0.9,
                            duration: 4200.ms,
                          ),
                    ),
                  ),
                  Positioned(
                    left: 20,
                    right: 20,
                    bottom: 36,
                    child: Opacity(
                      opacity: (1 - progress * 1.2).clamp(0.0, 1.0),
                      child: Transform.translate(
                        offset: Offset(0, progress * 40),
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
                            )
                                .animate()
                                .fadeIn(delay: 120.ms, duration: 700.ms)
                                .blur(
                                  begin: const Offset(8, 8),
                                  end: Offset.zero,
                                  duration: 800.ms,
                                )
                                .slideY(
                                  begin: 0.25,
                                  end: 0,
                                  duration: 800.ms,
                                  curve: Curves.easeOutCubic,
                                ),
                            const SizedBox(height: 16),
                            Text(
                              'DUSOL · DISIA · Région Maritime',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: AppTheme.gold300,
                                letterSpacing: 1.6,
                                fontWeight: FontWeight.w700,
                              ),
                            )
                                .animate()
                                .fadeIn(delay: 280.ms, duration: 700.ms)
                                .slideY(begin: 0.3, end: 0, duration: 800.ms),
                            const SizedBox(height: 6),
                            Text(
                              'SIG Sols Togo',
                              style: theme.textTheme.displaySmall?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                height: 0.98,
                                fontSize: 42,
                              ),
                            )
                                .animate()
                                .fadeIn(delay: 420.ms, duration: 900.ms)
                                .blur(
                                  begin: const Offset(10, 10),
                                  end: Offset.zero,
                                  duration: 1000.ms,
                                )
                                .slideY(
                                  begin: 0.35,
                                  end: 0,
                                  duration: 1000.ms,
                                  curve: Curves.easeOutCubic,
                                ),
                            const SizedBox(height: 10),
                            Text(
                              'Les sols de la Maritime, cartographiés et partagés — du terrain à la carte.',
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: Colors.white.withValues(alpha: 0.9),
                                height: 1.4,
                              ),
                            )
                                .animate()
                                .fadeIn(delay: 620.ms, duration: 800.ms)
                                .slideY(begin: 0.25, end: 0, duration: 850.ms),
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
                            )
                                .animate()
                                .fadeIn(delay: 820.ms, duration: 700.ms)
                                .slideY(begin: 0.4, end: 0, duration: 800.ms)
                                .scale(
                                  begin: const Offset(0.94, 0.94),
                                  end: const Offset(1, 1),
                                  duration: 800.ms,
                                ),
                            const SizedBox(height: 18),
                            Row(
                              children: [
                                for (var i = 0; i < _heroPhotos.length; i++)
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 320),
                                    margin: const EdgeInsets.only(right: 6),
                                    width: i == _heroIndex ? 20 : 7,
                                    height: 7,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(99),
                                      color: i == _heroIndex
                                          ? AppTheme.gold400
                                          : Colors.white.withValues(alpha: 0.35),
                                    ),
                                  ),
                                const Spacer(),
                                AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 350),
                                  child: Text(
                                    caption.toUpperCase(),
                                    key: ValueKey(caption),
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: Colors.white.withValues(alpha: 0.72),
                                      letterSpacing: 1.2,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
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
                  color: AppTheme.gold500,
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
        )
            .animate()
            .fadeIn(duration: 700.ms)
            .blur(begin: const Offset(6, 6), end: Offset.zero, duration: 800.ms)
            .slideY(begin: 0.2, end: 0, duration: 800.ms, curve: Curves.easeOutCubic),
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
              )
                  .animate()
                  .fadeIn(
                    delay: (80 * i).ms,
                    duration: 700.ms,
                    curve: Curves.easeOutCubic,
                  )
                  .blur(
                    begin: const Offset(10, 10),
                    end: Offset.zero,
                    delay: (80 * i).ms,
                    duration: 850.ms,
                  )
                  .slideY(
                    begin: 0.28,
                    end: 0,
                    delay: (80 * i).ms,
                    duration: 850.ms,
                    curve: Curves.easeOutCubic,
                  )
                  .scale(
                    begin: const Offset(0.94, 0.94),
                    end: const Offset(1, 1),
                    delay: (80 * i).ms,
                    duration: 850.ms,
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
