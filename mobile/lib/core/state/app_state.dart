// Simple App State Manager for Demo/Testing
class AppState {
  static const String apiBaseUrl = 'https://erp-production-5697.up.railway.app/api';
  static Map<String, dynamic>? currentUser;

  static bool get isSuperAdmin => currentUser?['role'] == 'super_admin';
  static bool get isStoreAdmin => currentUser?['role'] == 'store_admin';
  static bool get isFsm => currentUser?['role'] == 'field_sales_manager';
  static bool get isSalesman => currentUser?['role'] == 'salesman';
}
