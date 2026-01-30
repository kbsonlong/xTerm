import 'package:hive/hive.dart';

part 'websocket_connection.g.dart';

@HiveType(typeId: 1)
class WebSocketConnection extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  String url;

  @HiveField(3)
  Map<String, String>? headers;

  @HiveField(4)
  Map<String, dynamic>? queryParams;

  @HiveField(5)
  String? protocol;

  @HiveField(6)
  DateTime createdAt;

  @HiveField(7)
  DateTime? lastConnectedAt;

  @HiveField(8)
  bool isFavorite;

  @HiveField(9)
  Map<String, dynamic>? extraConfig;

  WebSocketConnection({
    required this.id,
    required this.name,
    required this.url,
    this.headers,
    this.queryParams,
    this.protocol,
    required this.createdAt,
    this.lastConnectedAt,
    this.isFavorite = false,
    this.extraConfig,
  });

  factory WebSocketConnection.create({
    required String name,
    required String url,
    Map<String, String>? headers,
    Map<String, dynamic>? queryParams,
    String? protocol,
  }) {
    return WebSocketConnection(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      url: url,
      headers: headers,
      queryParams: queryParams,
      protocol: protocol,
      createdAt: DateTime.now(),
      lastConnectedAt: null,
      isFavorite: false,
    );
  }

  String get displayName => name;

  String get connectionInfo {
    final info = 'WebSocket: $url';
    if (protocol != null) {
      return '$info (协议: $protocol)';
    }
    return info;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'url': url,
      'headers': headers,
      'queryParams': queryParams,
      'protocol': protocol,
      'createdAt': createdAt.toIso8601String(),
      'lastConnectedAt': lastConnectedAt?.toIso8601String(),
      'isFavorite': isFavorite,
    };
  }

  @override
  String toString() {
    return 'WebSocketConnection{name: $name, url: $url, protocol: $protocol}';
  }
}