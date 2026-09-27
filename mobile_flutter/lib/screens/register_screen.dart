import 'dart:ui' as dart_ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:google_sign_in_web/web_only.dart' as web;

import '../app_state.dart';
import '../models/auth_models.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import 'otp_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({required this.auth, required this.appState, super.key});

  final AuthService auth;
  final AppState appState;

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();
  final _roles = [
    'SupplyChainManager',
    'QualityInspector',
    'ITAdmin',
    'FloorWorker',
  ];
  String _role = 'SupplyChainManager';
  bool _obscurePassword = true;
  bool _obscureConfirmation = true;
  bool _loading = false;
  bool _isGoogleLoading = false;
  String? _error;

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId: '933911313790-13cjef02fqivfpgpvmebrb9dktlk1cno.apps.googleusercontent.com',
    scopes: ['email', 'profile', 'openid'],
  );

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      _googleSignIn.onCurrentUserChanged.listen((account) async {
        if (!mounted) return;
        if (account != null) {
          setState(() => _isGoogleLoading = true);
          try {
            final auth = await account.authentication;
            final idToken = auth.idToken;
            if (idToken != null) {
              await _processGoogleToken(idToken);
            }
          } catch (e) {
            if (mounted) setState(() => _error = e.toString());
          } finally {
            if (mounted) setState(() => _isGoogleLoading = false);
          }
        }
      });
    }
  }

  Future<void> _processGoogleToken(String idToken) async {
    final result = await widget.appState.auth.googleLogin(idToken);
    
    if (result is Map<String, dynamic> && result['requiresRoleSelection'] == true) {
      if (!mounted) return;
      final role = await _showRoleSelectionDialog();
      if (role == null) {
        await _googleSignIn.signOut();
        return;
      }
      
      final session = await widget.appState.auth.googleRegister(idToken, role);
      widget.appState.setSession(session);
      if (mounted) Navigator.pop(context);
    } else if (result is AuthSession) {
      widget.appState.setSession(result);
      if (mounted) Navigator.pop(context);
    }
  }


  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final message = await widget.auth.register(
        fullName: _name.text.trim(),
        email: _email.text.trim().toLowerCase(),
        password: _password.text,
        role: _role,
      );
      if (!mounted) return;
      await Navigator.pushReplacement<void, void>(
        context,
        MaterialPageRoute(
          builder: (_) => OtpScreen(
            auth: widget.auth,
            email: _email.text.trim().toLowerCase(),
            initialMessage: message,
          ),
        ),
      );
    } on ApiException catch (exception) {
      if (mounted) setState(() => _error = exception.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isGoogleLoading = true);
    try {
      final account = await _googleSignIn.signIn();
      if (account == null) {
        setState(() => _isGoogleLoading = false);
        return;
      }
      final auth = await account.authentication;
      final idToken = auth.idToken;
      
      if (idToken == null) {
        throw Exception('Failed to obtain Google ID Token.');
      }

      final result = await widget.appState.auth.googleLogin(idToken);
      
      if (result is Map<String, dynamic> && result['requiresRoleSelection'] == true) {
        if (!mounted) return;
        final role = await _showRoleSelectionDialog();
        if (role == null) {
          await _googleSignIn.signOut();
          setState(() => _isGoogleLoading = false);
          return;
        }
        
        final session = await widget.appState.auth.googleRegister(idToken, role);
        widget.appState.setSession(session);
        Navigator.of(context).pop(); // Go back to root (which is now logged in)
      } else if (result is AuthSession) {
        widget.appState.setSession(result);
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _isGoogleLoading = false);
    }
  }

  Future<int?> _showRoleSelectionDialog() async {
    int selectedRole = 1;
    return showDialog<int>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: const Color(0xFF111D2D),
          title: const Text('Choose Your Role', style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Please select your role to complete Google Sign-In.', style: TextStyle(color: Color(0xFF9BAABC))),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                value: selectedRole,
                dropdownColor: const Color(0xFF111D2D),
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: const Color(0xFF08111F),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                items: const [
                  DropdownMenuItem(value: 1, child: Text('Supply Chain Manager')),
                  DropdownMenuItem(value: 2, child: Text('Quality Inspector')),
                  DropdownMenuItem(value: 3, child: Text('System Admin')),
                  DropdownMenuItem(value: 0, child: Text('Floor Worker')),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => selectedRole = val);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF19B5C5)),
              onPressed: () => Navigator.pop(context, selectedRole),
              child: const Text('Complete Sign In', style: TextStyle(color: Colors.black)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFF020617), // slate-950
    body: Stack(
      children: [
        // Background Decorative Blobs
        Positioned(
          top: -150,
          left: -150,
          child: Container(
            width: 350,
            height: 350,
            decoration: BoxDecoration(
              color: const Color(0xFF0284C7).withValues(alpha: 0.4),
              shape: BoxShape.circle,
            ),
          ),
        ),
        Positioned(
          top: -150,
          right: -150,
          child: Container(
            width: 350,
            height: 350,
            decoration: BoxDecoration(
              color: const Color(0xFF0891B2).withValues(alpha: 0.4),
              shape: BoxShape.circle,
            ),
          ),
        ),
        Positioned(
          bottom: -100,
          left: 50,
          child: Container(
            width: 250,
            height: 250,
            decoration: BoxDecoration(
              color: const Color(0xFF2563EB).withValues(alpha: 0.4),
              shape: BoxShape.circle,
            ),
          ),
        ),
        // Blur Effect
        BackdropFilter(
          filter: dart_ui.ImageFilter.blur(sigmaX: 80.0, sigmaY: 80.0),
          child: Container(color: Colors.transparent),
        ),
        // Scrollable Content
        SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header Logo
                    Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Image.asset(
                            'assets/amic-logo.png',
                            width: 56,
                            height: 56,
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'AMIC',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Create Account',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Join the Manufacturing Coordinator system',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFF94A3B8), // slate-400
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // Glassmorphic Card
                    Container(
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.5),
                            blurRadius: 30,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Positioned(
                            top: -28,
                            left: 0,
                            right: 0,
                            child: Center(
                              child: Container(
                                width: 200,
                                height: 2,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.transparent,
                                      const Color(0xFF0EA5E9).withValues(alpha: 0.5),
                                      Colors.transparent,
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (_error != null)
                                  Container(
                                    margin: const EdgeInsets.only(bottom: 16),
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                                      border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.2)),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.error_outline, color: Color(0xFFF87171), size: 16),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            _error!,
                                            style: const TextStyle(color: Color(0xFFF87171), fontSize: 13),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                _fieldLabel('Full Name'),
                                TextFormField(
                                  controller: _name,
                                  textInputAction: TextInputAction.next,
                                  style: const TextStyle(color: Colors.white),
                                  decoration: _inputDecoration(
                                    hint: 'John Doe',
                                    icon: Icons.person_outline,
                                  ),
                                  validator: (value) => value == null || value.trim().isEmpty
                                      ? 'Enter your full name.'
                                      : null,
                                ),
                                const SizedBox(height: 16),
                                _fieldLabel('Email Address'),
                                TextFormField(
                                  controller: _email,
                                  keyboardType: TextInputType.emailAddress,
                                  textInputAction: TextInputAction.next,
                                  style: const TextStyle(color: Colors.white),
                                  decoration: _inputDecoration(
                                    hint: 'john@company.com',
                                    icon: Icons.mail_outline,
                                  ),
                                  validator: (value) => value == null || !value.contains('@')
                                      ? 'Enter a valid email address.'
                                      : null,
                                ),
                                const SizedBox(height: 16),
                                _fieldLabel('Role'),
                                DropdownButtonFormField<String>(
                                  value: _role,
                                  dropdownColor: const Color(0xFF0F172A),
                                  style: const TextStyle(color: Colors.white),
                                  decoration: _inputDecoration(
                                    hint: 'Select Role',
                                    icon: Icons.badge_outlined,
                                  ),
                                  items: _roles
                                      .map((role) => DropdownMenuItem(value: role, child: Text(role)))
                                      .toList(),
                                  onChanged: (value) => setState(() => _role = value!),
                                ),
                                const SizedBox(height: 16),
                                _fieldLabel('Password'),
                                TextFormField(
                                  controller: _password,
                                  obscureText: _obscurePassword,
                                  textInputAction: TextInputAction.next,
                                  style: const TextStyle(color: Colors.white),
                                  decoration: _inputDecoration(
                                    hint: '••••••••',
                                    icon: Icons.lock_outline,
                                  ).copyWith(
                                    suffixIcon: IconButton(
                                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                                      color: const Color(0xFF94A3B8),
                                      icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                                    ),
                                  ),
                                  validator: (value) => value == null || value.length < 8
                                      ? 'Password must be at least 8 characters.'
                                      : null,
                                ),
                                const SizedBox(height: 16),
                                _fieldLabel('Confirm Password'),
                                TextFormField(
                                  controller: _confirmPassword,
                                  obscureText: _obscureConfirmation,
                                  style: const TextStyle(color: Colors.white),
                                  decoration: _inputDecoration(
                                    hint: '••••••••',
                                    icon: Icons.lock_outline,
                                  ).copyWith(
                                    suffixIcon: IconButton(
                                      onPressed: () => setState(() => _obscureConfirmation = !_obscureConfirmation),
                                      color: const Color(0xFF94A3B8),
                                      icon: Icon(_obscureConfirmation ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                                    ),
                                  ),
                                  validator: (value) => value != _password.text ? 'Passwords do not match.' : null,
                                ),
                                const SizedBox(height: 26),
                                Container(
                                  height: 52,
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [Color(0xFF0284C7), Color(0xFF0891B2)],
                                    ),
                                    borderRadius: BorderRadius.circular(10),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.white.withValues(alpha: 0.1),
                                        blurRadius: 15,
                                      ),
                                    ],
                                  ),
                                  child: ElevatedButton.icon(
                                    onPressed: _loading || _isGoogleLoading ? null : _submit,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.transparent,
                                      shadowColor: Colors.transparent,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                    icon: _loading
                                        ? const SizedBox.square(
                                            dimension: 18,
                                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                          )
                                        : const Icon(Icons.person_add_outlined),
                                    label: Text(
                                      _loading ? 'Creating account...' : 'Create account',
                                      style: const TextStyle(fontWeight: FontWeight.w700),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 20),
                                Row(
                                  children: [
                                    const Expanded(child: Divider(color: Color(0xFF334155))),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 14),
                                      child: const Text('OR', style: TextStyle(color: Color(0xFF64748B), fontSize: 12, fontWeight: FontWeight.bold)),
                                    ),
                                    const Expanded(child: Divider(color: Color(0xFF334155))),
                                  ],
                                ),
                                const SizedBox(height: 20),
                                kIsWeb
                                  ? SizedBox(
                                      height: 52,
                                      child: web.renderButton(),
                                    )
                                  : SizedBox(
                                      height: 52,
                                      child: OutlinedButton.icon(
                                        onPressed: _loading || _isGoogleLoading ? null : _handleGoogleSignIn,
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: Colors.white,
                                          side: const BorderSide(color: Color(0xFF334155)),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                        ),
                                        icon: _isGoogleLoading
                                            ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                            : const Icon(Icons.g_mobiledata, size: 28),
                                        label: Text(
                                          _isGoogleLoading ? 'Connecting...' : 'Sign in with Google',
                                          style: const TextStyle(fontWeight: FontWeight.w600),
                                        ),
                                      ),
                                    ),
                                const SizedBox(height: 20),
                                TextButton(
                                  onPressed: _loading ? null : () => Navigator.pop(context),
                                  child: const Text(
                                    'Already have an account? Sign in',
                                    style: TextStyle(color: Color(0xFF38BDF8)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );

  Widget _fieldLabel(String label) => Padding(
    padding: const EdgeInsets.only(left: 2, bottom: 7),
    child: Text(
      label,
      style: const TextStyle(
        color: Color(0xFFCBD5E1), // slate-300
        fontSize: 13,
        fontWeight: FontWeight.w500,
      ),
    ),
  );

  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
  }) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 14), // slate-500
    prefixIcon: Icon(icon, color: const Color(0xFF64748B), size: 20),
    filled: true,
    fillColor: const Color(0xFF0F172A).withValues(alpha: 0.5), // slate-900/50
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFF334155)), // slate-700
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFF0EA5E9), width: 1.5), // brand-500
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFFEF4444)), // red-500
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
    ),
  );
}
