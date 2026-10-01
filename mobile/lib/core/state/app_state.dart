// Simple App State Manager for Demo/Testing
class AppState {
  static String apiBaseUrl = 'http://localhost:5000/api';
  static Map<String, dynamic>? currentUser;

  static bool get isSuperAdmin => currentUser?['role'] == 'super_admin';
  static bool get isStoreAdmin => currentUser?['role'] == 'store_admin';
  static bool get isFsm => currentUser?['role'] == 'field_sales_manager';
  static bool get isSalesman => currentUser?['role'] == 'salesman';
}
