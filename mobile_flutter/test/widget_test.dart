import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';

import 'package:mobile_flutter/app_state.dart';
import 'package:mobile_flutter/screens/login_screen.dart';
import 'package:mobile_flutter/services/api_client.dart';
import 'package:mobile_flutter/services/auth_service.dart';
import 'package:mobile_flutter/services/session_storage.dart';

void main() {
  testWidgets('login screen renders the existing auth entry point', (
    tester,
  ) async {
    final storage = SessionStorage();
    final api = ApiClient(storage: storage);
    final appState = AppState(
      auth: AuthService(api, storage),
      storage: storage,
    );

    await tester.pumpWidget(MaterialApp(home: LoginScreen(appState: appState)));

    expect(find.text('Quality control,\nin your pocket.'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
  });
}
