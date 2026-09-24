import 'package:flutter/material.dart';

import '../models/user_profile.dart';
import '../utils/shift_helper.dart';

class EmployeeManagementView extends StatefulWidget {
  final List<UserProfile> Function() employees;
  final bool canManageEmployees;
  final Future<void> Function(BuildContext context)? onAddEmployee;
  final void Function(String employeeId, UserProfile updatedEmployee)? onUpdateEmployee;
  final void Function(String employeeId)? onDeleteEmployee;

  const EmployeeManagementView({
    super.key,
    required this.employees,
    required this.canManageEmployees,
    this.onAddEmployee,
    this.onUpdateEmployee,
    this.onDeleteEmployee,
  });

  @override
  State<EmployeeManagementView> createState() => _EmployeeManagementViewState();
}

class _EmployeeManagementViewState extends State<EmployeeManagementView> {
  static const _assignableRoles = [
    'Factory / Floor Worker',
    'Supply Chain Manager',
    'Quality Inspector',
  ];

  Future<void> _deleteEmployee(UserProfile employee) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Delete employee', style: TextStyle(color: Colors.white)),
        content: Text(
          'Delete ${employee.fullName} (${employee.employeeId})? This cannot be undone.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (shouldDelete == true && mounted) {
      widget.onDeleteEmployee?.call(employee.employeeId);
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${employee.fullName} was deleted.')),
      );
    }
  }

  Future<void> _editEmployee(UserProfile employee) async {
    final fullNameController = TextEditingController(text: employee.fullName);
    final usernameController = TextEditingController(text: employee.username);
    var role = employee.role;
    var isOnline = employee.isOnline;
    var removeProfileImage = false;

    final updatedEmployee = await showDialog<UserProfile>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          title: const Text('Update employee', style: TextStyle(color: Colors.white)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: fullNameController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(labelText: 'Full name'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: usernameController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(labelText: 'Username'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  initialValue: employee.employeeId,
                  readOnly: true,
                  style: const TextStyle(color: Colors.white60),
                  decoration: const InputDecoration(labelText: 'Employee ID (locked)'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: role,
                  dropdownColor: const Color(0xFF1E1E1E),
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(labelText: 'Role'),
                  items: _assignableRoles
                      .map(
                        (item) => DropdownMenuItem(value: item, child: Text(item)),
                      )
                      .toList(),
                  onChanged: (value) => setDialogState(() => role = value!),
                ),
                if (employee.profileImageBytes != null) ...[
                  TextButton.icon(
                    onPressed: () => setDialogState(
                      () => removeProfileImage = !removeProfileImage,
                    ),
                    icon: Icon(
                      removeProfileImage
                          ? Icons.undo_outlined
                          : Icons.delete_outline,
                    ),
                    label: Text(
                      removeProfileImage
                          ? 'Keep profile picture'
                          : 'Delete profile picture',
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Employee is online'),
                  value: isOnline,
                  onChanged: (value) => setDialogState(() => isOnline = value),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(
                dialogContext,
                employee.copyWith(
                  fullName: fullNameController.text.trim(),
                  username: usernameController.text.trim(),
                  role: role,
                  isOnline: isOnline,
                  lastLoginAt: isOnline && !employee.isOnline
                      ? DateTime.now()
                      : employee.lastLoginAt,
                  lastLogoutAt: !isOnline && employee.isOnline
                      ? DateTime.now()
                      : employee.lastLogoutAt,
                  removeProfileImage: removeProfileImage,
                ),
              ),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    fullNameController.dispose();
    usernameController.dispose();

    if (updatedEmployee != null && mounted) {
      widget.onUpdateEmployee?.call(employee.employeeId, updatedEmployee);
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final employees = widget.employees();

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF121212),
        foregroundColor: Colors.white,
        title: Text(widget.canManageEmployees ? 'Employee Management' : 'Employees'),
      ),
      floatingActionButton: widget.canManageEmployees
          ? FloatingActionButton.extended(
              backgroundColor: const Color(0xFFFFD700),
              foregroundColor: Colors.black,
              onPressed: () async {
                await widget.onAddEmployee?.call(context);
                if (mounted) setState(() {});
              },
              icon: const Icon(Icons.person_add_alt_1),
              label: const Text('ADD EMPLOYEE'),
            )
          : null,
      body: Scrollbar(
        thumbVisibility: true,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (!widget.canManageEmployees) ...[
              const Text(
                'Employee activity and floor-worker shift information.',
                style: TextStyle(color: Colors.white60),
              ),
              const SizedBox(height: 16),
            ],
            if (employees.isEmpty)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(
                  child: Text(
                    'No employee accounts have been registered.',
                    style: TextStyle(color: Colors.white60),
                  ),
                ),
              )
            else
              ...employees.map((employee) => _buildEmployeeCard(employee)),
            const SizedBox(height: 90),
          ],
        ),
      ),
    );
  }

  Widget _buildEmployeeCard(UserProfile employee) {
    final statusColor = employee.isOnline ? Colors.greenAccent : Colors.grey;
    final activityLabel = employee.isOnline ? 'Last Login' : 'Last Logout';
    final activityTime = employee.isOnline
        ? employee.lastLoginAt
        : employee.lastLogoutAt;
    return Card(
      color: const Color(0xFF1E1E1E),
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: const Color(0xFF1E2E42),
                  backgroundImage: employee.profileImageBytes == null
                      ? null
                      : MemoryImage(employee.profileImageBytes!),
                  child: employee.profileImageBytes == null
                      ? Text(employee.initials)
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        employee.fullName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${employee.employeeId} • ${employee.username}',
                        style: const TextStyle(color: Colors.white60),
                      ),
                    ],
                  ),
                ),
                if (widget.canManageEmployees)
                  PopupMenuButton<String>(
                    onSelected: (action) {
                      if (action == 'edit') _editEmployee(employee);
                      if (action == 'delete') _deleteEmployee(employee);
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'edit', child: Text('Update employee')),
                      PopupMenuItem(value: 'delete', child: Text('Delete employee')),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(employee.role, style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 6),
            Text(
              '$activityLabel: ${_formatActivityTime(activityTime)}',
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.circle, color: statusColor, size: 10),
                const SizedBox(width: 6),
                Text(
                  employee.isOnline ? 'Active' : 'Offline',
                  style: TextStyle(color: statusColor, fontWeight: FontWeight.bold),
                ),
                if (employee.isFloorWorker) ...[
                  const SizedBox(width: 14),
                  const Icon(Icons.schedule, color: Colors.white54, size: 16),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      currentShiftLabel(),
                      style: const TextStyle(color: Colors.white60, fontSize: 12),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatActivityTime(Object? value) {
    final dateTime = switch (value) {
      DateTime value => value,
      String value => DateTime.tryParse(value),
      _ => null,
    };
    if (dateTime == null) return 'Never';
    final hour = dateTime.hour % 12 == 0 ? 12 : dateTime.hour % 12;
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final period = dateTime.hour >= 12 ? 'PM' : 'AM';
    return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} $hour:$minute $period';
  }
}
