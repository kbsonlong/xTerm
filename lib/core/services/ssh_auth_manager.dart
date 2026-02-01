import 'dart:async';

import '../models/ssh_connection.dart';
import 'otp_service.dart';
import 'secure_otp_storage.dart';
import 'ssh_service.dart';

// 认证状态枚举
enum AuthState {
  initial,       // 初始状态
  primaryAuth,   // 主认证进行中
  otpRequired,   // 需要 OTP
  otpVerifying,  // OTP 验证中
  completed,     // 认证完成
  error,         // 认证错误
}

// 认证异常
class SshAuthException implements Exception {
  final String message;
  final AuthState state;

  SshAuthException(this.message, {this.state = AuthState.error});

  @override
  String toString() => 'SshAuthException: $message (state: $state)';
}

// 认证管理器
class SshAuthManager {
  final SshConnection connection;
  final SecureOtpStorage otpStorage;
  final OtpService otpService;
  final SshService sshService;

  // 状态流
  Stream<AuthState> get stateStream => _stateController.stream;
  final _stateController = StreamController<AuthState>.broadcast();

  // OTP 代码流
  Stream<String?> get otpCodeStream => _otpCodeController.stream;
  final _otpCodeController = StreamController<String?>.broadcast();

  AuthState _state = AuthState.initial;
  String? _currentOtpCode;
  Completer<String>? _otpInputCompleter;

  SshAuthManager({
    required this.connection,
    required this.otpStorage,
    required this.otpService,
    required this.sshService,
  });

  // 获取当前状态
  AuthState get currentState => _state;

  // 执行认证
  Future<void> authenticate() async {
    try {
      _updateState(AuthState.primaryAuth);

      // 执行主认证
      await _performPrimaryAuth();

      // 检查是否需要 OTP
      if (connection.requiresOtp) {
        await _performOtpAuth();
      }

      _updateState(AuthState.completed);
    } catch (e) {
      _updateState(AuthState.error, error: e);
      rethrow;
    }
  }

  // 执行主认证
  Future<void> _performPrimaryAuth() async {
    try {
      // 根据认证方式准备认证参数
      switch (connection.authMethod) {
        case AuthMethod.password:
        case AuthMethod.passwordWithOtp:
          // 使用密码认证
          await sshService.connect(connection);
          break;

        case AuthMethod.privateKey:
        case AuthMethod.keyWithOtp:
          // 使用密钥认证
          await sshService.connect(connection);
          break;
      }
    } catch (e) {
      throw SshAuthException(
        'Primary authentication failed: $e',
        state: AuthState.error,
      );
    }
  }

  // 执行 OTP 认证
  Future<void> _performOtpAuth() async {
    if (!connection.requiresOtp || connection.otpConfig == null) {
      return;
    }

    try {
      _updateState(AuthState.otpRequired);

      // 获取 OTP 密钥
      final otpData = await otpStorage.getOtpSecret(
        connection.otpConfig!.secretId!,
        requireBiometric: true,
      );

      if (otpData == null) {
        throw SshAuthException(
          'OTP secret not found or access denied',
          state: AuthState.error,
        );
      }

      // 生成当前 OTP 代码
      final otpCode = otpService.generateCode(
        secret: otpData.secret,
        config: otpData.config,
      );

      _currentOtpCode = otpCode;
      _otpCodeController.add(otpCode);

      // 等待用户确认或输入
      final userOtp = await _requestOtpInput();

      // 验证 OTP
      _updateState(AuthState.otpVerifying);

      final isValid = otpService.validateCode(
        secret: otpData.secret,
        code: userOtp,
        config: otpData.config,
      );

      if (!isValid) {
        throw SshAuthException(
          'Invalid OTP code',
          state: AuthState.error,
        );
      }

      // 执行 OTP 认证（通过键盘交互）
      await _sendOtpToServer(userOtp);

    } catch (e) {
      if (e is! SshAuthException) {
        throw SshAuthException(
          'OTP authentication failed: $e',
          state: AuthState.error,
        );
      }
      rethrow;
    }
  }

  // 请求 OTP 输入
  Future<String> _requestOtpInput() async {
    _otpInputCompleter = Completer<String>();

    // 这里会触发 UI 显示 OTP 输入对话框
    // UI 层应该监听 otpCodeStream 和 stateStream，然后调用 provideOtpInput

    // 设置超时（30秒）
    final timeout = Future.delayed(const Duration(seconds: 30), () {
      if (!_otpInputCompleter!.isCompleted) {
        _otpInputCompleter!.completeError(
          TimeoutException('OTP input timeout'),
        );
      }
    });

    try {
      final userOtp = await _otpInputCompleter!.future;
      await timeout; // 等待超时 future 完成（或取消）
      return userOtp;
    } catch (e) {
      throw SshAuthException(
        'OTP input failed: $e',
        state: AuthState.error,
      );
    } finally {
      _otpInputCompleter = null;
    }
  }

  // 提供 OTP 输入（由 UI 调用）
  void provideOtpInput(String otpCode) {
    if (_otpInputCompleter != null && !_otpInputCompleter!.isCompleted) {
      _otpInputCompleter!.complete(otpCode);
    }
  }

  // 取消 OTP 输入
  void cancelOtpInput() {
    if (_otpInputCompleter != null && !_otpInputCompleter!.isCompleted) {
      _otpInputCompleter!.completeError(
        SshAuthException('OTP input cancelled by user'),
      );
    }
  }

  // 发送 OTP 到服务器
  Future<void> _sendOtpToServer(String otpCode) async {
    // 这里需要扩展 SSH 服务以支持键盘交互认证
    // 目前先模拟发送
    await Future.delayed(const Duration(milliseconds: 500));

    // TODO: 实现实际的键盘交互认证
    // await sshService.sendKeyboardInteractiveResponse([otpCode]);
  }

  // 获取 OTP 剩余时间
  int? getOtpRemainingSeconds() {
    if (!connection.requiresOtp || connection.otpConfig == null) {
      return null;
    }

    return otpService.getRemainingSeconds(connection.otpConfig!);
  }

  // 获取 OTP 进度百分比
  double? getOtpProgressPercentage() {
    if (!connection.requiresOtp || connection.otpConfig == null) {
      return null;
    }

    return otpService.getProgressPercentage(connection.otpConfig!);
  }

  // 更新状态
  void _updateState(AuthState state, {Object? error}) {
    _state = state;
    _stateController.add(state);

    if (error != null && state == AuthState.error) {
      _stateController.addError(error);
    }
  }

  // 清理资源
  void dispose() {
    _stateController.close();
    _otpCodeController.close();
    _otpInputCompleter?.completeError(
      SshAuthException('Auth manager disposed'),
    );
  }
}