import 'package:flutter/material.dart';

import 'app_state.dart';
import 'app_colors.dart';
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
        navigationBarTheme: NavigationBarThemeData(
          indicatorColor: AppColors.violet,
          iconTheme: WidgetStateProperty.resolveWith(
            (states) => IconThemeData(
              color: states.contains(WidgetState.selected)
                  ? AppColors.strongText
                  : AppColors.mutedText,
            ),
          ),
          labelTextStyle: WidgetStateProperty.resolveWith(
            (states) => TextStyle(
              color: states.contains(WidgetState.selected)
                  ? AppColors.violet
                  : AppColors.mutedText,
            ),
          ),
        ),
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
          ? HomeShell(appState: appState, qualityService: qualityService)
          : LoginScreen(appState: appState),
    ),
  );
}
