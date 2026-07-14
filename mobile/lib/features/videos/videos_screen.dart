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
      if (widget.kind == 'video') {
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
    try {
      final ok = await showDialog<bool>(
        context: context,
        builder:
            (_) => AlertDialog(
              title: Text(
                'Publier ${widget.kind == 'short' ? 'un short' : 'une vidéo'}',
              ),
              content: TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(labelText: 'Titre'),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Annuler'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Envoyer'),
                ),
              ],
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

    final hasStories = widget.kind == 'video' && _stories.isNotEmpty;
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: _posts.length + 1 + (hasStories ? 1 : 0),
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
                          'agriculture': 'Agriculture',
                          'education': 'Éducation',
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
            if (hasStories && i == 1) {
              return SizedBox(
                height: 104,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _stories.length + 1,
                  itemBuilder: (_, si) {
                    if (si == 0) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(36),
                          onTap: _uploadStory,
                          child: Column(
                            children: [
                              const CircleAvatar(
                                radius: 30,
                                child: Icon(Icons.add),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Ma story',
                                style: Theme.of(context).textTheme.labelSmall,
                              ),
                            ],
                          ),
                        ),
                      );
                    }
                    final s =
                        _stories[si - 1] is Map
                            ? Map<String, dynamic>.from(_stories[si - 1] as Map)
                            : <String, dynamic>{};
                    final thumbnail = Env.resolveMediaUrl(
                      s['thumbnail_url']?.toString() ??
                          s['image_url']?.toString() ??
                          s['media_url']?.toString() ??
                          s['file']?.toString(),
                    );
                    return Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(36),
                        onTap: () => _openStory(s),
                        child: Column(
                          children: [
                            CircleAvatar(
                              radius: 30,
                              backgroundImage:
                                  thumbnail.isEmpty
                                      ? null
                                      : CachedNetworkImageProvider(thumbnail),
                              child:
                                  thumbnail.isEmpty
                                      ? const Icon(Icons.auto_stories)
                                      : null,
                            ),
                            const SizedBox(height: 4),
                            SizedBox(
                              width: 64,
                              child: Text(
                                s['author_display']?.toString() ??
                                    s['author']?.toString() ??
                                    'Story',
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.labelSmall,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              );
            }
            final idx = i - 1 - (hasStories ? 1 : 0);
            final p = _postAt(idx);
            final thumb = Env.resolveMediaUrl(p['thumbnail_url']?.toString());
            final favorite =
                p['is_favorite'] == true || p['favorited_by_me'] == true;
            return Card(
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => _openPost(p),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (thumb.isNotEmpty)
                      CachedNetworkImage(
                        imageUrl: thumb,
                        height: widget.kind == 'short' ? 220 : 160,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorWidget:
                            (_, __, ___) => Container(
                              height: widget.kind == 'short' ? 220 : 160,
                              color: Colors.black26,
                              child: const Icon(Icons.videocam, size: 48),
                            ),
                      )
                    else
                      Container(
                        height: widget.kind == 'short' ? 220 : 160,
                        color:
                            Theme.of(
                              context,
                            ).colorScheme.surfaceContainerHighest,
                        child: const Center(
                          child: Icon(Icons.play_circle_outline, size: 56),
                        ),
                      ),
                    ListTile(
                      title: Text(p['title']?.toString() ?? 'Sans titre'),
                      subtitle: Text(
                        '${p['author_display'] ?? p['author_username'] ?? 'SIG Sols Togo'} · ${p['like_count'] ?? 0} j’aime',
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'J’aime',
                            icon: Icon(
                              p['liked_by_me'] == true
                                  ? Icons.favorite
                                  : Icons.favorite_border,
                            ),
                            onPressed: () => _toggleLike(p),
                          ),
                          IconButton(
                            tooltip: 'Favori',
                            icon: Icon(
                              favorite ? Icons.bookmark : Icons.bookmark_border,
                            ),
                            onPressed: () => _toggleFavorite(p),
                          ),
                          IconButton(
                            tooltip: 'Commentaires',
                            icon: const Icon(Icons.comment_outlined),
                            onPressed: () => _openPost(p, openComments: true),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _upload,
        icon: const Icon(Icons.upload),
        label: Text(
          widget.kind == 'short' ? 'Publier un short' : 'Publier une vidéo',
        ),
      ),
    );
  }
}
