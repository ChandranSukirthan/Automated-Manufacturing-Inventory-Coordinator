import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/controllers/inventory_controller.dart';
import 'package:frontend/main.dart';
import 'package:frontend/models/user_profile.dart';
import 'package:frontend/utils/shift_helper.dart';

void main() {
  testWidgets('starts on the employee sign-in page', (tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('Employee Sign In'), findsOneWidget);
    expect(find.text('SIGN IN AS EMPLOYEE'), findsOneWidget);
  });

  group('low-stock alert form state', () {
    test('starts without preselected material details', () {
      final controller = InventoryController();

      expect(controller.packagingType, isEmpty);
      expect(controller.sku, isEmpty);
      expect(controller.quantityRequested, 1);
    });

    test('keeps the quantity above zero when adjusted', () {
      final controller = InventoryController();

      controller.decrementQuantity();
      expect(controller.quantityRequested, 1);

      controller.incrementQuantity();
      expect(controller.quantityRequested, 2);

      controller.setQuantityRequested(0);
      expect(controller.quantityRequested, 1);
    });
  });

  test('profile details can be updated while retaining its assigned ID', () {
    const profile = UserProfile(
      fullName: 'Sam Perera',
      username: 'sam.perera',
      employeeId: 'EMP-42',
      role: 'Factory / Floor Worker',
    );

    final updatedProfile = profile.copyWith(role: 'Supply Chain Manager');

    expect(updatedProfile.fullName, 'Sam Perera');
    expect(updatedProfile.username, 'sam.perera');
    expect(updatedProfile.employeeId, 'EMP-42');
    expect(updatedProfile.role, 'Supply Chain Manager');
  });

  test('only managers and Admin can approve financial actions', () {
    const floorWorker = UserProfile(
      fullName: 'Floor Worker',
      username: 'floor.worker',
      employeeId: 'EMP1',
      role: 'Factory / Floor Worker',
    );
    const manager = UserProfile(
      fullName: 'Supply Manager',
      username: 'supply.manager',
      employeeId: 'M2',
      role: 'Supply Chain Manager',
    );
    const admin = UserProfile(
      fullName: 'System Administrator',
      username: 'Admin',
      employeeId: 'ADMIN',
      role: 'IT / System Admin',
    );

    expect(floorWorker.canApproveFinancialActions, isFalse);
    expect(floorWorker.canViewManagerDashboard, isFalse);
    expect(manager.canApproveFinancialActions, isTrue);
    expect(manager.canViewManagerDashboard, isTrue);
    expect(admin.canApproveFinancialActions, isTrue);
  });

  test('shift labels follow the device time ranges', () {
    expect(
      shiftLabelFor(DateTime(2026, 1, 1, 8)),
      'Morning Shift (8 AM - 12 PM)',
    );
    expect(
      shiftLabelFor(DateTime(2026, 1, 1, 11, 59)),
      'Morning Shift (8 AM - 12 PM)',
    );
    expect(
      shiftLabelFor(DateTime(2026, 1, 1, 12)),
      'Evening Shift (12 PM - 6 PM)',
    );
    expect(
      shiftLabelFor(DateTime(2026, 1, 1, 17, 59)),
      'Evening Shift (12 PM - 6 PM)',
    );
    expect(
      shiftLabelFor(DateTime(2026, 1, 1, 18)),
      'Night Shift (6 PM - 8 AM)',
    );
    expect(
      shiftLabelFor(DateTime(2026, 1, 1, 7, 59)),
      'Night Shift (6 PM - 8 AM)',
    );
  });
}
