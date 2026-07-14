import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../services/sig_api.dart';
import '../../shared/widgets/dusol_ui.dart';
import '../../shared/widgets/error_view.dart';
import '../../shared/widgets/loading_view.dart';

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final _searchCtrl = TextEditingController();
  final _dmUserCtrl = TextEditingController();
  final _dmBodyCtrl = TextEditingController();

  List<dynamic> _feed = [];
  List<dynamic> _favorites = [];
  List<dynamic> _searchResults = [];
  List<dynamic> _messages = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
    _loadFeed();
  }

  @override
  void dispose() {
    _tabs.dispose();
    _searchCtrl.dispose();
    _dmUserCtrl.dispose();
    _dmBodyCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadFeed() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final feed = await context.read<SigApi>().fetchFeed();
      setState(() {
        _feed = feed;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _loadFavorites() async {
    try {
      final fav = await context.read<SigApi>().fetchFavorites();
      setState(() => _favorites = fav);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _searchUsers() async {
    final q = _searchCtrl.text.trim();
    if (q.isEmpty) {
      return;
    }
    try {
      final results = await context.read<SigApi>().searchUsers(q);
      if (mounted) {
        setState(() => _searchResults = results);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _loadMessages() async {
    try {
      final withUser = _dmUserCtrl.text.trim();
      final msgs = await context.read<SigApi>().fetchMessages(
        withUser: withUser.isEmpty ? null : withUser,
      );
      if (mounted) {
        setState(() => _messages = msgs);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _toggleFollow(Map<String, dynamic> user) async {
    final username = user['username']?.toString() ?? '';
    if (username.isEmpty) {
      return;
    }
    final following = user['is_following'] == true || user['following'] == true;
    try {
      if (following) {
        await context.read<SigApi>().unfollowUser(username);
      } else {
        await context.read<SigApi>().followUser(username);
      }
      if (!mounted) return;
      setState(() {
        final index = _searchResults.indexOf(user);
        if (index >= 0) {
          _searchResults[index] = {...user, 'is_following': !following};
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            following ? 'Vous ne suivez plus $username' : 'Abonné à $username',
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _sendMessage() async {
    final recipient = _dmUserCtrl.text.trim();
    final body = _dmBodyCtrl.text.trim();
    if (recipient.isEmpty || body.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Indiquez un destinataire et un message.'),
        ),
      );
      return;
    }
    try {
      await context.read<SigApi>().sendMessage(
        recipientUsername: recipient,
        body: body,
      );
      _dmBodyCtrl.clear();
      await _loadMessages();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: DusolHeroHeader(
            title: 'Communauté',
            subtitle: 'Fil · membres · messages',
          ),
        ),
        TabBar(
          controller: _tabs,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Fil'),
            Tab(text: 'Recherche'),
            Tab(text: 'Favoris'),
            Tab(text: 'Messages'),
          ],
          onTap: (i) {
            if (i == 1) _searchUsers();
            if (i == 2) _loadFavorites();
            if (i == 3) _loadMessages();
          },
        ),
        Expanded(
          child:
              _loading && _tabs.index == 0
                  ? const LoadingView()
                  : _error != null && _tabs.index == 0
                  ? ErrorView(message: _error!, onRetry: _loadFeed)
                  : TabBarView(
                    controller: _tabs,
                    children: [
                      RefreshIndicator(
                        onRefresh: _loadFeed,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: _feed.length,
                          itemBuilder: (_, i) => _feedTile(_feed[i]),
                        ),
                      ),
                      ListView(
                        padding: const EdgeInsets.all(12),
                        children: [
                          TextField(
                            controller: _searchCtrl,
                            decoration: InputDecoration(
                              hintText: 'Rechercher un membre',
                              suffixIcon: IconButton(
                                icon: const Icon(Icons.search),
                                onPressed: _searchUsers,
                              ),
                            ),
                            onSubmitted: (_) => _searchUsers(),
                          ),
                          ..._searchResults.map((u) {
                            final user = Map<String, dynamic>.from(u as Map);
                            final un = user['username']?.toString() ?? '';
                            final following =
                                user['is_following'] == true ||
                                user['following'] == true;
                            return ListTile(
                              title: Text(
                                user['display_name']?.toString() ?? un,
                              ),
                              subtitle: Text('@$un'),
                              onTap:
                                  un.isEmpty
                                      ? null
                                      : () => context.push(
                                        '/community/profil/${Uri.encodeComponent(un)}',
                                      ),
                              trailing: IconButton(
                                tooltip:
                                    following ? 'Ne plus suivre' : 'Suivre',
                                icon: Icon(
                                  following
                                      ? Icons.person_remove_outlined
                                      : Icons.person_add_outlined,
                                ),
                                onPressed: () => _toggleFollow(user),
                              ),
                            );
                          }),
                        ],
                      ),
                      RefreshIndicator(
                        onRefresh: _loadFavorites,
                        child: ListView.builder(
                          itemCount: _favorites.length,
                          itemBuilder: (_, i) {
                            final f = Map<String, dynamic>.from(
                              _favorites[i] as Map,
                            );
                            return ListTile(
                              title: Text(
                                f['title']?.toString() ??
                                    f['target_type']?.toString() ??
                                    '—',
                              ),
                              subtitle: Text(
                                '${f['target_type']} #${f['target_id']}',
                              ),
                            );
                          },
                        ),
                      ),
                      ListView(
                        padding: const EdgeInsets.all(12),
                        children: [
                          Text(
                            'Messages directs',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Saisissez un membre pour afficher ou démarrer une conversation.',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _dmUserCtrl,
                            decoration: InputDecoration(
                              labelText: 'Utilisateur',
                              suffixIcon: IconButton(
                                icon: const Icon(Icons.refresh),
                                tooltip: 'Charger la conversation',
                                onPressed: _loadMessages,
                              ),
                            ),
                            onSubmitted: (_) => _loadMessages(),
                          ),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _dmBodyCtrl,
                                  decoration: const InputDecoration(
                                    labelText: 'Message',
                                  ),
                                  minLines: 1,
                                  maxLines: 4,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.send),
                                tooltip: 'Envoyer',
                                onPressed: _sendMessage,
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (_messages.isEmpty)
                            const Padding(
                              padding: EdgeInsets.all(16),
                              child: Center(
                                child: Text('Aucun message pour le moment.'),
                              ),
                            ),
                          ..._messages.map((m) {
                            final msg = Map<String, dynamic>.from(m as Map);
                            return ListTile(
                              title: Text(msg['body']?.toString() ?? ''),
                              subtitle: Text(
                                msg['sender']?.toString() ??
                                    msg['created_at']?.toString() ??
                                    '',
                              ),
                            );
                          }),
                        ],
                      ),
                    ],
                  ),
        ),
      ],
    );
  }

  Widget _feedTile(dynamic item) {
    final f = Map<String, dynamic>.from(item as Map);
    final username = f['author_username']?.toString() ?? '';
    final letter =
        (f['author_username'] ?? '?').toString().isNotEmpty
            ? (f['author_username'] ?? '?').toString()[0].toUpperCase()
            : '?';
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppTheme.emerald800,
          foregroundColor: AppTheme.gold300,
          child: Text(letter),
        ),
        title: Text(
          f['title']?.toString() ?? f['kind']?.toString() ?? 'Publication',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        subtitle: InkWell(
          onTap: username.isEmpty
              ? null
              : () => context.push(
                    '/community/profil/${Uri.encodeComponent(username)}',
                  ),
          child: Text(f['author_display']?.toString() ?? '@$username'),
        ),
        onTap: username.isEmpty
            ? null
            : () => context.push(
                  '/community/profil/${Uri.encodeComponent(username)}',
                ),
        trailing: Text(
          '❤ ${f['like_count'] ?? 0}',
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: AppTheme.gold400,
              ),
        ),
      ),
    ).dusolEnter();
  }
}
