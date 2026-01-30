import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xterm/xterm.dart';

import '../services/ssh_service.dart';
import '../repositories/ssh_repository.dart';
import '../models/ssh_connection.dart';

final sshRepositoryProvider = Provider<SshRepository>((ref) {
  final repository = SshRepository();
  repository.init();
  ref.onDispose(() => repository.close());
  return repository;
});

final sshServiceProvider = Provider<SshService>((ref) {
  return SshService();
});

final sshConnectionsProvider = FutureProvider<List<SshConnection>>((ref) async {
  final repository = ref.watch(sshRepositoryProvider);
  return await repository.getAllConnections();
});

final favoriteConnectionsProvider = FutureProvider<List<SshConnection>>((ref) async {
  final repository = ref.watch(sshRepositoryProvider);
  return await repository.getFavoriteConnections();
});

final sshConnectionProvider = StateProvider<SshConnection?>((ref) => null);

final sshTerminalProvider = StateProvider<Terminal?>((ref) => null);

final sshConnectionStateProvider = StateProvider<ConnectionState>((ref) {
  return ConnectionState.disconnected;
});

enum ConnectionState {
  disconnected,
  connecting,
  connected,
  error,
}

class SshConnectionNotifier extends StateNotifier<ConnectionState> {
  final Ref ref;
  final SshService sshService;

  SshConnectionNotifier(this.ref, this.sshService) : super(ConnectionState.disconnected);

  Future<void> connect(SshConnection connection) async {
    state = ConnectionState.connecting;
    try {
      await sshService.connect(connection);
      state = ConnectionState.connected;

      // 更新最后连接时间
      final repository = ref.read(sshRepositoryProvider);
      await repository.updateLastConnected(connection.id);
    } catch (e) {
      state = ConnectionState.error;
      rethrow;
    }
  }

  Future<void> disconnect() async {
    await sshService.disconnect();
    state = ConnectionState.disconnected;
  }

  Future<void> executeCommand(String command) async {
    if (state != ConnectionState.connected) {
      throw Exception('Not connected');
    }
    await sshService.executeCommand(command);
  }

  Future<void> sendToTerminal(String data) async {
    if (state != ConnectionState.connected) {
      throw Exception('Not connected');
    }
    await sshService.sendToShell(data);
  }

  Future<Map<String, dynamic>> testConnection(SshConnection connection) async {
    return await sshService.testConnection(connection);
  }
}

final sshConnectionNotifierProvider = StateNotifierProvider<SshConnectionNotifier, ConnectionState>((ref) {
  final sshService = ref.watch(sshServiceProvider);
  return SshConnectionNotifier(ref, sshService);
});