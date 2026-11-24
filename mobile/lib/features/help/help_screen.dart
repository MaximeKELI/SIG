import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/config/env.dart';
import 'gallery_catalog.dart';

/// Équivalent web : #view-help
class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Aide')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Guide rapide SIG Sols Togo', style: theme.textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(
            'Même backend et mêmes API que le site web.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 20),
          Text('Partenaires', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Row(
            children: const [
              Expanded(
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.all(12),
                    child: Column(
                      children: [
                        Icon(Icons.agriculture, size: 40),
                        SizedBox(height: 8),
                        Text('DUSOL'),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.all(12),
                    child: Column(
                      children: [
                        Icon(Icons.map, size: 40),
                        SizedBox(height: 8),
                        Text('SIG-SOL'),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _GalleryRail(
            eyebrow: 'Mémoire visuelle',
            title: 'Graine d’espoir',
            subtitle: 'Formations terrain — planches, pépinières et semences.',
            photos: GalleryCatalog.graine,
          ),
          const SizedBox(height: 20),
          _GalleryRail(
            eyebrow: 'Soirée',
            title: 'Cinéma DuSol',
            subtitle: 'Ouverture, projection, table ronde et networking.',
            photos: GalleryCatalog.cinema,
          ),
          const SizedBox(height: 16),
          _HelpCard(
            title: 'Carte',
            bullets: const [
              'Filtrez par pH, type de sol, validation.',
              'Limitez le chargement à la zone visible.',
              'Superposez NASA, chaleur pH, trajectoire et proximité.',
              'Agents : ajout de point ou import GeoJSON/CSV.',
            ],
          ),
          _HelpCard(
            title: 'Gestes mobile',
            bullets: const [
              'Pincer pour zoomer · glisser pour déplacer.',
              'Appui long / mode ajout pour créer un point.',
              'Menu latéral : recherche, notifications, admin, langue.',
              'Tirez vers le bas pour rafraîchir listes et carte.',
            ],
          ),
          if (kDebugMode)
            Card(
              child: Column(
                children: [
                  const ListTile(
                    title: Text('API & documentation (debug)'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.health_and_safety),
                    title: const Text('Santé système'),
                    subtitle: const Text('PostGIS, Redis, APIs'),
                    onTap: () => launchUrl(Uri.parse(Env.healthUrl)),
                  ),
                  ListTile(
                    leading: const Icon(Icons.api),
                    title: const Text('Schéma API'),
                    onTap: () =>
                        launchUrl(Uri.parse('${Env.origin}/api/schema/')),
                  ),
                  ListTile(
                    leading: const Icon(Icons.admin_panel_settings),
                    title: const Text('Administration Django'),
                    onTap: () =>
                        launchUrl(Uri.parse('${Env.origin}/admin/')),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Crédits & infos', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  const Text(
                    'Données NASA : domaine public — crédit NASA Earth Science (RG05).',
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'DISIA – Ministère de l’Agriculture, Togo · DUSOL · MIT License.',
                  ),
                  const SizedBox(height: 8),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.code),
                    title: const Text('Développement'),
                    subtitle: Text(
                      Env.developerPhone.isNotEmpty
                          ? '${Env.developer} · ${Env.developerPhone}'
                          : Env.developer,
                    ),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.mail_outline),
                    title: const Text('Contact'),
                    subtitle: Text(Env.supportEmail),
                  ),
                  if (Env.resolvedPrivacyPolicyUrl.isNotEmpty)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.privacy_tip_outlined),
                      title: const Text('Politique de confidentialité'),
                      subtitle: Text(Env.resolvedPrivacyPolicyUrl),
                      onTap: () => launchUrl(
                        Uri.parse(Env.resolvedPrivacyPolicyUrl),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HelpCard extends StatelessWidget {
  const _HelpCard({required this.title, required this.bullets});

  final String title;
  final List<String> bullets;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            ...bullets.map(
              (b) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('• '),
                    Expanded(child: Text(b)),
                  ],
                ),
              ),
            ),
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
