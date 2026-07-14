import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/config/env.dart';

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
          Card(
            child: Column(
              children: [
                const ListTile(
                  title: Text('API & documentation'),
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
                  onTap: () => launchUrl(Uri.parse('${Env.origin}/api/schema/')),
                ),
                ListTile(
                  leading: const Icon(Icons.admin_panel_settings),
                  title: const Text('Administration Django'),
                  onTap: () => launchUrl(Uri.parse('${Env.origin}/admin/')),
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
                  Text('Crédits', style: theme.textTheme.titleMedium),
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
                    leading: const Icon(Icons.person),
                    title: Text(Env.developer),
                    subtitle: Text(Env.developerPhone),
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
