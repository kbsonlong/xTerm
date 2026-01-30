import 'package:go_router/go_router.dart';

import '../features/home/home_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/ssh/ssh_connections_screen.dart';
import '../features/ssh/ssh_connection_form_screen.dart';
import '../features/ssh/ssh_terminal_screen.dart';
import '../features/websocket/websocket_connections_screen.dart';
import '../features/websocket/websocket_connection_form_screen.dart';
import '../features/websocket/websocket_terminal_screen.dart';

final appRoutes = [
  GoRoute(
    path: '/',
    builder: (context, state) => const HomeScreen(),
  ),
  GoRoute(
    path: '/settings',
    builder: (context, state) => const SettingsScreen(),
  ),
  GoRoute(
    path: '/ssh',
    builder: (context, state) => const SshConnectionsScreen(),
  ),
  GoRoute(
    path: '/ssh/new',
    builder: (context, state) => const SshConnectionFormScreen(),
  ),
  GoRoute(
    path: '/ssh/edit/:id',
    builder: (context, state) {
      final id = state.pathParameters['id']!;
      return SshConnectionFormScreen(connectionId: id);
    },
  ),
  GoRoute(
    path: '/ssh/terminal/:id',
    builder: (context, state) {
      final id = state.pathParameters['id']!;
      return SshTerminalScreen(connectionId: id);
    },
  ),
  GoRoute(
    path: '/websocket',
    builder: (context, state) => const WebSocketConnectionsScreen(),
  ),
  GoRoute(
    path: '/websocket/new',
    builder: (context, state) => const WebSocketConnectionFormScreen(),
  ),
  GoRoute(
    path: '/websocket/edit/:id',
    builder: (context, state) {
      final id = state.pathParameters['id']!;
      return WebSocketConnectionFormScreen(connectionId: id);
    },
  ),
  GoRoute(
    path: '/websocket/terminal/:id',
    builder: (context, state) {
      final id = state.pathParameters['id']!;
      return WebSocketTerminalScreen(connectionId: id);
    },
  ),
];