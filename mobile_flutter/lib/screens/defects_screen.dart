import 'package:flutter/material.dart';

import '../models/quality_models.dart';
import '../services/api_client.dart';
import '../services/quality_service.dart';
import '../widgets/app_widgets.dart';
import 'defect_detail_screen.dart';
import 'defect_form_screen.dart';

class DefectsScreen extends StatefulWidget {
  const DefectsScreen({required this.service, super.key});

  final QualityService service;

  @override
  State<DefectsScreen> createState() => _DefectsScreenState();
}

class _DefectsScreenState extends State<DefectsScreen> {
  List<DefectReport>? _defects;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final defects = await widget.service.getDefects();
      if (mounted) setState(() => _defects = defects);
    } on ApiException catch (exception) {
      if (mounted) setState(() => _error = exception.message);
    }
  }

  Future<void> _create() async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => DefectFormScreen(service: widget.service),
      ),
    );
    if (created == true) {
      _load();
    }
  }

  Future<void> _open(DefectReport defect) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            DefectDetailScreen(service: widget.service, defectId: defect.id),
      ),
    );
    if (mounted) _load();
  }

  Future<void> _delete(DefectReport defect) async {
    try {
      await widget.service.deleteDefect(defect.id);
      if (mounted) _load();
    } on ApiException catch (exception) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(exception.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _error != null && _defects == null
          ? StateMessage(message: _error!, icon: Icons.cloud_off, action: _load)
          : _defects == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: _defects!.isEmpty
                  ? ListView(
                      children: const [
                        SizedBox(height: 180),
                        StateMessage(
                          message: 'No defect reports yet.',
                          icon: Icons.fact_check_outlined,
                        ),
                      ],
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                      itemCount: _defects!.length,
                      itemBuilder: (context, index) {
                        final defect = _defects![index];
                        return Card(
                          child: ListTile(
                            contentPadding: const EdgeInsets.all(16),
                            title: Text(
                              defect.batchId,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                '${defect.productType}\n${defect.description}',
                              ),
                            ),
                            isThreeLine: true,
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    StatusPill(defect.severity),
                                    const SizedBox(height: 8),
                                    Text(
                                      defect.status,
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelSmall,
                                    ),
                                  ],
                                ),
                                PopupMenuButton<String>(
                                  onSelected: (value) {
                                    if (value == 'view') {
                                      _open(defect);
                                    }
                                    if (value == 'delete') {
                                      _confirmDelete(defect);
                                    }
                                  },
                                  itemBuilder: (_) => const [
                                    PopupMenuItem(
                                      value: 'view',
                                      child: Text('View details'),
                                    ),
                                    PopupMenuItem(
                                      value: 'delete',
                                      child: Text('Delete'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            onTap: () => _open(defect),
                          ),
                        );
                      },
                    ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _create,
        icon: const Icon(Icons.add),
        label: const Text('Report defect'),
      ),
    );
  }

  Future<void> _confirmDelete(DefectReport defect) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete report?'),
        content: const Text(
          'This permanently removes the selected defect report.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) await _delete(defect);
  }
}
