import 'package:flutter/material.dart';

import 'app_state.dart';
import 'app_colors.dart';
import 'screens/home_shell.dart';
import 'screens/login_screen.dart';
import 'services/api_client.dart';
import 'services/auth_service.dart';
import 'services/purchase_order_service.dart';
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
    ManufacturingApp(
      appState: appState,
      qualityService: QualityService(api),
      poService: PurchaseOrderService(api),
    ),
  );
}

class ManufacturingApp extends StatelessWidget {
  const ManufacturingApp({
    required this.appState,
    required this.qualityService,
    required this.poService,
    super.key,
  });

  final AppState appState;
  final QualityService qualityService;
  final PurchaseOrderService poService;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: appState,
    builder: (context, _) => MaterialApp(
      title: 'Manufacturing Coordinator',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          brightness: Brightness.dark,
        ).copyWith(
          primary: AppColors.primary,
          onPrimary: AppColors.background,
          secondary: AppColors.info,
          onSecondary: AppColors.background,
          tertiary: AppColors.warning,
          error: AppColors.error,
          onError: AppColors.strongText,
          surface: AppColors.surface,
          onSurface: AppColors.primaryText,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.background,
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
          filled: true,
          fillColor: AppColors.background,
        ),
        cardTheme: const CardThemeData(
          margin: EdgeInsets.only(bottom: 12),
          elevation: 0,
          color: AppColors.surface,
        ),
      ),
      home: appState.isLoading
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : appState.isAuthenticated
          ? HomeShell(
              appState: appState,
              qualityService: qualityService,
              poService: poService,
            )
          : LoginScreen(appState: appState),
    ),
  );
}
