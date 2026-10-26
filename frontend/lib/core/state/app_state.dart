import 'package:flutter/foundation.dart';

// Simple App State Manager for Demo/Testing
class AppState {
  static String apiBaseUrl = kIsWeb
      ? 'http://localhost:5001/api'
      : 'https://erp-production-5697.up.railway.app/api';
  static Map<String, dynamic>? currentUser;

  static bool get isSuperAdmin => currentUser?['role'] == 'super_admin';
  static bool get isStoreAdmin => currentUser?['role'] == 'store_admin';
  static bool get isFsm => currentUser?['role'] == 'field_sales_manager';
  static bool get isSalesman => currentUser?['role'] == 'salesman';

  /// Global refresh callback registered by active dashboards (Salesman, FSM, Store Admin, Super Admin)
  static Future<void> Function()? onGlobalRefresh;

  /// Trigger global refresh across active dashboard
  static Future<void> triggerRefresh() async {
    if (onGlobalRefresh != null) {
      await onGlobalRefresh!();
    }
  }
}
