import 'package:hive/hive.dart';

import 'auth_method.dart';

part 'otp_config.g.dart';

@HiveType(typeId: 10)
class OtpConfig extends HiveObject {
  @HiveField(0)
  OtpType type;

  @HiveField(1)
  int digits;

  @HiveField(2)
  int period; // TOTP 时间间隔（秒）

  @HiveField(3)
  String algorithm;

  @HiveField(4)
  String issuer;

  @HiveField(5)
  String account;

  @HiveField(6)
  String? secret; // Base32 格式的密钥（仅用于临时存储）

  @HiveField(7)
  String? secretId; // 安全存储中的密钥 ID

  OtpConfig({
    this.type = OtpType.totp,
    this.digits = 6,
    this.period = 30,
    this.algorithm = 'SHA1',
    this.issuer = '',
    this.account = '',
    this.secret,
    this.secretId,
  });

  factory OtpConfig.fromUri(String uri) {
    // 解析 otpauth:// URI
    // 格式: otpauth://totp/Issuer:Account?secret=SECRET&issuer=Issuer&algorithm=SHA1&digits=6&period=30
    final uriParts = Uri.parse(uri);

    if (uriParts.scheme != 'otpauth') {
      throw ArgumentError('Invalid OTP URI scheme');
    }

    final type = uriParts.host == 'totp' ? OtpType.totp : OtpType.hotp;

    // 解析路径部分获取 issuer 和 account
    final path = uriParts.path;
    final pathParts = path.split(':');
    String issuer = '';
    String account = '';

    if (pathParts.length == 2) {
      issuer = pathParts[0];
      account = pathParts[1];
    } else if (pathParts.length == 1) {
      account = pathParts[0];
    }

    // 解析查询参数
    final params = uriParts.queryParameters;
    final secret = params['secret'] ?? '';
    final algorithm = params['algorithm'] ?? 'SHA1';
    final digits = int.tryParse(params['digits'] ?? '6') ?? 6;
    final period = int.tryParse(params['period'] ?? '30') ?? 30;
    final uriIssuer = params['issuer'] ?? '';

    // 优先使用查询参数中的 issuer
    if (uriIssuer.isNotEmpty) {
      issuer = uriIssuer;
    }

    return OtpConfig(
      type: type,
      digits: digits,
      period: period,
      algorithm: algorithm,
      issuer: issuer,
      account: account,
      secret: secret,
    );
  }

  String toUri() {
    return 'otpauth://${type.name}/'
           '${issuer.isNotEmpty ? '$issuer:' : ''}$account'
           '?secret=${secret ?? ''}'
           '&issuer=$issuer'
           '&algorithm=$algorithm'
           '&digits=$digits'
           '&period=$period';
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type.name,
      'digits': digits,
      'period': period,
      'algorithm': algorithm,
      'issuer': issuer,
      'account': account,
      'secretId': secretId,
    };
  }

  factory OtpConfig.fromJson(Map<String, dynamic> json) {
    return OtpConfig(
      type: OtpTypeExtension.fromName(json['type'] ?? 'totp'),
      digits: json['digits'] ?? 6,
      period: json['period'] ?? 30,
      algorithm: json['algorithm'] ?? 'SHA1',
      issuer: json['issuer'] ?? '',
      account: json['account'] ?? '',
      secretId: json['secretId'],
    );
  }

  @override
  String toString() {
    return 'OtpConfig{type: $type, issuer: $issuer, account: $account, digits: $digits}';
  }

  // 复制方法
  OtpConfig copyWith({
    OtpType? type,
    int? digits,
    int? period,
    String? algorithm,
    String? issuer,
    String? account,
    String? secret,
    String? secretId,
  }) {
    return OtpConfig(
      type: type ?? this.type,
      digits: digits ?? this.digits,
      period: period ?? this.period,
      algorithm: algorithm ?? this.algorithm,
      issuer: issuer ?? this.issuer,
      account: account ?? this.account,
      secret: secret ?? this.secret,
      secretId: secretId ?? this.secretId,
    );
  }
}