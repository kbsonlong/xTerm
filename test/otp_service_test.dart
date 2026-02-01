import 'package:flutter_test/flutter_test.dart';
import 'package:otp/otp.dart';

import '../lib/core/models/otp_config.dart';
import '../lib/core/services/otp_service.dart';

void main() {
  group('OtpService Tests', () {
    late OtpService otpService;

    setUp(() {
      otpService = OtpService();
    });

    test('generates valid TOTP code', () {
      const secret = 'JBSWY3DPEHPK3PXP'; // 标准测试密钥
      final config = OtpConfig(
        type: OtpType.totp,
        digits: 6,
        period: 30,
        algorithm: 'SHA1',
        issuer: 'Test',
        account: 'test@example.com',
        secret: secret,
      );

      final code = otpService.generateCode(secret: secret, config: config);

      expect(code, hasLength(6));
      expect(int.tryParse(code), isNotNull);
    });

    test('validates correct TOTP code', () {
      const secret = 'JBSWY3DPEHPK3PXP';
      final config = OtpConfig(
        type: OtpType.totp,
        digits: 6,
        period: 30,
        algorithm: 'SHA1',
        secret: secret,
      );

      // 生成代码
      final code = otpService.generateCode(secret: secret, config: config);

      // 验证代码
      final isValid = otpService.validateCode(
        secret: secret,
        code: code,
        config: config,
      );

      expect(isValid, isTrue);
    });

    test('rejects incorrect TOTP code', () {
      const secret = 'JBSWY3DPEHPK3PXP';
      final config = OtpConfig(
        type: OtpType.totp,
        digits: 6,
        period: 30,
        algorithm: 'SHA1',
        secret: secret,
      );

      const wrongCode = '123456';

      final isValid = otpService.validateCode(
        secret: secret,
        code: wrongCode,
        config: config,
      );

      expect(isValid, isFalse);
    });

    test('generates valid HOTP code', () {
      const secret = 'JBSWY3DPEHPK3PXP';
      final config = OtpConfig(
        type: OtpType.hotp,
        digits: 6,
        algorithm: 'SHA1',
        secret: secret,
      );

      final code = otpService.generateCode(
        secret: secret,
        config: config,
        counter: 0,
      );

      expect(code, hasLength(6));
      expect(int.tryParse(code), isNotNull);
    });

    test('generates random secret', () {
      final secret = otpService.generateSecret();

      expect(secret, isNotEmpty);
      expect(secret.length, greaterThanOrEqualTo(16));
      expect(otpService.isValidSecret(secret), isTrue);
    });

    test('validates secret format', () {
      const validSecret = 'JBSWY3DPEHPK3PXP';
      const invalidSecret = 'invalid-secret!@#';

      expect(otpService.isValidSecret(validSecret), isTrue);
      expect(otpService.isValidSecret(invalidSecret), isFalse);
    });

    test('formats secret with spaces', () {
      const secret = 'JBSWY3DPEHPK3PXP';
      final formatted = otpService.formatSecret(secret);

      expect(formatted, contains(' '));
      expect(formatted.replaceAll(' ', ''), equals(secret));
    });

    test('generates QR code data URI', () {
      const secret = 'JBSWY3DPEHPK3PXP';
      final config = OtpConfig(
        type: OtpType.totp,
        digits: 6,
        period: 30,
        algorithm: 'SHA1',
        issuer: 'Test Issuer',
        account: 'test@example.com',
        secret: secret,
      );

      final uri = otpService.generateQrCodeData(
        secret: secret,
        config: config,
      );

      expect(uri, startsWith('otpauth://totp/'));
      expect(uri, contains('secret=$secret'));
      expect(uri, contains('issuer=Test%20Issuer'));
      expect(uri, contains('account=test%40example.com'));
    });

    test('parses QR code data URI', () {
      const uri = 'otpauth://totp/Test%20Issuer:test%40example.com'
          '?secret=JBSWY3DPEHPK3PXP'
          '&issuer=Test%20Issuer'
          '&algorithm=SHA1'
          '&digits=6'
          '&period=30';

      final config = otpService.parseQrCodeData(uri);

      expect(config.type, OtpType.totp);
      expect(config.issuer, 'Test Issuer');
      expect(config.account, 'test@example.com');
      expect(config.secret, 'JBSWY3DPEHPK3PXP');
      expect(config.algorithm, 'SHA1');
      expect(config.digits, 6);
      expect(config.period, 30);
    });

    test('calculates remaining seconds for TOTP', () {
      final config = OtpConfig(
        type: OtpType.totp,
        period: 30,
      );

      final remaining = otpService.getRemainingSeconds(config);

      expect(remaining, greaterThanOrEqualTo(0));
      expect(remaining, lessThanOrEqualTo(30));
    });

    test('calculates progress percentage', () {
      final config = OtpConfig(
        type: OtpType.totp,
        period: 30,
      );

      final progress = otpService.getProgressPercentage(config);

      expect(progress, greaterThanOrEqualTo(0.0));
      expect(progress, lessThanOrEqualTo(1.0));
    });
  });

  group('OtpConfig Tests', () {
    test('creates from URI', () {
      const uri = 'otpauth://totp/Example:alice%40google.com'
          '?secret=JBSWY3DPEHPK3PXP'
          '&issuer=Example'
          '&algorithm=SHA1'
          '&digits=6'
          '&period=30';

      final config = OtpConfig.fromUri(uri);

      expect(config.type, OtpType.totp);
      expect(config.issuer, 'Example');
      expect(config.account, 'alice@google.com');
      expect(config.secret, 'JBSWY3DPEHPK3PXP');
      expect(config.algorithm, 'SHA1');
      expect(config.digits, 6);
      expect(config.period, 30);
    });

    test('generates URI', () {
      const secret = 'JBSWY3DPEHPK3PXP';
      final config = OtpConfig(
        type: OtpType.totp,
        digits: 6,
        period: 30,
        algorithm: 'SHA1',
        issuer: 'Example',
        account: 'alice@google.com',
        secret: secret,
      );

      final uri = config.toUri();

      expect(uri, startsWith('otpauth://totp/'));
      expect(uri, contains('secret=$secret'));
      expect(uri, contains('issuer=Example'));
      expect(uri, contains('account=alice%40google.com'));
    });

    test('copies with new values', () {
      final original = OtpConfig(
        type: OtpType.totp,
        digits: 6,
        period: 30,
        algorithm: 'SHA1',
        issuer: 'Original',
        account: 'original@example.com',
        secret: 'original-secret',
      );

      final copied = original.copyWith(
        issuer: 'Updated',
        account: 'updated@example.com',
      );

      expect(copied.type, original.type);
      expect(copied.digits, original.digits);
      expect(copied.period, original.period);
      expect(copied.algorithm, original.algorithm);
      expect(copied.issuer, 'Updated');
      expect(copied.account, 'updated@example.com');
      expect(copied.secret, original.secret);
    });
  });
}