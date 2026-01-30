import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/websocket_service.dart';
import '../repositories/websocket_repository.dart';
import '../models/websocket_connection.dart';

final webSocketRepositoryProvider = Provider<WebSocketRepository>((ref) {
  final repository = WebSocketRepository();
  repository.init();
  ref.onDispose(() => repository.close());
  return repository;
});

final webSocketServiceProvider = Provider<WebSocketService>((ref) {
  return WebSocketService();
});

final webSocketConnectionsProvider = FutureProvider<List<WebSocketConnection>>((ref) async {
  final repository = ref.watch(webSocketRepositoryProvider);
  return await repository.getAllConnections();
});

final favoriteWebSocketConnectionsProvider = FutureProvider<List<WebSocketConnection>>((ref) async {
  final repository = ref.watch(webSocketRepositoryProvider);
  return await repository.getFavoriteConnections();
});

final webSocketConnectionProvider = StateProvider<WebSocketConnection?>((ref) => null);

final webSocketConnectionStateProvider = StateProvider<WebSocketConnectionState>((ref) {
  return WebSocketConnectionState.disconnected;
});

enum WebSocketConnectionState {
  disconnected,
  connecting,
  connected,
  error,
}

class WebSocketConnectionNotifier extends StateNotifier<WebSocketConnectionState> {
  final Ref ref;
  final WebSocketService webSocketService;

  WebSocketConnectionNotifier(this.ref, this.webSocketService)
      : super(WebSocketConnectionState.disconnected);

  Future<void> connect(WebSocketConnection connection) async {
    state = WebSocketConnectionState.connecting;
    try {
      await webSocketService.connect(connection);
      state = WebSocketConnectionState.connected;

      // 更新最后连接时间
      final repository = ref.read(webSocketRepositoryProvider);
      await repository.updateLastConnected(connection.id);
    } catch (e) {
      state = WebSocketConnectionState.error;
      rethrow;
    }
  }

  Future<void> disconnect() async {
    await webSocketService.disconnect();
    state = WebSocketConnectionState.disconnected;
  }

  Future<void> sendMessage(String message) async {
    if (state != WebSocketConnectionState.connected) {
      throw Exception('未连接');
    }
    await webSocketService.sendMessage(message);
  }

  Future<void> sendJson(Map<String, dynamic> json) async {
    if (state != WebSocketConnectionState.connected) {
      throw Exception('未连接');
    }
    await webSocketService.sendJson(json);
  }

  Future<void> sendBinary(List<int> data) async {
    if (state != WebSocketConnectionState.connected) {
      throw Exception('未连接');
    }
    await webSocketService.sendBinary(data);
  }

  Future<Map<String, dynamic>> testConnection(WebSocketConnection connection) async {
    return await webSocketService.testConnection(connection);
  }
}

final webSocketConnectionNotifierProvider =
    StateNotifierProvider<WebSocketConnectionNotifier, WebSocketConnectionState>((ref) {
  final webSocketService = ref.watch(webSocketServiceProvider);
  return WebSocketConnectionNotifier(ref, webSocketService);
});