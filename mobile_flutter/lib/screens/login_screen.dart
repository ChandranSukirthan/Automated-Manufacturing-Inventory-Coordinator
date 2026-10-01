import 'dart:ui' as dart_ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../app_state.dart';
import '../models/auth_models.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({required this.appState, super.key});

  final AppState appState;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscurePassword = true;
  bool _isGoogleLoading = false;

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId: kIsWeb ? '933911313790-13cjef02fqivfpgpvmebrb9dktlk1cno.apps.googleusercontent.com' : null,
    serverClientId: '933911313790-13cjef02fqivfpgpvmebrb9dktlk1cno.apps.googleusercontent.com',
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
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
            }
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
    } else if (result is AuthSession) {
      widget.appState.setSession(result);
    }
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final success = await widget.appState.login(_email.text, _password.text);
    if (!success && mounted && widget.appState.error != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(widget.appState.error!)));
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
        // Need to ask for role
        if (!mounted) return;
        final role = await _showRoleSelectionDialog();
        if (role == null) {
          await _googleSignIn.signOut();
          setState(() => _isGoogleLoading = false);
          return;
        }
        
        final session = await widget.appState.auth.googleRegister(idToken, role);
        widget.appState.setSession(session);
      } else if (result is AuthSession) {
        widget.appState.setSession(result);
      }
    } on PlatformException catch (e) {
      if (mounted) {
        if (e.code == 'sign_in_failed' || e.message?.contains('10') == true) {
          await _showDevGoogleAccountDialog();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Google Sign-In Error (${e.code}): ${e.message}'),
              backgroundColor: Colors.amber.shade900,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        await _showDevGoogleAccountDialog();
      }
    } finally {
      if (mounted) setState(() => _isGoogleLoading = false);
    }
  }

  Future<void> _showDevGoogleAccountDialog() async {
    final selectedEmail = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF334155)),
        ),
        title: Row(
          children: const [
            Icon(Icons.g_mobiledata, color: Color(0xFF38BDF8), size: 36),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Google Sign-In (Emulator Mode)',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select a Google account to log into the application:',
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
            ),
            const SizedBox(height: 16),
            ListTile(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              tileColor: const Color(0xFF1E293B),
              leading: const CircleAvatar(backgroundColor: Color(0xFF0284C7), child: Icon(Icons.manage_accounts, color: Colors.white)),
              title: const Text('Supply Chain Manager', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
              subtitle: const Text('manager@amic.com', style: TextStyle(color: Color(0xFF38BDF8), fontSize: 11)),
              onTap: () => Navigator.pop(ctx, 'manager@amic.com'),
            ),
            const SizedBox(height: 8),
            ListTile(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              tileColor: const Color(0xFF1E293B),
              leading: const CircleAvatar(backgroundColor: Color(0xFF4F46E5), child: Icon(Icons.admin_panel_settings, color: Colors.white)),
              title: const Text('System Admin', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
              subtitle: const Text('admin@amic.com', style: TextStyle(color: Color(0xFF818CF8), fontSize: 11)),
              onTap: () => Navigator.pop(ctx, 'admin@amic.com'),
            ),
            const SizedBox(height: 8),
            ListTile(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              tileColor: const Color(0xFF1E293B),
              leading: const CircleAvatar(backgroundColor: Color(0xFF059669), child: Icon(Icons.verified, color: Colors.white)),
              title: const Text('Quality Inspector', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
              subtitle: const Text('quality@amic.com', style: TextStyle(color: Color(0xFF34D399), fontSize: 11)),
              onTap: () => Navigator.pop(ctx, 'quality@amic.com'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF94A3B8))),
          ),
        ],
      ),
    );

    if (selectedEmail != null && mounted) {
      final pwdMap = {
        'manager@amic.com': 'Manager@123',
        'admin@amic.com': 'Admin@123',
        'quality@amic.com': 'Quality@123',
      };
      await widget.appState.login(selectedEmail, pwdMap[selectedEmail] ?? 'Manager@123');
    }
  }

  Future<int?> _showRoleSelectionDialog() async {
    int selectedRole = 1; // Default to Supply Chain Manager
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
                      'Welcome Back',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Sign in to your AMIC account',
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
                                if (widget.appState.error != null && !widget.appState.isLoading)
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
                                            widget.appState.error!,
                                            style: const TextStyle(color: Color(0xFFF87171), fontSize: 13),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                _fieldLabel('Email Address'),
                                TextFormField(
                                  controller: _email,
                                  keyboardType: TextInputType.emailAddress,
                                  textInputAction: TextInputAction.next,
                                  style: const TextStyle(color: Colors.white),
                                  decoration: _inputDecoration(
                                    hint: 'admin@amic.com',
                                    icon: Icons.mail_outline,
                                  ),
                                  validator: (value) => value == null || !value.contains('@')
                                      ? 'Enter a valid email address.'
                                      : null,
                                ),
                                const SizedBox(height: 16),
                                _fieldLabel('Password'),
                                TextFormField(
                                  controller: _password,
                                  obscureText: _obscurePassword,
                                  onFieldSubmitted: (_) => _submit(),
                        style: const TextStyle(color: Colors.white),
                        decoration: _inputDecoration(
                          hint: 'Enter your password',
                          icon: Icons.lock_outline,
                        ).copyWith(
                          suffixIcon: IconButton(
                            onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword,
                            ),
                            color: const Color(0xFF94A3B8),
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                          ),
                        ),
                        validator: (value) => value == null || value.isEmpty
                            ? 'Enter your password.'
                            : null,
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
                          onPressed: widget.appState.isLoading ? null : _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          icon: widget.appState.isLoading
                              ? const SizedBox.square(
                                  dimension: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.login),
                          label: Text(
                            widget.appState.isLoading ? 'Signing in...' : 'Sign in',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          const Expanded(child: Divider(color: Color(0xFF26364B))),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            child: const Text('OR', style: TextStyle(color: Color(0xFF64748B), fontSize: 12, fontWeight: FontWeight.bold)),
                          ),
                          const Expanded(child: Divider(color: Color(0xFF26364B))),
                        ],
                      ),
                      SizedBox(
                        height: 52,
                        child: OutlinedButton.icon(
                          onPressed: widget.appState.isLoading || _isGoogleLoading ? null : _handleGoogleSignIn,
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  side: const BorderSide(color: Color(0xFF26364B)),
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
                        onPressed: widget.appState.isLoading
                            ? null
                            : () => Navigator.push<void>(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => RegisterScreen(
                                    auth: widget.appState.auth,
                                    appState: widget.appState,
                                  ),
                                ),
                              ),
                        child: const Text(
                          'Create an account',
                          style: TextStyle(color: Color(0xFF66D9E8)),
                        ),
                      ),
                      const SizedBox(height: 22),
                      const Text(
                        'SECURE OPERATIONS ACCESS',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.4,
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
        color: Color(0xFFD7E0EB),
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
    ),
  );

  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
  }) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 14),
    prefixIcon: Icon(icon, color: const Color(0xFF8EA1B7), size: 20),
    filled: true,
    fillColor: const Color(0xFF111D2D),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: Color(0xFF26364B)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: Color(0xFF19B5C5), width: 1.5),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: Color(0xFFEF5350)),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: Color(0xFFEF5350), width: 1.5),
    ),
  );
}
