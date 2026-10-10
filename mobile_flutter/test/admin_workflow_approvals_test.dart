import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/models/admin/workflow_model.dart';
import 'package:mobile_flutter/services/admin/admin_api_service.dart';
import 'package:mobile_flutter/screens/admin/tabs/agent_workflows_tab.dart';
import 'package:mobile_flutter/screens/admin/subscreens/workflow_detail_screen.dart';

WorkflowModel workflow(
  String type, {
  dynamic status = 'WaitingForApproval',
  dynamic approval = 'Pending',
}) => WorkflowModel.fromJson({
  'id': 'db-$type',
  'workflowId': 'WF-$type',
  'workflowType': type,
  'objective': '$type request',
  'status': status,
  'approvalStatus': approval,
  'startedAt': '2026-10-10T00:00:00Z',
  'currentAgent': 'Supervisor',
  'purchaseOrderId': type == 'Procurement' ? 26 : null,
});

class FakeAdmin extends Fake implements AdminApiService {
  String? approved;
  String? rejected;
  @override
  Future<dynamic> approveWorkflow(String id) async {
    approved = id;
    return workflow(
      'Procurement',
      status: 'Running',
      approval: 'Approved',
    ).toJson();
  }

  @override
  Future<dynamic> rejectWorkflow(String id) async {
    rejected = id;
    return workflow(
      'Procurement',
      status: 'Failed',
      approval: 'Rejected',
    ).toJson();
  }
}

void main() {
  test(
    'all pending workflow types match web eligibility and enum numbers parse',
    () {
      for (final type in ['Maintenance', 'Procurement', 'Quality']) {
        expect(workflow(type).canAuthorize, isTrue);
        expect(workflow(type, status: 3, approval: 0).canAuthorize, isTrue);
        expect(workflow(type, status: 'Completed').canAuthorize, isFalse);
        expect(workflow(type, status: 'Failed').canAuthorize, isFalse);
        expect(workflow(type, approval: 'Approved').canAuthorize, isFalse);
      }
    },
  );
  for (final approve in [true, false]) {
    testWidgets(
      'procurement ${approve ? 'approve' : 'reject'} uses workflow ID and removes controls',
      (tester) async {
        final service = FakeAdmin();
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark(),
            home: WorkflowDetailScreen(
              workflow: workflow('Procurement'),
              service: service,
            ),
          ),
        );
        final button = find.text(approve ? 'Approve Plan' : 'Reject');
        await tester.ensureVisible(button);
        await tester.tap(button);
        await tester.pumpAndSettle();
        expect(approve ? service.approved : service.rejected, 'WF-Procurement');
        expect(find.text('Approve Plan'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'filters combine search and approval queue and reset; narrow layout fits',
    (tester) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: AgentWorkflowsTab(
            workflows: [
              workflow('Procurement'),
              workflow('Maintenance'),
              workflow('Quality', status: 'Completed'),
            ],
            service: FakeAdmin(),
            loading: false,
            onRefresh: () async {},
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      await tester.enterText(find.byType(TextField), ' procurement ');
      await tester.pumpAndSettle();
      expect(find.text('1 of 3 workflows - Newest first'), findsOneWidget);
      await tester.ensureVisible(find.byType(FilterChip));
      await tester.tap(find.byType(FilterChip));
      await tester.pumpAndSettle();
      expect(find.text('1 of 3 workflows - Newest first'), findsOneWidget);
      await tester.tap(find.text('Clear filters'));
      await tester.pumpAndSettle();
      expect(find.text('3 of 3 workflows - Newest first'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
