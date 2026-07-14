import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/sig_api.dart';
import '../../shared/widgets/error_view.dart';
import '../../shared/widgets/loading_view.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<dynamic> _items = [];
  bool _loading = true;
  String? _error;

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
      final items = await context.read<SigApi>().fetchNotifications();
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          IconButton(
            icon: const Icon(Icons.done_all),
            tooltip: 'Tout marquer lu',
            onPressed: () async {
              await context.read<SigApi>().markAllNotificationsRead();
              _load();
            },
          ),
        ],
      ),
      body: _loading
          ? const LoadingView()
          : _error != null
              ? ErrorView(message: _error!, onRetry: _load)
              : _items.isEmpty
                  ? const Center(child: Text('Aucune notification'))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.builder(
                        itemCount: _items.length,
                        itemBuilder: (_, i) {
                          final n = Map<String, dynamic>.from(_items[i] as Map);
                          final read = n['is_read'] == true;
                          final message =
                              n['message']?.toString() ??
                              n['body']?.toString() ??
                              '';
                          return ListTile(
                            leading: Icon(read ? Icons.notifications : Icons.notifications_active),
                            title: Text(n['title']?.toString() ?? '—'),
                            subtitle: Text(
                              message.isNotEmpty
                                  ? message
                                  : (n['created_at']?.toString() ?? ''),
                            ),
                            onTap: () async {
                              final id = n['id'] as int?;
                              if (id != null) {
                                await context.read<SigApi>().markNotificationRead(id);
                                _load();
                              }
                            },
                          );
                        },
                      ),
                    ),
    );
  }
}
