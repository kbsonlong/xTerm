import 'package:otp/otp.dart';

import '../models/otp_config.dart';

class OtpService {
  // 生成 TOTP 代码
  String generateTotpCode({
    required String secret,
    required OtpConfig config,
  }) {
    final algorithm = _getAlgorithm(config.algorithm);

    return OTP.generateTOTPCodeString(
      secret,
      DateTime.now().millisecondsSinceEpoch,
      algorithm: algorithm,
      length: config.digits,
      interval: config.period,
    );
  }

  // 生成 HOTP 代码
  String generateHotpCode({
    required String secret,
    required OtpConfig config,
    int counter = 0,
  }) {
    final algorithm = _getAlgorithm(config.algorithm);

    return OTP.generateHOTPCodeString(
      secret,
      counter,
      algorithm: algorithm,
      length: config.digits,
    );
  }

  // 根据配置生成 OTP 代码
  String generateCode({
    required String secret,
    required OtpConfig config,
    int counter = 0,
  }) {
    switch (config.type) {
      case OtpType.totp:
        return generateTotpCode(secret: secret, config: config);
      case OtpType.hotp:
        return generateHotpCode(secret: secret, config: config, counter: counter);
    }
  }

  // 验证 OTP 代码
  bool validateCode({
    required String secret,
    required String code,
    required OtpConfig config,
    int counter = 0,
    int window = 1, // 时间窗口（用于 TOTP）
  }) {
    final generated = generateCode(secret: secret, config: config, counter: counter);
    return generated == code;
  }

  // 生成随机密钥
  String generateSecret({int length = 16}) {
    return OTP.randomSecret(length: length);
  }

  // 生成二维码数据 URI
  String generateQrCodeData({
    required String secret,
    required OtpConfig config,
  }) {
    return config.copyWith(secret: secret).toUri();
  }

  // 解析二维码数据 URI
  OtpConfig parseQrCodeData(String uri) {
    return OtpConfig.fromUri(uri);
  }

  // 获取剩余时间（用于 TOTP）
  int getRemainingSeconds(OtpConfig config) {
    if (config.type != OtpType.totp) {
      return 0;
    }

    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return config.period - (now % config.period);
  }

  // 获取进度百分比（用于 UI 显示）
  double getProgressPercentage(OtpConfig config) {
    if (config.type != OtpType.totp) {
      return 1.0;
    }

    final remaining = getRemainingSeconds(config);
    return remaining / config.period;
  }

  // 将算法字符串转换为 Algorithm 枚举
  Algorithm _getAlgorithm(String algorithm) {
    switch (algorithm.toUpperCase()) {
      case 'SHA256':
        return Algorithm.SHA256;
      case 'SHA384':
        return Algorithm.SHA384;
      case 'SHA512':
        return Algorithm.SHA512;
      case 'SHA1':
      default:
        return Algorithm.SHA1;
    }
  }

  // 检查密钥格式是否有效
  bool isValidSecret(String secret) {
    try {
      // Base32 格式验证
      final normalized = secret.replaceAll(' ', '').toUpperCase();
      final pattern = RegExp(r'^[A-Z2-7]+=*$');
      return pattern.hasMatch(normalized);
    } catch (e) {
      return false;
    }
  }

  // 格式化密钥（添加空格便于阅读）
  String formatSecret(String secret) {
    final normalized = secret.replaceAll(' ', '').toUpperCase();
    final chunks = <String>[];

    for (var i = 0; i < normalized.length; i += 4) {
      final end = i + 4;
      if (end <= normalized.length) {
        chunks.add(normalized.substring(i, end));
      } else {
        chunks.add(normalized.substring(i));
      }
    }

    return chunks.join(' ');
  }
}