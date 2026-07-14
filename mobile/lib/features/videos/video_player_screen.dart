import 'dart:io' show Platform, Process;

import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

import '../../core/auth/auth_service.dart';
import '../../core/config/env.dart';
import '../../core/theme/app_theme.dart';
import '../../services/sig_api.dart';

class VideoPlayerScreen extends StatefulWidget {
  const VideoPlayerScreen({
    super.key,
    this.post,
    this.videoUrl,
    this.title,
    this.openComments = false,
  }) : assert(post != null || videoUrl != null);

  final Map<String, dynamic>? post;
  final String? videoUrl;
  final String? title;
  final bool openComments;

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  late Map<String, dynamic> _post;
  String? _initializationError;
  String? _resolvedUrl;

  @override
  void initState() {
    super.initState();
    _post =
        widget.post == null
            ? <String, dynamic>{
              'title': widget.title,
              'file_url': widget.videoUrl,
            }
            : Map<String, dynamic>.from(widget.post!);
    _initializePlayer();
    if (widget.openComments) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _showComments());
    }
  }

  String get _mediaUrl {
    final raw =
        widget.videoUrl ??
        _post['file_url'] ??
        _post['video_url'] ??
        _post['media_url'] ??
        _post['file'];
    return Env.resolveMediaUrl(raw?.toString());
  }

  int? get _postId =>
      _post['id'] is int
          ? _post['id'] as int
          : int.tryParse(_post['id']?.toString() ?? '');

  Future<void> _initializePlayer() async {
    final url = _mediaUrl;
    _resolvedUrl = url;
    if (url.isEmpty) {
      setState(() => _initializationError = 'Vidéo indisponible (URL vide).');
      return;
    }
    try {
      final controller = VideoPlayerController.networkUrl(
        Uri.parse(url),
        httpHeaders: const {'Accept': '*/*'},
      );
      await controller.initialize().timeout(const Duration(seconds: 25));
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _initializationError = null;
        _videoController = controller;
        _chewieController = ChewieController(
          videoPlayerController: controller,
          autoPlay: true,
          looping: false,
          allowFullScreen: true,
          materialProgressColors: ChewieProgressColors(
            playedColor: AppTheme.gold500,
            handleColor: AppTheme.gold300,
            backgroundColor: AppTheme.emerald950,
            bufferedColor: AppTheme.emerald800,
          ),
        );
      });
    } catch (e) {
      if (!mounted) return;
      setState(
        () => _initializationError =
            'Impossible de charger cette vidéo.\n$e',
      );
    }
  }

  Future<void> _openExternally() async {
    final url = _resolvedUrl ?? _mediaUrl;
    if (url.isEmpty) return;
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
        if (ok) return;
      }
      if (Platform.isLinux) {
        await Process.run('xdg-open', [url]);
      }
    } catch (e) {
      if (mounted) {
        _showMessage('Ouverture externe impossible : $e');
      }
    }
  }

  Future<void> _deletePost() async {
    final id = _postId;
    if (id == null) return;
    final auth = context.read<AuthService>();
    final can =
        auth.user?.isAdmin == true ||
        _post['is_mine'] == true ||
        (_post['author_username']?.toString() == auth.user?.username);
    if (!can) return;
    final ok = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Supprimer cette publication ?'),
            content: const Text('Action définitive.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Annuler'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Supprimer'),
              ),
            ],
          ),
    );
    if (ok != true || !mounted) return;
    try {
      await context.read<SigApi>().deleteVideo(id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Publication supprimée.')),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) _showMessage('Suppression impossible : $e');
    }
  }

  Future<void> _toggleLike() async {
    final id = _postId;
    if (id == null) return;
    try {
      final response = await context.read<SigApi>().toggleVideoLike(id);
      if (!mounted) return;
      setState(() {
        _post['liked_by_me'] =
            response['liked'] ?? !(_post['liked_by_me'] == true);
        _post['like_count'] =
            response['like_count'] ?? _post['like_count'] ?? 0;
      });
    } catch (e) {
      if (mounted) _showMessage('Impossible d’aimer la vidéo : $e');
    }
  }

  Future<void> _showComments() async {
    final id = _postId;
    if (id == null) {
      _showMessage(
        'Les commentaires ne sont pas disponibles pour cette vidéo.',
      );
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _CommentsSheet(postId: id),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    _chewieController?.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = _post['title']?.toString() ?? widget.title ?? 'Vidéo';
    final author =
        _post['author_display']?.toString() ??
        _post['author_username']?.toString() ??
        '';
    final likes = _post['like_count'] ?? 0;
    final canEngage = _postId != null;
    final auth = context.watch<AuthService>();
    final canDelete =
        auth.isAuthenticated &&
        (auth.user?.isAdmin == true ||
            _post['is_mine'] == true ||
            _post['author_username']?.toString() == auth.user?.username);

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          if (canDelete)
            IconButton(
              tooltip: 'Supprimer',
              onPressed: _deletePost,
              icon: const Icon(Icons.delete_outline),
            ),
          if (_resolvedUrl != null && _resolvedUrl!.isNotEmpty)
            IconButton(
              tooltip: 'Ouvrir à l’extérieur',
              onPressed: _openExternally,
              icon: const Icon(Icons.open_in_new),
            ),
        ],
      ),
      body: ListView(
        children: [
          AspectRatio(
            aspectRatio: _videoController?.value.aspectRatio ?? 16 / 9,
            child:
                _chewieController != null
                    ? Chewie(controller: _chewieController!)
                    : ColoredBox(
                      color: Colors.black,
                      child: Center(
                        child:
                            _initializationError != null
                                ? Padding(
                                  padding: const EdgeInsets.all(24),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.videocam_off_outlined,
                                        color: AppTheme.gold300,
                                        size: 48,
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        _initializationError!,
                                        style: const TextStyle(
                                          color: Colors.white,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                      const SizedBox(height: 16),
                                      FilledButton.icon(
                                        onPressed: _openExternally,
                                        icon: const Icon(Icons.open_in_new),
                                        label: const Text(
                                          'Ouvrir dans le lecteur système',
                                        ),
                                      ),
                                      TextButton(
                                        onPressed: () {
                                          setState(() {
                                            _initializationError = null;
                                          });
                                          _initializePlayer();
                                        },
                                        child: const Text('Réessayer'),
                                      ),
                                    ],
                                  ),
                                )
                                : const CircularProgressIndicator(),
                      ),
                    ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.headlineSmall),
                if (author.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text('Par $author'),
                ],
                if ((_post['description']?.toString() ?? '').isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(_post['description'].toString()),
                ],
                const SizedBox(height: 8),
                Row(
                  children: [
                    IconButton(
                      tooltip: 'J’aime',
                      onPressed: canEngage ? _toggleLike : null,
                      icon: Icon(
                        _post['liked_by_me'] == true
                            ? Icons.favorite
                            : Icons.favorite_border,
                      ),
                    ),
                    Text('$likes'),
                    const SizedBox(width: 16),
                    TextButton.icon(
                      onPressed: canEngage ? _showComments : null,
                      icon: const Icon(Icons.comment_outlined),
                      label: Text(
                        '${_post['comment_count'] ?? 0} commentaires',
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

class _CommentsSheet extends StatefulWidget {
  const _CommentsSheet({required this.postId});

  final int postId;

  @override
  State<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<_CommentsSheet> {
  final TextEditingController _controller = TextEditingController();
  List<dynamic> _comments = [];
  bool _loading = true;
  bool _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  Future<void> _loadComments() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final comments = await context.read<SigApi>().fetchVideoComments(
        widget.postId,
      );
      if (mounted) {
        setState(() {
          _comments = comments;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '$e';
          _loading = false;
        });
      }
    }
  }

  Future<void> _sendComment() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await context.read<SigApi>().postVideoComment(widget.postId, text);
      _controller.clear();
      await _loadComments();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Impossible de publier : $e')));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _toggleCommentLike(Map<String, dynamic> comment) async {
    final id =
        comment['id'] is int
            ? comment['id'] as int
            : int.tryParse(comment['id']?.toString() ?? '');
    if (id == null) return;
    try {
      final response = await context.read<SigApi>().toggleCommentLike(id);
      if (!mounted) return;
      setState(() {
        comment['liked_by_me'] =
            response['liked'] ?? !(comment['liked_by_me'] == true);
        comment['like_count'] =
            response['like_count'] ?? comment['like_count'] ?? 0;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Impossible d’aimer ce commentaire : $e')),
        );
      }
    }
  }

  Map<String, dynamic> _commentAt(int index) {
    final value = _comments[index];
    if (value is Map<String, dynamic>) return value;
    final comment =
        value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};
    _comments[index] = comment;
    return comment;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          top: 16,
          left: 16,
          right: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * .72,
          child: Column(
            children: [
              Text(
                'Commentaires',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Expanded(
                child:
                    _loading
                        ? const Center(child: CircularProgressIndicator())
                        : _error != null
                        ? Center(child: Text('Erreur : $_error'))
                        : _comments.isEmpty
                        ? const Center(
                          child: Text('Aucun commentaire — soyez le premier.'),
                        )
                        : ListView.builder(
                          itemCount: _comments.length,
                          itemBuilder: (_, index) {
                            final comment = _commentAt(index);
                            return ListTile(
                              title: Text(comment['text']?.toString() ?? ''),
                              subtitle: Text(
                                comment['author_display']?.toString() ??
                                    comment['author_username']?.toString() ??
                                    '',
                              ),
                              trailing:
                                  comment['id'] == null
                                      ? null
                                      : Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text('${comment['like_count'] ?? 0}'),
                                          IconButton(
                                            onPressed:
                                                () =>
                                                    _toggleCommentLike(comment),
                                            icon: Icon(
                                              comment['liked_by_me'] == true
                                                  ? Icons.favorite
                                                  : Icons.favorite_border,
                                            ),
                                          ),
                                        ],
                                      ),
                            );
                          },
                        ),
              ),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        hintText: 'Ajouter un commentaire…',
                      ),
                      onSubmitted: (_) => _sendComment(),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Publier',
                    onPressed: _sending ? null : _sendComment,
                    icon:
                        _sending
                            ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                            : const Icon(Icons.send),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
