import 'dart:async';

import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../services/auth_service.dart';

class OtpScreen extends StatefulWidget {
  const OtpScreen({
    required this.auth,
    required this.email,
    this.initialMessage,
    super.key,
  });

  final AuthService auth;
  final String email;
  final String? initialMessage;

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _code = TextEditingController();
  Timer? _timer;
  int _secondsLeft = 180;
  bool _loading = false;
  bool _resending = false;
  String? _error;
  String? _success;

  @override
  void initState() {
    super.initState();
    _success = widget.initialMessage;
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_secondsLeft == 0) {
        _timer?.cancel();
      } else if (mounted) {
        setState(() => _secondsLeft--);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _code.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    if (_secondsLeft == 0 || !_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
      _success = null;
    });
    try {
      final message = await widget.auth.verifyOtp(
        email: widget.email,
        code: _code.text,
      );
      if (!mounted) return;
      setState(() => _success = message);
      await Future<void>.delayed(const Duration(milliseconds: 500));
      if (mounted) Navigator.pop(context);
    } on ApiException catch (exception) {
      if (mounted) setState(() => _error = exception.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resend() async {
    setState(() {
      _resending = true;
      _error = null;
      _success = null;
    });
    try {
      final message = await widget.auth.resendOtp(widget.email);
      if (mounted) {
        setState(() {
          _code.clear();
          _secondsLeft = 180;
          _success = message;
        });
        _startTimer();
      }
    } on ApiException catch (exception) {
      if (mounted) setState(() => _error = exception.message);
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  String get _timerLabel {
    final minutes = (_secondsLeft ~/ 60).toString().padLeft(2, '0');
    final seconds = (_secondsLeft % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Verify email')),
    body: SafeArea(
      child: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(28),
          children: [
            Icon(
              Icons.verified_user_outlined,
              size: 56,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'Check your email',
              style: Theme.of(context).textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text('We sent a six-digit code to ${widget.email}.'),
            const SizedBox(height: 28),
            if (_error != null) ...[
              _MessageBox(message: _error!, error: true),
              const SizedBox(height: 16),
            ],
            if (_success != null) ...[
              _MessageBox(message: _success!, error: false),
              const SizedBox(height: 16),
            ],
            TextFormField(
              controller: _code,
              keyboardType: TextInputType.number,
              maxLength: 6,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall
                  ?.copyWith(letterSpacing: 6, fontWeight: FontWeight.w700),
              decoration: const InputDecoration(
                labelText: 'Verification code',
                counterText: '',
              ),
              validator: (value) => value == null || value.length != 6
                  ? 'Enter all 6 digits.'
                  : null,
            ),
            const SizedBox(height: 12),
            Center(
              child: Text(
                _secondsLeft == 0 ? 'Code expired' : _timerLabel,
                style: TextStyle(
                  color: _secondsLeft < 30
                      ? Theme.of(context).colorScheme.error
                      : null,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _loading || _secondsLeft == 0 ? null : _verify,
              icon: _loading
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.verified_outlined),
              label: Text(_loading ? 'Verifying...' : 'Verify account'),
            ),
            TextButton(
              onPressed: _resending ? null : _resend,
              child: Text(_resending ? 'Sending...' : 'Resend code'),
            ),
          ],
        ),
      ),
    ),
  );
}

class _MessageBox extends StatelessWidget {
  const _MessageBox({required this.message, required this.error});

  final String message;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: error ? scheme.errorContainer : scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        message,
        style: TextStyle(
          color: error ? scheme.onErrorContainer : scheme.onSecondaryContainer,
        ),
      ),
    );
  }
}
