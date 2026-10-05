import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/models/procurement_models.dart';

void main() {
  group('11-Stage Procurement Pipeline Step Enum Tests', () {
    test('contains exactly the 11 sequential procurement stages required', () {
      final steps = ProcurementPipelineStep.values;
      expect(steps.length, equals(11));

      expect(steps[0], equals(ProcurementPipelineStep.lowStock));
      expect(steps[0].title, equals('LOW STOCK'));

      expect(steps[1], equals(ProcurementPipelineStep.procurementRequested));
      expect(steps[1].title, equals('PROCUREMENT REQUESTED'));

      expect(steps[2], equals(ProcurementPipelineStep.aiResearching));
      expect(steps[2].title, equals('AI RESEARCHING'));

      expect(steps[3], equals(ProcurementPipelineStep.recommendationReady));
      expect(steps[3].title, equals('RECOMMENDATION READY'));

      expect(steps[4], equals(ProcurementPipelineStep.waitingForApproval));
      expect(steps[4].title, equals('WAITING FOR MANAGER APPROVAL'));

      expect(steps[5], equals(ProcurementPipelineStep.approved));
      expect(steps[5].title, equals('APPROVED'));

      expect(steps[6], equals(ProcurementPipelineStep.paymentProcessing));
      expect(steps[6].title, equals('PAYMENT PROCESSING'));

      expect(steps[7], equals(ProcurementPipelineStep.paid));
      expect(steps[7].title, equals('PAID'));

      expect(steps[8], equals(ProcurementPipelineStep.supplierNotified));
      expect(steps[8].title, equals('SUPPLIER NOTIFIED'));

      expect(steps[9], equals(ProcurementPipelineStep.incomingSupply));
      expect(steps[9].title, equals('INCOMING SUPPLY'));

      expect(steps[10], equals(ProcurementPipelineStep.completed));
      expect(steps[10].title, equals('COMPLETED'));
    });
  });

  group('SupplyDeliveryStatus Enum & Mapping Tests', () {
    test('parses all delivery statuses and normalized aliases correctly', () {
      expect(SupplyDeliveryStatus.fromString('EXPECTED'), equals(SupplyDeliveryStatus.expected));
      expect(SupplyDeliveryStatus.fromString('IN_TRANSIT'), equals(SupplyDeliveryStatus.inTransit));
      expect(SupplyDeliveryStatus.fromString('RECEIVED'), equals(SupplyDeliveryStatus.received));
      expect(SupplyDeliveryStatus.fromString('PARTIALLY_RECEIVED'), equals(SupplyDeliveryStatus.partiallyReceived));
      expect(SupplyDeliveryStatus.fromString('DELAYED'), equals(SupplyDeliveryStatus.delayed));
      expect(SupplyDeliveryStatus.fromString('COMPLETED'), equals(SupplyDeliveryStatus.completed));

      // Aliases
      expect(SupplyDeliveryStatus.fromString('SENT'), equals(SupplyDeliveryStatus.inTransit));
      expect(SupplyDeliveryStatus.fromString('SHIPPED'), equals(SupplyDeliveryStatus.inTransit));
      expect(SupplyDeliveryStatus.fromString('ARRIVED'), equals(SupplyDeliveryStatus.received));
      expect(SupplyDeliveryStatus.fromString(null), equals(SupplyDeliveryStatus.expected));
    });
  });

  group('SupplierCandidateItem Tests', () {
    test('parses candidate json with 17 fields and evaluates qualityStatus', () {
      final json = {
        'id': 1,
        'supplierId': 5,
        'supplierName': 'Apex Packaging Materials Ltd',
        'materialName': 'Food Grade BOPP Film',
        'unitPrice': 3.50,
        'currency': 'USD',
        'minimumOrderQuantity': 500.0,
        'packSize': 100.0,
        'leadTimeDays': 5,
        'qualityEvidence': 'ISO 9001:2015 & ASTM F1249 Certified',
        'supplierStatus': 'APPROVED',
        'confidenceScore': 0.94,
        'sourceUrl': 'https://apexpackaging.example.com/bopp',
        'isValidated': true,
        'recommendedOrderQuantity': 1000.0,
        'totalCost': 3500.0,
        'availability': 'In Stock',
        'createdAt': '2026-09-25T10:00:00Z',
      };

      final candidate = SupplierCandidateItem.fromJson(json);
      expect(candidate.id, equals(1));
      expect(candidate.supplierName, equals('Apex Packaging Materials Ltd'));
      expect(candidate.unitPrice, equals(3.50));
      expect(candidate.isApproved, isTrue);
      expect(candidate.isUnverified, isFalse);
      expect(candidate.qualityStatus, equals('VERIFIED'));
      expect(candidate.availability, equals('In Stock'));
    });

    test('correctly evaluates UNKNOWN and NOT VERIFIED quality statuses', () {
      final unverifiedJson = {
        'id': 2,
        'supplierName': 'Unknown Vendor',
        'materialName': 'Polymer Film',
        'unitPrice': 2.00,
        'currency': 'USD',
        'minimumOrderQuantity': 100.0,
        'packSize': 50.0,
        'leadTimeDays': 10,
        'qualityEvidence': 'Unverified vendor - no certificate uploaded',
        'supplierStatus': 'UNVERIFIED',
        'confidenceScore': 0.4,
        'isValidated': false,
        'recommendedOrderQuantity': 200.0,
        'totalCost': 400.0,
        'createdAt': '2026-09-25T10:00:00Z',
      };

      final c = SupplierCandidateItem.fromJson(unverifiedJson);
      expect(c.isUnverified, isTrue);
      expect(c.qualityStatus, equals('NOT VERIFIED'));
    });
  });

  group('ProcurementStatusTracking Tests', () {
    test('maps backend states to the 11-step pipeline accurately', () {
      // 1. Waiting for Approval
      final trackingApproval = ProcurementStatusTracking.fromJson({
        'procurementId': 101,
        'materialName': 'Food Grade BOPP Film',
        'requiredSpecification': '50 Micron',
        'netDeficit': 800.0,
        'procurementStatus': 'RecommendationReady',
        'workflowId': 'WF-PROC-101',
        'purchaseOrderId': 42,
        'purchaseOrderNumber': 'PO-2026-0042',
        'purchaseOrderStatus': 'PendingApproval',
        'requiresHumanApproval': true,
        'supplierName': 'Apex Packaging',
        'supplierStatus': 'APPROVED',
        'recommendedQuantity': 1000.0,
        'unitPrice': 3.50,
        'totalCost': 3500.0,
        'qualityEvidence': 'ISO 9001 Certified',
      });

      expect(trackingApproval.pipelineStep, equals(ProcurementPipelineStep.waitingForApproval));
      expect(trackingApproval.isApprovalPending, isTrue);
      expect(trackingApproval.qualityStatus, equals('VERIFIED'));

      // 2. Approved
      final trackingApproved = ProcurementStatusTracking.fromJson({
        'procurementId': 101,
        'materialName': 'Film',
        'netDeficit': 800.0,
        'procurementStatus': 'Approved',
        'purchaseOrderStatus': 'Approved',
        'requiresHumanApproval': false,
      });
      expect(trackingApproved.pipelineStep, equals(ProcurementPipelineStep.approved));

      // 3. Paid
      final trackingPaid = ProcurementStatusTracking.fromJson({
        'procurementId': 101,
        'materialName': 'Film',
        'netDeficit': 800.0,
        'procurementStatus': 'Approved',
        'purchaseOrderStatus': 'Approved',
        'paymentStatus': 'Paid',
        'requiresHumanApproval': false,
      });
      expect(trackingPaid.pipelineStep, equals(ProcurementPipelineStep.paid));

      // 4. Supplier Notified
      final trackingNotified = ProcurementStatusTracking.fromJson({
        'procurementId': 101,
        'materialName': 'Film',
        'netDeficit': 800.0,
        'procurementStatus': 'Approved',
        'purchaseOrderStatus': 'Approved',
        'paymentStatus': 'Paid',
        'supplierNotificationStatus': 'Sent',
        'requiresHumanApproval': false,
      });
      expect(trackingNotified.pipelineStep, equals(ProcurementPipelineStep.supplierNotified));

      // 5. Incoming Supply
      final trackingIncoming = ProcurementStatusTracking.fromJson({
        'procurementId': 101,
        'materialName': 'Film',
        'netDeficit': 800.0,
        'procurementStatus': 'Approved',
        'purchaseOrderStatus': 'Sent',
        'paymentStatus': 'Paid',
        'supplierNotificationStatus': 'Sent',
        'requiresHumanApproval': false,
      });
      expect(trackingIncoming.pipelineStep, equals(ProcurementPipelineStep.incomingSupply));

      // 6. Completed
      final trackingCompleted = ProcurementStatusTracking.fromJson({
        'procurementId': 101,
        'materialName': 'Film',
        'netDeficit': 800.0,
        'procurementStatus': 'Completed',
        'purchaseOrderStatus': 'Completed',
        'paymentStatus': 'Paid',
        'supplierNotificationStatus': 'Sent',
        'requiresHumanApproval': false,
      });
      expect(trackingCompleted.pipelineStep, equals(ProcurementPipelineStep.completed));
    });
  });

  group('IncomingSupplyItem Tests', () {
    test('parses incoming supply delivery payload correctly', () {
      final json = {
        'purchaseOrderId': 42,
        'poNumber': 'PO-2026-0042',
        'supplierName': 'Apex Packaging Materials Ltd',
        'materialName': 'Food Grade BOPP Film',
        'quantity': 1000.0,
        'expectedDelivery': '2026-10-01T08:00:00Z',
        'deliveryStatus': 'IN_TRANSIT',
        'trackingNumber': 'TRK-APEX-9921',
        'statusRemarks': 'Dispatched via Express Freight',
      };

      final item = IncomingSupplyItem.fromJson(json);
      expect(item.purchaseOrderId, equals(42));
      expect(item.poNumber, equals('PO-2026-0042'));
      expect(item.supplierName, equals('Apex Packaging Materials Ltd'));
      expect(item.quantity, equals(1000.0));
      expect(item.deliveryStatus, equals(SupplyDeliveryStatus.inTransit));
      expect(item.trackingNumber, equals('TRK-APEX-9921'));
    });
  });
}
