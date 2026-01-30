import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/websocket_connection.dart';
import '../../core/repositories/websocket_repository.dart';

class WebSocketConnectionFormScreen extends ConsumerStatefulWidget {
  final String? connectionId;

  const WebSocketConnectionFormScreen({super.key, this.connectionId});

  @override
  ConsumerState<WebSocketConnectionFormScreen> createState() =>
      _WebSocketConnectionFormScreenState();
}

class _WebSocketConnectionFormScreenState extends ConsumerState<WebSocketConnectionFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _urlController = TextEditingController();
  final _protocolController = TextEditingController();
  final _headersController = TextEditingController();
  final _queryParamsController = TextEditingController();

  bool _isLoading = false;
  WebSocketConnection? _existingConnection;

  @override
  void initState() {
    super.initState();
    _loadExistingConnection();
  }

  Future<void> _loadExistingConnection() async {
    if (widget.connectionId == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final repository = ref.read(webSocketRepositoryProvider);
      final connection = await repository.getConnection(widget.connectionId!);

      if (connection != null) {
        _existingConnection = connection;
        _nameController.text = connection.name;
        _urlController.text = connection.url;
        _protocolController.text = connection.protocol ?? '';
        _headersController.text = _mapToString(connection.headers);
        _queryParamsController.text = _mapToString(connection.queryParams);
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  String _mapToString(Map<String, dynamic>? map) {
    if (map == null || map.isEmpty) return '';
    return map.entries.map((e) => '${e.key}: ${e.value}').join('\n');
  }

  Map<String, dynamic>? _stringToMap(String text) {
    if (text.trim().isEmpty) return null;

    final lines = text.trim().split('\n');
    final map = <String, dynamic>{};

    for (final line in lines) {
      final parts = line.split(':');
      if (parts.length >= 2) {
        final key = parts[0].trim();
        final value = parts.sublist(1).join(':').trim();
        map[key] = value;
      }
    }

    return map.isNotEmpty ? map : null;
  }

  Future<void> _saveConnection() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final repository = ref.read(webSocketRepositoryProvider);

      final connection = WebSocketConnection.create(
        name: _nameController.text.trim(),
        url: _urlController.text.trim(),
        protocol: _protocolController.text.trim().isNotEmpty ? _protocolController.text.trim() : null,
        headers: _stringToMap(_headersController.text) as Map<String, String>?,
        queryParams: _stringToMap(_queryParamsController.text),
      );

      if (_existingConnection != null) {
        connection.id = _existingConnection!.id;
        connection.createdAt = _existingConnection!.createdAt;
        connection.lastConnectedAt = _existingConnection!.lastConnectedAt;
        connection.isFavorite = _existingConnection!.isFavorite;
      }

      await repository.saveConnection(connection);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_existingConnection == null ? '连接已创建' : '连接已更新'),
            backgroundColor: Colors.green,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('保存失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_existingConnection == null ? '新建 WebSocket 连接' : '编辑 WebSocket 连接'),
        actions: [
          if (_existingConnection != null)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('删除连接'),
                    content: const Text('确定要删除这个连接吗？'),
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
                  await repository.deleteConnection(_existingConnection!.id);
                  if (mounted) {
                    context.pop();
                  }
                }
              },
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: '连接名称',
                        hintText: '例如：WebSocket 服务器',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return '请输入连接名称';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _urlController,
                      decoration: const InputDecoration(
                        labelText: 'WebSocket URL',
                        hintText: '例如：ws://localhost:8080/ws',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return '请输入 WebSocket URL';
                        }
                        if (!value.startsWith('ws://') && !value.startsWith('wss://')) {
                          return 'URL 必须以 ws:// 或 wss:// 开头';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _protocolController,
                      decoration: const InputDecoration(
                        labelText: '协议（可选）',
                        hintText: '例如：chat, echo',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '请求头（可选）',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              '每行一个键值对，格式：键: 值',
                              style: TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _headersController,
                              decoration: const InputDecoration(
                                hintText: '例如：\nAuthorization: Bearer token\nUser-Agent: xTerm',
                                border: OutlineInputBorder(),
                              ),
                              maxLines: 4,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '查询参数（可选）',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              '每行一个键值对，格式：键: 值',
                              style: TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _queryParamsController,
                              decoration: const InputDecoration(
                                hintText: '例如：\ntoken: abc123\nversion: 1.0',
                                border: OutlineInputBorder(),
                              ),
                              maxLines: 4,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _saveConnection,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(_existingConnection == null ? '创建连接' : '更新连接'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _urlController.dispose();
    _protocolController.dispose();
    _headersController.dispose();
    _queryParamsController.dispose();
    super.dispose();
  }
}