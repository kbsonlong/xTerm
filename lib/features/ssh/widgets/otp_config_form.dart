import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/models/auth_method.dart';
import '../../../core/models/otp_config.dart';
import '../../../core/models/ssh_connection.dart';
import '../../../core/services/otp_service.dart';
import '../../../core/services/secure_otp_storage.dart';

class OtpConfigForm extends ConsumerStatefulWidget {
  final SshConnection connection;
  final ValueChanged<SshConnection> onConnectionUpdated;
  final SecureOtpStorage? otpStorage;
  final OtpService? otpService;

  const OtpConfigForm({
    super.key,
    required this.connection,
    required this.onConnectionUpdated,
    this.otpStorage,
    this.otpService,
  });

  @override
  ConsumerState<OtpConfigForm> createState() => _OtpConfigFormState();
}

class _OtpConfigFormState extends ConsumerState<OtpConfigForm> {
  final _otpService = OtpService();
  SecureOtpStorage? _otpStorage;
  Timer? _timer;
  String? _currentOtpCode;
  int _remainingSeconds = 30;
  bool _isTesting = false;
  bool _showManualInput = false;
  String? _manualSecret;
  final _manualSecretController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _otpStorage = widget.otpStorage;
    _startOtpTimer();
    _loadExistingOtpConfig();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _manualSecretController.dispose();
    super.dispose();
  }

  void _loadExistingOtpConfig() {
    if (widget.connection.otpConfig?.secret != null) {
      _manualSecret = widget.connection.otpConfig!.secret;
      _manualSecretController.text = _manualSecret!;
    }
  }

  void _startOtpTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (widget.connection.otpConfig != null) {
        setState(() {
          _remainingSeconds = _otpService.getRemainingSeconds(widget.connection.otpConfig!);
          if (_remainingSeconds <= 0) {
            _remainingSeconds = widget.connection.otpConfig!.period;
            _updateCurrentOtpCode();
          }
        });
      }
    });

    _updateCurrentOtpCode();
  }

  void _updateCurrentOtpCode() {
    if (widget.connection.otpConfig != null && _manualSecret != null) {
      setState(() {
        _currentOtpCode = _otpService.generateCode(
          secret: _manualSecret!,
          config: widget.connection.otpConfig!,
        );
      });
    }
  }

  Future<void> _scanQrCode() async {
    final result = await Navigator.of(context).push<OtpConfig?>(
      MaterialPageRoute(
        builder: (context) => const QrCodeScannerScreen(),
      ),
    );

    if (result != null && mounted) {
      await _applyOtpConfig(result);
    }
  }

  Future<void> _applyOtpConfig(OtpConfig config) async {
    setState(() {
      widget.connection.otpConfig = config;
      widget.connection.useOtp = true;
      _manualSecret = config.secret;
      _manualSecretController.text = config.secret ?? '';
    });

    _updateCurrentOtpCode();
    widget.onConnectionUpdated(widget.connection.copyWith(
      useOtp: true,
      otpConfig: config,
    ));
  }

  Future<void> _testOtp() async {
    if (_manualSecret == null || widget.connection.otpConfig == null) {
      return;
    }

    setState(() => _isTesting = true);

    try {
      final testCode = _otpService.generateCode(
        secret: _manualSecret!,
        config: widget.connection.otpConfig!,
      );

      // 显示测试结果
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('OTP Test'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Generated OTP Code: $testCode'),
              const SizedBox(height: 16),
              if (_currentOtpCode != null)
                Text(
                  'Current OTP Code: $_currentOtpCode',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } catch (e) {
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Test Failed'),
          content: Text('Error: $e'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isTesting = false);
      }
    }
  }

  void _toggleManualInput() {
    setState(() {
      _showManualInput = !_showManualInput;
      if (!_showManualInput) {
        _manualSecretController.clear();
        _manualSecret = null;
      }
    });
  }

  void _saveManualSecret() {
    final secret = _manualSecretController.text.trim();
    if (secret.isEmpty) {
      return;
    }

    if (!_otpService.isValidSecret(secret)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid OTP secret format. Please enter a valid Base32 secret.'),
        ),
      );
      return;
    }

    setState(() {
      _manualSecret = secret;
    });

    // 更新配置
    final config = (widget.connection.otpConfig ?? OtpConfig()).copyWith(
      secret: secret,
    );

    _applyOtpConfig(config);
  }

  void _generateNewSecret() {
    final newSecret = _otpService.generateSecret();
    _manualSecretController.text = newSecret;
    _saveManualSecret();
  }

  void _updateAuthMethod(AuthMethod method) {
    final useOtp = method == AuthMethod.passwordWithOtp || method == AuthMethod.keyWithOtp;

    setState(() {
      widget.connection.authMethod = method;
      widget.connection.useOtp = useOtp;
    });

    widget.onConnectionUpdated(widget.connection.copyWith(
      authMethod: method,
      useOtp: useOtp,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 认证方式选择
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Text(
            'Authentication Method',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),

        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildAuthMethodChip(
              AuthMethod.password,
              'Password',
              Icons.lock,
            ),
            _buildAuthMethodChip(
              AuthMethod.privateKey,
              'Private Key',
              Icons.vpn_key,
            ),
            _buildAuthMethodChip(
              AuthMethod.passwordWithOtp,
              'Password + OTP',
              Icons.lock_clock,
            ),
            _buildAuthMethodChip(
              AuthMethod.keyWithOtp,
              'Key + OTP',
              Icons.vpn_key_rounded,
            ),
          ],
        ),

        const SizedBox(height: 24),

        // OTP 配置部分
        if (widget.connection.useOtp) ...[
          Text(
            'OTP Configuration',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),

          // OTP 代码显示
          if (_currentOtpCode != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Text(
                      _currentOtpCode!,
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        letterSpacing: 8,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: _otpService.getProgressPercentage(widget.connection.otpConfig!),
                      backgroundColor: Colors.grey[300],
                      valueColor: AlwaysStoppedAnimation<Color>(
                        _remainingSeconds > 10 ? Colors.green : Colors.orange,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Refreshes in $_remainingSeconds seconds',
                      style: Theme.of(context).textTheme.caption,
                    ),
                  ],
                ),
              ),
            ),

          const SizedBox(height: 16),

          // 配置按钮
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _scanQrCode,
                  icon: const Icon(Icons.qr_code_scanner),
                  label: const Text('Scan QR Code'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _toggleManualInput,
                  icon: Icon(_showManualInput ? Icons.visibility_off : Icons.visibility),
                  label: Text(_showManualInput ? 'Hide Input' : 'Manual Input'),
                ),
              ),
            ],
          ),

          // 手动输入区域
          if (_showManualInput) ...[
            const SizedBox(height: 16),
            TextField(
              controller: _manualSecretController,
              decoration: InputDecoration(
                labelText: 'OTP Secret (Base32)',
                hintText: 'Enter your OTP secret key',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _generateNewSecret,
                  tooltip: 'Generate new secret',
                ),
              ),
              onChanged: (value) {
                setState(() {
                  _manualSecret = value.trim().isNotEmpty ? value.trim() : null;
                });
              },
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _manualSecret != null ? _saveManualSecret : null,
                    child: const Text('Save Secret'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _testOtp,
                    child: _isTesting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Test OTP'),
                  ),
                ),
              ],
            ),
          ],

          // OTP 配置信息
          if (widget.connection.otpConfig != null) ...[
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'OTP Configuration Details',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    _buildConfigDetail('Issuer', widget.connection.otpConfig!.issuer),
                    _buildConfigDetail('Account', widget.connection.otpConfig!.account),
                    _buildConfigDetail('Type', widget.connection.otpConfig!.type.name.toUpperCase()),
                    _buildConfigDetail('Algorithm', widget.connection.otpConfig!.algorithm),
                    _buildConfigDetail('Digits', widget.connection.otpConfig!.digits.toString()),
                    if (widget.connection.otpConfig!.type == OtpType.totp)
                      _buildConfigDetail('Period', '${widget.connection.otpConfig!.period} seconds'),
                  ],
                ),
              ),
            ),
          ],
        ],

        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildAuthMethodChip(AuthMethod method, String label, IconData icon) {
    final isSelected = widget.connection.authMethod == method;
    final useOtp = method == AuthMethod.passwordWithOtp || method == AuthMethod.keyWithOtp;

    return FilterChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 4),
          Text(label),
        ],
      ),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          _updateAuthMethod(method);
        }
      },
      backgroundColor: isSelected
          ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
          : null,
      selectedColor: Theme.of(context).colorScheme.primary.withOpacity(0.2),
      checkmarkColor: Theme.of(context).colorScheme.primary,
      labelStyle: TextStyle(
        color: isSelected
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.onSurface,
      ),
      avatar: useOtp
          ? const Icon(Icons.security, size: 16)
          : null,
    );
  }

  Widget _buildConfigDetail(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

// 二维码扫描屏幕
class QrCodeScannerScreen extends StatefulWidget {
  const QrCodeScannerScreen({super.key});

  @override
  State<QrCodeScannerScreen> createState() => _QrCodeScannerScreenState();
}

class _QrCodeScannerScreenState extends State<QrCodeScannerScreen> {
  final MobileScannerController _controller = MobileScannerController();
  final OtpService _otpService = OtpService();
  bool _isScanning = true;
  String? _scannedData;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (!_isScanning) return;

    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final barcode = barcodes.first;
    if (barcode.rawValue == null) return;

    setState(() {
      _isScanning = false;
      _scannedData = barcode.rawValue;
    });

    try {
      final config = _otpService.parseQrCodeData(_scannedData!);
      Navigator.of(context).pop(config);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Invalid QR code: $e'),
          backgroundColor: Colors.red,
        ),
      );

      // 重新开始扫描
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() => _isScanning = true);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan QR Code'),
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on),
            onPressed: () => _controller.toggleTorch(),
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
          ),
          if (_isScanning)
            const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.qr_code_scanner, size: 80, color: Colors.white),
                  SizedBox(height: 16),
                  Text(
                    'Align QR code within frame',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          if (!_isScanning && _scannedData != null)
            Center(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.check_circle, color: Colors.green, size: 48),
                      const SizedBox(height: 16),
                      const Text('QR Code Scanned Successfully'),
                      const SizedBox(height: 8),
                      Text(
                        _scannedData!,
                        style: const TextStyle(fontSize: 12),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Icon(Icons.close),
      ),
    );
  }
}