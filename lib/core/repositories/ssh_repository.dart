import 'dart:async';

import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';

import '../models/ssh_connection.dart';

class SshRepository {
  static const String _boxName = 'ssh_connections';
  late Box<SshConnection> _box;

  Future<void> init() async {
    final appDir = await getApplicationDocumentsDirectory();
    Hive.init(appDir.path);

    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(SshConnectionAdapter());
    }

    _box = await Hive.openBox<SshConnection>(_boxName);
  }

  Future<List<SshConnection>> getAllConnections() async {
    await _ensureInitialized();
    return _box.values.toList();
  }

  Future<List<SshConnection>> getFavoriteConnections() async {
    await _ensureInitialized();
    return _box.values.where((conn) => conn.isFavorite).toList();
  }

  Future<SshConnection?> getConnection(String id) async {
    await _ensureInitialized();
    return _box.get(id);
  }

  Future<void> saveConnection(SshConnection connection) async {
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

  Future<void> updateConnection(SshConnection connection) async {
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

  Future<List<SshConnection>> searchConnections(String query) async {
    await _ensureInitialized();
    final allConnections = await getAllConnections();

    return allConnections.where((conn) {
      return conn.name.toLowerCase().contains(query.toLowerCase()) ||
             conn.host.toLowerCase().contains(query.toLowerCase()) ||
             conn.username.toLowerCase().contains(query.toLowerCase());
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