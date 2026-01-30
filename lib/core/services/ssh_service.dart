import 'dart:async';
import 'dart:io';

import 'package:ssh2/ssh2.dart';
import 'package:xterm/xterm.dart';

import '../models/ssh_connection.dart';

class SshService {
  SSHClient? _client;
  StreamController<String>? _outputController;
  StreamController<String>? _errorController;
  bool _isConnected = false;

  Stream<String> get outputStream => _outputController?.stream ?? const Stream.empty();
  Stream<String> get errorStream => _errorController?.stream ?? const Stream.empty();
  bool get isConnected => _isConnected;

  Future<void> connect(SshConnection connection) async {
    try {
      _outputController = StreamController<String>();
      _errorController = StreamController<String>();

      _client = SSHClient(
        host: connection.host,
        port: connection.port,
        username: connection.username,
        passwordOrKey: connection.password ??
            (connection.privateKeyPath != null
                ? {
                    'privateKey': File(connection.privateKeyPath!).readAsStringSync(),
                    'passphrase': connection.passphrase,
                  }
                : null),
      );

      await _client!.connect();
      _isConnected = true;

      _outputController!.add('Connected to ${connection.host}:${connection.port}\r\n');
      _outputController!.add('Welcome to SSH terminal\r\n\r\n');

      // 开始监听 shell 输出
      _startShell();
    } catch (e) {
      _errorController?.add('Connection failed: $e');
      await disconnect();
      rethrow;
    }
  }

  Future<void> _startShell() async {
    if (_client == null) return;

    try {
      final shell = await _client!.startShell(
        ptyType: 'xterm',
        callback: (dynamic data) {
          if (data is String) {
            _outputController?.add(data);
          }
        },
      );

      // 监听用户输入
      _outputController?.stream.listen((data) {
        // 这里处理从终端发送到 SSH 的数据
      });
    } catch (e) {
      _errorController?.add('Failed to start shell: $e');
    }
  }

  Future<void> executeCommand(String command) async {
    if (_client == null || !_isConnected) {
      throw Exception('Not connected to SSH server');
    }

    try {
      final result = await _client!.execute(command);
      _outputController?.add('$result\r\n');
    } catch (e) {
      _errorController?.add('Command execution failed: $e');
    }
  }

  Future<void> sendToShell(String data) async {
    if (_client == null || !_isConnected) return;

    try {
      await _client!.writeToShell(data);
    } catch (e) {
      _errorController?.add('Failed to send data to shell: $e');
    }
  }

  Future<void> disconnect() async {
    try {
      await _client?.disconnect();
      _client = null;
      _isConnected = false;
      await _outputController?.close();
      await _errorController?.close();
      _outputController = null;
      _errorController = null;
    } catch (e) {
      // 忽略断开连接时的错误
    }
  }

  Future<Map<String, dynamic>> testConnection(SshConnection connection) async {
    SSHClient? testClient;
    try {
      testClient = SSHClient(
        host: connection.host,
        port: connection.port,
        username: connection.username,
        passwordOrKey: connection.password ??
            (connection.privateKeyPath != null
                ? {
                    'privateKey': File(connection.privateKeyPath!).readAsStringSync(),
                    'passphrase': connection.passphrase,
                  }
                : null),
      );

      final stopwatch = Stopwatch()..start();
      await testClient.connect();
      stopwatch.stop();

      await testClient.disconnect();

      return {
        'success': true,
        'latency': stopwatch.elapsedMilliseconds,
        'message': 'Connection successful',
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Connection failed: $e',
      };
    } finally {
      await testClient?.disconnect();
    }
  }

  Future<List<Map<String, dynamic>>> listFiles(String path) async {
    if (_client == null || !_isConnected) {
      throw Exception('Not connected to SSH server');
    }

    try {
      final result = await _client!.execute('ls -la "$path"');
      final lines = result.split('\n');
      final files = <Map<String, dynamic>>[];

      for (final line in lines) {
        if (line.trim().isEmpty || line.startsWith('total')) continue;

        final parts = line.split(RegExp(r'\s+'));
        if (parts.length >= 9) {
          final permissions = parts[0];
          final size = parts[4];
          final date = '${parts[5]} ${parts[6]} ${parts[7]}';
          final name = parts.sublist(8).join(' ');

          files.add({
            'name': name,
            'permissions': permissions,
            'size': int.tryParse(size) ?? 0,
            'date': date,
            'isDirectory': permissions.startsWith('d'),
            'isLink': permissions.startsWith('l'),
          });
        }
      }

      return files;
    } catch (e) {
      throw Exception('Failed to list files: $e');
    }
  }
}