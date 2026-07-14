import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import '../../core/auth/auth_service.dart';
import '../../core/config/env.dart';
import '../../core/offline/offline_sync_service.dart';
import '../../services/sig_api.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _dbInfo;
  String? _dbStatus;
  bool _photoBusy = false;

  @override
  void initState() {
    super.initState();
    _loadHealth();
  }

  Future<void> _loadHealth() async {
    try {
      final health = await context.read<SigApi>().fetchSystemHealth();
      if (!mounted) return;
      final checks = health['checks'] as Map<String, dynamic>?;
      setState(() {
        _dbStatus = checks?['database']?.toString();
        _dbInfo = checks?['database_info'] != null
            ? Map<String, dynamic>.from(checks!['database_info'] as Map)
            : null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _dbStatus = 'indisponible');
    }
  }

  Future<void> _editProfile(AuthService auth) async {
    final user = auth.user!;
    final first = TextEditingController(text: user.firstName ?? '');
    final last = TextEditingController(text: user.lastName ?? '');
    final bio = TextEditingController(text: user.bio ?? '');
    final phone = TextEditingController(text: user.phone ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Modifier le profil'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: first, decoration: const InputDecoration(labelText: 'Prénom')),
              TextField(controller: last, decoration: const InputDecoration(labelText: 'Nom')),
              TextField(controller: phone, decoration: const InputDecoration(labelText: 'Téléphone')),
              TextField(controller: bio, decoration: const InputDecoration(labelText: 'Bio'), maxLines: 3),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Enregistrer')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      final client = context.read<ApiClient>();
      final data = await client.updateProfile({
        'first_name': first.text.trim(),
        'last_name': last.text.trim(),
        'phone': phone.text.trim(),
        'bio': bio.text.trim(),
      });
      if (data['user'] != null) {
        await auth.refreshFromJson(Map<String, dynamic>.from(data['user'] as Map));
      } else {
        await auth.refreshFromJson(Map<String, dynamic>.from(data));
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profil mis à jour')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _changePassword() async {
    final oldP = TextEditingController();
    final newP = TextEditingController();
    final confirmP = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Changer le mot de passe'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: oldP, obscureText: true, decoration: const InputDecoration(labelText: 'Ancien')),
            TextField(controller: newP, obscureText: true, decoration: const InputDecoration(labelText: 'Nouveau')),
            TextField(
              controller: confirmP,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Confirmer'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Valider')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    if (newP.text != confirmP.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Les mots de passe ne correspondent pas.')),
      );
      return;
    }
    try {
      await context.read<SigApi>().changePassword(
        oldPassword: oldP.text,
        newPassword: newP.text,
        newPasswordConfirm: confirmP.text,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Mot de passe changé')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _uploadPhoto(AuthService auth) async {
    final pick = await FilePicker.platform.pickFiles(type: FileType.image);
    if (pick == null || pick.files.single.path == null || !mounted) return;
    setState(() => _photoBusy = true);
    try {
      final data = await context.read<ApiClient>().uploadProfilePhoto(pick.files.single.path!);
      await auth.refreshFromJson(Map<String, dynamic>.from(data));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Photo mise à jour')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _photoBusy = false);
    }
  }

  Future<void> _deletePhoto(AuthService auth) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Supprimer la photo'),
        content: const Text('Retirer votre photo de profil ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Supprimer')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _photoBusy = true);
    try {
      final data = await context.read<SigApi>().deleteProfilePhoto();
      await auth.refreshFromJson(Map<String, dynamic>.from(data));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Photo supprimée')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _photoBusy = false);
    }
  }

  Future<void> _showTrajectory() async {
    try {
      final r = await context.read<SigApi>().fetchTrajectory();
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Trajectoire 24h'),
          content: Text('${(r['points'] as List?)?.length ?? 0} position(s) enregistrée(s)'),
        ),
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Widget _avatar(AuthService auth) {
    final user = auth.user;
    final photoUrl = Env.resolveMediaUrl(user?.profilePhotoUrl);
    final letter = (user?.displayName ?? '?')[0].toUpperCase();
    return CircleAvatar(
      radius: 40,
      backgroundImage: photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
      child: _photoBusy
          ? const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : (photoUrl.isEmpty
              ? Text(letter, style: const TextStyle(fontSize: 32))
              : null),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final sync = context.watch<OfflineSyncService>();
    final user = auth.user;
    final hasPhoto = (user?.profilePhotoUrl ?? '').isNotEmpty;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        GestureDetector(
          onTap: _photoBusy ? null : () => _uploadPhoto(auth),
          child: _avatar(auth),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextButton(
              onPressed: _photoBusy ? null : () => _uploadPhoto(auth),
              child: const Text('Changer la photo'),
            ),
            if (hasPhoto)
              TextButton(
                onPressed: _photoBusy ? null : () => _deletePhoto(auth),
                child: const Text('Supprimer'),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(user?.displayName ?? '', style: Theme.of(context).textTheme.headlineSmall, textAlign: TextAlign.center),
        Text('@${user?.username ?? ''} · ${user?.role ?? ''}', textAlign: TextAlign.center),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextButton.icon(onPressed: () => _editProfile(auth), icon: const Icon(Icons.edit), label: const Text('Modifier')),
            TextButton.icon(onPressed: _changePassword, icon: const Icon(Icons.lock), label: const Text('Mot de passe')),
          ],
        ),
        if (user?.email != null) ListTile(leading: const Icon(Icons.email), title: Text(user!.email!)),
        if (user?.phone != null) ListTile(leading: const Icon(Icons.phone), title: Text(user!.phone!)),
        if (user?.region != null) ListTile(leading: const Icon(Icons.place), title: Text(user!.region!)),
        if (user?.bio != null && user!.bio!.isNotEmpty)
          ListTile(leading: const Icon(Icons.info), title: Text(user.bio!)),
        ListTile(
          leading: const Icon(Icons.timeline),
          title: const Text('Ma trajectoire'),
          onTap: _showTrajectory,
        ),
        const Divider(),
        ListTile(leading: const Icon(Icons.api), title: const Text('API backend'), subtitle: Text(Env.apiBaseUrl)),
        if (sync.pendingCount > 0)
          ListTile(
            leading: const Icon(Icons.cloud_upload),
            title: Text('${sync.pendingCount} point(s) en attente'),
            trailing: IconButton(icon: const Icon(Icons.sync), onPressed: () => sync.sync()),
          ),
        ListTile(
          leading: Icon(_dbStatus == 'ok' ? Icons.check_circle : Icons.storage, color: _dbStatus == 'ok' ? Colors.green : null),
          title: const Text('Base de données'),
          subtitle: Text(_dbInfo != null
              ? '${_dbInfo!['backend']} · ${_dbInfo!['name']} — partagée avec le web'
              : _dbStatus ?? 'Vérification…'),
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: () async {
            await auth.logout();
            if (context.mounted) context.go('/login');
          },
          icon: const Icon(Icons.logout),
          label: const Text('Déconnexion'),
        ),
      ],
    );
  }
}
