import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:xterm/xterm.dart';

import '../../core/models/websocket_connection.dart';
import '../../core/providers/websocket_provider.dart';
import '../../core/repositories/websocket_repository.dart';

class WebSocketTerminalScreen extends ConsumerStatefulWidget {
  final String connectionId;

  const WebSocketTerminalScreen({super.key, required this.connectionId});

  @override
  ConsumerState<WebSocketTerminalScreen> createState() => _WebSocketTerminalScreenState();
}

class _WebSocketTerminalScreenState extends ConsumerState<WebSocketTerminalScreen> {
  late Terminal terminal;
  late TerminalController controller;
  final TextEditingController _messageController = TextEditingController();
  WebSocketConnection? _connection;
  bool _isConnecting = false;
  String? _errorMessage;
  bool _sendAsJson = false;

  @override
  void initState() {
    super.initState();
    terminal = Terminal(maxLines: 10000);
    controller = TerminalController(terminal);
    _loadConnection();
  }

  Future<void> _loadConnection() async {
    try {
      final repository = ref.read(webSocketRepositoryProvider);
      final connection = await repository.getConnection(widget.connectionId);
      if (connection != null) {
        setState(() {
          _connection = connection;
        });
        _connectToWebSocket();
      }
    } catch (e) {
      setState(() {
        _errorMessage = '加载连接失败: $e';
      });
    }
  }

  Future<void> _connectToWebSocket() async {
    if (_connection == null) return;

    setState(() {
      _isConnecting = true;
      _errorMessage = null;
    });

    terminal.write('正在连接到 ${_connection!.url}...\r\n');

    try {
      final notifier = ref.read(webSocketConnectionNotifierProvider.notifier);
      await notifier.connect(_connection!);

      // 监听 WebSocket 输出
      final webSocketService = ref.read(webSocketServiceProvider);
      webSocketService.outputStream.listen((data) {
        terminal.write(data);
      });

      webSocketService.errorStream.listen((error) {
        terminal.write('错误: $error\r\n');
      });

      setState(() {
        _isConnecting = false;
      });

      terminal.write('连接成功！\r\n');
      terminal.write('输入消息并按回车发送，输入 "help" 查看帮助\r\n\r\n');
      _showPrompt();
    } catch (e) {
      setState(() {
        _isConnecting = false;
        _errorMessage = '连接失败: $e';
      });
      terminal.write('连接失败: $e\r\n');
    }
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    try {
      final notifier = ref.read(webSocketConnectionNotifierProvider.notifier);

      if (_sendAsJson) {
        try {
          final json = jsonDecode(message);
          await notifier.sendJson(json);
        } catch (e) {
          terminal.write('JSON 格式错误: $e\r\n');
          return;
        }
      } else {
        await notifier.sendMessage(message);
      }

      _messageController.clear();
      _showPrompt();
    } catch (e) {
      terminal.write('发送失败: $e\r\n');
    }
  }

  void _showPrompt() {
    terminal.write('> ');
  }

  Future<void> _disconnect() async {
    try {
      final notifier = ref.read(webSocketConnectionNotifierProvider.notifier);
      await notifier.disconnect();
      terminal.write('已断开连接\r\n');
      if (mounted) {
        context.pop();
      }
    } catch (e) {
      terminal.write('断开连接失败: $e\r\n');
    }
  }

  void _showConnectionInfo() {
    if (_connection == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('连接信息'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('名称: ${_connection!.name}'),
            Text('URL: ${_connection!.url}'),
            if (_connection!.protocol != null) Text('协议: ${_connection!.protocol}'),
            Text('创建时间: ${_connection!.createdAt}'),
            if (_connection!.lastConnectedAt != null)
              Text('最后连接: ${_connection!.lastConnectedAt}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  void _showHelp() {
    terminal.write('\r\n可用命令:\r\n');
    terminal.write('  help          - 显示帮助信息\r\n');
    terminal.write('  clear         - 清屏\r\n');
    terminal.write('  json on/off   - 切换 JSON 发送模式\r\n');
    terminal.write('  ping          - 发送 ping 消息\r\n');
    terminal.write('  disconnect    - 断开连接\r\n');
    terminal.write('  info          - 显示连接信息\r\n');
    _showPrompt();
  }

  void _handleCommand(String command) {
    final parts = command.split(' ');
    final cmd = parts[0].toLowerCase();

    switch (cmd) {
      case 'help':
        _showHelp();
        break;
      case 'clear':
        terminal.clear();
        _showPrompt();
        break;
      case 'json':
        if (parts.length > 1) {
          final mode = parts[1].toLowerCase();
          if (mode == 'on') {
            _sendAsJson = true;
            terminal.write('已切换到 JSON 发送模式\r\n');
          } else if (mode == 'off') {
            _sendAsJson = false;
            terminal.write('已切换到文本发送模式\r\n');
          }
        } else {
          terminal.write('当前模式: ${_sendAsJson ? "JSON" : "文本"}\r\n');
        }
        _showPrompt();
        break;
      case 'ping':
        _messageController.text = 'ping';
        _sendMessage();
        break;
      case 'disconnect':
        _disconnect();
        break;
      case 'info':
        _showConnectionInfo();
        _showPrompt();
        break;
      default:
        terminal.write('未知命令: $cmd\r\n');
        terminal.write('输入 "help" 查看可用命令\r\n');
        _showPrompt();
    }
  }

  @override
  Widget build(BuildContext context) {
    final connectionState = ref.watch(webSocketConnectionNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(_connection?.name ?? 'WebSocket 终端'),
        actions: [
          if (_connection != null)
            IconButton(
              icon: const Icon(Icons.info),
              onPressed: _showConnectionInfo,
            ),
          PopupMenuButton(
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'clear',
                child: ListTile(
                  leading: Icon(Icons.clear_all),
                  title: Text('清屏'),
                ),
              ),
              const PopupMenuItem(
                value: 'json',
                child: ListTile(
                  leading: Icon(Icons.code),
                  title: Text('切换 JSON 模式'),
                ),
              ),
              const PopupMenuItem(
                value: 'reconnect',
                child: ListTile(
                  leading: Icon(Icons.refresh),
                  title: Text('重新连接'),
                ),
              ),
              const PopupMenuItem(
                value: 'disconnect',
                child: ListTile(
                  leading: Icon(Icons.stop, color: Colors.red),
                  title: Text('断开连接', style: TextStyle(color: Colors.red)),
                ),
              ),
            ],
            onSelected: (value) {
              switch (value) {
                case 'clear':
                  terminal.clear();
                  _showPrompt();
                  break;
                case 'json':
                  setState(() {
                    _sendAsJson = !_sendAsJson;
                  });
                  terminal.write('已切换到 ${_sendAsJson ? "JSON" : "文本"} 发送模式\r\n');
                  _showPrompt();
                  break;
                case 'reconnect':
                  _connectToWebSocket();
                  break;
                case 'disconnect':
                  _disconnect();
                  break;
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          if (_isConnecting)
            LinearProgressIndicator(
              backgroundColor: Theme.of(context).colorScheme.surface,
            ),
          if (_errorMessage != null)
            Container(
              padding: const EdgeInsets.all(8),
              color: Colors.red.shade100,
              child: Row(
                children: [
                  const Icon(Icons.error, color: Colors.red),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_errorMessage!)),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      setState(() {
                        _errorMessage = null;
                      });
                    },
                  ),
                ],
              ),
            ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: TerminalView(
                terminal,
                controller: controller,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(8.0),
            color: Theme.of(context).cardColor,
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(
                      connectionState == WebSocketConnectionState.connected
                          ? Icons.wifi
                          : connectionState == WebSocketConnectionState.connecting
                              ? Icons.wifi_find
                              : Icons.wifi_off,
                      color: connectionState == WebSocketConnectionState.connected
                          ? Colors.green
                          : connectionState == WebSocketConnectionState.connecting
                              ? Colors.orange
                              : Colors.red,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      connectionState == WebSocketConnectionState.connected
                          ? '已连接'
                          : connectionState == WebSocketConnectionState.connecting
                              ? '连接中...'
                              : '未连接',
                      style: TextStyle(
                        color: connectionState == WebSocketConnectionState.connected
                            ? Colors.green
                            : connectionState == WebSocketConnectionState.connecting
                                ? Colors.orange
                                : Colors.red,
                      ),
                    ),
                    const Spacer(),
                    Switch(
                      value: _sendAsJson,
                      onChanged: (value) {
                        setState(() {
                          _sendAsJson = value;
                        });
                      },
                    ),
                    const Text('JSON'),
                    const SizedBox(width: 16),
                    if (connectionState == WebSocketConnectionState.connected)
                      ElevatedButton(
                        onPressed: _disconnect,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade100,
                          foregroundColor: Colors.red,
                        ),
                        child: const Text('断开连接'),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        decoration: InputDecoration(
                          hintText: _sendAsJson ? '输入 JSON 消息...' : '输入消息...',
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.send),
                            onPressed: _sendMessage,
                          ),
                        ),
                        onSubmitted: (_) => _sendMessage(),
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

  @override
  void dispose() {
    controller.dispose();
    _messageController.dispose();
    super.dispose();
  }
}