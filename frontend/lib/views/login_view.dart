import 'package:flutter/material.dart';

class LoginView extends StatefulWidget {
  final bool Function(String username, String password) onAdminLogin;
  final bool Function(String employeeIdOrUsername, String password)
      onEmployeeLogin;

  const LoginView({
    super.key,
    required this.onAdminLogin,
    required this.onEmployeeLogin,
  });

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isAdminSignIn = false;
  bool _obscurePassword = true;
  String? _signInError;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _changeMode(bool isAdminSignIn) {
    setState(() {
      _isAdminSignIn = isAdminSignIn;
      _signInError = null;
      _usernameController.clear();
      _passwordController.clear();
    });
  }

  void _signIn() {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final isAuthenticated = _isAdminSignIn
        ? widget.onAdminLogin(
            _usernameController.text.trim(),
            _passwordController.text,
          )
        : widget.onEmployeeLogin(
            _usernameController.text.trim(),
            _passwordController.text,
          );
    if (!isAuthenticated) {
      setState(() {
        _signInError = _isAdminSignIn
            ? 'Incorrect Admin username or password.'
            : 'Incorrect employee ID, username, or password.';
      });
    }
  }

  InputDecoration _decoration(String label, {Widget? suffixIcon}) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white60),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: const Color(0xFF1E1E1E),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.white12),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.white12),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFFFD700)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const yellowAccent = Color(0xFFFFD700);
    final heading = _isAdminSignIn ? 'Admin Sign In' : 'Employee Sign In';
    final prompt = _isAdminSignIn
        ? 'Sign in to manage employees and financial approvals.'
        : 'Sign in with your employee ID or username.';

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: SafeArea(
        child: Scrollbar(
          thumbVisibility: true,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 48),
                      Icon(
                        _isAdminSignIn
                            ? Icons.admin_panel_settings_outlined
                            : Icons.precision_manufacturing,
                        color: yellowAccent,
                        size: 52,
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'AMIC',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: yellowAccent,
                          fontSize: 30,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: ChoiceChip(
                              label: const Text('Employee'),
                              selected: !_isAdminSignIn,
                              onSelected: (_) => _changeMode(false),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ChoiceChip(
                              label: const Text('Admin'),
                              selected: _isAdminSignIn,
                              onSelected: (_) => _changeMode(true),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 28),
                      Text(
                        heading,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        prompt,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white60, fontSize: 15),
                      ),
                      const SizedBox(height: 36),
                      TextFormField(
                        controller: _usernameController,
                        textCapitalization: _isAdminSignIn
                            ? TextCapitalization.none
                            : TextCapitalization.characters,
                        style: const TextStyle(color: Colors.white),
                        decoration: _decoration(
                          _isAdminSignIn ? 'Admin username' : 'Employee ID or username',
                        ),
                        validator: (value) => value == null || value.trim().isEmpty
                            ? 'Enter ${_isAdminSignIn ? 'the Admin username' : 'your employee ID or username'}'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        style: const TextStyle(color: Colors.white),
                        decoration: _decoration(
                          'Password',
                          suffixIcon: IconButton(
                            tooltip: _obscurePassword
                                ? 'Show password'
                                : 'Hide password',
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              color: Colors.white60,
                            ),
                            onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword,
                            ),
                          ),
                        ),
                        validator: (value) => value == null || value.isEmpty
                            ? 'Enter your password'
                            : null,
                        onFieldSubmitted: (_) => _signIn(),
                      ),
                      if (_signInError != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          _signInError!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.redAccent),
                        ),
                      ],
                      const SizedBox(height: 28),
                      SizedBox(
                        height: 52,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: yellowAccent,
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: const Icon(Icons.login),
                          label: Text(
                            _isAdminSignIn ? 'SIGN IN AS ADMIN' : 'SIGN IN AS EMPLOYEE',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          onPressed: _signIn,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
