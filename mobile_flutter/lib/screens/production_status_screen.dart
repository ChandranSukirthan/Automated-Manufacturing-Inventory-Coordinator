import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../services/floor_worker_operations_service.dart';

class ProductionStatusScreen extends StatefulWidget {
  const ProductionStatusScreen({this.service, super.key});

  final FloorWorkerOperationsService? service;

  @override
  State<ProductionStatusScreen> createState() => _ProductionStatusScreenState();
}

class _ProductionStatusScreenState extends State<ProductionStatusScreen> {
  static const _yellow = Color(0xFFFFD700);
  late final FloorWorkerOperationsService _service;
  bool _loading = true;
  String? _error;
  List<ProductionShiftSummary> _shifts = const [];

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? FloorWorkerOperationsService();
    _load();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final shifts = await _service.fetchProductionShifts();
      if (mounted) {
        setState(() {
          _shifts = shifts;
          _loading = false;
        });
      }
    } on ApiException catch (error) {
      if (mounted) {
        setState(() {
          _error = error.message;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Production status could not be loaded.';
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Production Status'),
      actions: [
        IconButton(
          onPressed: _load,
          icon: const Icon(Icons.refresh),
          tooltip: 'Refresh',
        ),
      ],
    ),
    body: RefreshIndicator(
      onRefresh: _load,
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _errorState()
          : _shifts.isEmpty
          ? const OperationsEmptyState(
              message: 'No production shifts are scheduled.',
            )
          : ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: _shifts.length,
              itemBuilder: (_, index) => _shiftCard(_shifts[index]),
            ),
    ),
  );

  Widget _errorState() => ListView(
    physics: const AlwaysScrollableScrollPhysics(),
    padding: const EdgeInsets.all(24),
    children: [
      const Icon(Icons.cloud_off_outlined, size: 42, color: Colors.redAccent),
      const SizedBox(height: 12),
      Text(_error!, textAlign: TextAlign.center),
      const SizedBox(height: 12),
      Center(
        child: FilledButton(onPressed: _load, child: const Text('Retry')),
      ),
    ],
  );

  Widget _shiftCard(ProductionShiftSummary shift) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.precision_manufacturing_outlined,
                color: _yellow,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  shift.name,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              _StatusChip(status: shift.status),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Output: ${shift.actualOutput} actual / ${shift.adjustedOutput} adjusted / ${shift.productionTarget} target',
          ),
          Text('Material available: ${shift.availableMaterial} units'),
          if (shift.startTime != null || shift.endTime != null) ...[
            const SizedBox(height: 8),
            Text(
              '${_formatTime(shift.startTime)} – ${_formatTime(shift.endTime)}',
              style: const TextStyle(color: Colors.white60),
            ),
          ],
        ],
      ),
    ),
  );
}

String _formatTime(DateTime? value) => value == null
    ? 'Time not set'
    : value.toUtc().add(const Duration(hours: 5, minutes: 30)).toString().split('.').first;

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) =>
      Chip(label: Text(status), visualDensity: VisualDensity.compact);
}

class OperationsEmptyState extends StatelessWidget {
  const OperationsEmptyState({required this.message, super.key});
  final String message;

  @override
  Widget build(BuildContext context) => ListView(
    physics: const AlwaysScrollableScrollPhysics(),
    children: [
      const SizedBox(height: 120),
      Center(child: Text(message)),
    ],
  );
}
