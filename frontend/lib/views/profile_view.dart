import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/user_profile.dart';
import '../utils/shift_helper.dart';

class ProfileView extends StatefulWidget {
  final UserProfile profile;
  final ValueChanged<UserProfile> onProfileChanged;
  final VoidCallback? onManageEmployees;

  const ProfileView({
    super.key,
    required this.profile,
    required this.onProfileChanged,
    this.onManageEmployees,
  });

  @override
  State<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<ProfileView> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _fullNameController;
  late final TextEditingController _usernameController;
  Uint8List? _profileImageBytes;
  bool _removeProfileImage = false;

  bool get _canEditUsername =>
      !widget.profile.isFloorWorker && !widget.profile.isAdmin;

  @override
  void initState() {
    super.initState();
    _fullNameController = TextEditingController(text: widget.profile.fullName);
    _usernameController = TextEditingController(text: widget.profile.username);
    _profileImageBytes = widget.profile.profileImageBytes;
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  void _saveProfile() {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    widget.onProfileChanged(
      widget.profile.copyWith(
        fullName: _fullNameController.text.trim(),
        username: _canEditUsername ? _usernameController.text.trim() : null,
        profileImageBytes: _profileImageBytes,
        removeProfileImage: _removeProfileImage,
      ),
    );
    Navigator.pop(context);
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
      if (mounted) {
        setState(() {
          _profileImageBytes = bytes;
          _removeProfileImage = false;
        });
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to open the photo picker.')),
      );
    }
  }

  void _deleteProfileImage() {
    setState(() {
      _profileImageBytes = null;
      _removeProfileImage = true;
    });
  }

  InputDecoration _decoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white60),
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
    final initials = widget.profile.initials.isEmpty ? '?' : widget.profile.initials;

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF121212),
        foregroundColor: Colors.white,
        title: const Text('My Profile'),
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
                    Center(
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          CircleAvatar(
                            radius: 56,
                            backgroundColor: const Color(0xFF1E2E42),
                            backgroundImage: _profileImageBytes == null
                                ? null
                                : MemoryImage(_profileImageBytes!),
                            child: _profileImageBytes == null
                                ? Text(
                                    initials,
                                    style: const TextStyle(
                                      color: yellowAccent,
                                      fontSize: 28,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  )
                                : null,
                          ),
                          if (!widget.profile.isAdmin)
                            Positioned(
                              right: -4,
                              bottom: -4,
                              child: IconButton.filled(
                                tooltip: 'Upload profile picture',
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
                    if (!widget.profile.isAdmin)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          TextButton.icon(
                            onPressed: _pickProfileImage,
                            icon: const Icon(Icons.upload_outlined),
                            label: const Text('Upload profile picture'),
                          ),
                          if (_profileImageBytes != null)
                            TextButton.icon(
                              onPressed: _deleteProfileImage,
                              icon: const Icon(Icons.delete_outline),
                              label: const Text('Delete picture'),
                            ),
                        ],
                      ),
                    const SizedBox(height: 12),
                    Text(
                      widget.profile.isFloorWorker
                          ? 'Floor workers may update their full name only.'
                          : widget.profile.isAdmin
                              ? 'The Admin username and role are protected.'
                              : 'You may update your full name and username.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white60),
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _fullNameController,
                      textCapitalization: TextCapitalization.words,
                      style: const TextStyle(color: Colors.white),
                      decoration: _decoration('Full name'),
                      validator: (value) => value == null || value.trim().isEmpty
                          ? 'Enter your full name'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _usernameController,
                      readOnly: !_canEditUsername,
                      style: const TextStyle(color: Colors.white),
                      decoration: _decoration('Username'),
                      validator: (value) {
                        if (!_canEditUsername) return null;
                        return value == null || value.trim().isEmpty
                            ? 'Enter a username'
                            : null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      initialValue: widget.profile.employeeId,
                      readOnly: true,
                      style: const TextStyle(color: Colors.white),
                      decoration: _decoration('Employee ID'),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      initialValue: widget.profile.role,
                      readOnly: true,
                      style: const TextStyle(color: Colors.white),
                      decoration: _decoration('Role'),
                    ),
                    if (widget.profile.isFloorWorker) ...[
                      const SizedBox(height: 16),
                      ListTile(
                        tileColor: const Color(0xFF1E1E1E),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        leading: const Icon(Icons.schedule, color: yellowAccent),
                        title: const Text(
                          'Current shift',
                          style: TextStyle(color: Colors.white60),
                        ),
                        subtitle: Text(
                          currentShiftLabel(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
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
                        onPressed: _saveProfile,
                        icon: const Icon(Icons.save_outlined),
                        label: const Text(
                          'SAVE PROFILE',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    if (widget.profile.isAdmin && widget.onManageEmployees != null) ...[
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: widget.onManageEmployees,
                        icon: const Icon(Icons.manage_accounts_outlined),
                        label: const Text('MANAGE EMPLOYEES'),
                      ),
                    ],
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
