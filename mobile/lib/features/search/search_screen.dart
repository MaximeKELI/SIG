import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/sig_api.dart';
import '../videos/video_player_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _ctrl = TextEditingController();
  List<dynamic> _results = [];
  bool _loading = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final q = _ctrl.text.trim();
    if (q.length < 2) return;
    setState(() => _loading = true);
    try {
      final results = await context.read<SigApi>().globalSearch(q);
      if (!mounted) return;
      setState(() {
        _results = results;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _openVideo(dynamic id) async {
    final postId = id is int ? id : int.tryParse('$id');
    if (postId == null) return;
    try {
      final post = await context.read<SigApi>().fetchVideo(postId);
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => VideoPlayerScreen(post: post),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _open(Map<String, dynamic> r) async {
    final type = r['type']?.toString();
    final id = r['id'];
    final username = r['username']?.toString() ?? r['title']?.toString();
    switch (type) {
      case 'user':
        if (username != null && username.isNotEmpty) {
          context.push('/community/profil/$username');
        }
        break;
      case 'sheet':
        if (id != null) {
          final url = context.read<SigApi>().sheetPdfUrl(id is int ? id : int.parse('$id'));
          await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
        }
        break;
      case 'video':
      case 'short':
        await _openVideo(id);
        break;
      case 'point':
        final pointId = id is int ? id : int.tryParse('$id');
        if (pointId != null) {
          context.go('/?point=$pointId');
        } else {
          context.go('/');
        }
        break;
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Recherche globale')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _ctrl,
                    decoration: const InputDecoration(
                      hintText: 'Points, fiches, vidéos, utilisateurs…',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onSubmitted: (_) => _search(),
                  ),
                ),
                IconButton(icon: const Icon(Icons.search), onPressed: _search),
              ],
            ),
          ),
          if (_loading) const LinearProgressIndicator(),
          Expanded(
            child: ListView.builder(
              itemCount: _results.length,
              itemBuilder: (_, i) {
                final r = Map<String, dynamic>.from(_results[i] as Map);
                return ListTile(
                  leading: Icon(_iconFor(r['type']?.toString())),
                  title: Text(r['title']?.toString() ?? '—'),
                  subtitle: Text('${r['type'] ?? ''} · ${r['subtitle'] ?? ''}'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _open(r),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  IconData _iconFor(String? type) {
    switch (type) {
      case 'point':
        return Icons.place;
      case 'sheet':
        return Icons.menu_book;
      case 'video':
      case 'short':
        return Icons.videocam;
      case 'user':
        return Icons.person;
      default:
        return Icons.search;
    }
  }
}
