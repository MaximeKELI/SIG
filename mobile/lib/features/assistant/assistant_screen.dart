import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../services/sig_api.dart';
import '../../shared/widgets/dusol_ui.dart';

class AssistantScreen extends StatefulWidget {
  const AssistantScreen({super.key});

  @override
  State<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends State<AssistantScreen> {
  final _ctrl = TextEditingController();
  final _messages = <Map<String, String>>[];
  Map<String, dynamic>? _status;
  bool _loading = false;
  bool _ready = false;

  static const _suggestions = [
    'Comment lire le NDVI sur ma parcelle ?',
    'pH acide : quelles corrections au Togo ?',
    'Interpréter une carte de fertilité',
  ];

  @override
  void initState() {
    super.initState();
    _checkStatus();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _checkStatus() async {
    try {
      final s = await context.read<SigApi>().assistantStatus();
      setState(() {
        _status = s;
        _ready = s['available'] == true;
      });
    } catch (e) {
      setState(() => _status = {'available': false, 'message': e.toString()});
    }
  }

  Future<void> _send([String? preset]) async {
    final text = (preset ?? _ctrl.text).trim();
    if (text.isEmpty || _loading || !_ready) return;
    if (preset == null) _ctrl.clear();
    setState(() {
      _messages.add({'role': 'user', 'content': text});
      _loading = true;
    });
    try {
      final res = await context.read<SigApi>().assistantChat(
            message: text,
            history: _messages.where((m) => m['role'] != 'system').toList(),
            context: {
              'view': 'mobile',
              'platform': 'flutter',
              'model': _status?['model'],
            },
          );
      setState(() {
        _messages.add({
          'role': 'assistant',
          'content':
              res['reply']?.toString() ?? res['message']?.toString() ?? '—',
        });
      });
    } catch (e) {
      setState(() {
        _messages.add({'role': 'assistant', 'content': 'Erreur Gemini: $e'});
      });
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: DusolHeroHeader(
            title: 'Assistant sols',
            subtitle: _ready
                ? 'Gemini ${_status?['model'] ?? ''} · conseils terrain'
                : 'Service momentanément indisponible',
          ),
        ),
        if (_status != null && !_ready)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Card(
              child: ListTile(
                leading: const Icon(Icons.info_outline, color: AppTheme.gold400),
                title: Text(
                  _status!['message']?.toString() ?? 'Clé API manquante',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ),
          ),
        Expanded(
          child: _messages.isEmpty
              ? ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text(
                      'Suggestions',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    for (var i = 0; i < _suggestions.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: OutlinedButton(
                          onPressed: _ready ? () => _send(_suggestions[i]) : null,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(_suggestions[i]),
                          ),
                        ).dusolEnter(index: i),
                      ),
                  ],
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _messages.length,
                  itemBuilder: (_, i) {
                    final m = _messages[i];
                    final isUser = m['role'] == 'user';
                    return Align(
                      alignment:
                          isUser ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.sizeOf(context).width * 0.82,
                        ),
                        decoration: BoxDecoration(
                          gradient: isUser
                              ? const LinearGradient(
                                  colors: [
                                    AppTheme.emerald800,
                                    AppTheme.emerald900,
                                  ],
                                )
                              : null,
                          color: isUser ? null : AppTheme.card,
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(16),
                            topRight: const Radius.circular(16),
                            bottomLeft: Radius.circular(isUser ? 16 : 4),
                            bottomRight: Radius.circular(isUser ? 4 : 16),
                          ),
                          border: Border.all(
                            color: AppTheme.gold500.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Text(
                          m['content'] ?? '',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Colors.white.withValues(alpha: 0.95),
                              ),
                        ),
                      ).dusolEnter(index: i),
                    );
                  },
                ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _ctrl,
                    enabled: _ready,
                    decoration: const InputDecoration(
                      hintText: 'Question sols, parcelles, NDVI…',
                      prefixIcon: Icon(Icons.chat_bubble_outline),
                    ),
                    onSubmitted: (_) => _send(),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _loading || !_ready ? null : () => _send(),
                  style: FilledButton.styleFrom(
                    shape: const CircleBorder(),
                    padding: const EdgeInsets.all(14),
                  ),
                  child: _loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send_rounded),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
