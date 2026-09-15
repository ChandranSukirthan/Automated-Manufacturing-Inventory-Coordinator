import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../app_state.dart';
import '../services/api_client.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({required this.appState, super.key});

  final AppState appState;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final TextEditingController _nameController;
  String? _email;
  String? _role;
  String? _error;
  String? _message;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final user = widget.appState.session!.user;
    _nameController = TextEditingController(text: user.fullName);
    _email = user.email;
    _role = user.role;
    _load();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final user = await widget.appState.auth.getProfile();
      if (mounted) {
        setState(() {
          _nameController.text = user.fullName;
          _email = user.email;
          _role = user.role;
        });
      }
    } on ApiException catch (exception) {
      if (mounted) setState(() => _error = exception.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    final fullName = _nameController.text.trim();
    if (fullName.isEmpty) {
      setState(() {
        _error = 'Name is required.';
        _message = null;
      });
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
      _message = null;
    });
    try {
      final user = await widget.appState.updateProfile(fullName);
      if (mounted) {
        setState(() {
          _nameController.text = user.fullName;
          _email = user.email;
          _role = user.role;
          _message = 'Profile updated successfully.';
        });
      }
    } on ApiException catch (exception) {
      if (mounted) setState(() => _error = exception.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                if (_error != null)
                  _Message(text: _error!, color: AppColors.errorText),
                if (_message != null)
                  _Message(text: _message!, color: AppColors.primary),
                TextField(
                  controller: _nameController,
                  maxLength: 200,
                  decoration: const InputDecoration(labelText: 'Name'),
                ),
                const SizedBox(height: 16),
                InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    helperText: 'Email is managed by the authentication system.',
                  ),
                  child: Text(_email ?? ''),
                ),
                const SizedBox(height: 16),
                InputDecorator(
                  decoration: const InputDecoration(labelText: 'Role'),
                  child: Text(_role ?? ''),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined),
                  label: Text(_saving ? 'Saving...' : 'Save changes'),
                ),
              ],
            ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Text(text, style: TextStyle(color: color)),
  );
}
