import 'package:cached_network_image/cached_network_image.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/auth/auth_service.dart';
import '../../core/config/env.dart';
import '../../core/theme/app_theme.dart';
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
  bool _uploading = false;
  String? _error;
  String _category = '';

  bool get _isShort => widget.kind == 'short';

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
      if (_isShort) {
        stories = await api.fetchStories().catchError((_) => <dynamic>[]);
      }
      if (!mounted) return;
      setState(() {
        _posts = posts;
        _stories = stories;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<bool> _ensureAuth() async {
    final loggedIn = context.read<AuthService>().isAuthenticated;
    if (loggedIn) return true;
    final go = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Connexion requise'),
            content: const Text(
              'Connectez-vous pour publier une vidéo ou un short.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Annuler'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Se connecter'),
              ),
            ],
          ),
    );
    if (go == true && mounted) context.go('/login');
    return false;
  }

  Future<_PickedMedia?> _pickVideo() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder:
          (ctx) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.videocam_outlined),
                  title: const Text('Filmer avec la caméra'),
                  onTap: () => Navigator.pop(ctx, 'camera'),
                ),
                ListTile(
                  leading: const Icon(Icons.video_library_outlined),
                  title: const Text('Choisir dans la galerie'),
                  onTap: () => Navigator.pop(ctx, 'gallery'),
                ),
                ListTile(
                  leading: const Icon(Icons.folder_open_outlined),
                  title: const Text('Fichier (explorateur)'),
                  onTap: () => Navigator.pop(ctx, 'file'),
                ),
              ],
            ),
          ),
    );
    if (choice == null) return null;

    try {
      if (choice == 'camera' || choice == 'gallery') {
        final picker = ImagePicker();
        final x = await picker.pickVideo(
          source:
              choice == 'camera' ? ImageSource.camera : ImageSource.gallery,
          maxDuration: _isShort ? const Duration(seconds: 60) : null,
        );
        if (x == null) return null;
        final path = x.path;
        final bytes = path.isEmpty ? await x.readAsBytes() : null;
        return _PickedMedia(
          path: path.isEmpty ? null : path,
          bytes: bytes,
          name: x.name,
        );
      }

      final result = await FilePicker.platform.pickFiles(
        type: FileType.video,
        withData: true,
      );
      if (result == null || result.files.isEmpty) return null;
      final f = result.files.single;
      return _PickedMedia(
        path: f.path,
        bytes: f.bytes,
        name: f.name,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Impossible de sélectionner la vidéo : $e')),
        );
      }
      return null;
    }
  }

  Future<void> _upload() async {
    if (!await _ensureAuth()) return;
    final media = await _pickVideo();
    if (!mounted || media == null) return;
    if (media.path == null && media.bytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fichier inaccessible sur cet appareil.')),
      );
      return;
    }

    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final tagsCtrl = TextEditingController();
    var category = 'sols';
    try {
      final ok = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (ctx) {
          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 8,
              bottom: MediaQuery.viewInsetsOf(ctx).bottom + 20,
            ),
            child: StatefulBuilder(
              builder: (ctx, setLocal) {
                return SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        _isShort ? 'Publier un short' : 'Publier une vidéo',
                        style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Fichier : ${media.name}',
                        style: Theme.of(ctx).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: titleCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Titre *',
                        ),
                        textCapitalization: TextCapitalization.sentences,
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: descCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Description',
                        ),
                        maxLines: 3,
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        initialValue: category,
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
                      const SizedBox(height: 10),
                      TextField(
                        controller: tagsCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Hashtags',
                          hintText: 'sols, nasa, ndvi',
                        ),
                      ),
                      const SizedBox(height: 18),
                      FilledButton.icon(
                        onPressed: () => Navigator.pop(ctx, true),
                        icon: const Icon(Icons.cloud_upload_outlined),
                        label: const Text('Envoyer pour validation'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Annuler'),
                      ),
                    ],
                  ),
                );
              },
            ),
          );
        },
      );
      if (!mounted || ok != true) return;

      setState(() => _uploading = true);
      await context.read<SigApi>().uploadVideo(
        kind: widget.kind,
        title:
            titleCtrl.text.trim().isEmpty
                ? 'Sans titre'
                : titleCtrl.text.trim(),
        description: descCtrl.text.trim(),
        category: category,
        tags: tagsCtrl.text.trim().replaceAll('#', '').replaceAll(' ', ','),
        filePath: media.path,
        fileBytes: media.bytes,
        fileName: media.name,
        durationSeconds: _isShort ? 60 : null,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Publication envoyée — en attente de validation admin.',
          ),
        ),
      );
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Échec publication : $e')));
      }
    } finally {
      titleCtrl.dispose();
      descCtrl.dispose();
      tagsCtrl.dispose();
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _uploadStory() async {
    if (!await _ensureAuth()) return;
    final picker = ImagePicker();
    final x = await picker.pickMedia();
    if (!mounted || x == null) return;
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
      setState(() => _uploading = true);
      final api = context.read<SigApi>();
      final path = x.path;
      final bytes = path.isEmpty ? await x.readAsBytes() : null;
      await api.uploadStory(
        caption: caption.text.trim(),
        filePath: path.isEmpty ? null : path,
        fileBytes: bytes,
        fileName: x.name,
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
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _toggleLike(Map<String, dynamic> post) async {
    if (!await _ensureAuth()) return;
    if (!mounted) return;
    final id = _idOf(post);
    if (id == null) return;
    final api = context.read<SigApi>();
    try {
      final result = await api.toggleVideoLike(id);
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
    if (!await _ensureAuth()) return;
    if (!mounted) return;
    final id = _idOf(post);
    if (id == null) return;
    final wasFavorite =
        post['is_favorite'] == true || post['favorited_by_me'] == true;
    final api = context.read<SigApi>();
    try {
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

  String _thumbUrl(Map<String, dynamic> post) => Env.resolveMediaUrl(
    post['thumbnail_url']?.toString() ?? '',
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

    return Stack(
      children: [
        Scaffold(
          floatingActionButton: FloatingActionButton.extended(
            onPressed: _uploading ? null : _upload,
            backgroundColor: AppTheme.gold500,
            foregroundColor: AppTheme.emerald950,
            icon: Icon(_isShort ? Icons.bolt : Icons.videocam),
            label: Text(_isShort ? 'Publier short' : 'Publier vidéo'),
          ),
          body:
              _isShort
                  ? _buildShortsBody()
                  : RefreshIndicator(
                    onRefresh: _load,
                    child: _buildVideosBody(),
                  ),
        ),
        if (_uploading)
          const ColoredBox(
            color: Color(0x66000000),
            child: Center(
              child: Card(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 14),
                      Text('Envoi en cours…'),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildVideosBody() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      itemCount: _posts.length + 2,
      itemBuilder: (_, i) {
        if (i == 0) return _heroHeader();
        if (i == 1) return _categoryChips();
        final post = _postAt(i - 2);
        return _videoCard(post);
      },
    );
  }

  Widget _buildShortsBody() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: _heroHeader(),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _storiesStrip(),
        ),
        Expanded(
          child:
              _posts.isEmpty
                  ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: const [
                      SizedBox(height: 80),
                      Center(child: Text('Aucun short pour le moment.')),
                    ],
                  )
                  : PageView.builder(
                    scrollDirection: Axis.vertical,
                    itemCount: _posts.length,
                    itemBuilder: (_, i) => _shortPage(_postAt(i)),
                  ),
        ),
      ],
    );
  }

  Widget _heroHeader() {
    final title = _isShort ? 'Shorts' : 'Vidéos communauté';
    final sub =
        _isShort
            ? 'Format court ≤ 60 s · stories 24 h'
            : 'Reportages sols, NASA & SIG — modération admin';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppTheme.emerald900, AppTheme.emerald950, Color(0xFF1A2F24)],
        ),
        border: Border.all(color: AppTheme.gold500.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontFamily: AppTheme.fontDisplay,
                    color: AppTheme.gold300,
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                onPressed: _load,
                tooltip: 'Actualiser',
                icon: const Icon(Icons.refresh, color: AppTheme.gold300),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(sub, style: TextStyle(color: Colors.white.withValues(alpha: 0.78))),
        ],
      ),
    );
  }

  Widget _categoryChips() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
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
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(category.value),
                  selected: _category == category.key,
                  onSelected: (_) {
                    if (_category == category.key) return;
                    setState(() => _category = category.key);
                    _load();
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _storiesStrip() {
    return SizedBox(
      height: 112,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(bottom: 12),
        itemCount: _stories.length + 1,
        itemBuilder: (_, si) {
          if (si == 0) {
            return Padding(
              padding: const EdgeInsets.only(right: 12),
              child: InkWell(
                onTap: _uploadStory,
                borderRadius: BorderRadius.circular(40),
                child: Column(
                  children: [
                    Container(
                      width: 68,
                      height: 68,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: AppTheme.gold500, width: 2),
                        color: AppTheme.emerald800,
                      ),
                      child: const Icon(Icons.add, color: AppTheme.gold300),
                    ),
                    const SizedBox(height: 6),
                    const Text('Story', style: TextStyle(fontSize: 12)),
                  ],
                ),
              ),
            );
          }
          final story = Map<String, dynamic>.from(_stories[si - 1] as Map);
          final label =
              (story['author_display'] ?? story['author'] ?? 'S').toString();
          return Padding(
            padding: const EdgeInsets.only(right: 12),
            child: InkWell(
              onTap: () => _openStory(story),
              child: Column(
                children: [
                  Container(
                    width: 68,
                    height: 68,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [AppTheme.gold500, AppTheme.emerald600],
                      ),
                      border: Border.all(color: Colors.white24, width: 2),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      label.isNotEmpty ? label[0].toUpperCase() : 'S',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontSize: 22,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  SizedBox(
                    width: 64,
                    child: Text(
                      label,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 11),
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

  Widget _videoCard(Map<String, dynamic> post) {
    final thumb = _thumbUrl(post);
    final favorite =
        post['is_favorite'] == true || post['favorited_by_me'] == true;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Theme.of(context).cardTheme.color,
        border: Border.all(color: AppTheme.gold500.withValues(alpha: 0.18)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openPost(post),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (thumb.isNotEmpty)
                    CachedNetworkImage(
                      imageUrl: thumb,
                      fit: BoxFit.cover,
                      errorWidget:
                          (_, __, ___) => Container(
                            color: AppTheme.emerald900,
                            child: const Icon(
                              Icons.videocam,
                              color: Colors.white54,
                              size: 48,
                            ),
                          ),
                    )
                  else
                    Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [AppTheme.emerald800, AppTheme.emerald950],
                        ),
                      ),
                      child: const Icon(
                        Icons.play_circle_outline,
                        size: 56,
                        color: AppTheme.gold300,
                      ),
                    ),
                  const Align(
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.play_circle_fill,
                      size: 58,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 8, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          post['title']?.toString() ?? 'Sans titre',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${post['author_display'] ?? post['author_username'] ?? 'SIG Sols'} · ${post['like_count'] ?? 0} j’aime',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => _toggleLike(post),
                    icon: Icon(
                      post['liked_by_me'] == true
                          ? Icons.favorite
                          : Icons.favorite_border,
                      color:
                          post['liked_by_me'] == true
                              ? Colors.redAccent
                              : null,
                    ),
                  ),
                  IconButton(
                    onPressed: () => _toggleFavorite(post),
                    icon: Icon(
                      favorite ? Icons.bookmark : Icons.bookmark_border,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _shortPage(Map<String, dynamic> post) {
    final thumb = _thumbUrl(post);
    return Container(
      margin: const EdgeInsets.fromLTRB(8, 0, 8, 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: Colors.black,
        border: Border.all(color: AppTheme.gold500.withValues(alpha: 0.25)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (thumb.isNotEmpty)
            CachedNetworkImage(imageUrl: thumb, fit: BoxFit.cover)
          else
            const ColoredBox(color: Colors.black87),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Colors.black87],
              ),
            ),
          ),
          InkWell(
            onTap: () => _openPost(post),
            child: const Center(
              child: Icon(
                Icons.play_circle_fill,
                size: 72,
                color: Colors.white70,
              ),
            ),
          ),
          Positioned(
            left: 18,
            right: 18,
            bottom: 28,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  post['title']?.toString() ?? 'Short',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  post['author_display']?.toString() ??
                      post['author']?.toString() ??
                      '',
                  style: const TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 12),
                Row(
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
                      style: const TextStyle(color: Colors.white),
                    ),
                    IconButton(
                      onPressed: () => _openPost(post, openComments: true),
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
        ],
      ),
    );
  }
}

class _PickedMedia {
  const _PickedMedia({this.path, this.bytes, required this.name});

  final String? path;
  final List<int>? bytes;
  final String name;
}
