import 'dart:async';

import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';

import '../models/websocket_connection.dart';

class WebSocketRepository {
  static const String _boxName = 'websocket_connections';
  late Box<WebSocketConnection> _box;

  Future<void> init() async {
    final appDir = await getApplicationDocumentsDirectory();
    Hive.init(appDir.path);

    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(WebSocketConnectionAdapter());
    }

    _box = await Hive.openBox<WebSocketConnection>(_boxName);
  }

  Future<List<WebSocketConnection>> getAllConnections() async {
    await _ensureInitialized();
    return _box.values.toList();
  }

  Future<List<WebSocketConnection>> getFavoriteConnections() async {
    await _ensureInitialized();
    return _box.values.where((conn) => conn.isFavorite).toList();
  }

  Future<WebSocketConnection?> getConnection(String id) async {
    await _ensureInitialized();
    return _box.get(id);
  }

  Future<void> saveConnection(WebSocketConnection connection) async {
    await _ensureInitialized();
    await _box.put(connection.id, connection);
  }

  Future<void> deleteConnection(String id) async {
    await _ensureInitialized();
    await _box.delete(id);
  }

  Future<void> deleteAllConnections() async {
    await _ensureInitialized();
    await _box.clear();
  }

  Future<void> updateConnection(WebSocketConnection connection) async {
    await _ensureInitialized();
    await saveConnection(connection);
  }

  Future<void> markAsFavorite(String id, bool isFavorite) async {
    await _ensureInitialized();
    final connection = await getConnection(id);
    if (connection != null) {
      connection.isFavorite = isFavorite;
      await saveConnection(connection);
    }
  }

  Future<void> updateLastConnected(String id) async {
    await _ensureInitialized();
    final connection = await getConnection(id);
    if (connection != null) {
      connection.lastConnectedAt = DateTime.now();
      await saveConnection(connection);
    }
  }

  Future<List<WebSocketConnection>> searchConnections(String query) async {
    await _ensureInitialized();
    final allConnections = await getAllConnections();

    return allConnections.where((conn) {
      return conn.name.toLowerCase().contains(query.toLowerCase()) ||
             conn.url.toLowerCase().contains(query.toLowerCase());
    }).toList();
  }

  Future<int> getConnectionCount() async {
    await _ensureInitialized();
    return _box.length;
  }

  Future<void> _ensureInitialized() async {
    if (!_box.isOpen) {
      await init();
    }
  }

  Future<void> close() async {
    if (_box.isOpen) {
      await _box.close();
    }
  }
}