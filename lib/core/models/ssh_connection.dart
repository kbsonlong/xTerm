import 'package:hive/hive.dart';

part 'ssh_connection.g.dart';

@HiveType(typeId: 0)
class SshConnection extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  String host;

  @HiveField(3)
  int port;

  @HiveField(4)
  String username;

  @HiveField(5)
  String? password;

  @HiveField(6)
  String? privateKeyPath;

  @HiveField(7)
  String? passphrase;

  @HiveField(8)
  DateTime createdAt;

  @HiveField(9)
  DateTime? lastConnectedAt;

  @HiveField(10)
  bool isFavorite;

  @HiveField(11)
  Map<String, dynamic>? extraConfig;

  SshConnection({
    required this.id,
    required this.name,
    required this.host,
    this.port = 22,
    required this.username,
    this.password,
    this.privateKeyPath,
    this.passphrase,
    required this.createdAt,
    this.lastConnectedAt,
    this.isFavorite = false,
    this.extraConfig,
  });

  factory SshConnection.create({
    required String name,
    required String host,
    int port = 22,
    required String username,
    String? password,
    String? privateKeyPath,
    String? passphrase,
  }) {
    return SshConnection(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      host: host,
      port: port,
      username: username,
      password: password,
      privateKeyPath: privateKeyPath,
      passphrase: passphrase,
      createdAt: DateTime.now(),
      lastConnectedAt: null,
      isFavorite: false,
    );
  }

  String get displayName => name;

  String get connectionString => '$username@$host:$port';

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'host': host,
      'port': port,
      'username': username,
      'createdAt': createdAt.toIso8601String(),
      'lastConnectedAt': lastConnectedAt?.toIso8601String(),
      'isFavorite': isFavorite,
    };
  }

  @override
  String toString() {
    return 'SshConnection{name: $name, host: $host, port: $port, username: $username}';
  }
}