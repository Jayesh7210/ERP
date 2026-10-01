import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile/main.dart';
import 'package:mobile/core/state/app_state.dart';
import 'package:mobile/core/services/session_service.dart';
import 'package:mobile/features/auth/login_page.dart';
import 'package:mobile/features/shell/dashboard_shell.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppState.currentUser = null;
  });

  test('SessionService saves, retrieves, and clears user session correctly', () async {
    expect(await SessionService.getUser(), isNull);
    expect(await SessionService.getToken(), isNull);

    final mockUser = {
      'id': 'test_user_1',
      'name': 'Salesman John',
      'role': 'salesman',
      'email': 'sales@erp.com'
    };

    await SessionService.saveUser(mockUser, token: 'mock_jwt_token_123');

    final retrievedUser = await SessionService.getUser();
    expect(retrievedUser, isNotNull);
    expect(retrievedUser!['id'], 'test_user_1');
    expect(retrievedUser['name'], 'Salesman John');
    expect(retrievedUser['role'], 'salesman');

    final retrievedToken = await SessionService.getToken();
    expect(retrievedToken, 'mock_jwt_token_123');

    await SessionService.clearSession();
    expect(await SessionService.getUser(), isNull);
    expect(await SessionService.getToken(), isNull);
  });

  test('SessionService saves and retrieves custom API base URL', () async {
    expect(await SessionService.getApiBaseUrl(), isNull);

    await SessionService.saveApiBaseUrl('http://192.168.1.100:5000/api');
    final savedUrl = await SessionService.getApiBaseUrl();
    expect(savedUrl, 'http://192.168.1.100:5000/api');
  });

  testWidgets('App opens LoginPage when no session is cached', (WidgetTester tester) async {
    await tester.pumpWidget(const ErpApp(initialUser: null));
    expect(find.byType(LoginPage), findsOneWidget);
    expect(find.byType(DashboardShell), findsNothing);
  });

  testWidgets('App auto-logs in and opens DashboardShell when session is cached', (WidgetTester tester) async {
    final cachedUser = {
      'id': 'u1',
      'name': 'Super Admin',
      'role': 'super_admin',
      'email': 'admin@erp.com'
    };
    AppState.currentUser = cachedUser;

    await tester.pumpWidget(ErpApp(initialUser: cachedUser));
    await tester.pumpAndSettle();

    expect(find.byType(DashboardShell), findsOneWidget);
    expect(find.byType(LoginPage), findsNothing);
  });
}
