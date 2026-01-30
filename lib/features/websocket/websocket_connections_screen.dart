import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/websocket_connection.dart';
import '../../core/providers/websocket_provider.dart';
import '../../core/repositories/websocket_repository.dart';
import 'websocket_connection_form_screen.dart';
import 'websocket_terminal_screen.dart';

class WebSocketConnectionsScreen extends ConsumerStatefulWidget {
  const WebSocketConnectionsScreen({super.key});

  @override
  ConsumerState<WebSocketConnectionsScreen> createState() => _WebSocketConnectionsScreenState();
}

class _WebSocketConnectionsScreenState extends ConsumerState<WebSocketConnectionsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _deleteConnection(WebSocketConnection connection) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除连接'),
        content: Text('确定要删除连接 "${connection.name}" 吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final repository = ref.read(webSocketRepositoryProvider);
      await repository.deleteConnection(connection.id);
      setState(() {});
    }
  }

  Future<void> _toggleFavorite(WebSocketConnection connection) async {
    final repository = ref.read(webSocketRepositoryProvider);
    await repository.markAsFavorite(connection.id, !connection.isFavorite);
    setState(() {});
  }

  Future<void> _testConnection(WebSocketConnection connection) async {
    final notifier = ref.read(webSocketConnectionNotifierProvider.notifier);
    final result = await notifier.testConnection(connection);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(result['success'] ? '连接测试成功' : '连接测试失败'),
        content: Text(result['message']),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final connectionsAsync = ref.watch(webSocketConnectionsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('WebSocket 连接管理'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              context.push('/websocket/new');
            },
          ),
        ],
      ),
      body: connectionsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text('加载失败: $error'),
            ],
          ),
        ),
        data: (connections) {
          final filteredConnections = _searchQuery.isEmpty
              ? connections
              : connections.where((conn) {
                  return conn.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                         conn.url.toLowerCase().contains(_searchQuery.toLowerCase());
                }).toList();

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: '搜索连接...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: filteredConnections.length,
                  itemBuilder: (context, index) {
                    final connection = filteredConnections[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: ListTile(
                        leading: Icon(
                          Icons.wifi,
                          color: Theme.of(context).primaryColor,
                        ),
                        title: Text(connection.name),
                        subtitle: Text(connection.url),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(
                                connection.isFavorite ? Icons.star : Icons.star_border,
                                color: connection.isFavorite ? Colors.amber : null,
                              ),
                              onPressed: () => _toggleFavorite(connection),
                            ),
                            PopupMenuButton(
                              itemBuilder: (context) => [
                                const PopupMenuItem(
                                  value: 'connect',
                                  child: ListTile(
                                    leading: Icon(Icons.play_arrow),
                                    title: Text('连接'),
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'edit',
                                  child: ListTile(
                                    leading: Icon(Icons.edit),
                                    title: Text('编辑'),
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'test',
                                  child: ListTile(
                                    leading: Icon(Icons.wifi),
                                    title: Text('测试连接'),
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'delete',
                                  child: ListTile(
                                    leading: Icon(Icons.delete, color: Colors.red),
                                    title: Text('删除', style: TextStyle(color: Colors.red)),
                                  ),
                                ),
                              ],
                              onSelected: (value) {
                                switch (value) {
                                  case 'connect':
                                    context.push('/websocket/terminal/${connection.id}');
                                    break;
                                  case 'edit':
                                    context.push('/websocket/edit/${connection.id}');
                                    break;
                                  case 'test':
                                    _testConnection(connection);
                                    break;
                                  case 'delete':
                                    _deleteConnection(connection);
                                    break;
                                }
                              },
                            ),
                          ],
                        ),
                        onTap: () {
                          context.push('/websocket/terminal/${connection.id}');
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          context.push('/websocket/new');
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}