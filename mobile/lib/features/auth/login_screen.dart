import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/auth/auth_service.dart';
import '../../core/config/env.dart';
import '../../core/i18n/locale_service.dart';
import '../../core/theme/app_theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _userCtrl = TextEditingController(text: 'admin');
  final _passCtrl = TextEditingController(text: 'admin123');
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _userCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await context.read<AuthService>().login(
            _userCtrl.text.trim(),
            _passCtrl.text,
          );
      if (mounted) context.go('/');
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final i18n = context.watch<LocaleService>();
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                children: [
                  Image.asset('assets/images/logo-dusol.png', height: 80, errorBuilder: (_, __, ___) => const Icon(Icons.map, size: 80, color: AppTheme.accent)),
                  const SizedBox(height: 16),
                  Text(Env.appName, style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 4),
                  Text('DUSOL · DISIA · Région Maritime',
                      style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 4),
                  Text('${Env.developer} · ${Env.developerPhone}',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppTheme.accent)),
                  const SizedBox(height: 32),
                  TextField(
                    controller: _userCtrl,
                    decoration: const InputDecoration(labelText: 'Utilisateur'),
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _passCtrl,
                    decoration: const InputDecoration(labelText: 'Mot de passe'),
                    obscureText: true,
                    onSubmitted: (_) => _login(),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(_error!, style: const TextStyle(color: Colors.redAccent)),
                  ],
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _loading ? null : _login,
                      child: _loading
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : Text(i18n.t('auth.login')),
                    ),
                  ),
                  TextButton(
                    onPressed: () => context.push('/register'),
                    child: Text(i18n.t('auth.register')),
                  ),
                  TextButton(
                    onPressed: () => context.push('/forgot-password'),
                    child: Text(i18n.t('auth.forgot')),
                  ),
                  TextButton(
                    onPressed: () => context.go('/'),
                    child: const Text('Continuer sans compte'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
