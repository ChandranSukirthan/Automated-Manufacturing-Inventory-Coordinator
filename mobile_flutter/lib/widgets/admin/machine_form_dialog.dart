import 'package:flutter/material.dart';
import '../../models/admin/machine_model.dart';
import '../../services/admin/admin_api_service.dart';

class MachineFormDialog extends StatefulWidget {
  final MachineModel? machine;
  final AdminApiService service;

  const MachineFormDialog({
    this.machine,
    required this.service,
    super.key,
  });

  @override
  State<MachineFormDialog> createState() => _MachineFormDialogState();
}

class _MachineFormDialogState extends State<MachineFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _locationController;
  late TextEditingController _uptimeController;
  late TextEditingController _intervalController;
  late int _selectedStatus;
  bool _saving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final m = widget.machine;
    _nameController = TextEditingController(text: m?.name ?? '');
    _locationController = TextEditingController(text: m?.location ?? '');
    _uptimeController = TextEditingController(
      text: m != null ? m.uptimeHours.toStringAsFixed(1) : '0.0',
    );
    _intervalController = TextEditingController(
      text: m != null ? m.maintenanceIntervalHours.toStringAsFixed(0) : '500',
    );

    if (m != null) {
      if (m.status.toLowerCase().contains('maintenance')) {
        _selectedStatus = 1;
      } else if (m.status.toLowerCase().contains('offline')) {
        _selectedStatus = 2;
      } else {
        _selectedStatus = 0;
      }
    } else {
      _selectedStatus = 0;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _locationController.dispose();
    _uptimeController.dispose();
    _intervalController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _saving = true;
      _errorMessage = null;
    });

    final name = _nameController.text.trim();
    final location = _locationController.text.trim();
    final uptime = double.tryParse(_uptimeController.text.trim()) ?? 0.0;
    final interval = double.tryParse(_intervalController.text.trim()) ?? 500.0;

    try {
      if (widget.machine == null) {
        final created = await widget.service.createMachine(
          name: name,
          status: _selectedStatus,
          uptimeHours: uptime,
          maintenanceIntervalHours: interval,
          location: location,
        );
        if (mounted) Navigator.of(context).pop(created);
      } else {
        final updated = await widget.service.updateMachine(
          widget.machine!.id,
          name: name,
          status: _selectedStatus,
          uptimeHours: uptime,
          maintenanceIntervalHours: interval,
          location: location,
        );
        if (mounted) Navigator.of(context).pop(updated);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.machine != null;

    return Dialog(
      backgroundColor: const Color(0xFF1E293B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 480),
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isEdit ? 'Edit Equipment' : 'Add New Equipment',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Color(0xFF94A3B8)),
                      onPressed: () => Navigator.of(context).pop(),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFEF4444)),
                    ),
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(color: Color(0xFFFCA5A5), fontSize: 13),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                _buildTextField(
                  controller: _nameController,
                  label: 'Machine / Equipment Name *',
                  hint: 'e.g. CNC Milling Machine 04',
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Name is required' : null,
                ),
                const SizedBox(height: 12),

                _buildTextField(
                  controller: _locationController,
                  label: 'Plant Location *',
                  hint: 'e.g. Bay 3, Production Line B',
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Location is required' : null,
                ),
                const SizedBox(height: 12),

                const Text(
                  'Operating Status',
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
                      value: _selectedStatus,
                      dropdownColor: const Color(0xFF1E293B),
                      icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFF94A3B8)),
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      isExpanded: true,
                      items: const [
                        DropdownMenuItem(
                          value: 0,
                          child: Row(
                            children: [
                              Icon(Icons.check_circle_outline, color: Color(0xFF10B981), size: 16),
                              SizedBox(width: 8),
                              Text('Operational'),
                            ],
                          ),
                        ),
                        DropdownMenuItem(
                          value: 1,
                          child: Row(
                            children: [
                              Icon(Icons.build_circle_outlined, color: Color(0xFFF59E0B), size: 16),
                              SizedBox(width: 8),
                              Text('Under Maintenance'),
                            ],
                          ),
                        ),
                        DropdownMenuItem(
                          value: 2,
                          child: Row(
                            children: [
                              Icon(Icons.error_outline, color: Color(0xFFEF4444), size: 16),
                              SizedBox(width: 8),
                              Text('Offline'),
                            ],
                          ),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedStatus = val);
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: _buildTextField(
                        controller: _uptimeController,
                        label: 'Uptime (Hours)',
                        hint: '0.0',
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Required';
                          final num = double.tryParse(v);
                          if (num == null || num < 0) return 'Must be >= 0';
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildTextField(
                        controller: _intervalController,
                        label: 'Interval (Hours) *',
                        hint: '500',
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Required';
                          final num = double.tryParse(v);
                          if (num == null || num <= 0) return 'Must be > 0';
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _saving ? null : () => Navigator.of(context).pop(),
                      child: const Text('Cancel', style: TextStyle(color: Color(0xFF94A3B8))),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: _saving ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF06B6D4),
                        foregroundColor: const Color(0xFF0B0F19),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0B0F19)),
                            )
                          : Text(
                              isEdit ? 'Save Changes' : 'Create Machine',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
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
          keyboardType: keyboardType,
          validator: validator,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Color(0xFF475569), fontSize: 13),
            filled: true,
            fillColor: const Color(0xFF0F172A),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFEF4444)),
            ),
          ),
        ),
      ],
    );
  }
}
