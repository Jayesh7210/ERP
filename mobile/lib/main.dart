import 'package:flutter/material.dart';
import 'core/constants/colors.dart';
import 'core/services/session_service.dart';
import 'core/state/app_state.dart';
import 'features/auth/login_page.dart';
import 'features/shell/dashboard_shell.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // API endpoint is permanently hardcoded to production Railway server
  // (AppState.apiBaseUrl = 'https://erp-production-5697.up.railway.app/api')

  // Restore persistent user session if present
  final cachedUser = await SessionService.getUser();
  if (cachedUser != null && cachedUser['role'] != null) {
    AppState.currentUser = cachedUser;
  }

  runApp(ErpApp(initialUser: AppState.currentUser));
}

class ErpApp extends StatelessWidget {
  final Map<String, dynamic>? initialUser;
  const ErpApp({super.key, this.initialUser});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ERP Sales & Distribution',
      theme: ThemeData(
        scaffoldBackgroundColor: AppColors.background,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          primary: AppColors.primary,
          secondary: AppColors.accent,
        ),
        fontFamily: 'Inter',
        useMaterial3: true,
      ),
      home: initialUser != null ? const DashboardShell() : const LoginPage(),
      debugShowCheckedModeBanner: false,
    );
  }
}
