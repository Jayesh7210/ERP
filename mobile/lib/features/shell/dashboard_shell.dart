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
  List<Map<String, dynamic>> _notifications = [];

  @override
  void initState() {
    super.initState();
    _initNotifications();
  }

  void _initNotifications() {
    if (AppState.isSuperAdmin) {
      _notifications = [
        {
          'id': '1',
          'title': 'Workforce Registration Requests',
          'body': 'New staff registrations & KYC documents pending review.',
          'time': '10m ago',
          'icon': Icons.badge_outlined,
          'color': Colors.blue,
          'is_read': false,
        },
        {
          'id': '2',
          'title': 'Central Warehouse Stock Movement',
          'body': 'Inward stock delivery verified for central hub distribution.',
          'time': '1h ago',
          'icon': Icons.inventory_2_outlined,
          'color': Colors.indigo,
          'is_read': false,
        },
        {
          'id': '3',
          'title': 'Daily Settlement Reconciliation',
          'body': 'Consolidated day collection report ready for audit review.',
          'time': '3h ago',
          'icon': Icons.account_balance_wallet_outlined,
          'color': Colors.teal,
          'is_read': false,
        },
      ];
    } else if (AppState.isFsm) {
      _notifications = [
        {
          'id': '1',
          'title': 'Stock Allocation Ready',
          'body': 'Morning delivery arrived at warehouse. Allocate bottles to salesmen.',
          'time': '15m ago',
          'icon': Icons.local_shipping_outlined,
          'color': Colors.orange,
          'is_read': false,
        },
        {
          'id': '2',
          'title': 'Salesman Settlement Submitted',
          'body': 'Salesman John submitted daily collection tallies for verification.',
          'time': '45m ago',
          'icon': Icons.receipt_long_outlined,
          'color': Colors.green,
          'is_read': false,
        },
        {
          'id': '3',
          'title': 'Team Field Attendance',
          'body': 'All active route salesmen have logged attendance for today.',
          'time': '2h ago',
          'icon': Icons.people_outline,
          'color': Colors.blue,
          'is_read': false,
        },
      ];
    } else if (AppState.isSalesman) {
      _notifications = [
        {
          'id': '1',
          'title': 'Stock Dispatched to You',
          'body': 'Manager allocated 20 bottles to your daily field inventory.',
          'time': '20m ago',
          'icon': Icons.liquor_outlined,
          'color': Colors.deepOrange,
          'is_read': false,
        },
        {
          'id': '2',
          'title': 'Daily Settlement Reminder',
          'body': 'Record today\'s bottle sales and submit collection tally before 8 PM.',
          'time': '1h ago',
          'icon': Icons.payments_outlined,
          'color': Colors.teal,
          'is_read': false,
        },
        {
          'id': '3',
          'title': 'Referral Incentive Credited',
          'body': 'Bonus commission credited to your wallet for registered salesman.',
          'time': '4h ago',
          'icon': Icons.card_giftcard_outlined,
          'color': Colors.purple,
          'is_read': false,
        },
      ];
    } else if (AppState.isStoreAdmin) {
      _notifications = [
        {
          'id': '1',
          'title': 'Stock Inward Awaiting Verification',
          'body': 'Direct factory delivery batch #INW-204 arrived at gate.',
          'time': '30m ago',
          'icon': Icons.fact_check_outlined,
          'color': Colors.blue,
          'is_read': false,
        },
        {
          'id': '2',
          'title': 'Low Stock Alert',
          'body': 'Inventory for SKU 500ml is running below critical threshold.',
          'time': '2h ago',
          'icon': Icons.warning_amber_rounded,
          'color': Colors.red,
          'is_read': false,
        },
        {
          'id': '3',
          'title': 'Audit Log Generated',
          'body': 'Weekly inward receipts ledger archived for warehouse.',
          'time': '5h ago',
          'icon': Icons.history_edu_outlined,
          'color': Colors.green,
          'is_read': false,
        },
      ];
    } else {
      _notifications = [
        {
          'id': '1',
          'title': 'Welcome to Distribution ERP',
          'body': 'Your operations account is active and connected.',
          'time': 'Just now',
          'icon': Icons.notifications_active_outlined,
          'color': Colors.blue,
          'is_read': false,
        },
        {
          'id': '2',
          'title': 'Security Verification',
          'body': 'Active session established from mobile device.',
          'time': '1h ago',
          'icon': Icons.shield_outlined,
          'color': Colors.green,
          'is_read': false,
        },
      ];
    }
  }

  int get _unreadNotificationCount =>
      _notifications.where((n) => n['is_read'] == false).length;

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
          // Notification Bell with unread badge counter
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined, color: Colors.white),
                tooltip: 'Notifications',
                onPressed: () => _showNotificationsModal(context),
              ),
              if (_unreadNotificationCount > 0)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.redAccent,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                    child: Text(
                      '$_unreadNotificationCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        height: 1,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white),
            tooltip: 'Settings',
            onPressed: () => _showSettingsModal(context),
          ),
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

  void _showSettingsModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalCtx) {
        final user = AppState.currentUser;
        final name = user?['name']?.toString() ?? 'User';
        final emailOrPhone = user?['email']?.toString() ?? user?['phone']?.toString() ?? '';
        final role = user?['role']?.toString().replaceAll('_', ' ').toUpperCase() ?? 'STAFF';
        final initial = name.isNotEmpty ? name.substring(0, 1).toUpperCase() : 'U';

        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.settings, color: AppColors.primary, size: 22),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Settings',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: AppColors.textSecondary),
                      onPressed: () => Navigator.pop(modalCtx),
                      tooltip: 'Close',
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // User Info Summary Card
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: AppColors.primary,
                        child: Text(
                          initial,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            if (emailOrPhone.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                emailOrPhone,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          role,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Settings Section Header
                const Text(
                  'ACCOUNT & PREFERENCES',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 10),

                // Notifications Option inside Settings
                InkWell(
                  onTap: () {
                    Navigator.pop(modalCtx);
                    _showNotificationsModal(context);
                  },
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.notifications_active_outlined, color: Colors.blue, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Text(
                                    'Notifications & Alerts',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue,
                                    ),
                                  ),
                                  if (_unreadNotificationCount > 0) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                      decoration: BoxDecoration(
                                        color: Colors.redAccent,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        '$_unreadNotificationCount',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 2),
                              const Text(
                                'View role updates, activity & announcements',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.blueGrey,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right, color: Colors.blue, size: 20),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Logout Button Option
                InkWell(
                  onTap: () {
                    Navigator.pop(modalCtx);
                    _confirmLogout(context);
                  },
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.red.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.logout_rounded, color: Colors.red, size: 20),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Log Out',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Sign out of your active session',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.redAccent,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right, color: Colors.red, size: 20),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),
                Center(
                  child: Text(
                    'More settings options coming soon • v1.0.0',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade400,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showNotificationsModal(BuildContext context) {
    if (_notifications.isEmpty) {
      _initNotifications();
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalCtx) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            final unreadCount = _unreadNotificationCount;
            final roleName = AppState.currentUser?['role']?.toString().replaceAll('_', ' ').toUpperCase() ?? 'YOUR ROLE';

            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.75,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 12),
                  // Drag Handle
                  Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Header
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.notifications_active_rounded, color: AppColors.primary, size: 18),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Wrap(
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: 6,
                                children: [
                                  const Text(
                                    'Notifications',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  if (unreadCount > 0)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                      decoration: BoxDecoration(
                                        color: Colors.redAccent,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        '$unreadCount new',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              Text(
                                'Updates for $roleName',
                                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        if (unreadCount > 0)
                          TextButton(
                            onPressed: () {
                              setState(() {
                                for (var n in _notifications) {
                                  n['is_read'] = true;
                                }
                              });
                              setModalState(() {});
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('All notifications marked as read'),
                                  duration: Duration(seconds: 2),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            },
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: const Text(
                              'Mark read',
                              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppColors.primary),
                            ),
                          ),
                        IconButton(
                          icon: const Icon(Icons.close, color: AppColors.textSecondary, size: 18),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                          onPressed: () => Navigator.pop(modalCtx),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 20),

                  // Notifications List
                  Flexible(
                    child: _notifications.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.symmetric(vertical: 40),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.notifications_none_rounded, size: 48, color: Colors.grey.shade400),
                                const SizedBox(height: 12),
                                const Text(
                                  'No Notifications',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'You\'re all caught up with your tasks!',
                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            shrinkWrap: true,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                            itemCount: _notifications.length,
                            separatorBuilder: (ctx, idx) => const SizedBox(height: 10),
                            itemBuilder: (ctx, idx) {
                              final item = _notifications[idx];
                              final isRead = item['is_read'] == true;
                              final icon = item['icon'] as IconData? ?? Icons.notifications;
                              final color = item['color'] as Color? ?? AppColors.primary;

                              return InkWell(
                                onTap: () {
                                  if (!isRead) {
                                    setState(() {
                                      item['is_read'] = true;
                                    });
                                    setModalState(() {});
                                  }
                                },
                                borderRadius: BorderRadius.circular(14),
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: isRead ? Colors.grey.shade50 : color.withValues(alpha: 0.05),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: isRead ? Colors.grey.shade200 : color.withValues(alpha: 0.3),
                                      width: isRead ? 1 : 1.2,
                                    ),
                                  ),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: color.withValues(alpha: 0.12),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(icon, color: color, size: 18),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    item['title'] ?? '',
                                                    style: TextStyle(
                                                      fontSize: 13.5,
                                                      fontWeight: isRead ? FontWeight.w600 : FontWeight.bold,
                                                      color: AppColors.textPrimary,
                                                    ),
                                                  ),
                                                ),
                                                if (!isRead)
                                                  Container(
                                                    width: 7,
                                                    height: 7,
                                                    margin: const EdgeInsets.only(left: 6),
                                                    decoration: const BoxDecoration(
                                                      color: Colors.blueAccent,
                                                      shape: BoxShape.circle,
                                                    ),
                                                  ),
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              item['body'] ?? '',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: isRead ? AppColors.textSecondary : Colors.black87,
                                                height: 1.3,
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                            Row(
                                              children: [
                                                Icon(Icons.access_time_rounded, size: 11, color: Colors.grey.shade500),
                                                const SizedBox(width: 4),
                                                Text(
                                                  item['time'] ?? '',
                                                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),

                  // Bottom footer
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      'Tap any alert to mark as read • Realtime operations sync',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(
          children: [
            Icon(Icons.logout_rounded, color: Colors.red, size: 24),
            SizedBox(width: 10),
            Text(
              'Confirm Logout',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: const Text(
          'Are you sure want to logout?',
          style: TextStyle(fontSize: 14, color: AppColors.textPrimary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            onPressed: () async {
              Navigator.pop(dialogCtx);
              await SessionService.clearSession();
              AppState.currentUser = null;
              if (context.mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginPage()),
                  (route) => false,
                );
              }
            },
            child: const Text('Logout', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
