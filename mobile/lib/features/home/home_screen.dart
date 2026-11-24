import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/i18n/locale_service.dart';
import '../../core/theme/app_theme.dart';
import '../help/gallery_catalog.dart';

/// Accueil mobile — même expérience que le web :
/// carrousel hero fondant, parallax, galeries mosaïque animées.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _scroll = ScrollController();
  Timer? _heroTimer;
  double _offset = 0;
  int _heroIndex = 0;
  bool _paused = false;

  List<GalleryPhoto> get _heroPhotos => GalleryCatalog.hero;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (!mounted) return;
      setState(() => _offset = _scroll.offset);
    });
    _startHeroTimer();
  }

  void _startHeroTimer() {
    _heroTimer?.cancel();
    _heroTimer = Timer.periodic(const Duration(milliseconds: 5200), (_) {
      if (!mounted || _paused || _heroPhotos.length < 2) return;
      setState(() => _heroIndex = (_heroIndex + 1) % _heroPhotos.length);
    });
  }

  void _goHero(int index) {
    setState(() => _heroIndex = index % _heroPhotos.length);
    _startHeroTimer();
  }

  void _nextHero() => _goHero(_heroIndex + 1);
  void _prevHero() => _goHero(_heroIndex - 1 + _heroPhotos.length);

  @override
  void dispose() {
    _heroTimer?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final i18n = context.watch<LocaleService>();
    final top = MediaQuery.paddingOf(context).top;
    final bottom = MediaQuery.paddingOf(context).bottom;
    final heroH = MediaQuery.sizeOf(context).height * 0.88;
    final progress = (_offset / heroH).clamp(0.0, 1.0);
    final parallax = _offset * 0.38;
    final photos = _heroPhotos;
    final caption = photos.isEmpty
        ? ''
        : photos[_heroIndex.clamp(0, photos.length - 1)].caption;

    return ColoredBox(
      color: AppTheme.emerald950,
      child: CustomScrollView(
        controller: _scroll,
        slivers: [
          SliverToBoxAdapter(
            child: SizedBox(
              height: heroH,
              child: ClipRect(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // —— Carrousel fondant ——
                    Transform.translate(
                      offset: Offset(0, parallax),
                      child: Transform.scale(
                        scale: 1.06 + progress * 0.08,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            for (var i = 0; i < photos.length; i++)
                              AnimatedOpacity(
                                opacity: i == _heroIndex ? 1 : 0,
                                duration: const Duration(milliseconds: 1100),
                                curve: Curves.easeInOutCubic,
                                child: AnimatedScale(
                                  scale: i == _heroIndex ? 1.0 : 1.08,
                                  duration: const Duration(milliseconds: 1300),
                                  curve: Curves.easeOutCubic,
                                  child: Image.asset(
                                    photos[i].asset,
                                    fit: BoxFit.cover,
                                    alignment: const Alignment(0, -0.25),
                                    errorBuilder: (_, __, ___) =>
                                        const ColoredBox(color: AppTheme.emerald950),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    // Voiles
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
                            AppTheme.emerald950.withValues(alpha: 0.82),
                            Colors.transparent,
                          ],
                          stops: const [0, 0.48],
                        ),
                      ),
                    ),
                    // Lueur or
                    Positioned(
                      left: -40,
                      bottom: 60,
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
                            )
                            .fade(begin: 0.45, end: 0.9, duration: 4200.ms),
                      ),
                    ),
                    // Swipe (sous le contenu interactif)
                    Positioned.fill(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTapDown: (_) => setState(() => _paused = true),
                        onTapUp: (_) {
                          setState(() => _paused = false);
                          _startHeroTimer();
                        },
                        onTapCancel: () {
                          setState(() => _paused = false);
                          _startHeroTimer();
                        },
                        onHorizontalDragEnd: (d) {
                          final v = d.primaryVelocity ?? 0;
                          if (v < -200) {
                            _nextHero();
                          } else if (v > 200) {
                            _prevHero();
                          }
                        },
                        child: const SizedBox.expand(),
                      ),
                    ),
                    // Contenu (au-dessus des gestes)
                    Positioned(
                      left: 20,
                      right: 20,
                      top: top + 12,
                      bottom: 28 + bottom * 0.2,
                      child: Opacity(
                        opacity: (1 - progress * 1.2).clamp(0.0, 1.0),
                        child: Transform.translate(
                          offset: Offset(0, progress * 48),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Spacer(),
                              Row(
                                children: [
                                  const _BrandBadge(
                                    asset: 'assets/images/logo-dusol.png',
                                    round: true,
                                  ),
                                  const SizedBox(width: 10),
                                  const _BrandBadge(
                                    asset: 'assets/images/logo-sig-sol.png',
                                    round: false,
                                  ),
                                ],
                              )
                                  .animate()
                                  .fadeIn(delay: 100.ms, duration: 700.ms)
                                  .blur(
                                    begin: const Offset(8, 8),
                                    end: Offset.zero,
                                    duration: 800.ms,
                                  )
                                  .slideY(begin: 0.25, end: 0, duration: 800.ms),
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
                                  .fadeIn(delay: 260.ms, duration: 700.ms)
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
                                  .fadeIn(delay: 400.ms, duration: 900.ms)
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
                                  .fadeIn(delay: 600.ms, duration: 800.ms)
                                  .slideY(begin: 0.25, end: 0, duration: 850.ms),
                              const SizedBox(height: 18),
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
                                  .fadeIn(delay: 800.ms, duration: 700.ms)
                                  .slideY(begin: 0.4, end: 0, duration: 800.ms),
                              const SizedBox(height: 22),
                              Row(
                                children: [
                                  _CarouselNav(
                                    icon: Icons.chevron_left,
                                    onTap: _prevHero,
                                  ),
                                  const SizedBox(width: 10),
                                  for (var i = 0; i < photos.length; i++)
                                    GestureDetector(
                                      onTap: () => _goHero(i),
                                      child: AnimatedContainer(
                                        duration: const Duration(milliseconds: 320),
                                        margin: const EdgeInsets.only(right: 6),
                                        width: i == _heroIndex ? 22 : 7,
                                        height: 7,
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(99),
                                          color: i == _heroIndex
                                              ? AppTheme.gold400
                                              : Colors.white.withValues(alpha: 0.35),
                                        ),
                                      ),
                                    ),
                                  const SizedBox(width: 4),
                                  _CarouselNav(
                                    icon: Icons.chevron_right,
                                    onTap: _nextHero,
                                  ),
                                  const Spacer(),
                                  Flexible(
                                    child: AnimatedSwitcher(
                                      duration: const Duration(milliseconds: 380),
                                      child: Text(
                                        caption.toUpperCase(),
                                        key: ValueKey(caption),
                                        textAlign: TextAlign.right,
                                        overflow: TextOverflow.ellipsis,
                                        style: theme.textTheme.labelSmall?.copyWith(
                                          color: Colors.white.withValues(alpha: 0.72),
                                          letterSpacing: 1.2,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              )
                                  .animate()
                                  .fadeIn(delay: 1000.ms, duration: 700.ms),
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
                  // Transition fondante hero → galerie
                  Container(
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          AppTheme.emerald950,
                          theme.scaffoldBackgroundColor,
                        ],
                      ),
                    ),
                  ),
                  _GalleryMosaic(
                    eyebrow: 'Mémoire visuelle',
                    title: 'Graine d’espoir',
                    subtitle: 'Formations terrain — planches, pépinières et semences.',
                    photos: GalleryCatalog.graine,
                  ),
                  Divider(
                    height: 1,
                    thickness: 1,
                    color: AppTheme.gold500.withValues(alpha: 0.22),
                  ),
                  const SizedBox(height: 8),
                  _GalleryMosaic(
                    eyebrow: 'Soirée',
                    title: 'Cinéma DuSol',
                    subtitle: 'Ouverture, projection, table ronde et networking.',
                    photos: GalleryCatalog.cinema,
                  ),
                  SizedBox(height: 48 + bottom),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CarouselNav extends StatelessWidget {
  const _CarouselNav({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.28),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 36,
          height: 36,
          child: Icon(icon, color: Colors.white, size: 22),
        ),
      ),
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

class _GalleryMosaic extends StatelessWidget {
  const _GalleryMosaic({
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
    final w = MediaQuery.sizeOf(context).width;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 14),
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
            .slideY(begin: 0.18, end: 0, duration: 800.ms, curve: Curves.easeOutCubic),
        // Mosaïque plein bord (2 colonnes, grandes tuiles)
        Padding(
          padding: const EdgeInsets.fromLTRB(0, 0, 0, 20),
          child: Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              for (var i = 0; i < photos.length; i++)
                _MosaicTile(
                  photo: photos[i],
                  photos: photos,
                  index: i,
                  width: i % 3 == 0 ? w : (w - 4) / 2,
                  height: i % 3 == 0 ? 220.0 : 168.0,
                )
                    .animate()
                    .fadeIn(
                      delay: (70 * i).ms,
                      duration: 700.ms,
                      curve: Curves.easeOutCubic,
                    )
                    .blur(
                      begin: const Offset(10, 10),
                      end: Offset.zero,
                      delay: (70 * i).ms,
                      duration: 850.ms,
                    )
                    .slideY(
                      begin: 0.22,
                      end: 0,
                      delay: (70 * i).ms,
                      duration: 850.ms,
                      curve: Curves.easeOutCubic,
                    ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MosaicTile extends StatelessWidget {
  const _MosaicTile({
    required this.photo,
    required this.photos,
    required this.index,
    required this.width,
    required this.height,
  });

  final GalleryPhoto photo;
  final List<GalleryPhoto> photos;
  final int index;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => _PhotoViewer(
              photos: photos,
              initialIndex: index,
            ),
          ),
        );
      },
      child: SizedBox(
        width: width,
        height: height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              photo.asset,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => ColoredBox(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: const Icon(Icons.image_not_supported_outlined),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(12, 28, 12, 10),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black87],
                  ),
                ),
                child: Text(
                  photo.caption,
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
