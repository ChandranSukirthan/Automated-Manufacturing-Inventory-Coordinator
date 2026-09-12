import 'package:flutter/material.dart';

import '../models/quality_models.dart';
import '../services/quality_service.dart';
import '../widgets/app_widgets.dart';
import 'defect_form_screen.dart';

class BatchDetailsScreen extends StatelessWidget {
  const BatchDetailsScreen({
    required this.service,
    required this.batch,
    super.key,
  });

  final QualityService service;
  final BatchDetails batch;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Batch details')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _Detail(label: 'Batch ID', value: batch.id),
        _Detail(label: 'Product type', value: batch.productType),
        const SizedBox(height: 12),
        Text('Inventory rolls', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        if (batch.inventoryRolls.isEmpty)
          const Card(child: ListTile(title: Text('No inventory rolls found.')))
        else
          ...batch.inventoryRolls.map(
            (roll) => Card(
              child: ListTile(
                title: Text(roll.id),
                subtitle: Text('Batch: ${roll.batchId}'),
                trailing: StatusPill(roll.status),
              ),
            ),
          ),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: () => Navigator.push<void>(
            context,
            MaterialPageRoute(
              builder: (_) => DefectFormScreen(
                service: service,
                initialBatchId: batch.id,
                initialProductType: batch.productType,
              ),
            ),
          ),
          icon: const Icon(Icons.fact_check_outlined),
          label: const Text('Report defect for this batch'),
        ),
      ],
    ),
  );
}

class _Detail extends StatelessWidget {
  const _Detail({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 4),
        Text(value, style: Theme.of(context).textTheme.headlineSmall),
      ],
    ),
  );
}