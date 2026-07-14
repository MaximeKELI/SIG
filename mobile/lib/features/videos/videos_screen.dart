import 'package:cached_network_image/cached_network_image.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/config/env.dart';
import '../../services/sig_api.dart';
import '../../shared/widgets/error_view.dart';
import '../../shared/widgets/loading_view.dart';
import 'video_player_screen.dart';

class VideosScreen extends StatefulWidget {
  const VideosScreen({super.key, this.kind = 'video'});

  final String kind;

  @override
  State<VideosScreen> createState() => _VideosScreenState();
}

class _VideosScreenState extends State<VideosScreen> {
  List<dynamic> _posts = [];
  List<dynamic> _stories = [];
  bool _loading = true;
  String? _error;
  String _category = '';

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
      final posts = await api.fetchVideos(
        kind: widget.kind,
        category: _category.isEmpty ? null : _category,
      );
      List<dynamic> stories = [];
      if (widget.kind == 'short') {
        stories = await api.fetchStories().catchError((_) => <dynamic>[]);
      }
      setState(() {
        _posts = posts;
        _stories = stories;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _upload() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.video);
    if (!mounted || result == null || result.files.single.path == null) return;
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final tagsCtrl = TextEditingController();
    var category = 'sols';
    try {
      final ok = await showDialog<bool>(
        context: context,
        builder:
            (_) => StatefulBuilder(
              builder:
                  (ctx, setLocal) => AlertDialog(
                    title: Text(
                      'Publier ${widget.kind == 'short' ? 'un short' : 'une vidéo'}',
                    ),
                    content: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextField(
                            controller: titleCtrl,
                            decoration: const InputDecoration(labelText: 'Titre'),
                          ),
                          TextField(
                            controller: descCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Description',
                            ),
                            maxLines: 2,
                          ),
                          DropdownButtonFormField<String>(
                            value: category,
                            decoration: const InputDecoration(
                              labelText: 'Catégorie',
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'sols',
                                child: Text('Sols & agriculture'),
                              ),
                              DropdownMenuItem(
                                value: 'nasa',
                                child: Text('NASA & satellite'),
                              ),
                              DropdownMenuItem(
                                value: 'sig',
                                child: Text('SIG & cartographie'),
                              ),
                              DropdownMenuItem(
                                value: 'formation',
                                child: Text('Formation'),
                              ),
                              DropdownMenuItem(
                                value: 'autre',
                                child: Text('Autre'),
                              ),
                            ],
                            onChanged:
                                (v) => setLocal(() => category = v ?? 'sols'),
                          ),
                          TextField(
                            controller: tagsCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Hashtags',
                              hintText: '#sols #ndvi',
                            ),
                          ),
                        ],
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Annuler'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Envoyer'),
                      ),
                    ],
                  ),
            ),
      );
      if (!mounted || ok != true) return;
      await context.read<SigApi>().uploadVideo(
        filePath: result.files.single.path!,
        kind: widget.kind,
        title:
            titleCtrl.text.trim().isEmpty
                ? 'Sans titre'
                : titleCtrl.text.trim(),
        description: descCtrl.text.trim(),
        category: category,
        hashtags: tagsCtrl.text.trim(),
      );
      if (mounted) await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      titleCtrl.dispose();
      descCtrl.dispose();
      tagsCtrl.dispose();
    }
  }

  Future<void> _uploadStory() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.media);
    if (!mounted || result == null || result.files.single.path == null) return;
    final caption = TextEditingController();
    try {
      final shouldUpload = await showDialog<bool>(
        context: context,
        builder:
            (dialogContext) => AlertDialog(
              title: const Text('Publier une story'),
              content: TextField(
                controller: caption,
                decoration: const InputDecoration(
                  labelText: 'Légende (optionnelle)',
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Annuler'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: const Text('Publier'),
                ),
              ],
            ),
      );
      if (!mounted || shouldUpload != true) return;
      await context.read<SigApi>().uploadStory(
        filePath: result.files.single.path!,
        caption: caption.text.trim(),
      );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Story publiée.')));
        await _load();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Impossible de publier la story : $e')),
        );
      }
    } finally {
      caption.dispose();
    }
  }

  Future<void> _toggleLike(Map<String, dynamic> post) async {
    final id = _idOf(post);
    if (id == null) return;
    try {
      final result = await context.read<SigApi>().toggleVideoLike(id);
      if (!mounted) return;
      setState(() {
        post['liked_by_me'] = result['liked'] ?? !(post['liked_by_me'] == true);
        post['like_count'] = result['like_count'] ?? post['like_count'] ?? 0;
      });
    } catch (e) {
      _showError('Impossible d’aimer cette publication : $e');
    }
  }

  Future<void> _toggleFavorite(Map<String, dynamic> post) async {
    final id = _idOf(post);
    if (id == null) return;
    final wasFavorite =
        post['is_favorite'] == true || post['favorited_by_me'] == true;
    try {
      final api = context.read<SigApi>();
      if (wasFavorite) {
        await api.removeFavorite(targetType: 'video', targetId: id);
      } else {
        await api.addFavorite(targetType: 'video', targetId: id);
      }
      if (mounted) {
        setState(() {
          post['is_favorite'] = !wasFavorite;
          post['favorited_by_me'] = !wasFavorite;
        });
      }
    } catch (e) {
      _showError('Impossible de modifier les favoris : $e');
    }
  }

  int? _idOf(Map<String, dynamic> value) =>
      value['id'] is int
          ? value['id'] as int
          : int.tryParse(value['id']?.toString() ?? '');

  Map<String, dynamic> _postAt(int index) {
    final value = _posts[index];
    if (value is Map<String, dynamic>) return value;
    final post =
        value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};
    _posts[index] = post;
    return post;
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  String _mediaUrl(Map<String, dynamic> post) => Env.resolveMediaUrl(
    post['file_url']?.toString() ??
        post['video_url']?.toString() ??
        post['media_url']?.toString() ??
        post['file']?.toString(),
  );

  Future<void> _openPost(
    Map<String, dynamic> post, {
    bool openComments = false,
  }) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder:
            (_) => VideoPlayerScreen(post: post, openComments: openComments),
      ),
    );
    if (mounted) await _load();
  }

  Future<void> _openStory(Map<String, dynamic> story) async {
    final mediaUrl = _mediaUrl(story);
    if (mediaUrl.isEmpty) {
      _showError('Média de story indisponible.');
      return;
    }
    final type =
        story['media_type']?.toString().toLowerCase() ??
        story['type']?.toString().toLowerCase() ??
        '';
    final isVideo =
        type.contains('video') ||
        RegExp(
          r'\.(mp4|mov|webm|m4v)(\?|$)',
          caseSensitive: false,
        ).hasMatch(mediaUrl);
    if (isVideo) {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          fullscreenDialog: true,
          builder:
              (_) => VideoPlayerScreen(
                videoUrl: mediaUrl,
                title: story['caption']?.toString() ?? 'Story',
              ),
        ),
      );
      return;
    }
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder:
          (dialogContext) => Dialog.fullscreen(
            child: Scaffold(
              appBar: AppBar(
                title: Text(
                  story['author_display']?.toString() ??
                      story['author']?.toString() ??
                      'Story',
                ),
              ),
              body: Center(
                child: InteractiveViewer(
                  child: CachedNetworkImage(
                    imageUrl: mediaUrl,
                    fit: BoxFit.contain,
                    errorWidget:
                        (_, __, ___) =>
                            const Icon(Icons.broken_image, size: 64),
                  ),
                ),
              ),
            ),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const LoadingView();
    if (_error != null) return ErrorView(message: _error!, onRetry: _load);

    final hasStories = widget.kind == 'short';
    if (widget.kind == 'short') {
      return Scaffold(
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _upload,
          icon: const Icon(Icons.upload),
          label: const Text('Short'),
        ),
        body: RefreshIndicator(
          onRefresh: _load,
          child: Column(
            children: [
              if (hasStories)
                SizedBox(
                  height: 104,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    itemCount: _stories.length + 1,
                    itemBuilder: (_, si) {
                      if (si == 0) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: ActionChip(
                            avatar: const Icon(Icons.add),
                            label: const Text('Story'),
                            onPressed: _uploadStory,
                          ),
                        );
                      }
                      final story = Map<String, dynamic>.from(
                        _stories[si - 1] as Map,
                      );
                      return Padding(
                        padding: const EdgeInsets.only(right: 10),
                        child: InkWell(
                          onTap: () => _openStory(story),
                          child: CircleAvatar(
                            radius: 34,
                            backgroundColor:
                                Theme.of(context).colorScheme.primaryContainer,
                            child: Text(
                              (story['author'] ?? story['caption'] ?? 'S')
                                  .toString()
                                  .characters
                                  .first
                                  .toUpperCase(),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              Expanded(
                child:
                    _posts.isEmpty
                        ? ListView(
                          children: const [
                            SizedBox(height: 120),
                            Center(child: Text('Aucun short pour le moment.')),
                          ],
                        )
                        : PageView.builder(
                          scrollDirection: Axis.vertical,
                          itemCount: _posts.length,
                          itemBuilder: (_, i) {
                            final post = _postAt(i);
                            return InkWell(
                              onTap: () => _openPost(post),
                              child: Container(
                                color: Colors.black,
                                padding: const EdgeInsets.all(20),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      Icons.play_circle_fill,
                                      size: 72,
                                      color: Colors.white70,
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      post['title']?.toString() ?? 'Short',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 20,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      post['author_display']?.toString() ??
                                          post['author']?.toString() ??
                                          '',
                                      style: const TextStyle(
                                        color: Colors.white70,
                                      ),
                                    ),
                                    const SizedBox(height: 24),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        IconButton(
                                          onPressed: () => _toggleLike(post),
                                          icon: Icon(
                                            post['liked_by_me'] == true
                                                ? Icons.favorite
                                                : Icons.favorite_border,
                                            color: Colors.white,
                                          ),
                                        ),
                                        Text(
                                          '${post['like_count'] ?? 0}',
                                          style: const TextStyle(
                                            color: Colors.white,
                                          ),
                                        ),
                                        IconButton(
                                          onPressed:
                                              () => _openPost(
                                                post,
                                                openComments: true,
                                              ),
                                          icon: const Icon(
                                            Icons.comment_outlined,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _upload,
        icon: const Icon(Icons.upload),
        label: const Text('Vidéo'),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: _posts.length + 1,
          itemBuilder: (_, i) {
            if (i == 0) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final category
                        in const <String, String>{
                          '': 'Tous',
                          'sols': 'Sols',
                          'nasa': 'NASA',
                          'sig': 'SIG',
                          'formation': 'Formation',
                          'autre': 'Autre',
                        }.entries)
                      ChoiceChip(
                        label: Text(category.value),
                        selected: _category == category.key,
                        onSelected: (_) {
                          if (_category == category.key) return;
                          setState(() => _category = category.key);
                          _load();
                        },
                      ),
                  ],
                ),
              );
            }
            final post = _postAt(i - 1);
            final favorite =
                post['is_favorite'] == true || post['favorited_by_me'] == true;
            return Card(
              child: ListTile(
                leading: const Icon(Icons.videocam),
                title: Text(post['title']?.toString() ?? 'Vidéo'),
                subtitle: Text(
                  post['author_display']?.toString() ??
                      post['category']?.toString() ??
                      '',
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(
                        post['liked_by_me'] == true
                            ? Icons.favorite
                            : Icons.favorite_border,
                      ),
                      onPressed: () => _toggleLike(post),
                    ),
                    IconButton(
                      icon: Icon(
                        favorite ? Icons.bookmark : Icons.bookmark_border,
                      ),
                      onPressed: () => _toggleFavorite(post),
                    ),
                  ],
                ),
                onTap: () => _openPost(post),
              ),
            );
          },
        ),
      ),
    );
  }
}
