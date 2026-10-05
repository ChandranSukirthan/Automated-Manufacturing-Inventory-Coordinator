# mobile_flutter

Mobile application for the Automated Manufacturing Inventory Coordinator.

## Test a roll QR code

1. Start the backend and sign in to the mobile app as a Floor Worker, Supply
   Chain Manager, or IT Admin.
2. In **Items**, choose **Register New Roll**. Select the packaging type, raw
   material, and an in-stock SKU number. Enter only the final roll number
   (for example, `01`) and a quantity greater than zero and no greater than
   the shown available amount.
3. The app creates the full roll reference from those choices (for example,
   `ROLL-BP-LAM-001-01`) and the server generates its QR code. The QR image
   opens immediately after registration. You can open it later with
   **Items** → the eye icon on the SKU → the QR icon on the roll.
4. Put that QR image on a different screen (or print it), then open the
   scanner in the app and scan it. A phone cannot normally scan a QR image
   displayed on its own screen.

The QR stores an internal roll reference, not the SKU. This allows the system
to distinguish two physical rolls that contain the same SKU and report the
correct remaining quantity for the scanned roll.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
