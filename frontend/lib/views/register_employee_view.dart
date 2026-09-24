import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class RegisterEmployeeView extends StatefulWidget {
  final String Function({
    required String fullName,
    required String username,
    required String role,
    required String password,
    Uint8List? profileImageBytes,
  }) onRegister;
  final VoidCallback onBackToLogin;
  final String currentUserRole;

  const RegisterEmployeeView({
    super.key,
    required this.onRegister,
    required this.onBackToLogin,
    required this.currentUserRole,
  });

  @override
  State<RegisterEmployeeView> createState() => _RegisterEmployeeViewState();
}

class _RegisterEmployeeViewState extends State<RegisterEmployeeView> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  String? _role;
  Uint8List? _profileImageBytes;
  bool _obscurePassword = true;
  bool _obscureConfirmation = true;

  static const _roles = [
    'Factory / Floor Worker',
    'Supply Chain Manager',
    'Quality Inspector',
  ];

  @override
  void dispose() {
    _fullNameController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _pickProfileImage() async {
    try {
      final image = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        imageQuality: 85,
      );
      if (image == null) return;

      final bytes = await image.readAsBytes();
      if (mounted) setState(() => _profileImageBytes = bytes);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to open the photo picker.')),
      );
    }
  }

  String? _validatePassword(String? value) {
    final password = value ?? '';
    if (password.length < 8) return 'Use at least 8 characters';
    if (!RegExp(r'[A-Z]').hasMatch(password)) {
      return 'Include at least one uppercase letter';
    }
    if (!RegExp(r'[a-z]').hasMatch(password)) {
      return 'Include at least one lowercase letter';
    }
    if (!RegExp(r'\d').hasMatch(password)) return 'Include at least one number';
    if (!RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(password)) {
      return 'Include at least one special character';
    }
    return null;
  }

  Future<void> _register() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final employeeId = widget.onRegister(
      fullName: _fullNameController.text.trim(),
      username: _usernameController.text.trim(),
      role: _role!,
      password: _passwordController.text,
      profileImageBytes: _profileImageBytes,
    );

    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text(
          'Registration successful',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Employee ID $employeeId has been assigned. The employee can use it with their password to sign in.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFD700),
              foregroundColor: Colors.black,
            ),
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('DONE'),
          ),
        ],
      ),
    );
    if (mounted) widget.onBackToLogin();
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
    final String currentUserRole = widget.currentUserRole;
    final canUploadProfilePicture =
        currentUserRole != 'Admin' && currentUserRole != 'IT / System Admin';
    final initials = _fullNameController.text
        .trim()
        .split(RegExp(r'\s+'))
        .where((name) => name.isNotEmpty)
        .take(2)
        .map((name) => name[0].toUpperCase())
        .join();

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF121212),
        foregroundColor: Colors.white,
        title: const Text('Register employee'),
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back),
          onPressed: widget.onBackToLogin,
        ),
      ),
      body: Scrollbar(
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
                    const Text(
                      'Create your employee account',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Your employee ID is assigned automatically after registration.',
                      style: TextStyle(color: Colors.white60),
                    ),
                    const SizedBox(height: 24),
                    Center(
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          CircleAvatar(
                            radius: 52,
                            backgroundColor: const Color(0xFF1E2E42),
                            backgroundImage: _profileImageBytes == null
                                ? null
                                : MemoryImage(_profileImageBytes!),
                            child: _profileImageBytes == null
                                ? Text(
                                    initials.isEmpty ? '?' : initials,
                                    style: const TextStyle(
                                      color: yellowAccent,
                                      fontSize: 26,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  )
                                : null,
                          ),
                          if (canUploadProfilePicture)
                            Positioned(
                              right: -4,
                              bottom: -4,
                              child: IconButton.filled(
                                tooltip: 'Upload optional profile picture',
                                style: IconButton.styleFrom(
                                  backgroundColor: yellowAccent,
                                  foregroundColor: Colors.black,
                                ),
                                onPressed: _pickProfileImage,
                                icon: const Icon(Icons.add_a_photo_outlined),
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (canUploadProfilePicture)
                      TextButton.icon(
                        onPressed: _pickProfileImage,
                        icon: const Icon(Icons.upload_outlined),
                        label: const Text('Upload profile picture (optional)'),
                      ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _fullNameController,
                      textCapitalization: TextCapitalization.words,
                      style: const TextStyle(color: Colors.white),
                      decoration: _decoration('Full name'),
                      onChanged: (_) => setState(() {}),
                      validator: (value) => value == null || value.trim().isEmpty
                          ? 'Enter your full name'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _usernameController,
                      style: const TextStyle(color: Colors.white),
                      decoration: _decoration('Username'),
                      validator: (value) => value == null || value.trim().isEmpty
                          ? 'Enter a username'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _role,
                      dropdownColor: const Color(0xFF1E1E1E),
                      style: const TextStyle(color: Colors.white),
                      decoration: _decoration('Role'),
                      hint: const Text('Select your role',
                          style: TextStyle(color: Colors.white38)),
                      items: _roles
                          .map((role) => DropdownMenuItem(
                                value: role,
                                child: Text(role),
                              ))
                          .toList(),
                      onChanged: (value) => setState(() => _role = value),
                      validator: (value) => value == null
                          ? 'Select your role'
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
                          tooltip: _obscurePassword ? 'Show password' : 'Hide password',
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
                      validator: _validatePassword,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _confirmPasswordController,
                      obscureText: _obscureConfirmation,
                      style: const TextStyle(color: Colors.white),
                      decoration: _decoration(
                        'Confirm password',
                        suffixIcon: IconButton(
                          tooltip: _obscureConfirmation
                              ? 'Show password'
                              : 'Hide password',
                          icon: Icon(
                            _obscureConfirmation
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            color: Colors.white60,
                          ),
                          onPressed: () => setState(
                            () => _obscureConfirmation = !_obscureConfirmation,
                          ),
                        ),
                      ),
                      validator: (value) => value != _passwordController.text
                          ? 'Passwords do not match'
                          : null,
                      onFieldSubmitted: (_) => _register(),
                    ),
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
                        onPressed: _register,
                        icon: const Icon(Icons.person_add_alt_1),
                        label: const Text(
                          'REGISTER EMPLOYEE',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
