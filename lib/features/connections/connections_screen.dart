import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/ssh_connection.dart';
import '../../core/models/websocket_connection.dart';
import '../../core/providers/ssh_provider.dart';
import '../../core/providers/websocket_provider.dart';

class ConnectionsScreen extends ConsumerStatefulWidget {
  const ConnectionsScreen({super.key});

  @override
  ConsumerState<ConnectionsScreen> createState() => _ConnectionsScreenState();
}

class _ConnectionsScreenState extends ConsumerState<ConnectionsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedTab = 'all';

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

  Widget _buildConnectionCard(dynamic connection) {
    final isSsh = connection is SshConnection;
    final isWebSocket = connection is WebSocketConnection;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: Icon(
          isSsh ? Icons.computer : Icons.wifi,
          color: Theme.of(context).primaryColor,
        ),
        title: Text(connection.name),
        subtitle: Text(isSsh ? connection.connectionString : connection.url),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(
                connection.isFavorite ? Icons.star : Icons.star_border,
                color: connection.isFavorite ? Colors.amber : null,
              ),
              onPressed: () {
                // TODO: 切换收藏状态
              },
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
                final routePrefix = isSsh ? '/ssh' : '/websocket';
                switch (value) {
                  case 'connect':
                    context.push('$routePrefix/terminal/${connection.id}');
                    break;
                  case 'edit':
                    context.push('$routePrefix/edit/${connection.id}');
                    break;
                  case 'test':
                    // TODO: 测试连接
                    break;
                  case 'delete':
                    // TODO: 删除连接
                    break;
                }
              },
            ),
          ],
        ),
        onTap: () {
          final routePrefix = connection is SshConnection ? '/ssh' : '/websocket';
          context.push('$routePrefix/terminal/${connection.id}');
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sshConnectionsAsync = ref.watch(sshConnectionsProvider);
    final webSocketConnectionsAsync = ref.watch(webSocketConnectionsProvider);

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('连接管理'),
          bottom: TabBar(
            tabs: const [
              Tab(text: '全部'),
              Tab(text: 'SSH'),
              Tab(text: 'WebSocket'),
            ],
            onTap: (index) {
              setState(() {
                _selectedTab = ['all', 'ssh', 'websocket'][index];
              });
            },
          ),
          actions: [
            PopupMenuButton(
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'ssh',
                  child: ListTile(
                    leading: Icon(Icons.computer),
                    title: Text('新建 SSH 连接'),
                  ),
                ),
                const PopupMenuItem(
                  value: 'websocket',
                  child: ListTile(
                    leading: Icon(Icons.wifi),
                    title: Text('新建 WebSocket 连接'),
                  ),
                ),
              ],
              onSelected: (value) {
                switch (value) {
                  case 'ssh':
                    context.push('/ssh/new');
                    break;
                  case 'websocket':
                    context.push('/websocket/new');
                    break;
                }
              },
            ),
          ],
        ),
        body: Column(
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
              child: sshConnectionsAsync.when(
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
                data: (sshConnections) {
                  return webSocketConnectionsAsync.when(
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
                    data: (webSocketConnections) {
                      List<dynamic> connections;
                      switch (_selectedTab) {
                        case 'ssh':
                          connections = sshConnections;
                          break;
                        case 'websocket':
                          connections = webSocketConnections;
                          break;
                        default:
                          connections = [
                            ...sshConnections,
                            ...webSocketConnections,
                          ];
                      }

                      final filteredConnections = _searchQuery.isEmpty
                          ? connections
                          : connections.where((conn) {
                              return conn.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                                     (conn is SshConnection &&
                                         conn.host.toLowerCase().contains(_searchQuery.toLowerCase())) ||
                                     (conn is WebSocketConnection &&
                                         conn.url.toLowerCase().contains(_searchQuery.toLowerCase()));
                            }).toList();

                      if (filteredConnections.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.link_off, size: 64, color: Colors.grey),
                              const SizedBox(height: 16),
                              const Text(
                                '暂无连接',
                                style: TextStyle(color: Colors.grey),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                '点击右上角按钮创建新连接',
                                style: TextStyle(color: Colors.grey, fontSize: 12),
                              ),
                            ],
                          ),
                        );
                      }

                      return ListView.builder(
                        itemCount: filteredConnections.length,
                        itemBuilder: (context, index) {
                          return _buildConnectionCard(filteredConnections[index]);
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            showModalBottomSheet(
              context: context,
              builder: (context) => SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                      leading: const Icon(Icons.computer),
                      title: const Text('新建 SSH 连接'),
                      onTap: () {
                        Navigator.of(context).pop();
                        context.push('/ssh/new');
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.wifi),
                      title: const Text('新建 WebSocket 连接'),
                      onTap: () {
                        Navigator.of(context).pop();
                        context.push('/websocket/new');
                      },
                    ),
                  ],
                ),
              ),
            );
          },
          child: const Icon(Icons.add),
        ),
      ),
    );
  }
}