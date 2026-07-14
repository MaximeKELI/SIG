import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/sig_api.dart';
import '../../shared/widgets/error_view.dart';
import '../../shared/widgets/loading_view.dart';

class PublicProfileScreen extends StatefulWidget {
  const PublicProfileScreen({super.key, required this.username});

  final String username;

  @override
  State<PublicProfileScreen> createState() => _PublicProfileScreenState();
}

class _PublicProfileScreenState extends State<PublicProfileScreen> {
  Map<String, dynamic>? _profile;
  bool _loading = true;
  bool _updatingFollow = false;
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
      final profile = await context.read<SigApi>().publicProfile(
        widget.username,
      );
      if (mounted) {
        setState(() {
          _profile = profile;
          _loading = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _toggleFollow() async {
    if (_profile == null || _updatingFollow) return;
    final following = _isFollowing;
    setState(() => _updatingFollow = true);
    try {
      final api = context.read<SigApi>();
      if (following) {
        await api.unfollowUser(widget.username);
      } else {
        await api.followUser(widget.username);
      }
      if (mounted) {
        setState(() {
          _profile = {..._profile!, 'is_following': !following};
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              following ? 'Vous ne suivez plus ce membre.' : 'Membre suivi.',
            ),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Action impossible : $error')));
      }
    } finally {
      if (mounted) setState(() => _updatingFollow = false);
    }
  }

  bool get _isFollowing =>
      _profile?['is_following'] == true || _profile?['following'] == true;

  @override
  Widget build(BuildContext context) {
    final profile = _profile;
    return Scaffold(
      appBar: AppBar(title: const Text('Profil public')),
      body:
          _loading
              ? const LoadingView()
              : _error != null
              ? ErrorView(message: _error!, onRetry: _load)
              : RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Center(child: _avatar(profile!)),
                    const SizedBox(height: 16),
                    Text(
                      _displayName(profile),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '@${profile['username'] ?? widget.username}',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: _updatingFollow ? null : _toggleFollow,
                      icon: Icon(
                        _isFollowing
                            ? Icons.person_remove_outlined
                            : Icons.person_add_outlined,
                      ),
                      label: Text(_isFollowing ? 'Ne plus suivre' : 'Suivre'),
                    ),
                    const SizedBox(height: 24),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'À propos',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              profile['bio']?.toString().trim().isNotEmpty ==
                                      true
                                  ? profile['bio'].toString()
                                  : 'Ce membre n’a pas encore renseigné de biographie.',
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (profile['profile_stats'] is Map)
                      _stats(profile['profile_stats'] as Map),
                  ],
                ),
              ),
    );
  }

  Widget _avatar(Map<String, dynamic> profile) {
    final photo = profile['profile_photo_url']?.toString();
    final initial =
        _displayName(profile).isNotEmpty
            ? _displayName(profile)[0].toUpperCase()
            : '?';
    return CircleAvatar(
      radius: 48,
      foregroundImage:
          photo != null && photo.isNotEmpty ? NetworkImage(photo) : null,
      child: Text(initial, style: const TextStyle(fontSize: 32)),
    );
  }

  Widget _stats(Map<dynamic, dynamic> stats) {
    final values = stats.entries.where((entry) => entry.value is num).toList();
    if (values.isEmpty) return const SizedBox.shrink();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          spacing: 24,
          runSpacing: 12,
          children:
              values
                  .map(
                    (entry) => Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${entry.value}',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text(_label(entry.key.toString())),
                      ],
                    ),
                  )
                  .toList(),
        ),
      ),
    );
  }

  String _displayName(Map<String, dynamic> profile) {
    final name = profile['display_name']?.toString();
    if (name != null && name.isNotEmpty) return name;
    final first = profile['first_name']?.toString() ?? '';
    final last = profile['last_name']?.toString() ?? '';
    return '$first $last'.trim().isNotEmpty
        ? '$first $last'.trim()
        : widget.username;
  }

  String _label(String key) => key.replaceAll('_', ' ');
}
