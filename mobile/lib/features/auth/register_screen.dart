import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/auth/auth_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _email = TextEditingController();
  final _first = TextEditingController();
  final _last = TextEditingController();
  final _pass = TextEditingController();
  final _pass2 = TextEditingController();
  final _phone = TextEditingController();
  final _org = TextEditingController();
  final _pseudo = TextEditingController();
  final _city = TextEditingController();
  String _role = 'public';
  String _region = 'Maritime';
  bool _consent = false;
  bool _loading = false;

  @override
  void dispose() {
    _username.dispose();
    _email.dispose();
    _first.dispose();
    _last.dispose();
    _pass.dispose();
    _pass2.dispose();
    _phone.dispose();
    _org.dispose();
    _pseudo.dispose();
    _city.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_consent) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Le consentement au suivi statistique est requis.'),
        ),
      );
      return;
    }
    setState(() => _loading = true);
    try {
      await context.read<AuthService>().register({
        'username': _username.text.trim(),
        'email': _email.text.trim(),
        'first_name': _first.text.trim(),
        'last_name': _last.text.trim(),
        'password': _pass.text,
        'password_confirm': _pass2.text,
        'role': _role,
        'region': _region,
        'phone': _phone.text.trim(),
        'organization': _org.text.trim(),
        'pseudonym': _pseudo.text.trim(),
        'city': _city.text.trim(),
        'consent_analytics': true,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Compte créé — connectez-vous')),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Inscription')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _first,
              decoration: const InputDecoration(labelText: 'Prénom *'),
              validator: (v) => v!.isEmpty ? 'Requis' : null,
            ),
            TextFormField(
              controller: _last,
              decoration: const InputDecoration(labelText: 'Nom *'),
              validator: (v) => v!.isEmpty ? 'Requis' : null,
            ),
            TextFormField(
              controller: _email,
              decoration: const InputDecoration(labelText: 'Email *'),
              validator:
                  (v) => v!.contains('@') ? null : 'Email invalide',
            ),
            TextFormField(
              controller: _username,
              decoration: const InputDecoration(labelText: 'Identifiant *'),
              validator:
                  (v) => v!.length >= 3 ? null : 'Min. 3 caractères',
            ),
            TextFormField(
              controller: _pseudo,
              decoration: const InputDecoration(
                labelText: 'Pseudonyme (quiz)',
              ),
            ),
            TextFormField(
              controller: _phone,
              decoration: const InputDecoration(labelText: 'Téléphone'),
              keyboardType: TextInputType.phone,
            ),
            TextFormField(
              controller: _org,
              decoration: const InputDecoration(labelText: 'Organisation'),
            ),
            TextFormField(
              controller: _city,
              decoration: const InputDecoration(labelText: 'Ville'),
            ),
            DropdownButtonFormField<String>(
              value: _role,
              decoration: const InputDecoration(labelText: 'Rôle'),
              items: const [
                DropdownMenuItem(value: 'public', child: Text('Public')),
                DropdownMenuItem(value: 'agent', child: Text('Agent')),
                DropdownMenuItem(
                  value: 'chercheur',
                  child: Text('Chercheur'),
                ),
              ],
              onChanged: (v) => setState(() => _role = v ?? 'public'),
            ),
            DropdownButtonFormField<String>(
              value: _region,
              decoration: const InputDecoration(labelText: 'Région'),
              items: const [
                DropdownMenuItem(
                  value: 'Maritime',
                  child: Text('Maritime'),
                ),
                DropdownMenuItem(
                  value: 'Plateaux',
                  child: Text('Plateaux'),
                ),
                DropdownMenuItem(
                  value: 'Centrale',
                  child: Text('Centrale'),
                ),
                DropdownMenuItem(value: 'Kara', child: Text('Kara')),
                DropdownMenuItem(
                  value: 'Savanes',
                  child: Text('Savanes'),
                ),
              ],
              onChanged: (v) => setState(() => _region = v ?? 'Maritime'),
            ),
            TextFormField(
              controller: _pass,
              decoration: const InputDecoration(labelText: 'Mot de passe *'),
              obscureText: true,
              validator:
                  (v) => v!.length >= 8 ? null : 'Min. 8 caractères',
            ),
            TextFormField(
              controller: _pass2,
              decoration: const InputDecoration(labelText: 'Confirmer *'),
              obscureText: true,
              validator:
                  (v) =>
                      v == _pass.text ? null : 'Les mots de passe diffèrent',
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _consent,
              onChanged: (v) => setState(() => _consent = v ?? false),
              title: const Text(
                'J’accepte le suivi statistique de mon activité (requis)',
              ),
              controlAffinity: ListTileControlAffinity.leading,
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _loading ? null : _submit,
              child:
                  _loading
                      ? const CircularProgressIndicator()
                      : const Text('Créer le compte'),
            ),
          ],
        ),
      ),
    );
  }
}
