import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../../core/constants/colors.dart';
import '../../core/state/app_state.dart';
import '../../core/services/offline_sync_service.dart';
import 'modules/inventory_intake_tab.dart';
import 'modules/fsm_distribution_tab.dart';
import 'modules/direct_retail_sale_tab.dart';
import 'modules/distributor_sale_tab.dart';
import 'modules/store_reports_tab.dart';

// 2. STORE ADMIN DASHBOARD (WAREHOUSE ADMIN)
class StoreAdminDashboard extends StatefulWidget {
  const StoreAdminDashboard({super.key});

  @override
  State<StoreAdminDashboard> createState() => _StoreAdminDashboardState();
}

class _StoreAdminDashboardState extends State<StoreAdminDashboard> {
  int _activeTab = 0; // 0: Inventory & Intake, 1: FSM Distribution, 2: Retail Sales, 3: Distributor Sales, 4: Reports & History
  final List<int> _tabHistory = [0];
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

    if (_activeTab != 0) {
      setState(() {
        _activeTab = 0;
        _tabHistory.clear();
        _tabHistory.add(0);
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

  // Data Stores (Warehouse Scoped)
  List<Map<String, dynamic>> _warehouseStocks = [];
  List<Map<String, dynamic>> _alerts = [];
  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _prices = [];
  List<Map<String, dynamic>> _intakes = [];
  List<Map<String, dynamic>> _transfers = [];
  List<Map<String, dynamic>> _fsmUsers = [];
  List<Map<String, dynamic>> _retailCustomers = [];
  List<Map<String, dynamic>> _distributors = [];
  List<Map<String, dynamic>> _sales = [];
  double _dispatchEarnings = 0.0;
  int _dispatchedUnits = 0;

  String get _warehouseId => AppState.currentUser?['warehouse_id'] ?? 'w1';

  @override
  void initState() {
    super.initState();
    _loadAllStoreData();
  }

  bool _isSyncingOffline = false;

  Future<void> _loadAllStoreData() async {
    setState(() => _isLoading = true);
    await Future.wait([
      _loadProductsAndPrices(),
      _loadWarehouseStock(),
      _loadLowStockAlerts(),
      _loadIntakeHistory(),
      _loadTransfers(),
      _loadFsmUsers(),
      _loadCustomers(),
      _loadSales(),
      _loadEarnings(),
    ]);
    if (mounted) setState(() => _isLoading = false);

    // Auto-sync pending offline transactions for store_admin
    _syncPendingActions(silent: true);
  }

  Future<void> _syncPendingActions({bool silent = false}) async {
    if (_isSyncingOffline) return;
    final count = await OfflineSyncService.getPendingCount(role: 'store_admin');
    if (count == 0) return;

    if (mounted) setState(() => _isSyncingOffline = true);

    try {
      final res = await OfflineSyncService.syncAll(
        apiBaseUrl: AppState.apiBaseUrl,
        role: 'store_admin',
      );

      if (mounted) {
        if (res.synced > 0) {
          _loadWarehouseStock();
          _loadSales();
          _loadIntakeHistory();
          _loadTransfers();
          if (!silent) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('✅ Synced ${res.synced} offline transaction${res.synced > 1 ? 's' : ''} to server!'),
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

  Future<void> _loadProductsAndPrices() async {
    try {
      final resP = await http.get(Uri.parse('${AppState.apiBaseUrl}/products'));
      if (resP.statusCode == 200) {
        _products = List<Map<String, dynamic>>.from(jsonDecode(resP.body));
      }
      final resPr = await http.get(Uri.parse('${AppState.apiBaseUrl}/products/prices'));
      if (resPr.statusCode == 200) {
        _prices = List<Map<String, dynamic>>.from(jsonDecode(resPr.body));
      }
    } catch (_) {
      _products = [];
      _prices = [];
    }
  }

  Future<void> _loadWarehouseStock() async {
    try {
      final res = await http.get(Uri.parse('${AppState.apiBaseUrl}/stock/$_warehouseId'));
      if (res.statusCode == 200) {
        _warehouseStocks = List<Map<String, dynamic>>.from(jsonDecode(res.body));
      }
    } catch (_) {
      _warehouseStocks = [];
    }
  }

  Future<void> _loadEarnings() async {
    try {
      final userId = AppState.currentUser?['id'] ?? 'u2';
      final res = await http.get(Uri.parse('${AppState.apiBaseUrl}/store-admin/earnings/$userId'));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        _dispatchEarnings = (data['today_earned'] as num?)?.toDouble() ?? 0.0;
        _dispatchedUnits = (data['units_dispatched'] as num?)?.toInt() ?? 0;
      }
    } catch (_) {
      _dispatchEarnings = 0.0;
      _dispatchedUnits = 0;
    }
  }

  Future<void> _loadLowStockAlerts() async {
    try {
      final res = await http.get(Uri.parse('${AppState.apiBaseUrl}/stock/alerts?warehouse_id=$_warehouseId'));
      if (res.statusCode == 200) {
        _alerts = List<Map<String, dynamic>>.from(jsonDecode(res.body));
      }
    } catch (_) {
      _alerts = [];
    }
  }

  Future<void> _loadIntakeHistory() async {
    try {
      final res = await http.get(Uri.parse('${AppState.apiBaseUrl}/stock/intakes?warehouse_id=$_warehouseId'));
      if (res.statusCode == 200) {
        _intakes = List<Map<String, dynamic>>.from(jsonDecode(res.body));
      }
    } catch (_) {
      _intakes = [];
    }
  }

  Future<void> _loadTransfers() async {
    try {
      final res = await http.get(Uri.parse('${AppState.apiBaseUrl}/stock/transfers?from_id=$_warehouseId'));
      if (res.statusCode == 200) {
        _transfers = List<Map<String, dynamic>>.from(jsonDecode(res.body));
      }
    } catch (_) {
      _transfers = [];
    }
  }

  Future<void> _loadFsmUsers() async {
    try {
      final res = await http.get(Uri.parse('${AppState.apiBaseUrl}/users?role=field_sales_manager'));
      if (res.statusCode == 200) {
        final all = List<Map<String, dynamic>>.from(jsonDecode(res.body));
        _fsmUsers = all.where((u) => u['role'] == 'field_sales_manager').toList();
      }
    } catch (_) {
      _fsmUsers = [];
    }
  }

  Future<void> _loadCustomers() async {
    try {
      final resR = await http.get(Uri.parse('${AppState.apiBaseUrl}/customers?customer_type=retail'));
      if (resR.statusCode == 200) {
        _retailCustomers = List<Map<String, dynamic>>.from(jsonDecode(resR.body));
      }
      final resD = await http.get(Uri.parse('${AppState.apiBaseUrl}/customers?customer_type=distributor'));
      if (resD.statusCode == 200) {
        _distributors = List<Map<String, dynamic>>.from(jsonDecode(resD.body));
      }
    } catch (_) {
      _retailCustomers = [];
      _distributors = [];
    }
  }

  Future<void> _loadSales() async {
    try {
      final res = await http.get(Uri.parse('${AppState.apiBaseUrl}/sales/report?warehouse_id=$_warehouseId'));
      if (res.statusCode == 200) {
        _sales = List<Map<String, dynamic>>.from(jsonDecode(res.body));
      }
    } catch (_) {
      _sales = [];
    }
  }

  int _getStockForProduct(String productId) {
    final entry = _warehouseStocks.firstWhere(
      (s) => s['product_id'] == productId,
      orElse: () => {'quantity': 0},
    );
    return entry['quantity'] is int ? entry['quantity'] : int.tryParse(entry['quantity'].toString()) ?? 0;
  }

  double _getRetailPriceForProduct(String productId) {
    final prod = _products.firstWhere((p) => p['id'] == productId, orElse: () => {});
    return (prod['base_price'] is num ? (prod['base_price'] as num).toDouble() : 500.0);
  }

  double _getDistributorPriceForProduct(String productId) {
    final pr = _prices.firstWhere(
      (p) => p['product_id'] == productId && p['role'] == 'distributor',
      orElse: () => {},
    );
    if (pr.isNotEmpty && pr['price'] != null) {
      return (pr['price'] as num).toDouble();
    }
    // Fallback: 20% discount on base price
    final base = _getRetailPriceForProduct(productId);
    return base * 0.80;
  }

  String _getProductName(String productId) {
    final p = _products.firstWhere((item) => item['id'] == productId, orElse: () => {});
    return p['name'] ?? productId;
  }

  String _getProductUnit(String productId) {
    final p = _products.firstWhere((item) => item['id'] == productId, orElse: () => {});
    return p['unit'] ?? 'units';
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, dynamic result) {
        if (didPop) return;
        _handleBackNavigation();
      },
      child: Scaffold(
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _loadAllStoreData,
                child: Column(
                  children: [
                    _buildOfflineSyncBanner(),
                    Expanded(child: _buildBody()),
                  ],
                ),
              ),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _activeTab,
          selectedItemColor: AppColors.accent,
          unselectedItemColor: AppColors.textSecondary,
          backgroundColor: Colors.white,
          type: BottomNavigationBarType.fixed,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          unselectedLabelStyle: const TextStyle(fontSize: 11),
          onTap: (index) => _changeTab(index),
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.warehouse), label: 'Inventory'),
            BottomNavigationBarItem(icon: Icon(Icons.local_shipping), label: 'FSM Transfer'),
            BottomNavigationBarItem(icon: Icon(Icons.shopping_bag), label: 'Retail Sale'),
            BottomNavigationBarItem(icon: Icon(Icons.storefront), label: 'Distributor'),
            BottomNavigationBarItem(icon: Icon(Icons.query_stats), label: 'Reports'),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    switch (_activeTab) {
      case 0:
        return InventoryIntakeTab(
          warehouseId: _warehouseId,
          warehouseStocks: _warehouseStocks,
          alerts: _alerts,
          products: _products,
          dispatchEarnings: _dispatchEarnings,
          dispatchedUnits: _dispatchedUnits,
          getStockForProduct: _getStockForProduct,
          getRetailPriceForProduct: _getRetailPriceForProduct,
          getDistributorPriceForProduct: _getDistributorPriceForProduct,
          onRefresh: _loadAllStoreData,
        );
      case 1:
        return FsmDistributionView(
          warehouseId: _warehouseId,
          products: _products,
          fsmUsers: _fsmUsers,
          transfers: _transfers,
          getStockForProduct: _getStockForProduct,
          onTransferComplete: _loadAllStoreData,
        );
      case 2:
        return DirectRetailSaleView(
          warehouseId: _warehouseId,
          products: _products,
          customers: _retailCustomers,
          sales: _sales.where((s) => (s['customer_type'] ?? 'retail') == 'retail').toList(),
          getStockForProduct: _getStockForProduct,
          getRetailPrice: _getRetailPriceForProduct,
          onSaleComplete: _loadAllStoreData,
        );
      case 3:
        return DistributorSaleView(
          warehouseId: _warehouseId,
          products: _products,
          distributors: _distributors,
          sales: _sales.where((s) => s['customer_type'] == 'distributor').toList(),
          getStockForProduct: _getStockForProduct,
          getDistributorPrice: _getDistributorPriceForProduct,
          onSaleComplete: _loadAllStoreData,
        );
      case 4:
        return StoreReportsView(
          warehouseId: _warehouseId,
          intakes: _intakes,
          transfers: _transfers,
          sales: _sales,
          alerts: _alerts,
          getProductName: _getProductName,
          getProductUnit: _getProductUnit,
        );
      default:
        return InventoryIntakeTab(
          warehouseId: _warehouseId,
          warehouseStocks: _warehouseStocks,
          alerts: _alerts,
          products: _products,
          dispatchEarnings: _dispatchEarnings,
          dispatchedUnits: _dispatchedUnits,
          getStockForProduct: _getStockForProduct,
          getRetailPriceForProduct: _getRetailPriceForProduct,
          getDistributorPriceForProduct: _getDistributorPriceForProduct,
          onRefresh: _loadAllStoreData,
        );
    }
  }
}