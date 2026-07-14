import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/auth/auth_service.dart';
import '../../core/config/env.dart';
import '../../core/i18n/locale_service.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/dusol_ui.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _loading = false;
  bool _obscure = true;
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
    final dark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: DusolAtmosphere(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Column(
                  children: [
                    Image.asset(
                      'assets/images/logo-dusol.png',
                      height: 88,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.landscape_rounded,
                        size: 88,
                        color: AppTheme.gold500,
                      ),
                    ).dusolPop(),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      Env.appName,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.displaySmall,
                    ).dusolEnter(),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'DUSOL · DISIA · Région Maritime',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${Env.developer} · ${Env.developerPhone}',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: AppTheme.gold400,
                          ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      decoration: BoxDecoration(
                        borderRadius: AppRadius.card,
                        color: dark
                            ? AppTheme.card.withValues(alpha: 0.85)
                            : Colors.white.withValues(alpha: 0.92),
                        border: Border.all(
                          color: AppTheme.gold500.withValues(alpha: 0.22),
                        ),
                        boxShadow: AppTheme.softShadow,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Connexion',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: AppSpacing.md),
                          TextField(
                            controller: _userCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Utilisateur',
                              prefixIcon: Icon(Icons.person_outline),
                            ),
                            textInputAction: TextInputAction.next,
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          TextField(
                            controller: _passCtrl,
                            decoration: InputDecoration(
                              labelText: 'Mot de passe',
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                onPressed: () =>
                                    setState(() => _obscure = !_obscure),
                                icon: Icon(
                                  _obscure
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                ),
                              ),
                            ),
                            obscureText: _obscure,
                            onSubmitted: (_) => _login(),
                          ),
                          if (_error != null) ...[
                            const SizedBox(height: AppSpacing.sm),
                            Text(
                              _error!,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                                fontSize: 13,
                              ),
                            ),
                          ],
                          const SizedBox(height: AppSpacing.lg),
                          FilledButton(
                            onPressed: _loading ? null : _login,
                            child: _loading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : Text(i18n.t('auth.login')),
                          ),
                        ],
                      ),
                    ).dusolEnter(index: 1),
                    const SizedBox(height: AppSpacing.md),
                    TextButton(
                      onPressed: () => context.push('/register'),
                      child: Text(i18n.t('auth.register')),
                    ),
                    TextButton(
                      onPressed: () => context.push('/forgot-password'),
                      child: Text(i18n.t('auth.forgot')),
                    ),
                    OutlinedButton(
                      onPressed: () => context.go('/'),
                      child: const Text('Continuer sans compte'),
                    ).dusolEnter(index: 2),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
