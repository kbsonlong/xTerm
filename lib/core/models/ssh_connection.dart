import 'package:hive/hive.dart';

import 'auth_method.dart';
import 'otp_config.dart';

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

  @HiveField(12)
  AuthMethod authMethod;

  @HiveField(13)
  bool useOtp;

  @HiveField(14)
  OtpConfig? otpConfig;

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
    this.authMethod = AuthMethod.password,
    this.useOtp = false,
    this.otpConfig,
  });

  factory SshConnection.create({
    required String name,
    required String host,
    int port = 22,
    required String username,
    String? password,
    String? privateKeyPath,
    String? passphrase,
    AuthMethod authMethod = AuthMethod.password,
    bool useOtp = false,
    OtpConfig? otpConfig,
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
      authMethod: authMethod,
      useOtp: useOtp,
      otpConfig: otpConfig,
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
      'authMethod': authMethod.name,
      'useOtp': useOtp,
      'otpConfig': otpConfig?.toJson(),
    };
  }

  // 检查是否需要 OTP 认证
  bool get requiresOtp => useOtp && otpConfig != null;

  // 获取认证方式描述
  String get authMethodDescription {
    switch (authMethod) {
      case AuthMethod.password:
        return 'Password';
      case AuthMethod.privateKey:
        return 'Private Key';
      case AuthMethod.passwordWithOtp:
        return 'Password + OTP';
      case AuthMethod.keyWithOtp:
        return 'Private Key + OTP';
    }
  }

  // 复制方法
  SshConnection copyWith({
    String? id,
    String? name,
    String? host,
    int? port,
    String? username,
    String? password,
    String? privateKeyPath,
    String? passphrase,
    DateTime? createdAt,
    DateTime? lastConnectedAt,
    bool? isFavorite,
    Map<String, dynamic>? extraConfig,
    AuthMethod? authMethod,
    bool? useOtp,
    OtpConfig? otpConfig,
  }) {
    return SshConnection(
      id: id ?? this.id,
      name: name ?? this.name,
      host: host ?? this.host,
      port: port ?? this.port,
      username: username ?? this.username,
      password: password ?? this.password,
      privateKeyPath: privateKeyPath ?? this.privateKeyPath,
      passphrase: passphrase ?? this.passphrase,
      createdAt: createdAt ?? this.createdAt,
      lastConnectedAt: lastConnectedAt ?? this.lastConnectedAt,
      isFavorite: isFavorite ?? this.isFavorite,
      extraConfig: extraConfig ?? this.extraConfig,
      authMethod: authMethod ?? this.authMethod,
      useOtp: useOtp ?? this.useOtp,
      otpConfig: otpConfig ?? this.otpConfig,
    );
  }

  @override
  String toString() {
    return 'SshConnection{name: $name, host: $host, port: $port, username: $username, authMethod: $authMethod, useOtp: $useOtp}';
  }
}