import 'package:flutter/material.dart';
import '../../models/admin/shift_model.dart';
import '../../services/admin/admin_api_service.dart';

class ShiftFormDialog extends StatefulWidget {
  final ShiftModel? shift;
  final AdminApiService service;

  const ShiftFormDialog({
    this.shift,
    required this.service,
    super.key,
  });

  @override
  State<ShiftFormDialog> createState() => _ShiftFormDialogState();
}

class _ShiftFormDialogState extends State<ShiftFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _targetController;
  late TextEditingController _availableMatController;
  late TextEditingController _actualOutputController;
  late TextEditingController _skuController;
  late int _selectedStatus;
  late DateTime _startTime;
  late DateTime _endTime;
  bool _saving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final s = widget.shift;
    _nameController = TextEditingController(text: s?.name ?? '');
    _targetController = TextEditingController(
      text: s != null ? s.targetOutput.toInt().toString() : '500',
    );
    _availableMatController = TextEditingController(
      text: s != null ? s.targetOutput.toInt().toString() : '500',
    );
    _actualOutputController = TextEditingController(
      text: s != null ? s.adjustedOutput.toInt().toString() : '0',
    );
    _skuController = TextEditingController(text: s?.materialSku ?? '');

    if (s != null) {
      if (s.status.toLowerCase().contains('active')) {
        _selectedStatus = 1;
      } else if (s.status.toLowerCase().contains('complete')) {
        _selectedStatus = 2;
      } else if (s.status.toLowerCase().contains('cancel')) {
        _selectedStatus = 3;
      } else {
        _selectedStatus = 0;
      }
      _startTime = s.startTime;
      _endTime = s.endTime;
    } else {
      _selectedStatus = 0;
      _startTime = DateTime.now();
      _endTime = DateTime.now().add(const Duration(hours: 8));
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _targetController.dispose();
    _availableMatController.dispose();
    _actualOutputController.dispose();
    _skuController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _saving = true;
      _errorMessage = null;
    });

    final name = _nameController.text.trim();
    final target = int.tryParse(_targetController.text.trim()) ?? 500;
    final available = int.tryParse(_availableMatController.text.trim()) ?? target;
    final actual = int.tryParse(_actualOutputController.text.trim()) ?? 0;
    final sku = _skuController.text.trim().isEmpty ? null : _skuController.text.trim();

    try {
      if (widget.shift == null) {
        final created = await widget.service.createShift(
          name: name,
          productionTarget: target,
          availableMaterial: available,
          actualOutput: actual,
          status: _selectedStatus,
          startTime: _startTime,
          endTime: _endTime,
          materialSku: sku,
        );
        if (mounted) Navigator.of(context).pop(created);
      } else {
        final updated = await widget.service.updateShift(
          widget.shift!.id,
          name: name,
          productionTarget: target,
          availableMaterial: available,
          actualOutput: actual,
          status: _selectedStatus,
          startTime: _startTime,
          endTime: _endTime,
          materialSku: sku,
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

  Future<void> _pickDateTime(bool isStart) async {
    final current = isStart ? _startTime : _endTime;
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2025),
      lastDate: DateTime(2030),
      builder: (context, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFF06B6D4),
            surface: Color(0xFF1E293B),
          ),
        ),
        child: child!,
      ),
    );
    if (pickedDate == null || !mounted) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current),
      builder: (context, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFF06B6D4),
            surface: Color(0xFF1E293B),
          ),
        ),
        child: child!,
      ),
    );
    if (pickedTime == null || !mounted) return;

    final resolved = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );

    setState(() {
      if (isStart) {
        _startTime = resolved;
        if (_endTime.isBefore(_startTime)) {
          _endTime = _startTime.add(const Duration(hours: 8));
        }
      } else {
        _endTime = resolved;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.shift != null;

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
                      isEdit ? 'Edit Production Shift' : 'Create Production Shift',
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
                  label: 'Shift Name *',
                  hint: 'e.g. Day Shift Alpha - Stamping Line',
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Shift name is required' : null,
                ),
                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: _buildTextField(
                        controller: _targetController,
                        label: 'Target Output (Units) *',
                        hint: '500',
                        keyboardType: TextInputType.number,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Required';
                          final num = int.tryParse(v);
                          if (num == null || num <= 0) return 'Must be > 0';
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildTextField(
                        controller: _availableMatController,
                        label: 'Available Material *',
                        hint: '500',
                        keyboardType: TextInputType.number,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Required';
                          final num = int.tryParse(v);
                          if (num == null || num < 0) return 'Must be >= 0';
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: _buildTextField(
                        controller: _actualOutputController,
                        label: 'Actual Output',
                        hint: '0',
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildTextField(
                        controller: _skuController,
                        label: 'Target Material SKU',
                        hint: 'e.g. RAW-STL-001',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                const Text(
                  'Shift Status',
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
                              Icon(Icons.schedule_rounded, color: Color(0xFF38BDF8), size: 16),
                              SizedBox(width: 8),
                              Text('Planned (Scheduled)'),
                            ],
                          ),
                        ),
                        DropdownMenuItem(
                          value: 1,
                          child: Row(
                            children: [
                              Icon(Icons.play_circle_outline_rounded, color: Color(0xFF10B981), size: 16),
                              SizedBox(width: 8),
                              Text('Active (In Progress)'),
                            ],
                          ),
                        ),
                        DropdownMenuItem(
                          value: 2,
                          child: Row(
                            children: [
                              Icon(Icons.task_alt_rounded, color: Color(0xFF64748B), size: 16),
                              SizedBox(width: 8),
                              Text('Completed'),
                            ],
                          ),
                        ),
                        DropdownMenuItem(
                          value: 3,
                          child: Row(
                            children: [
                              Icon(Icons.cancel_outlined, color: Color(0xFFEF4444), size: 16),
                              SizedBox(width: 8),
                              Text('Cancelled'),
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

                // Start & End Timestamps
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => _pickDateTime(true),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F172A),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFF334155)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Start Time', style: TextStyle(color: Color(0xFF64748B), fontSize: 10)),
                              const SizedBox(height: 2),
                              Text(
                                '${_startTime.month}/${_startTime.day} ${_startTime.hour.toString().padLeft(2, '0')}:${_startTime.minute.toString().padLeft(2, '0')}',
                                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: InkWell(
                        onTap: () => _pickDateTime(false),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F172A),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFF334155)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('End Time', style: TextStyle(color: Color(0xFF64748B), fontSize: 10)),
                              const SizedBox(height: 2),
                              Text(
                                '${_endTime.month}/${_endTime.day} ${_endTime.hour.toString().padLeft(2, '0')}:${_endTime.minute.toString().padLeft(2, '0')}',
                                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
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
                              isEdit ? 'Save Changes' : 'Create Shift',
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

