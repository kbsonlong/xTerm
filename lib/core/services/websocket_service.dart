import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:xterm/xterm.dart';

import '../models/websocket_connection.dart';

class WebSocketService {
  WebSocketChannel? _channel;
  StreamController<String>? _outputController;
  StreamController<String>? _errorController;
  bool _isConnected = false;
  Timer? _pingTimer;

  Stream<String> get outputStream => _outputController?.stream ?? const Stream.empty();
  Stream<String> get errorStream => _errorController?.stream ?? const Stream.empty();
  bool get isConnected => _isConnected;

  Future<void> connect(WebSocketConnection connection) async {
    try {
      _outputController = StreamController<String>();
      _errorController = StreamController<String>();

      // 构建完整的 URL
      String url = connection.url;
      if (connection.queryParams != null && connection.queryParams!.isNotEmpty) {
        final queryString = connection.queryParams!.entries
            .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value.toString())}')
            .join('&');
        url = '$url${url.contains('?') ? '&' : '?'}$queryString';
      }

      // 创建 WebSocket 连接
      _channel = WebSocketChannel.connect(
        Uri.parse(url),
        protocols: connection.protocol != null ? [connection.protocol!] : null,
        headers: connection.headers,
      );

      _isConnected = true;

      _outputController!.add('连接到 WebSocket: $url\r\n');
      if (connection.protocol != null) {
        _outputController!.add('使用协议: ${connection.protocol}\r\n');
      }
      _outputController!.add('连接成功！\r\n\r\n');

      // 开始监听消息
      _startListening();

      // 启动心跳检测
      _startPingTimer();
    } catch (e) {
      _errorController?.add('连接失败: $e');
      await disconnect();
      rethrow;
    }
  }

  void _startListening() {
    if (_channel == null) return;

    _channel!.stream.listen(
      (message) {
        if (message is String) {
          _outputController?.add('收到: $message\r\n');
        } else if (message is List<int>) {
          try {
            final text = utf8.decode(message);
            _outputController?.add('收到(二进制): $text\r\n');
          } catch (e) {
            _outputController?.add('收到二进制数据: ${message.length} bytes\r\n');
          }
        }
      },
      onError: (error) {
        _errorController?.add('WebSocket 错误: $error');
        _disconnect();
      },
      onDone: () {
        _outputController?.add('WebSocket 连接已关闭\r\n');
        _disconnect();
      },
    );
  }

  void _startPingTimer() {
    _pingTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (_isConnected && _channel != null) {
        sendMessage('ping');
      }
    });
  }

  Future<void> sendMessage(String message) async {
    if (_channel == null || !_isConnected) {
      throw Exception('未连接到 WebSocket 服务器');
    }

    try {
      _channel!.sink.add(message);
      _outputController?.add('发送: $message\r\n');
    } catch (e) {
      _errorController?.add('发送消息失败: $e');
      rethrow;
    }
  }

  Future<void> sendBinary(List<int> data) async {
    if (_channel == null || !_isConnected) {
      throw Exception('未连接到 WebSocket 服务器');
    }

    try {
      _channel!.sink.add(data);
      _outputController?.add('发送二进制数据: ${data.length} bytes\r\n');
    } catch (e) {
      _errorController?.add('发送二进制数据失败: $e');
      rethrow;
    }
  }

  Future<void> sendJson(Map<String, dynamic> json) async {
    final message = jsonEncode(json);
    await sendMessage(message);
  }

  void _disconnect() {
    _isConnected = false;
    _pingTimer?.cancel();
    _pingTimer = null;
  }

  Future<void> disconnect() async {
    try {
      await _channel?.sink.close();
      _disconnect();
      await _outputController?.close();
      await _errorController?.close();
      _outputController = null;
      _errorController = null;
      _channel = null;
    } catch (e) {
      // 忽略断开连接时的错误
    }
  }

  Future<Map<String, dynamic>> testConnection(WebSocketConnection connection) async {
    WebSocketChannel? testChannel;
    try {
      final stopwatch = Stopwatch()..start();

      String url = connection.url;
      if (connection.queryParams != null && connection.queryParams!.isNotEmpty) {
        final queryString = connection.queryParams!.entries
            .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value.toString())}')
            .join('&');
        url = '$url${url.contains('?') ? '&' : '?'}$queryString';
      }

      testChannel = WebSocketChannel.connect(
        Uri.parse(url),
        protocols: connection.protocol != null ? [connection.protocol!] : null,
        headers: connection.headers,
      );

      // 等待连接建立
      await testChannel.ready;
      stopwatch.stop();

      await testChannel.sink.close();

      return {
        'success': true,
        'latency': stopwatch.elapsedMilliseconds,
        'message': 'WebSocket 连接成功',
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'message': 'WebSocket 连接失败: $e',
      };
    } finally {
      await testChannel?.sink.close();
    }
  }
}