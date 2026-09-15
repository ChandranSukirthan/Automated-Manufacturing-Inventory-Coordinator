import 'package:flutter/material.dart';

import 'app_state.dart';
import 'screens/home_shell.dart';
import 'screens/login_screen.dart';
import 'services/api_client.dart';
import 'services/auth_service.dart';
import 'services/quality_service.dart';
import 'services/session_storage.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final storage = SessionStorage();
  final api = ApiClient(storage: storage);
  final appState = AppState(auth: AuthService(api, storage), storage: storage);
  api.onSessionExpired = appState.expireSession;
  await appState.restore();
  runApp(
    ManufacturingApp(appState: appState, qualityService: QualityService(api)),
  );
}

class ManufacturingApp extends StatelessWidget {
  const ManufacturingApp({
    required this.appState,
    required this.qualityService,
    super.key,
  });

  final AppState appState;
  final QualityService qualityService;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: appState,
    builder: (context, _) => MaterialApp(
      title: 'Manufacturing Coordinator',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF145A64),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF5F7F8),
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
          filled: true,
          fillColor: Colors.white,
        ),
        cardTheme: const CardThemeData(
          margin: EdgeInsets.only(bottom: 12),
          elevation: 0,
          color: Colors.white,
        ),
      ),
      home: appState.isLoading
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : appState.isAuthenticated
          ? HomeShell(appState: appState, qualityService: qualityService)
          : LoginScreen(appState: appState),
    ),
  );
}
