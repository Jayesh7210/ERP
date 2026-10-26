import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../../core/constants/colors.dart';
import '../../core/state/app_state.dart';
import '../../core/services/offline_sync_service.dart';
import 'modules/manager_dashboard_tab.dart';
import 'modules/my_team_tab.dart';
import 'modules/operations_home_tab.dart';
import 'modules/referral_requests_tab.dart';
import 'modules/settlement_hub_tab.dart';
import 'modules/fsm_stock_allocation_modal.dart';
import 'modules/fsm_warehouse_qr_modal.dart';
import 'modules/fsm_salesman_settlement_modal.dart';
import 'modules/fsm_warehouse_return_dialog.dart';

// 3. FIELD SALES MANAGER (FIELD MANAGER) — CLIENT 5-SCREEN REDESIGN
// =============================================================================

class FsmDashboard extends StatefulWidget {
  const FsmDashboard({super.key});

  @override
  State<FsmDashboard> createState() => _FsmDashboardState();
}

class _FsmDashboardState extends State<FsmDashboard> {
  // Navigation Tabs: 0: Dashboard, 1: Team, 2: Home (Center Highlight), 3: Requests, 4: Settlement
  int _activeTab = 2; // Default to Operations Home as in client mockup
  final List<int> _tabHistory = [2];
  DateTime? _lastBackPressTime;
  bool _isLoading = false;

  void _changeTab(int index) {
    if (_activeTab == index) return;
    setState(() {
      _activeTab = index;
      if (_tabHistory.isEmpty || _tabHistory.last != index) {
        _tabHistory.add(index);
      }
    });
  }

  void _handleBackNavigation() {
    if (_tabHistory.length > 1) {
      _tabHistory.removeLast();
      final prevTab = _tabHistory.last;
      setState(() {
        _activeTab = prevTab;
      });
      return;
    }

    if (_activeTab != 2) {
      setState(() {
        _activeTab = 2;
        _tabHistory.clear();
        _tabHistory.add(2);
      });
      return;
    }

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

  String get _fsmId => AppState.currentUser?['id']?.toString() ?? '';
  String get _fsmName => AppState.currentUser?['name']?.toString() ?? 'Field Sales Manager';
  String? _productId;
  String? _productName;


  // 1. Dashboard State
  Map<String, dynamic> _dashboardData = {
    'earnings': {'today_earned': 0, 'bottles_sold': 0, 'units_allocated': 0},
    'team_sales': {'bottles': 0},
    'stock_accountability': {'received': 0, 'allocated': 0, 'sold': 0, 'remaining': 0},
    'top_performers': [],
    'available_depot_stock': 0,
  };

  // 2. Team State
  Map<String, dynamic> _teamSummary = {'active': 0, 'offline': 0, 'total': 0};
  List<Map<String, dynamic>> _supervisedSalesmen = [];

  // 3. Requests State
  Map<String, dynamic> _requestsSummary = {'pending': 0, 'in_review': 0};
  String _selectedRequestFilter = 'All New';
  List<Map<String, dynamic>> _referralRequests = [];

  // 4. Settlement Hub State
  Map<String, dynamic> _settlementHub = {
    'depot_stock': 0,
    'warehouse': {
      'received': 0,
      'sold': 0,
      'returned': 0,
      'difference': 0,
      'inv_value': 0,
      'sold_value': 0,
      'status': 'settled',
    },
    'team_settlement': [],
  };

  int get _availableDepotStock => (_dashboardData['available_depot_stock'] as num?)?.toInt() ?? 0;
  double? _bottleUnitPrice;

  @override
  void initState() {
    super.initState();
    AppState.onGlobalRefresh = () => _loadAllFsmData(silent: true);
    _loadAllFsmData();
  }

  @override
  void dispose() {
    if (AppState.onGlobalRefresh != null) {
      AppState.onGlobalRefresh = null;
    }
    super.dispose();
  }

  bool _isSyncingOffline = false;

  Future<void> _loadAllFsmData({bool silent = false}) async {
    final hasExistingData = _dashboardData.isNotEmpty || _supervisedSalesmen.isNotEmpty;
    if (!silent || !hasExistingData) {
      setState(() => _isLoading = true);
    }
    await Future.wait([
      _loadDashboardMetrics(),
      _loadTeamRoster(),
      _loadReferralRequests(),
      _loadSettlementHub(),
      _loadProductPricing(),
    ]);
    if (mounted) setState(() => _isLoading = false);

    // Auto-sync pending offline transactions for FSM
    _syncPendingActions(silent: true);
  }

  Future<void> _loadProductPricing() async {
    try {
      final res = await http.get(Uri.parse('${AppState.apiBaseUrl}/products'));
      if (res.statusCode == 200) {
        final list = jsonDecode(res.body);
        if (list is List && list.isNotEmpty) {
          final first = list.first;
          final basePrice = (first['base_price'] as num?)?.toDouble();
          if (mounted) {
            setState(() {
              if (basePrice != null && basePrice > 0) _bottleUnitPrice = basePrice;
              _productId = first['id']?.toString();
              _productName = first['name']?.toString();
            });
          }
        }
      } else if (res.statusCode == 429) {
        _handleRateLimit(res);
      }
    } catch (_) {}
  }

  Future<void> _syncPendingActions({bool silent = false}) async {
    if (_isSyncingOffline) return;
    final count = await OfflineSyncService.getPendingCount(role: 'field_sales_manager');
    if (count == 0) return;

    if (mounted) setState(() => _isSyncingOffline = true);

    try {
      final res = await OfflineSyncService.syncAll(
        apiBaseUrl: AppState.apiBaseUrl,
        role: 'field_sales_manager',
      );

      if (mounted) {
        if (res.synced > 0) {
          _loadDashboardMetrics();
          _loadSettlementHub();
          _loadTeamRoster();
          if (!silent) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('✅ Synced ${res.synced} offline action${res.synced > 1 ? 's' : ''} to server!'),
                backgroundColor: Colors.green,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        } else if (!silent && res.failed > 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('⚠️ Sync failed: ${res.errors.isNotEmpty ? res.errors.first : 'Connection error'}'),
              backgroundColor: Colors.orange,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isSyncingOffline = false);
    }
  }

  Widget _buildOfflineSyncBanner() {
    return ValueListenableBuilder<int>(
      valueListenable: OfflineSyncService.pendingCountNotifier,
      builder: (context, pendingCount, _) {
        if (pendingCount == 0) return const SizedBox.shrink();
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF3CD),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFFFEEBA)),
            boxShadow: [
              BoxShadow(
                color: Colors.amber.withValues(alpha: 0.12),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              const Icon(Icons.cloud_upload_outlined, color: Color(0xFFB45309), size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$pendingCount Offline Action${pendingCount > 1 ? 's' : ''} Stored',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF451A03)),
                    ),
                    const Text(
                      'Saved on device. Tap to sync to server.',
                      style: TextStyle(fontSize: 11, color: Color(0xFF78350F)),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: _isSyncingOffline ? null : () => _syncPendingActions(silent: false),
                icon: _isSyncingOffline
                    ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.sync, size: 14),
                label: Text(
                  _isSyncingOffline ? 'Syncing...' : 'Sync Now',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFB45309),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  DateTime? _lastRateLimitAlert;
  void _handleRateLimit(http.Response res) {
    if (res.statusCode == 429 && mounted) {
      final now = DateTime.now();
      if (_lastRateLimitAlert != null && now.difference(_lastRateLimitAlert!).inSeconds < 3) {
        return;
      }
      _lastRateLimitAlert = now;
      String msg = 'Field Manager rate limit reached. Please wait a moment.';
      try {
        final body = jsonDecode(res.body);
        if (body is Map && body['error'] != null) {
          msg = body['error'].toString();
        }
      } catch (_) {}
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.speed, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Expanded(child: Text(msg)),
            ],
          ),
          backgroundColor: Colors.amber.shade900,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  Future<void> _loadDashboardMetrics() async {
    try {
      final res = await http.get(Uri.parse('${AppState.apiBaseUrl}/fsm/dashboard/$_fsmId'));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (mounted) {
          setState(() {
            _dashboardData = Map<String, dynamic>.from(data);
          });
        }
      } else if (res.statusCode == 429) {
        _handleRateLimit(res);
      }
    } catch (_) {}
  }

  Future<void> _loadTeamRoster() async {
    try {
      final res = await http.get(Uri.parse('${AppState.apiBaseUrl}/fsm/team/$_fsmId'));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (mounted) {
          setState(() {
            if (data['summary'] != null) {
              _teamSummary = Map<String, dynamic>.from(data['summary']);
            }
            if (data['salesmen'] != null) {
              _supervisedSalesmen = List<Map<String, dynamic>>.from(data['salesmen']);
            }
          });
        }
      } else if (res.statusCode == 429) {
        _handleRateLimit(res);
      }
    } catch (_) {}
  }

  Future<void> _loadReferralRequests() async {
    try {
      final res = await http.get(Uri.parse('${AppState.apiBaseUrl}/fsm/referral-requests/$_fsmId'));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (mounted) {
          setState(() {
            if (data['summary'] != null) {
              _requestsSummary = Map<String, dynamic>.from(data['summary']);
            }
            if (data['requests'] != null) {
              _referralRequests = List<Map<String, dynamic>>.from(data['requests']);
            }
          });
        }
      } else if (res.statusCode == 429) {
        _handleRateLimit(res);
      }
    } catch (_) {}
  }

  Future<void> _loadSettlementHub() async {
    try {
      final res = await http.get(Uri.parse('${AppState.apiBaseUrl}/fsm/settlement/$_fsmId'));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (mounted) {
          setState(() {
            _settlementHub = Map<String, dynamic>.from(data);
          });
        }
      } else if (res.statusCode == 429) {
        _handleRateLimit(res);
      }
    } catch (_) {}
  }

  // --- ACTIONS & MODALS ---

  void _openStockAllocationModal() {
    FsmStockAllocationModal.open(
      context: context,
      fsmId: _fsmId,
      fsmName: _fsmName,
      availableDepotStock: _availableDepotStock,
      supervisedSalesmen: _supervisedSalesmen,
      bottleUnitPrice: _bottleUnitPrice,
      productId: _productId,
      productName: _productName,
      onStockUpdated: _loadAllFsmData,
    );
  }

  void _handleScanWarehouseQR() {
    FsmWarehouseQrModal.open(
      context: context,
      fsmId: _fsmId,
      onReceiptConfirmed: _loadAllFsmData,
    );
  }

  void _openSalesmanSettlementScannerSheet([Map<String, dynamic>? initialSettlement]) {
    FsmSalesmanSettlementModal.open(
      context: context,
      fsmId: _fsmId,
      settlementHub: _settlementHub,
      initialSettlement: initialSettlement,
      onSettlementApproved: (returnedQty, salesmanName, soldQty, totalCollected) {
        setState(() {
          _settlementHub['depot_stock'] = ((_settlementHub['depot_stock'] ?? 0) as int) + returnedQty;
          _dashboardData['available_depot_stock'] = ((_dashboardData['available_depot_stock'] ?? 0) as int) + returnedQty;
        });
        _loadAllFsmData();
      },
    );
  }

  void _handleWarehouseReturnQR() {
    FsmWarehouseReturnDialog.show(
      context: context,
      fsmId: _fsmId,
      availableDepotStock: _availableDepotStock,
    );
  }

  Future<void> _handleReferralAction(String reqId, String action) async {
    try {
      final res = await http.put(
        Uri.parse('${AppState.apiBaseUrl}/fsm/referral-requests/$reqId'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'action': action}),
      );

      if (res.statusCode == 429) {
        _handleRateLimit(res);
        return;
      }

      final isApprove = action == 'approve';
      final msg = isApprove ? 'Candidate approved successfully!' : 'Candidate rejected.';

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: isApprove ? ClientColors.success : Colors.red.shade700,
            content: Text(msg),
          ),
        );
        setState(() {
          for (var r in _referralRequests) {
            if (r['id'] == reqId) {
              r['status'] = isApprove ? 'approved' : 'rejected';
            }
          }
        });
        _loadReferralRequests();
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          for (var r in _referralRequests) {
            if (r['id'] == reqId) {
              r['status'] = action == 'approve' ? 'approved' : 'rejected';
            }
          }
        });
      }
    }
  }

  Future<void> _handleSendReminder(String salesmanId, String name) async {
    try {
      final res = await http.post(Uri.parse('${AppState.apiBaseUrl}/fsm/settlement-remind/$salesmanId'));
      if (res.statusCode == 429) {
        _handleRateLimit(res);
        return;
      }
    } catch (_) {}

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: ClientColors.primary,
          content: Text('Settlement payment reminder sent to $name.'),
        ),
      );
    }
  }

  // --- BUILD ENTRY POINT ---

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, dynamic result) {
        if (didPop) return;
        _handleBackNavigation();
      },
      child: Scaffold(
        backgroundColor: ClientColors.creamBg,
        appBar: _buildTopAppBar(),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator(color: ClientColors.primary))
            : Column(
                children: [
                  _buildOfflineSyncBanner(),
                  Expanded(
                    child: IndexedStack(
                      index: _activeTab,
                      children: [
                        ManagerDashboardTab(
                          dashboardData: _dashboardData,
                          fsmName: _fsmName,
                          onRefresh: () => _loadAllFsmData(silent: true),
                          onViewAllTeam: () => _changeTab(1),
                          onScanWarehouseQR: _handleScanWarehouseQR,
                        ),
                        MyTeamTab(
                          teamSummary: _teamSummary,
                          supervisedSalesmen: _supervisedSalesmen,
                          onAllocateStock: _openStockAllocationModal,
                          onRefresh: () => _loadAllFsmData(silent: true),
                        ),
                        OperationsHomeTab(
                          availableDepotStock: _availableDepotStock,
                          pendingRequestsCount: (_requestsSummary['pending'] as num?)?.toInt() ?? 0,
                          onAllocateStock: _openStockAllocationModal,
                          onNavigateTab: _changeTab,
                          onScanWarehouseQR: _handleScanWarehouseQR,
                          onRefresh: () => _loadAllFsmData(silent: true),
                        ),
                        ReferralRequestsTab(
                          requestsSummary: _requestsSummary,
                          referralRequests: _referralRequests,
                          selectedFilter: _selectedRequestFilter,
                          onFilterSelected: (filter) => setState(() => _selectedRequestFilter = filter),
                          onReferralAction: _handleReferralAction,
                          onRefresh: () => _loadAllFsmData(silent: true),
                        ),
                        SettlementHubTab(
                          settlementHub: _settlementHub,
                          onScanSalesmanSettlement: () => _openSalesmanSettlementScannerSheet(),
                          onReviewSettlement: (st) => _openSalesmanSettlementScannerSheet(st),
                          onWarehouseReturnQR: _handleWarehouseReturnQR,
                          onSendReminder: _handleSendReminder,
                          onRefresh: () => _loadAllFsmData(silent: true),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
        bottomNavigationBar: _buildBottomNav(),
      ),
    );
  }

  PreferredSizeWidget _buildTopAppBar() {
    String titleText = 'Dashboard';
    if (_activeTab == 1) titleText = 'My Team';
    if (_activeTab == 2) titleText = 'Operations';
    if (_activeTab == 3) titleText = 'Referrals';
    if (_activeTab == 4) titleText = 'Settlement';

    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      automaticallyImplyLeading: false,
      leading: _activeTab != 2
          ? IconButton(
              icon: const Icon(Icons.arrow_back, color: ClientColors.textDark),
              onPressed: _handleBackNavigation,
              tooltip: 'Back',
            )
          : null,
      titleSpacing: _activeTab != 2 ? 0 : 16,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'FM',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF92400E)),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                titleText,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: ClientColors.textDark,
                ),
              ),
            ],
          ),
          Text(
            _fsmName,
            style: const TextStyle(fontSize: 11, color: ClientColors.textMuted),
          ),
        ],
      ),
      actions: const [],
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(top: BorderSide(color: ClientColors.border)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        child: SizedBox(
          height: 60,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _navItem(0, Icons.dashboard_outlined, Icons.dashboard, 'Dashboard'),
              _navItem(1, Icons.people_outline, Icons.people, 'Team'),
              _centerNavButton(),
              _navItem(3, Icons.person_add_alt_1_outlined, Icons.person_add, 'Requests'),
              _navItem(4, Icons.account_balance_wallet_outlined, Icons.account_balance_wallet, 'Settlement'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navItem(int index, IconData iconOutlined, IconData iconFilled, String label) {
    final bool isSel = _activeTab == index;
    return InkWell(
      onTap: () => _changeTab(index),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSel ? iconFilled : iconOutlined,
              color: isSel ? ClientColors.primary : ClientColors.textMuted,
              size: 22,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                color: isSel ? ClientColors.primary : ClientColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _centerNavButton() {
    final bool isSel = _activeTab == 2;
    return InkWell(
      onTap: () => _changeTab(2),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isSel ? ClientColors.primary : ClientColors.alertBg,
              shape: BoxShape.circle,
              border: Border.all(color: ClientColors.primary, width: isSel ? 0 : 1.5),
              boxShadow: [
                if (isSel)
                  BoxShadow(
                    color: ClientColors.primary.withValues(alpha: 0.35),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  )
              ],
            ),
            child: Icon(
              Icons.grid_view_rounded,
              color: isSel ? Colors.white : ClientColors.primary,
              size: 20,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Ops',
            style: TextStyle(
              fontSize: 10,
              fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
              color: isSel ? ClientColors.primary : ClientColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

extension SalesFilterExtension on List<Map<String, dynamic>> {
  List<Map<String, dynamic>> filterSalesBySeller(String sellerId) {
    return where((s) => s['salesman_id'] == sellerId).toList();
  }
}
