import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/models/admin/machine_model.dart';
import 'package:mobile_flutter/models/admin/shift_model.dart';
import 'package:mobile_flutter/models/admin/workflow_model.dart';
import 'package:mobile_flutter/models/admin/system_health_model.dart';

void main() {
  group('MachineModel Tests', () {
    test('MachineModel deserializes correctly from integer status', () {
      final json = {
        'id': 'm-123',
        'name': 'CNC Milling Machine 01',
        'status': 0,
        'uptimeHours': 120.5,
        'maintenanceIntervalHours': 500.0,
        'location': 'Shop Floor Bay 2',
        'isMaintenanceDue': false,
        'remainingHours': 379.5,
        'createdAt': '2026-09-01T08:00:00Z',
        'updatedAt': '2026-09-26T08:00:00Z',
      };

      final machine = MachineModel.fromJson(json);
      expect(machine.id, 'm-123');
      expect(machine.name, 'CNC Milling Machine 01');
      expect(machine.status, 'Operational');
      expect(machine.uptimeHours, 120.5);
      expect(machine.isMaintenanceDue, false);
    });

    test('MachineModel deserializes MaintenanceRequired status', () {
      final json = {
        'id': 'm-456',
        'name': 'Hydraulic Press 02',
        'status': 1,
        'uptimeHours': 510.0,
        'maintenanceIntervalHours': 500.0,
        'location': 'Press Shop',
        'isMaintenanceDue': true,
        'remainingHours': 0.0,
      };

      final machine = MachineModel.fromJson(json);
      expect(machine.status, 'MaintenanceRequired');
      expect(machine.isMaintenanceDue, true);
    });
  });

  group('ShiftModel Tests', () {
    test('ShiftModel deserializes correctly', () {
      final json = {
        'id': 's-1',
        'name': 'Morning Production Shift A',
        'startTime': '2026-09-26T06:00:00Z',
        'endTime': '2026-09-26T14:00:00Z',
        'targetOutput': 450.0,
        'adjustedOutput': 420.0,
        'status': 1,
        'notes': 'Normal operations with minor tooling change',
      };

      final shift = ShiftModel.fromJson(json);
      expect(shift.id, 's-1');
      expect(shift.name, 'Morning Production Shift A');
      expect(shift.status, 'Active');
      expect(shift.targetOutput, 450.0);
      expect(shift.adjustedOutput, 420.0);
    });
  });

  group('WorkflowModel Tests', () {
    test('WorkflowModel deserializes with steps and approval', () {
      final json = {
        'id': 'wf-99',
        'objective': 'Auto-rebalance production quotas',
        'status': 'WaitingForApproval',
        'currentStep': 3,
        'totalSteps': 5,
        'isWaitingForApproval': true,
        'steps': [
          {
            'stepNumber': 1,
            'agentName': 'Planner Agent',
            'status': 'Completed',
            'output': 'Identified bottleneck at Press 02',
          },
          {
            'stepNumber': 2,
            'agentName': 'Scheduler Agent',
            'status': 'Completed',
            'output': 'Adjusted quotas for Shift B',
          },
          {
            'stepNumber': 3,
            'agentName': 'Human-in-the-Loop',
            'status': 'Pending',
          },
        ],
      };

      final wf = WorkflowModel.fromJson(json);
      expect(wf.id, 'wf-99');
      expect(wf.isWaitingForApproval, true);
      expect(wf.currentAgent, 'Planner');
      expect(wf.approvalStatus, 'Waiting For Approval');
      expect(wf.steps.length, 3);
      expect(wf.steps[0].agentName, 'Planner Agent');
      expect(wf.steps[0].status, 'Completed');
    });
  });

  group('SystemHealthModel Tests', () {
    test('SystemHealthModel deserializes service statuses correctly', () {
      final json = {
        'overallStatus': 'ONLINE',
        'services': [
          {'name': 'ASP.NET API', 'status': 'ONLINE', 'message': 'Running'},
          {'name': 'PostgreSQL', 'status': 'ONLINE', 'message': 'Healthy'},
          {'name': 'FastAPI', 'status': 'ONLINE', 'message': 'Healthy'},
        ],
      };

      final health = SystemHealthModel.fromJson(json);
      expect(health.overallStatus, 'ONLINE');
      expect(health.services.length, 3);
      expect(health.services[0].name, 'ASP.NET API');
      expect(health.services[0].status, 'ONLINE');
    });
  });
}
