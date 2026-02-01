import 'dart:async';

import 'package:flutter/material.dart';

class OtpInputDialog extends StatefulWidget {
  final String connectionName;
  final int timeRemaining;
  final String? currentOtpCode;
  final ValueChanged<String> onOtpSubmitted;
  final VoidCallback onCancel;
  final VoidCallback? onUseCurrentCode;

  const OtpInputDialog({
    super.key,
    required this.connectionName,
    required this.timeRemaining,
    this.currentOtpCode,
    required this.onOtpSubmitted,
    required this.onCancel,
    this.onUseCurrentCode,
  });

  @override
  State<OtpInputDialog> createState() => _OtpInputDialogState();
}

class _OtpInputDialogState extends State<OtpInputDialog> {
  final _otpController = TextEditingController();
  Timer? _timer;
  int _remainingSeconds = 30;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _remainingSeconds = widget.timeRemaining;
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _otpController.dispose();
    super.dispose();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _remainingSeconds--;
        if (_remainingSeconds <= 0) {
          _remainingSeconds = 30;
        }
      });
    });
  }

  void _submitOtp() {
    final otp = _otpController.text.trim();
    if (otp.length == 6 && int.tryParse(otp) != null) {
      setState(() => _isSubmitting = true);
      widget.onOtpSubmitted(otp);
    }
  }

  void _useCurrentCode() {
    if (widget.currentOtpCode != null) {
      setState(() => _isSubmitting = true);
      widget.onOtpSubmitted(widget.currentOtpCode!);
    }
  }

  Color _getProgressColor() {
    if (_remainingSeconds > 20) return Colors.green;
    if (_remainingSeconds > 10) return Colors.orange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.security, color: Colors.blue),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'OTP Required for ${widget.connectionName}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Enter the 6-digit code from your authenticator app',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 20),

            // 当前 OTP 代码显示
            if (widget.currentOtpCode != null) ...[
              Card(
                color: Colors.blue.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.lightbulb_outline, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            'Current OTP Code',
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.currentOtpCode!,
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          letterSpacing: 8,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        onPressed: widget.onUseCurrentCode ?? _useCurrentCode,
                        icon: const Icon(Icons.check_circle, size: 16),
                        label: const Text('Use This Code'),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 40),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Divider(),
              const SizedBox(height: 20),
              const Text(
                'Or enter a different code:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
            ],

            // OTP 输入框
            TextField(
              controller: _otpController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              decoration: InputDecoration(
                labelText: 'OTP Code',
                hintText: '123456',
                counterText: '',
                prefixIcon: const Icon(Icons.lock_clock),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: () {
                    setState(() => _remainingSeconds = 30);
                  },
                  tooltip: 'Reset timer',
                ),
                border: const OutlineInputBorder(),
              ),
              onChanged: (value) {
                if (value.length == 6) {
                  _submitOtp();
                }
              },
            ),
            const SizedBox(height: 16),

            // 进度条
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Code refreshes in',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    Text(
                      '$_remainingSeconds seconds',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _getProgressColor(),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                LinearProgressIndicator(
                  value: _remainingSeconds / 30,
                  backgroundColor: Colors.grey[300],
                  valueColor: AlwaysStoppedAnimation<Color>(_getProgressColor()),
                  minHeight: 6,
                  borderRadius: BorderRadius.circular(3),
                ),
              ],
            ),

            const SizedBox(height: 8),
            Text(
              'Tip: Codes are typically 6 digits and change every 30 seconds',
              style: Theme.of(context).textTheme.caption,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : widget.onCancel,
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isSubmitting ? null : _submitOtp,
          child: _isSubmitting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Submit'),
        ),
      ],
    );
  }
}