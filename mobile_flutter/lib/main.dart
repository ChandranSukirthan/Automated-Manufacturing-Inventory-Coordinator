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
          backgroundColor: const Color(0xFF070B14),
          indicatorColor: AppColors.primary.withValues(alpha: 0.2),
          iconTheme: WidgetStateProperty.resolveWith(
            (states) => IconThemeData(
              color: states.contains(WidgetState.selected)
                  ? AppColors.primaryLight
                  : AppColors.mutedText,
            ),
          ),
          labelTextStyle: WidgetStateProperty.resolveWith(
            (states) => TextStyle(
              color: states.contains(WidgetState.selected)
                  ? AppColors.primaryLight
                  : AppColors.mutedText,
              fontWeight: states.contains(WidgetState.selected)
                  ? FontWeight.w700
                  : FontWeight.w500,
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.primaryLight, width: 1.5),
          ),
        ),
        cardTheme: CardThemeData(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 0,
          color: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: AppColors.border),
          ),
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
