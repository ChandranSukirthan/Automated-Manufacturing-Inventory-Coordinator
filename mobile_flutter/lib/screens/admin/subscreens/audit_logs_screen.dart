import 'package:flutter/material.dart';
import '../../../models/admin/audit_log_model.dart';
import '../../../services/admin/admin_api_service.dart';
import '../../../widgets/admin/admin_card.dart';

class AuditLogsScreen extends StatefulWidget {
  final AdminApiService service;

  const AuditLogsScreen({required this.service, super.key});

  @override
  State<AuditLogsScreen> createState() => _AuditLogsScreenState();
}

class _AuditLogsScreenState extends State<AuditLogsScreen> {
  List<AuditLogModel> _logs = [];
  bool _loading = true;
  String? _error;
  String _searchQuery = '';
  String _selectedActionFilter = 'All';
  final _search = TextEditingController();
  final _user = TextEditingController();
  final _entity = TextEditingController();
  final _action = TextEditingController();
  DateTime? _from, _to;
  @override
  void dispose() {
    _search.dispose();
    _user.dispose();
    _entity.dispose();
    _action.dispose();
    super.dispose();
  }

  Future<void> _pickDate(bool from) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: (from ? _from : _to) ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null && mounted)
      setState(() {
        if (from) {
          _from = picked;
        } else {
          _to = picked;
        }
      });
  }

  void _applyFilters() {
    if (_from != null && _to != null && _from!.isAfter(_to!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('From date must be before the to date.')),
      );
      return;
    }
    _loadLogs();
  }

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final list = await widget.service.getAuditLogs(
        userName: _user.text.trim(),
        entity: _entity.text.trim(),
        action: _action.text.trim(),
        fromDate: _from?.toUtc(),
        toDate: _to
            ?.add(const Duration(days: 1))
            .subtract(const Duration(microseconds: 1))
            .toUtc(),
      );
      if (mounted) {
        setState(() {
          _logs = list;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load audit logs: $e';
          _loading = false;
        });
      }
    }
  }

  Color _getActionColor(String action) {
    final lower = action.toLowerCase();
    if (lower.contains('create') || lower.contains('add'))
      return const Color(0xFF10B981);
    if (lower.contains('update') ||
        lower.contains('edit') ||
        lower.contains('adjust'))
      return const Color(0xFFF59E0B);
    if (lower.contains('delete') ||
        lower.contains('reject') ||
        lower.contains('deactivate'))
      return const Color(0xFFEF4444);
    if (lower.contains('activate') || lower.contains('approve'))
      return const Color(0xFF06B6D4);
    return const Color(0xFF8B5CF6);
  }

  IconData _getActionIcon(String action) {
    final lower = action.toLowerCase();
    if (lower.contains('create') || lower.contains('add'))
      return Icons.add_circle_outline_rounded;
    if (lower.contains('update') ||
        lower.contains('edit') ||
        lower.contains('adjust'))
      return Icons.edit_note_rounded;
    if (lower.contains('delete') || lower.contains('deactivate'))
      return Icons.remove_circle_outline_rounded;
    if (lower.contains('activate') || lower.contains('approve'))
      return Icons.verified_rounded;
    return Icons.history_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _logs.where((log) {
      final matchesSearch =
          _searchQuery.isEmpty ||
          log.action.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          log.userName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          log.entity.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (log.ipAddress?.toLowerCase().contains(_searchQuery.toLowerCase()) ??
              false);
      if (!matchesSearch) return false;

      if (_selectedActionFilter == 'All') return true;
      if (_selectedActionFilter == 'Create')
        return log.action.toLowerCase().contains('create');
      if (_selectedActionFilter == 'Update')
        return log.action.toLowerCase().contains('update');
      if (_selectedActionFilter == 'Security')
        return log.action.toLowerCase().contains('activate') ||
            log.action.toLowerCase().contains('role');
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFF0B0F19),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        title: const Text(
          'System Audit Trail',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF06B6D4)),
            tooltip: 'Refresh',
            onPressed: _loadLogs,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadLogs,
        color: const Color(0xFF06B6D4),
        backgroundColor: const Color(0xFF0F172A),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    TextField(
                      controller: _user,
                      decoration: const InputDecoration(labelText: 'User name'),
                    ),
                    TextField(
                      controller: _entity,
                      decoration: const InputDecoration(labelText: 'Entity'),
                    ),
                    TextField(
                      controller: _action,
                      decoration: const InputDecoration(labelText: 'Action'),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton(
                          onPressed: () => _pickDate(true),
                          child: Text(
                            _from == null
                                ? 'From date'
                                : 'From: ${_from.toString().split(' ')[0]}',
                          ),
                        ),
                        OutlinedButton(
                          onPressed: () => _pickDate(false),
                          child: Text(
                            _to == null
                                ? 'To date'
                                : 'To: ${_to.toString().split(' ')[0]}',
                          ),
                        ),
                        FilledButton(
                          onPressed: _loading ? null : _applyFilters,
                          child: const Text('Apply filters'),
                        ),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _search.clear();
                              _user.clear();
                              _entity.clear();
                              _action.clear();
                              _from = _to = null;
                              _searchQuery = '';
                              _selectedActionFilter = 'All';
                            });
                            _loadLogs();
                          },
                          child: const Text('Reset filters'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Search Input
            TextField(
              controller: _search,
              onChanged: (val) => setState(() => _searchQuery = val.trim()),
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Search audit events, users, entities, IP...',
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

            // Action Filter Chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: ['All', 'Create', 'Update', 'Security'].map((f) {
                  final selected = _selectedActionFilter == f;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(f),
                      selected: selected,
                      onSelected: (_) =>
                          setState(() => _selectedActionFilter = f),
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

            if (_loading && _logs.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(40),
                  child: CircularProgressIndicator(color: Color(0xFF06B6D4)),
                ),
              )
            else if (_error != null && _logs.isEmpty)
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
                        onPressed: _loadLogs,
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
                  'No audit events found.',
                  style: TextStyle(color: Color(0xFF64748B)),
                ),
              )
            else
              ...filtered.map((log) {
                final actionColor = _getActionColor(log.action);
                final actionIcon = _getActionIcon(log.action);

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
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: actionColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                actionIcon,
                                color: actionColor,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: actionColor.withValues(
                                            alpha: 0.2,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                          border: Border.all(
                                            color: actionColor.withValues(
                                              alpha: 0.5,
                                            ),
                                          ),
                                        ),
                                        child: Text(
                                          log.action,
                                          style: TextStyle(
                                            color: actionColor,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        log.entity,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'by ${log.userName} ${log.ipAddress != null ? "Ã¢â‚¬Â¢ ${log.ipAddress}" : ""}',
                                    style: const TextStyle(
                                      color: Color(0xFF94A3B8),
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              log.success
                                  ? Icons.check_circle_rounded
                                  : Icons.cancel_rounded,
                              color: log.success
                                  ? const Color(0xFF10B981)
                                  : const Color(0xFFEF4444),
                              size: 18,
                            ),
                          ],
                        ),
                        if (log.entityId.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Target ID: ${log.entityId}',
                            style: const TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 10,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(
                              log.timestamp
                                  .toUtc()
                                  .add(const Duration(hours: 5, minutes: 30))
                                  .toString()
                                  .split('.')[0],
                              style: const TextStyle(
                                color: Color(0xFF475569),
                                fontSize: 10,
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
