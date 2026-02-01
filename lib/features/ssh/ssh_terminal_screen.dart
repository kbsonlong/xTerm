import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:xterm/xterm.dart';

import '../../core/models/ssh_connection.dart';
import '../../core/providers/ssh_provider.dart';
import '../../core/repositories/ssh_repository.dart';
import '../../core/services/otp_service.dart';
import '../../core/services/secure_otp_storage.dart';
import '../../core/services/ssh_auth_manager.dart';
import '../../shared/widgets/terminal_widget.dart';
import 'widgets/otp_input_dialog.dart';

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
  SshAuthManager? _authManager;
  StreamSubscription<AuthState>? _authStateSubscription;
  StreamSubscription<String?>? _otpCodeSubscription;
  SecureOtpStorage? _otpStorage;
  OtpService? _otpService;
  String? _currentOtpCode;
  bool _showOtpDialog = false;

  @override
  void initState() {
    super.initState();
    terminal = Terminal(maxLines: 10000);
    controller = TerminalController(terminal);
    _otpStorage = SecureOtpStorage();
    _otpService = OtpService();
    _loadConnection();
  }

  @override
  void dispose() {
    _authStateSubscription?.cancel();
    _otpCodeSubscription?.cancel();
    _authManager?.dispose();
    super.dispose();
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
      _showOtpDialog = false;
    });

    terminal.write('正在连接到 ${_connection!.host}:${_connection!.port}...\r\n');

    try {
      // 初始化认证管理器
      _authManager?.dispose();
      _authStateSubscription?.cancel();
      _otpCodeSubscription?.cancel();

      final sshService = ref.read(sshServiceProvider);
      _authManager = SshAuthManager(
        connection: _connection!,
        otpStorage: _otpStorage!,
        otpService: _otpService!,
        sshService: sshService,
      );

      // 监听认证状态
      _authStateSubscription = _authManager!.stateStream.listen(_handleAuthState);
      _otpCodeSubscription = _authManager!.otpCodeStream.listen(_handleOtpCode);

      // 开始认证
      await _authManager!.authenticate();

      // 认证成功后，设置 SSH 连接
      final notifier = ref.read(sshConnectionNotifierProvider.notifier);
      await notifier.connect(_connection!);

      // 监听 SSH 输出
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

  void _handleAuthState(AuthState state) {
    switch (state) {
      case AuthState.initial:
        terminal.write('开始认证...\r\n');
        break;
      case AuthState.primaryAuth:
        terminal.write('执行主认证...\r\n');
        break;
      case AuthState.otpRequired:
        terminal.write('需要 OTP 二次认证...\r\n');
        _showOtpInputDialog();
        break;
      case AuthState.otpVerifying:
        terminal.write('验证 OTP 代码...\r\n');
        break;
      case AuthState.completed:
        terminal.write('认证成功！\r\n');
        break;
      case AuthState.error:
        terminal.write('认证失败\r\n');
        break;
    }
  }

  void _handleOtpCode(String? otpCode) {
    setState(() {
      _currentOtpCode = otpCode;
    });
  }

  void _showOtpInputDialog() {
    if (_showOtpDialog || _connection == null) return;

    setState(() => _showOtpDialog = true);

    final remainingSeconds = _authManager?.getOtpRemainingSeconds() ?? 30;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => OtpInputDialog(
        connectionName: _connection!.name,
        timeRemaining: remainingSeconds,
        currentOtpCode: _currentOtpCode,
        onOtpSubmitted: _handleOtpSubmitted,
        onCancel: _handleOtpCancelled,
        onUseCurrentCode: () {
          if (_currentOtpCode != null) {
            _handleOtpSubmitted(_currentOtpCode!);
          }
        },
      ),
    ).then((_) {
      if (mounted) {
        setState(() => _showOtpDialog = false);
      }
    });
  }

  void _handleOtpSubmitted(String otpCode) {
    _authManager?.provideOtpInput(otpCode);
    Navigator.of(context).pop();
  }

  void _handleOtpCancelled() {
    _authManager?.cancelOtpInput();
    Navigator.of(context).pop();
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
                terminal,
                controller: controller,
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