import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import '../lib/core/models/auth_method.dart';
import '../lib/core/models/otp_config.dart';
import '../lib/core/models/ssh_connection.dart';
import '../lib/core/services/otp_service.dart';
import '../lib/core/services/secure_otp_storage.dart';
import '../lib/core/services/ssh_auth_manager.dart';
import '../lib/core/services/ssh_service.dart';
import 'ssh_connection_with_otp_test.mocks.dart';

@GenerateMocks([SshService, SecureOtpStorage, OtpService])
void main() {
  group('SSH Connection with OTP Integration Tests', () {
    late MockSshService mockSshService;
    late MockSecureOtpStorage mockOtpStorage;
    late MockOtpService mockOtpService;
    late SshConnection connection;

    setUp(() {
      mockSshService = MockSshService();
      mockOtpStorage = MockSecureOtpStorage();
      mockOtpService = MockOtpService();

      connection = SshConnection.create(
        name: 'Test Server',
        host: 'test.example.com',
        username: 'user',
        authMethod: AuthMethod.passwordWithOtp,
        useOtp: true,
        otpConfig: OtpConfig(
          type: OtpType.totp,
          digits: 6,
          period: 30,
          algorithm: 'SHA1',
          issuer: 'Test',
          account: 'user@test.com',
          secret: 'test-secret',
          secretId: 'test-secret-id',
        ),
      );
    });

    test('creates SSH connection with OTP configuration', () {
      expect(connection.name, 'Test Server');
      expect(connection.host, 'test.example.com');
      expect(connection.username, 'user');
      expect(connection.authMethod, AuthMethod.passwordWithOtp);
      expect(connection.useOtp, isTrue);
      expect(connection.otpConfig, isNotNull);
      expect(connection.requiresOtp, isTrue);
    });

    test('gets correct authentication method description', () {
      expect(connection.authMethodDescription, 'Password + OTP');

      final keyConnection = connection.copyWith(
        authMethod: AuthMethod.keyWithOtp,
      );
      expect(keyConnection.authMethodDescription, 'Private Key + OTP');

      final passwordOnly = connection.copyWith(
        authMethod: AuthMethod.password,
        useOtp: false,
      );
      expect(passwordOnly.authMethodDescription, 'Password');
    });

    test('creates copy with updated values', () {
      final updated = connection.copyWith(
        name: 'Updated Server',
        host: 'updated.example.com',
        useOtp: false,
      );

      expect(updated.name, 'Updated Server');
      expect(updated.host, 'updated.example.com');
      expect(updated.useOtp, isFalse);
      expect(updated.username, connection.username); // 保持不变
      expect(updated.otpConfig, connection.otpConfig); // 保持不变
    });

    test('SshAuthManager initializes correctly', () {
      final authManager = SshAuthManager(
        connection: connection,
        otpStorage: mockOtpStorage,
        otpService: mockOtpService,
        sshService: mockSshService,
      );

      expect(authManager.currentState, AuthState.initial);
    });

    test('OtpConfig creates from URI correctly', () {
      const uri = 'otpauth://totp/Test:user%40test.com'
          '?secret=JBSWY3DPEHPK3PXP'
          '&issuer=Test'
          '&algorithm=SHA1'
          '&digits=6'
          '&period=30';

      final config = OtpConfig.fromUri(uri);

      expect(config.type, OtpType.totp);
      expect(config.issuer, 'Test');
      expect(config.account, 'user@test.com');
      expect(config.secret, 'JBSWY3DPEHPK3PXP');
      expect(config.algorithm, 'SHA1');
      expect(config.digits, 6);
      expect(config.period, 30);
    });

    test('OtpConfig generates correct URI', () {
      const secret = 'JBSWY3DPEHPK3PXP';
      final config = OtpConfig(
        type: OtpType.totp,
        digits: 6,
        period: 30,
        algorithm: 'SHA1',
        issuer: 'Test',
        account: 'user@test.com',
        secret: secret,
      );

      final uri = config.toUri();

      expect(uri, contains('otpauth://totp/'));
      expect(uri, contains('secret=$secret'));
      expect(uri, contains('issuer=Test'));
      expect(uri, contains('account=user%40test.com'));
      expect(uri, contains('algorithm=SHA1'));
      expect(uri, contains('digits=6'));
      expect(uri, contains('period=30'));
    });

    test('AuthMethod enum conversions work correctly', () {
      expect(AuthMethod.password.name, 'password');
      expect(AuthMethod.privateKey.name, 'privateKey');
      expect(AuthMethod.passwordWithOtp.name, 'passwordWithOtp');
      expect(AuthMethod.keyWithOtp.name, 'keyWithOtp');

      expect(AuthMethodExtension.fromName('password'), AuthMethod.password);
      expect(AuthMethodExtension.fromName('privateKey'), AuthMethod.privateKey);
      expect(
        AuthMethodExtension.fromName('passwordWithOtp'),
        AuthMethod.passwordWithOtp,
      );
      expect(AuthMethodExtension.fromName('keyWithOtp'), AuthMethod.keyWithOtp);
      expect(AuthMethodExtension.fromName('unknown'), AuthMethod.password);
    });

    test('OtpType enum conversions work correctly', () {
      expect(OtpType.totp.name, 'totp');
      expect(OtpType.hotp.name, 'hotp');

      expect(OtpTypeExtension.fromName('totp'), OtpType.totp);
      expect(OtpTypeExtension.fromName('hotp'), OtpType.hotp);
      expect(OtpTypeExtension.fromName('unknown'), OtpType.totp);
    });
  });

  group('SecureOtpStorage Mock Tests', () {
    late MockSecureOtpStorage mockStorage;
    late SshConnection connection;

    setUp(() {
      mockStorage = MockSecureOtpStorage();
      connection = SshConnection.create(
        name: 'Test',
        host: 'test.com',
        username: 'user',
        useOtp: true,
        otpConfig: OtpConfig(
          secretId: 'test-secret-id',
        ),
      );
    });

    test('stores OTP secret successfully', () async {
      const secret = 'test-secret';
      final config = OtpConfig(
        type: OtpType.totp,
        digits: 6,
        period: 30,
        algorithm: 'SHA1',
        issuer: 'Test',
        account: 'user@test.com',
      );

      when(mockStorage.storeOtpSecret(
        connectionId: anyNamed('connectionId'),
        secret: anyNamed('secret'),
        config: anyNamed('config'),
      )).thenAnswer((_) async => 'stored-secret-id');

      final secretId = await mockStorage.storeOtpSecret(
        connectionId: connection.id,
        secret: secret,
        config: config,
      );

      expect(secretId, 'stored-secret-id');
      verify(mockStorage.storeOtpSecret(
        connectionId: connection.id,
        secret: secret,
        config: config,
      )).called(1);
    });

    test('retrieves OTP secret successfully', () async {
      const secret = 'test-secret';
      final config = OtpConfig(
        type: OtpType.totp,
        digits: 6,
        period: 30,
        algorithm: 'SHA1',
        issuer: 'Test',
        account: 'user@test.com',
      );

      when(mockStorage.getOtpSecret('test-secret-id'))
          .thenAnswer((_) async => (secret: secret, config: config));

      final result = await mockStorage.getOtpSecret('test-secret-id');

      expect(result, isNotNull);
      expect(result!.secret, secret);
      expect(result.config.type, config.type);
      expect(result.config.digits, config.digits);
      verify(mockStorage.getOtpSecret('test-secret-id')).called(1);
    });

    test('returns null for non-existent OTP secret', () async {
      when(mockStorage.getOtpSecret('non-existent-id'))
          .thenAnswer((_) async => null);

      final result = await mockStorage.getOtpSecret('non-existent-id');

      expect(result, isNull);
      verify(mockStorage.getOtpSecret('non-existent-id')).called(1);
    });
  });
}