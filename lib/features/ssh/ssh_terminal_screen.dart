import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:xterm/xterm.dart';

import '../../core/models/ssh_connection.dart';
import '../../core/providers/ssh_provider.dart';
import '../../core/repositories/ssh_repository.dart';
import '../../shared/widgets/terminal_widget.dart';

class SshTerminalScreen extends ConsumerStatefulWidget {
  final String connectionId;

  const SshTerminalScreen({super.key, required this.connectionId});

  @override
  ConsumerState<SshTerminalScreen> createState() => _SshTerminalScreenState();
}

class _SshTerminalScreenState extends ConsumerState<SshTerminalScreen> {
  late Terminal terminal;
  late TerminalController controller;
  SshConnection? _connection;
  bool _isConnecting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    terminal = Terminal(maxLines: 10000);
    controller = TerminalController(terminal);
    _loadConnection();
  }

  Future<void> _loadConnection() async {
    try {
      final repository = ref.read(sshRepositoryProvider);
      final connection = await repository.getConnection(widget.connectionId);
      if (connection != null) {
        setState(() {
          _connection = connection;
        });
        _connectToSsh();
      }
    } catch (e) {
      setState(() {
        _errorMessage = '加载连接失败: $e';
      });
    }
  }

  Future<void> _connectToSsh() async {
    if (_connection == null) return;

    setState(() {
      _isConnecting = true;
      _errorMessage = null;
    });

    terminal.write('正在连接到 ${_connection!.host}:${_connection!.port}...\r\n');

    try {
      final notifier = ref.read(sshConnectionNotifierProvider.notifier);
      await notifier.connect(_connection!);

      // 监听 SSH 输出
      final sshService = ref.read(sshServiceProvider);
      sshService.outputStream.listen((data) {
        terminal.write(data);
      });

      sshService.errorStream.listen((error) {
        terminal.write('错误: $error\r\n');
      });

      // 设置终端输入处理
      controller.onInput = (input) async {
        try {
          await notifier.sendToTerminal(input);
        } catch (e) {
          terminal.write('发送失败: $e\r\n');
        }
      };

      setState(() {
        _isConnecting = false;
      });

      terminal.write('连接成功！\r\n\r\n');
    } catch (e) {
      setState(() {
        _isConnecting = false;
        _errorMessage = '连接失败: $e';
      });
      terminal.write('连接失败: $e\r\n');
    }
  }

  Future<void> _disconnect() async {
    try {
      final notifier = ref.read(sshConnectionNotifierProvider.notifier);
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
            Text('主机: ${_connection!.host}'),
            Text('端口: ${_connection!.port}'),
            Text('用户名: ${_connection!.username}'),
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

  void _sendCommand(String command) {
    if (command.trim().isNotEmpty) {
      controller.enter(command);
    }
  }

  @override
  Widget build(BuildContext context) {
    final connectionState = ref.watch(sshConnectionNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(_connection?.name ?? 'SSH 终端'),
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
                  break;
                case 'reconnect':
                  _connectToSsh();
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
                terminal: terminal,
                controller: controller,
                autofocus: true,
                style: TerminalStyle(
                  fontSize: 14,
                  fontFamily: 'RobotoMono',
                  foreground: Colors.white,
                  background: Colors.black,
                  cursor: Colors.green,
                  selection: Colors.blue.withOpacity(0.5),
                ),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(8.0),
            color: Theme.of(context).cardColor,
            child: Row(
              children: [
                Icon(
                  connectionState == ConnectionState.connected
                      ? Icons.wifi
                      : connectionState == ConnectionState.connecting
                          ? Icons.wifi_find
                          : Icons.wifi_off,
                  color: connectionState == ConnectionState.connected
                      ? Colors.green
                      : connectionState == ConnectionState.connecting
                          ? Colors.orange
                          : Colors.red,
                ),
                const SizedBox(width: 8),
                Text(
                  connectionState == ConnectionState.connected
                      ? '已连接'
                      : connectionState == ConnectionState.connecting
                          ? '连接中...'
                          : '未连接',
                  style: TextStyle(
                    color: connectionState == ConnectionState.connected
                        ? Colors.green
                        : connectionState == ConnectionState.connecting
                            ? Colors.orange
                            : Colors.red,
                  ),
                ),
                const Spacer(),
                if (connectionState == ConnectionState.connected)
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
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }
}