// 认证方式枚举
enum AuthMethod {
  password,          // 仅密码
  privateKey,        // 仅私钥
  passwordWithOtp,   // 密码 + OTP
  keyWithOtp,        // 私钥 + OTP
}

// OTP 类型枚举
enum OtpType {
  totp,  // 时间基础 OTP
  hotp,  // 计数器基础 OTP
}

// 将枚举转换为字符串以便存储
extension AuthMethodExtension on AuthMethod {
  String get name {
    switch (this) {
      case AuthMethod.password:
        return 'password';
      case AuthMethod.privateKey:
        return 'privateKey';
      case AuthMethod.passwordWithOtp:
        return 'passwordWithOtp';
      case AuthMethod.keyWithOtp:
        return 'keyWithOtp';
    }
  }

  static AuthMethod fromName(String name) {
    switch (name) {
      case 'password':
        return AuthMethod.password;
      case 'privateKey':
        return AuthMethod.privateKey;
      case 'passwordWithOtp':
        return AuthMethod.passwordWithOtp;
      case 'keyWithOtp':
        return AuthMethod.keyWithOtp;
      default:
        return AuthMethod.password;
    }
  }
}

extension OtpTypeExtension on OtpType {
  String get name {
    switch (this) {
      case OtpType.totp:
        return 'totp';
      case OtpType.hotp:
        return 'hotp';
    }
  }

  static OtpType fromName(String name) {
    switch (name) {
      case 'totp':
        return OtpType.totp;
      case 'hotp':
        return OtpType.hotp;
      default:
        return OtpType.totp;
    }
  }
}