import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/config/env.dart';
import '../../services/sig_api.dart';
import '../../shared/widgets/error_view.dart';
import '../../shared/widgets/loading_view.dart';

class SheetsScreen extends StatefulWidget {
  const SheetsScreen({super.key});

  @override
  State<SheetsScreen> createState() => _SheetsScreenState();
}

class _SheetsScreenState extends State<SheetsScreen> {
  List<dynamic> _sheets = [];
  final Set<int> _favoriteIds = {};
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = context.read<SigApi>();
      final results = await Future.wait<dynamic>([
        api.fetchSheets(),
        api.fetchFavorites().catchError((_) => <dynamic>[]),
      ]);
      final favIds = <int>{};
      for (final f in results[1]) {
        final m = Map<String, dynamic>.from(f as Map);
        if (m['target_type'] == 'sheet') {
          final id = m['target_id'] ?? m['id'];
          if (id != null) favIds.add(int.parse(id.toString()));
        }
      }
      setState(() {
        _sheets = results[0];
        _favoriteIds
          ..clear()
          ..addAll(favIds);
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _toggleFavorite(int id) async {
    final api = context.read<SigApi>();
    final isFav = _favoriteIds.contains(id);
    try {
      if (isFav) {
        await api.removeFavorite(targetType: 'sheet', targetId: id);
        setState(() => _favoriteIds.remove(id));
      } else {
        await api.addFavorite(targetType: 'sheet', targetId: id);
        setState(() => _favoriteIds.add(id));
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(isFav ? 'Retiré des favoris' : 'Ajouté aux favoris')),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const LoadingView();
    if (_error != null) return ErrorView(message: _error!, onRetry: _load);

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _sheets.length,
      itemBuilder: (_, i) {
        final s = Map<String, dynamic>.from(_sheets[i] as Map);
        final id = int.tryParse('${s['id']}') ?? 0;
        final isFav = _favoriteIds.contains(id);
        return Card(
          child: ListTile(
            title: Text(s['title']?.toString() ?? 'Fiche'),
            subtitle: Text(s['theme']?.toString() ?? ''),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(isFav ? Icons.favorite : Icons.favorite_border, color: isFav ? Colors.redAccent : null),
                  onPressed: id > 0 ? () => _toggleFavorite(id) : null,
                ),
                if (s['pdf_url'] != null) const Icon(Icons.picture_as_pdf),
              ],
            ),
            onTap: () async {
              final url = Env.resolveMediaUrl(s['pdf_url']?.toString());
              if (url.isEmpty) return;
              final uri = Uri.parse(url);
              final ok = await launchUrl(
                uri,
                mode: LaunchMode.inAppWebView,
              );
              if (!ok && mounted) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
          ),
        );
      },
    );
  }
}
