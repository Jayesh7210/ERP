import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants/colors.dart';
import '../../core/services/session_service.dart';
import '../../core/state/app_state.dart';
import '../auth/login_page.dart';
import '../super_admin/super_admin_dashboard.dart';
import '../super_admin/workforce_requests_page.dart';
import '../super_admin/stock_approvals_page.dart';
import '../store_admin/store_admin_dashboard.dart';
import '../fsm/fsm_dashboard.dart';
import '../salesman/salesman_dashboard.dart';

// DASHBOARD CONTAINER
class DashboardShell extends StatefulWidget {
  const DashboardShell({super.key});

  @override
  State<DashboardShell> createState() => _DashboardShellState();
}

class _DashboardShellState extends State<DashboardShell> {
  int _currentIndex = 0;
  final List<int> _superAdminTabHistory = [0];
  DateTime? _lastBackPressTime;

  void _changeSuperAdminTab(int index) {
    if (_currentIndex == index) return;
    setState(() {
      _currentIndex = index;
      if (_superAdminTabHistory.isEmpty || _superAdminTabHistory.last != index) {
        _superAdminTabHistory.add(index);
      }
    });
  }

  void _handleSuperAdminBackNavigation() {
    if (_superAdminTabHistory.length > 1) {
      _superAdminTabHistory.removeLast();
      final prev = _superAdminTabHistory.last;
      setState(() {
        _currentIndex = prev;
      });
      return;
    }

    if (_currentIndex != 0) {
      setState(() {
        _currentIndex = 0;
        _superAdminTabHistory.clear();
        _superAdminTabHistory.add(0);
      });
      return;
    }

    // Double-back to exit on root
    final now = DateTime.now();
    if (_lastBackPressTime == null || now.difference(_lastBackPressTime!) > const Duration(seconds: 2)) {
      _lastBackPressTime = now;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Press back again to exit'),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    SystemNavigator.pop();
  }

  List<Widget> _getPages() {
    if (AppState.isSuperAdmin) {
      return [
        const SuperAdminDashboard(),
        const WorkforceRequestsPage(),
        const StockApprovalsPage(),
      ];
    } else if (AppState.isStoreAdmin) {
      return [
        const StoreAdminDashboard(),
      ];
    } else if (AppState.isFsm) {
      return [
        const FsmDashboard(),
      ];
    } else {
      return [
        const SalesmanDashboard(),
      ];
    }
  }

  List<BottomNavigationBarItem> _getNavItems() {
    if (AppState.isSuperAdmin) {
      return const [
        BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Dashboard'),
        BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Workforce'),
        BottomNavigationBarItem(icon: Icon(Icons.fact_check), label: 'Stock Inward'),
      ];
    } else if (AppState.isStoreAdmin) {
      return const [];
    } else if (AppState.isFsm) {
      return const [];
    } else {
      return const [];
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = _getPages();
    final navItems = _getNavItems();

    final scaffold = Scaffold(
      appBar: AppBar(
        leading: (AppState.isSuperAdmin && _currentIndex != 0)
            ? IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: _handleSuperAdminBackNavigation,
                tooltip: 'Back',
              )
            : null,
        title: Text(
          '${AppState.currentUser?['name']} (${AppState.currentUser?['role'].toString().replaceAll('_', ' ').toUpperCase()})',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: AppColors.primary,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            tooltip: 'Logout',
            onPressed: () async {
              await SessionService.clearSession();
              AppState.currentUser = null;
              if (context.mounted) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginPage()),
                );
              }
            },
          )
        ],
      ),
      body: pages[_currentIndex],
      bottomNavigationBar: navItems.length > 1
          ? BottomNavigationBar(
              currentIndex: _currentIndex,
              selectedItemColor: AppColors.accent,
              unselectedItemColor: AppColors.textSecondary,
              backgroundColor: Colors.white,
              type: BottomNavigationBarType.fixed,
              onTap: _changeSuperAdminTab,
              items: navItems,
            )
          : null,
    );

    if (AppState.isSuperAdmin) {
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (bool didPop, dynamic result) {
          if (didPop) return;
          _handleSuperAdminBackNavigation();
        },
        child: scaffold,
      );
    }

    return scaffold;
  }
}
