import 'package:flutter/material.dart';
import '../../../models/admin/user_model.dart';
import '../../../services/admin/admin_api_service.dart';
import '../../../widgets/admin/admin_card.dart';

class UserManagementScreen extends StatefulWidget {
  final AdminApiService service;

  const UserManagementScreen({required this.service, super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  List<UserModel> _users = [];
  bool _loading = true;
  String? _error;
  String _searchQuery = '';
  String _selectedRoleFilter = 'All';

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final list = await widget.service.getUsers();
      if (mounted) {
        setState(() {
          _users = list;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load users: $e';
          _loading = false;
        });
      }
    }
  }

  Future<void> _toggleUserActive(UserModel user) async {
    try {
      if (user.isActive) {
        await widget.service.deactivateUser(user.id);
      } else {
        await widget.service.activateUser(user.id);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            user.isActive
                ? 'User "${user.fullName}" deactivated.'
                : 'User "${user.fullName}" activated.',
          ),
          backgroundColor: user.isActive
              ? const Color(0xFFEF4444)
              : const Color(0xFF10B981),
        ),
      );
      await _loadUsers();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update status: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  Future<void> _showCreateUserDialog() async {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    int roleId = 0;
    bool saving = false;
    String? dialogError;

    final created = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Dialog(
          backgroundColor: const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 440),
            padding: const EdgeInsets.all(20),
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Create New User',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.close,
                            color: Color(0xFF94A3B8),
                          ),
                          onPressed: () => Navigator.pop(ctx, false),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (dialogError != null) ...[
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFFEF4444,
                          ).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFEF4444)),
                        ),
                        child: Text(
                          dialogError!,
                          style: const TextStyle(
                            color: Color(0xFFFCA5A5),
                            fontSize: 13,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    _inputField(
                      controller: nameCtrl,
                      label: 'Full Name *',
                      hint: 'e.g. Samantha Perera',
                      validator: (v) => v == null || v.trim().isEmpty
                          ? 'Name required'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    _inputField(
                      controller: emailCtrl,
                      label: 'Email Address *',
                      hint: 'e.g. s.perera@amic-plant.lk',
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Email required';
                        }
                        if (!v.contains('@')) return 'Enter valid email';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    _inputField(
                      controller: passCtrl,
                      label: 'Password (min 8 chars) *',
                      hint: '••••••••',
                      obscureText: true,
                      validator: (v) {
                        if (v == null || v.length < 8) {
                          return 'Min 8 characters required';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Assigned Role *',
                      style: TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF334155)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          value: roleId,
                          dropdownColor: const Color(0xFF1E293B),
                          icon: const Icon(
                            Icons.keyboard_arrow_down,
                            color: Color(0xFF94A3B8),
                          ),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                          isExpanded: true,
                          items: const [
                            DropdownMenuItem(
                              value: 0,
                              child: Text('Floor Worker (Student 1)'),
                            ),
                            DropdownMenuItem(
                              value: 1,
                              child: Text('Supply Chain Manager (Student 2)'),
                            ),
                            DropdownMenuItem(
                              value: 2,
                              child: Text('Quality Inspector (Student 3)'),
                            ),
                            DropdownMenuItem(
                              value: 3,
                              child: Text('IT Admin (Student 4)'),
                            ),
                          ],
                          onChanged: (val) {
                            if (val != null) setDialogState(() => roleId = val);
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: saving
                              ? null
                              : () => Navigator.pop(ctx, false),
                          child: const Text(
                            'Cancel',
                            style: TextStyle(color: Color(0xFF94A3B8)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          onPressed: saving
                              ? null
                              : () async {
                                  if (!formKey.currentState!.validate()) return;
                                  setDialogState(() {
                                    saving = true;
                                    dialogError = null;
                                  });
                                  try {
                                    await widget.service.createUser(
                                      fullName: nameCtrl.text.trim(),
                                      email: emailCtrl.text.trim(),
                                      password: passCtrl.text.trim(),
                                      role: roleId,
                                    );
                                    if (ctx.mounted) Navigator.pop(ctx, true);
                                  } catch (err) {
                                    setDialogState(() {
                                      saving = false;
                                      dialogError = err.toString().replaceFirst(
                                        'Exception: ',
                                        '',
                                      );
                                    });
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF06B6D4),
                            foregroundColor: const Color(0xFF0B0F19),
                          ),
                          child: saving
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Color(0xFF0B0F19),
                                  ),
                                )
                              : const Text(
                                  'Create User',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );

    if (created == true) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('User account created successfully!'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
      }
      await _loadUsers();
    }
  }

  Future<void> _showAssignRoleDialog(UserModel user) async {
    int selectedRole = user.roleId;

    final updated = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'Change Role for ${user.fullName}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ...[
                (0, 'Floor Worker (Student 1)'),
                (1, 'Supply Chain Manager (Student 2)'),
                (2, 'Quality Inspector (Student 3)'),
                (3, 'IT Admin (Student 4)'),
              ].map(
                (r) => InkWell(
                  onTap: () => setDialogState(() => selectedRole = r.$1),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 4,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          selectedRole == r.$1
                              ? Icons.radio_button_checked
                              : Icons.radio_button_off,
                          color: const Color(0xFF06B6D4),
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          r.$2,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Color(0xFF94A3B8)),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  await widget.service.assignRole(user.id, selectedRole);
                  if (ctx.mounted) Navigator.pop(ctx, true);
                } catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(
                        content: Text('Failed: $e'),
                        backgroundColor: const Color(0xFFEF4444),
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF06B6D4),
                foregroundColor: const Color(0xFF0B0F19),
              ),
              child: const Text(
                'Save Role',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );

    if (updated == true) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('User role updated!'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
      }
      await _loadUsers();
    }
  }

  Future<void> _showEditUserDialog(UserModel user) async {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController(text: user.fullName);
    final emailCtrl = TextEditingController(text: user.email);

    final updated = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Edit User Profile',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _inputField(
                controller: nameCtrl,
                label: 'Full Name *',
                hint: 'Full Name',
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Name required' : null,
              ),
              const SizedBox(height: 12),
              _inputField(
                controller: emailCtrl,
                label: 'Email Address *',
                hint: 'Email',
                validator: (v) => v == null || !v.contains('@')
                    ? 'Valid email required'
                    : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Color(0xFF94A3B8)),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              try {
                await widget.service.updateUser(
                  user.id,
                  fullName: nameCtrl.text.trim(),
                  email: emailCtrl.text.trim(),
                );
                if (ctx.mounted) Navigator.pop(ctx, true);
              } catch (e) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(
                      content: Text('Failed: $e'),
                      backgroundColor: const Color(0xFFEF4444),
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF06B6D4),
              foregroundColor: const Color(0xFF0B0F19),
            ),
            child: const Text(
              'Save Changes',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (updated == true) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('User profile saved!'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
      }
      await _loadUsers();
    }
  }

  Widget _inputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    bool obscureText = false,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF94A3B8),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          validator: validator,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Color(0xFF475569), fontSize: 13),
            filled: true,
            fillColor: const Color(0xFF0F172A),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF334155)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF334155)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF06B6D4)),
            ),
          ),
        ),
      ],
    );
  }

  Color _getRoleColor(String role) {
    final lower = role.toLowerCase();
    if (lower.contains('admin') || lower == '3') return const Color(0xFF06B6D4);
    if (lower.contains('supply') || lower == '1') {
      return const Color(0xFFF59E0B);
    }
    if (lower.contains('quality') || lower == '2') {
      return const Color(0xFF8B5CF6);
    }
    return const Color(0xFF3B82F6);
  }

  String _formatRoleName(String role) {
    final lower = role.toLowerCase();
    if (lower.contains('admin') || lower == '3') return 'IT Admin';
    if (lower.contains('supply') || lower == '1') return 'Supply Chain Manager';
    if (lower.contains('quality') || lower == '2') return 'Quality Inspector';
    return 'Floor Worker';
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _users.where((u) {
      final matchesSearch =
          _searchQuery.isEmpty ||
          u.fullName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          u.email.toLowerCase().contains(_searchQuery.toLowerCase());
      if (!matchesSearch) return false;

      if (_selectedRoleFilter == 'All') return true;
      if (_selectedRoleFilter == 'Floor Worker') return u.roleId == 0;
      if (_selectedRoleFilter == 'Supply Chain') return u.roleId == 1;
      if (_selectedRoleFilter == 'Quality') return u.roleId == 2;
      if (_selectedRoleFilter == 'IT Admin') return u.roleId == 3;
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFF0B0F19),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        title: const Text(
          'User Management',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF06B6D4)),
            tooltip: 'Refresh',
            onPressed: _loadUsers,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateUserDialog,
        backgroundColor: const Color(0xFF06B6D4),
        foregroundColor: const Color(0xFF0B0F19),
        icon: const Icon(Icons.person_add_rounded),
        label: const Text(
          'Add User',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadUsers,
        color: const Color(0xFF06B6D4),
        backgroundColor: const Color(0xFF0F172A),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
          children: [
            // Search Input
            TextField(
              onChanged: (val) => setState(() => _searchQuery = val.trim()),
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Search by user name or email...',
                hintStyle: const TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 13,
                ),
                prefixIcon: const Icon(
                  Icons.search,
                  size: 18,
                  color: Color(0xFF64748B),
                ),
                filled: true,
                fillColor: const Color(0xFF0F172A),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFF334155)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFF334155)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFF06B6D4)),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Role Filter Chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children:
                    [
                      'All',
                      'Floor Worker',
                      'Supply Chain',
                      'Quality',
                      'IT Admin',
                    ].map((roleFilter) {
                      final selected = _selectedRoleFilter == roleFilter;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(roleFilter),
                          selected: selected,
                          onSelected: (_) =>
                              setState(() => _selectedRoleFilter = roleFilter),
                          backgroundColor: const Color(0xFF0F172A),
                          selectedColor: const Color(
                            0xFF06B6D4,
                          ).withValues(alpha: 0.25),
                          labelStyle: TextStyle(
                            color: selected
                                ? const Color(0xFF06B6D4)
                                : const Color(0xFF94A3B8),
                            fontSize: 12,
                            fontWeight: selected
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                          side: BorderSide(
                            color: selected
                                ? const Color(0xFF06B6D4)
                                : const Color(0xFF334155),
                          ),
                          visualDensity: VisualDensity.compact,
                        ),
                      );
                    }).toList(),
              ),
            ),
            const SizedBox(height: 14),

            if (_loading && _users.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(40),
                  child: CircularProgressIndicator(color: Color(0xFF06B6D4)),
                ),
              )
            else if (_error != null && _users.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: Color(0xFFEF4444),
                        size: 36,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _error!,
                        style: const TextStyle(color: Color(0xFFEF4444)),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: _loadUsers,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF06B6D4),
                        ),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              )
            else if (filtered.isEmpty)
              Container(
                padding: const EdgeInsets.all(24),
                alignment: Alignment.center,
                child: const Text(
                  'No matching users found.',
                  style: TextStyle(color: Color(0xFF64748B)),
                ),
              )
            else
              ...filtered.map((u) {
                final roleColor = _getRoleColor(u.role);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: AdminCard(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: roleColor.withValues(alpha: 0.2),
                              child: Text(
                                u.fullName.isNotEmpty
                                    ? u.fullName[0].toUpperCase()
                                    : 'U',
                                style: TextStyle(
                                  color: roleColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          u.fullName,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: u.isActive
                                              ? const Color(
                                                  0xFF10B981,
                                                ).withValues(alpha: 0.15)
                                              : const Color(
                                                  0xFFEF4444,
                                                ).withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        child: Text(
                                          u.isActive ? 'ACTIVE' : 'INACTIVE',
                                          style: TextStyle(
                                            color: u.isActive
                                                ? const Color(0xFF10B981)
                                                : const Color(0xFFEF4444),
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    u.email,
                                    style: const TextStyle(
                                      color: Color(0xFF94A3B8),
                                      fontSize: 12,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            PopupMenuButton<String>(
                              icon: const Icon(
                                Icons.more_vert,
                                color: Color(0xFF94A3B8),
                              ),
                              color: const Color(0xFF1E293B),
                              onSelected: (val) {
                                if (val == 'edit') _showEditUserDialog(u);
                                if (val == 'role') _showAssignRoleDialog(u);
                                if (val == 'toggle') _toggleUserActive(u);
                              },
                              itemBuilder: (ctx) => [
                                const PopupMenuItem(
                                  value: 'edit',
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.edit_outlined,
                                        color: Colors.white70,
                                        size: 16,
                                      ),
                                      SizedBox(width: 8),
                                      Text(
                                        'Edit Profile',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'role',
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.badge_outlined,
                                        color: Colors.white70,
                                        size: 16,
                                      ),
                                      SizedBox(width: 8),
                                      Text(
                                        'Assign Role',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 'toggle',
                                  child: Row(
                                    children: [
                                      Icon(
                                        u.isActive
                                            ? Icons.block_flipped
                                            : Icons.check_circle_outline,
                                        color: u.isActive
                                            ? const Color(0xFFEF4444)
                                            : const Color(0xFF10B981),
                                        size: 16,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        u.isActive ? 'Deactivate' : 'Activate',
                                        style: TextStyle(
                                          color: u.isActive
                                              ? const Color(0xFFEF4444)
                                              : const Color(0xFF10B981),
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        const Divider(color: Color(0xFF1E293B), height: 1),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: roleColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: roleColor.withValues(alpha: 0.4),
                                ),
                              ),
                              child: Text(
                                _formatRoleName(u.role),
                                style: TextStyle(
                                  color: roleColor,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            Text(
                              'Joined ${u.createdAt.year}-${u.createdAt.month.toString().padLeft(2, '0')}-${u.createdAt.day.toString().padLeft(2, '0')}',
                              style: const TextStyle(
                                color: Color(0xFF64748B),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}
