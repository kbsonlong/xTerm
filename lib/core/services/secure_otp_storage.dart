import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:pointycastle/export.dart';

import '../models/otp_config.dart';

class SecureOtpStorage {
  final FlutterSecureStorage _secureStorage;
  final LocalAuthentication _localAuth;
  final Uint8List _encryptionKey;

  static const String _keyPrefix = 'otp_secret_';
  static const String _keyStorageKey = 'otp_encryption_key';

  SecureOtpStorage()
      : _secureStorage = const FlutterSecureStorage(),
        _localAuth = LocalAuthentication(),
        _encryptionKey = Uint8List(32); // 256-bit key

  // 初始化加密密钥
  Future<void> _initializeEncryptionKey() async {
    final existingKey = await _secureStorage.read(key: _keyStorageKey);
    if (existingKey != null) {
      _encryptionKey.setAll(0, base64Decode(existingKey));
    } else {
      // 生成新的随机密钥
      final secureRandom = FortunaRandom();
      final seedSource = Random.secure();
      final seeds = <int>[];
      for (var i = 0; i < 32; i++) {
        seeds.add(seedSource.nextInt(256));
      }
      secureRandom.seed(KeyParameter(Uint8List.fromList(seeds)));

      final newKey = secureRandom.nextBytes(32);
      _encryptionKey.setAll(0, newKey);

      await _secureStorage.write(
        key: _keyStorageKey,
        value: base64Encode(newKey),
      );
    }
  }

  // 加密数据
  Future<String> _encryptData(Map<String, dynamic> data) async {
    await _initializeEncryptionKey();

    final jsonString = jsonEncode(data);
    final plaintext = utf8.encode(jsonString);

    // 使用 AES-GCM 加密
    final cipher = GCMBlockCipher(AESEngine())
      ..init(
        true,
        AEADParameters(
          KeyParameter(_encryptionKey),
          128,
          _generateNonce(),
          Uint8List(0), // 无附加认证数据
        ),
      );

    final ciphertext = cipher.process(Uint8List.fromList(plaintext));
    final encryptedData = {
      'ciphertext': base64Encode(ciphertext),
      'nonce': base64Encode(cipher.parameters.param.nonce),
      'tag': base64Encode(cipher.parameters.param.mac),
    };

    return jsonEncode(encryptedData);
  }

  // 解密数据
  Future<Map<String, dynamic>> _decryptData(String encryptedJson) async {
    await _initializeEncryptionKey();

    final encryptedData = jsonDecode(encryptedJson) as Map<String, dynamic>;
    final ciphertext = base64Decode(encryptedData['ciphertext'] as String);
    final nonce = base64Decode(encryptedData['nonce'] as String);
    final tag = base64Decode(encryptedData['tag'] as String);

    // 使用 AES-GCM 解密
    final cipher = GCMBlockCipher(AESEngine())
      ..init(
        false,
        AEADParameters(
          KeyParameter(_encryptionKey),
          128,
          nonce,
          Uint8List(0), // 无附加认证数据
        ),
      );

    final plaintext = cipher.process(ciphertext);

    // 验证认证标签
    final calculatedTag = cipher.parameters.param.mac;
    if (!_constantTimeEquals(calculatedTag, tag)) {
      throw Exception('Authentication tag mismatch');
    }

    final jsonString = utf8.decode(plaintext);
    return jsonDecode(jsonString) as Map<String, dynamic>;
  }

  // 生成随机 nonce
  Uint8List _generateNonce() {
    final secureRandom = FortunaRandom();
    final seedSource = Random.secure();
    final seeds = <int>[];
    for (var i = 0; i < 16; i++) {
      seeds.add(seedSource.nextInt(256));
    }
    secureRandom.seed(KeyParameter(Uint8List.fromList(seeds)));

    return secureRandom.nextBytes(12); // 96-bit nonce for GCM
  }

  // 常量时间比较（防止时序攻击）
  bool _constantTimeEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;

    var result = 0;
    for (var i = 0; i < a.length; i++) {
      result |= a[i] ^ b[i];
    }
    return result == 0;
  }

  // 存储 OTP 密钥
  Future<String> storeOtpSecret({
    required String connectionId,
    required String secret,
    required OtpConfig config,
  }) async {
    final storageId = '${_keyPrefix}${connectionId}_${DateTime.now().millisecondsSinceEpoch}';

    final data = {
      'secret': secret,
      'config': config.copyWith(secret: null, secretId: storageId).toJson(),
      'createdAt': DateTime.now().toIso8601String(),
    };

    final encryptedData = await _encryptData(data);

    await _secureStorage.write(
      key: storageId,
      value: encryptedData,
    );

    return storageId;
  }

  // 获取 OTP 密钥
  Future<({String secret, OtpConfig config})?> getOtpSecret(
    String storageId, {
    bool requireBiometric = true,
  }) async {
    if (requireBiometric) {
      final canAuthenticate = await _localAuth.canCheckBiometrics;
      if (canAuthenticate) {
        final authenticated = await _localAuth.authenticate(
          localizedReason: 'Access OTP secret',
          options: const AuthenticationOptions(
            stickyAuth: true,
            biometricOnly: true,
          ),
        );

        if (!authenticated) {
          return null;
        }
      }
    }

    final encryptedData = await _secureStorage.read(key: storageId);
    if (encryptedData == null) {
      return null;
    }

    try {
      final data = await _decryptData(encryptedData);
      final secret = data['secret'] as String;
      final configJson = data['config'] as Map<String, dynamic>;
      final config = OtpConfig.fromJson(configJson);

      return (secret: secret, config: config);
    } catch (e) {
      print('Failed to decrypt OTP secret: $e');
      return null;
    }
  }

  // 更新 OTP 配置
  Future<void> updateOtpConfig({
    required String storageId,
    required OtpConfig config,
  }) async {
    final encryptedData = await _secureStorage.read(key: storageId);
    if (encryptedData == null) {
      throw Exception('OTP secret not found');
    }

    final data = await _decryptData(encryptedData);
    data['config'] = config.copyWith(secret: null, secretId: storageId).toJson();

    final updatedEncryptedData = await _encryptData(data);
    await _secureStorage.write(
      key: storageId,
      value: updatedEncryptedData,
    );
  }

  // 删除 OTP 密钥
  Future<void> deleteOtpSecret(String storageId) async {
    await _secureStorage.delete(key: storageId);
  }

  // 检查 OTP 密钥是否存在
  Future<bool> hasOtpSecret(String storageId) async {
    final value = await _secureStorage.read(key: storageId);
    return value != null;
  }

  // 获取所有 OTP 密钥 ID
  Future<List<String>> getAllOtpSecretIds() async {
    final allKeys = await _secureStorage.readAll();
    return allKeys.keys
        .where((key) => key.startsWith(_keyPrefix))
        .toList();
  }

  // 清除所有 OTP 密钥
  Future<void> clearAllOtpSecrets() async {
    final otpKeys = await getAllOtpSecretIds();
    for (final key in otpKeys) {
      await _secureStorage.delete(key: key);
    }
  }
}