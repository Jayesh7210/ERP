import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../core/constants/colors.dart';
import '../../core/state/app_state.dart';
import '../../core/services/offline_sync_service.dart';
import 'workforce_requests_page.dart';
import 'modules/permissions_module.dart';
import 'modules/catalog_pricing_module.dart';
import 'modules/workforce_referrals_module.dart';
import 'modules/inventory_module.dart';
import 'modules/sales_oversight_module.dart';
import 'modules/audit_logs_module.dart';
import 'modules/settlement_oversight_module.dart';
import 'modules/warehouses_module.dart';
import 'modules/payments_history_module.dart';

class SuperAdminDashboard extends StatefulWidget {
  const SuperAdminDashboard({super.key});

  @override
  State<SuperAdminDashboard> createState() => _SuperAdminDashboardState();
}

class _SuperAdminDashboardState extends State<SuperAdminDashboard> {
  int _activeModule =
      0; // 0: Hub, 1: Users, 2: Permissions, 3: Products/Pricing, 4: Referrals, 5: Inventory/Transfers, 6: Sales, 7: Audit Logs, 8: Settlements, 9: Warehouses, 10: Payments

  final List<Map<String, dynamic>> _sales = [];
  final List<Map<String, dynamic>> _workforce = [];
  final List<Map<String, dynamic>> _permissions = [];
  final List<Map<String, dynamic>> _products = [];
  final List<Map<String, dynamic>> _prices = [];
  final List<Map<String, dynamic>> _warehouses = [];
  final List<Map<String, dynamic>> _globalStocks = [];
  final List<Map<String, dynamic>> _transfers = [];
  final List<Map<String, dynamic>> _alerts = [];
  final List<Map<String, dynamic>> _referrals = [];
  final List<Map<String, dynamic>> _auditLogs = [];
  final List<Map<String, dynamic>> _settlements = [];
  final List<Map<String, dynamic>> _payments = [];
  Map<String, dynamic> _summary = {};
  Map<String, dynamic> _referralTreeData = {};
  Map<String, dynamic> _paymentsSummary = {};

  bool _isLoading = false;
  bool _isSyncingOffline = false;
  int _inventorySubTab = 0; // 0: Global Stock, 1: Transfers, 2: Alerts

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  Future<void> _loadAllData({bool silent = false}) async {
    if (!silent || (_summary.isEmpty && _sales.isEmpty)) {
      setState(() => _isLoading = true);
    }
    await Future.wait([
      _loadSummary(),
      _loadSales(),
      _loadWorkforce(),
      _loadPermissions(),
      _loadProducts(),
      _loadPrices(),
      _loadWarehouses(),
      _loadGlobalStocks(),
      _loadTransfers(),
      _loadAlerts(),
      _loadReferrals(),
      _loadAuditLogs(),
      _loadSettlements(),
      _loadPayments(),
    ]);
    if (mounted) setState(() => _isLoading = false);

    // Auto-sync any offline actions in the background
    _syncPendingActions(silent: true);
  }

  Future<void> _syncPendingActions({bool silent = false}) async {
    if (_isSyncingOffline) return;
    final count = await OfflineSyncService.getPendingCount();
    if (count == 0) return;

    if (mounted) setState(() => _isSyncingOffline = true);

    try {
      final res = await OfflineSyncService.syncAll(
        apiBaseUrl: AppState.apiBaseUrl,
      );

      if (mounted) {
        if (res.synced > 0) {
          _loadSummary();
          _loadSales();
          _loadGlobalStocks();
          _loadTransfers();
          if (!silent) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  '✅ Synced ${res.synced} offline transaction${res.synced > 1 ? 's' : ''} to server!',
                ),
                backgroundColor: Colors.green,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        } else if (!silent && res.failed > 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '⚠️ Sync failed: ${res.errors.isNotEmpty ? res.errors.first : 'Connection error'}',
              ),
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
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF3CD),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFFFEEBA)),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.cloud_upload_outlined,
                color: Color(0xFFB45309),
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$pendingCount Offline Action${pendingCount > 1 ? 's' : ''} Stored',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: Color(0xFF451A03),
                      ),
                    ),
                    const Text(
                      'Saved on device. Tap to sync all to server.',
                      style: TextStyle(fontSize: 11, color: Color(0xFF78350F)),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: _isSyncingOffline
                    ? null
                    : () => _syncPendingActions(silent: false),
                icon: _isSyncingOffline
                    ? const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.sync, size: 14),
                label: Text(
                  _isSyncingOffline ? 'Syncing...' : 'Sync Now',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFB45309),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
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
      String msg = 'Super Admin rate limit reached. Please wait a moment.';
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

  Future<void> _loadSummary() async {
    try {
      final res = await http.get(
        Uri.parse('${AppState.apiBaseUrl}/reports/summary'),
      );
      if (res.statusCode == 200) {
        setState(() => _summary = jsonDecode(res.body));
      } else if (res.statusCode == 429) {
        _handleRateLimit(res);
      }
    } catch (_) {
      setState(
        () => _summary = {
          'totalRevenue': 0.0,
          'userCount': 1,
          'productCount': 0,
          'warehouseCount': 0,
          'pendingReferralPayouts': 0.0,
          'totalStock': 0,
          'todaySalesAmount': 0.0,
          'todaySalesBottles': 0,
          'todaySalesCount': 0,
          'pendingSettlementCount': 0,
          'pendingSettlementAmount': 0.0,
        },
      );
    }
  }

  Future<void> _loadSales() async {
    try {
      final res = await http.get(
        Uri.parse('${AppState.apiBaseUrl}/sales/report'),
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as List;
        setState(() {
          _sales.clear();
          _sales.addAll(data.cast<Map<String, dynamic>>());
        });
      } else if (res.statusCode == 429) {
        _handleRateLimit(res);
      }
    } catch (_) {
      setState(() {
        _sales.clear();
      });
    }
  }

  Future<void> _loadSettlements() async {
    try {
      final res = await http.get(
        Uri.parse('${AppState.apiBaseUrl}/settlements'),
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as List;
        setState(() {
          _settlements.clear();
          _settlements.addAll(data.cast<Map<String, dynamic>>());
        });
      } else if (res.statusCode == 429) {
        _handleRateLimit(res);
      }
    } catch (_) {
      setState(() {
        _settlements.clear();
      });
    }
  }

  Future<void> _loadPayments() async {
    try {
      final res = await http.get(Uri.parse('${AppState.apiBaseUrl}/payments'));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data is Map<String, dynamic>) {
          setState(() {
            _payments.clear();
            if (data['payments'] is List) {
              final raw = (data['payments'] as List).cast<Map<String, dynamic>>();
              _payments.addAll(raw.where((p) => !PaymentsHistoryModule.isStaticPayment(p)));
            }
            _recalculatePaymentsSummary();
          });
          return;
        }
      }
    } catch (_) {}

    // Fallback synthesis if offline
    final List<Map<String, dynamic>> synthesized = [];
    for (final s in _sales) {
      if ((s['id'] ?? '').toString().startsWith('sale_10')) continue;
      synthesized.add({
        'id': 'pay_${s['id']}',
        'payment_no':
            'PAY-SAL-${s['id'].toString().length > 5 ? s['id'].toString().substring(s['id'].toString().length - 5).toUpperCase() : s['id']}',
        'type': 'sale',
        'category': (s['customer_type'] == 'distributor')
            ? 'Wholesale Bulk Sale'
            : 'Retail Sale',
        'amount': double.tryParse(s['amount']?.toString() ?? '0') ?? 0.0,
        'payment_method': s['payment_method'] ?? 'online',
        'status': 'completed',
        'payer_name':
            s['customer']?['name'] ?? s['customer_name'] ?? 'Retail Customer',
        'payer_phone': s['customer']?['phone'] ?? '',
        'payer_type': s['customer_type'] ?? 'retail',
        'collector_name': s['salesman']?['name'] ?? 'Staff',
        'collector_role': s['salesman']?['role'] ?? 'salesman',
        'item_description':
            '${s['quantity'] ?? 1}x ${s['product']?['name'] ?? 'Product'}',
        'reference_id': s['id'],
        'notes': s['referral_code'] != null
            ? 'Ref: ${s['referral_code']}'
            : 'Payment received',
        'created_at': s['created_at'] ?? DateTime.now().toIso8601String(),
      });
    }

    for (final stl in _settlements) {
      synthesized.add({
        'id': 'pay_${stl['id']}',
        'payment_no':
            'PAY-STL-${stl['id'].toString().length > 5 ? stl['id'].toString().substring(stl['id'].toString().length - 5).toUpperCase() : stl['id']}',
        'type': 'settlement',
        'category': 'Daily Cash Settlement',
        'amount':
            double.tryParse(
              stl['cash_collected']?.toString() ??
                  stl['sold_amount']?.toString() ??
                  '0',
            ) ??
            0.0,
        'payment_method': 'cash',
        'status': (stl['status'] == 'settled' || stl['status'] == 'tally_zero')
            ? 'completed'
            : 'pending',
        'payer_name': stl['salesman_name'] ?? 'Salesman Cash Deposit',
        'payer_phone': '',
        'payer_type': 'salesman',
        'collector_name': 'Depot / FSM Vault',
        'collector_role': 'manager',
        'item_description': 'Evening Cash Settlement Handover',
        'reference_id': stl['id'],
        'notes': 'Diff: ₹${stl['difference'] ?? 0}',
        'created_at': stl['created_at'] ?? DateTime.now().toIso8601String(),
      });
    }

    setState(() {
      _payments.clear();
      _payments.addAll(synthesized.where((p) => !PaymentsHistoryModule.isStaticPayment(p)));
      _recalculatePaymentsSummary();
    });
  }

  void _recalculatePaymentsSummary() {
    double totalVol = 0.0;
    double onlineVol = 0.0;
    double cashVol = 0.0;
    double payoutsVol = 0.0;
    for (final p in _payments) {
      final amt = double.tryParse(p['amount']?.toString() ?? '0') ?? 0.0;
      totalVol += amt;
      if (p['payment_method'] == 'online' || p['payment_method'] == 'upi') {
        onlineVol += amt;
      } else if (p['payment_method'] == 'cash') {
        cashVol += amt;
      }
      if (p['type'] == 'referral_payout') {
        payoutsVol += amt;
      }
    }
    _paymentsSummary = {
      'total_volume': totalVol,
      'total_collected': totalVol - payoutsVol,
      'online_total': onlineVol,
      'cash_total': cashVol,
      'payouts_total': payoutsVol,
      'count': _payments.length,
    };
  }

  Future<void> _loadWorkforce() async {
    try {
      final res = await http.get(Uri.parse('${AppState.apiBaseUrl}/users'));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as List;
        setState(() {
          _workforce.clear();
          _workforce.addAll(data.cast<Map<String, dynamic>>());
        });
      } else if (res.statusCode == 429) {
        _handleRateLimit(res);
      }
    } catch (_) {
      setState(() {
        _workforce.clear();
        if (AppState.currentUser != null) {
          _workforce.add(Map<String, dynamic>.from(AppState.currentUser!));
        }
      });
    }
  }

  Future<void> _loadPermissions() async {
    try {
      final res = await http.get(
        Uri.parse('${AppState.apiBaseUrl}/permissions'),
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as List;
        setState(() {
          _permissions.clear();
          _permissions.addAll(data.cast<Map<String, dynamic>>());
        });
      } else if (res.statusCode == 429) {
        _handleRateLimit(res);
      }
    } catch (_) {
      setState(() {
        _permissions.clear();
        _permissions.addAll([
          {
            'role': 'store_admin',
            'permission_key': 'add_stock',
            'is_allowed': true,
          },
          {
            'role': 'store_admin',
            'permission_key': 'transfer_fsm',
            'is_allowed': true,
          },
          {
            'role': 'store_admin',
            'permission_key': 'direct_sale',
            'is_allowed': true,
          },
          {
            'role': 'store_admin',
            'permission_key': 'bulk_sale_distributor',
            'is_allowed': true,
          },
          {
            'role': 'field_sales_manager',
            'permission_key': 'receive_stock',
            'is_allowed': true,
          },
          {
            'role': 'field_sales_manager',
            'permission_key': 'transfer_salesman',
            'is_allowed': true,
          },
          {
            'role': 'field_sales_manager',
            'permission_key': 'direct_sale',
            'is_allowed': true,
          },
          {
            'role': 'salesman',
            'permission_key': 'view_assigned_stock',
            'is_allowed': true,
          },
          {
            'role': 'salesman',
            'permission_key': 'sell_to_customer',
            'is_allowed': true,
          },
          {
            'role': 'salesman',
            'permission_key': 'onboard_customer',
            'is_allowed': true,
          },
        ]);
      });
    }
  }

  Future<void> _loadProducts() async {
    try {
      final res = await http.get(Uri.parse('${AppState.apiBaseUrl}/products'));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as List;
        setState(() {
          _products.clear();
          _products.addAll(data.cast<Map<String, dynamic>>());
        });
      } else if (res.statusCode == 429) {
        _handleRateLimit(res);
      }
    } catch (_) {
      setState(() {
        _products.clear();
      });
    }
  }

  Future<void> _loadPrices() async {
    try {
      final res = await http.get(
        Uri.parse('${AppState.apiBaseUrl}/products/prices'),
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as List;
        setState(() {
          _prices.clear();
          _prices.addAll(data.cast<Map<String, dynamic>>());
        });
      } else if (res.statusCode == 429) {
        _handleRateLimit(res);
      }
    } catch (_) {
      setState(() {
        _prices.clear();
      });
    }
  }

  Future<void> _loadWarehouses() async {
    try {
      final res = await http.get(
        Uri.parse('${AppState.apiBaseUrl}/warehouses'),
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as List;
        setState(() {
          _warehouses.clear();
          _warehouses.addAll(data.cast<Map<String, dynamic>>());
        });
      } else if (res.statusCode == 429) {
        _handleRateLimit(res);
      }
    } catch (_) {
      setState(() {
        _warehouses.clear();
      });
    }
  }

  Future<void> _loadGlobalStocks() async {
    try {
      final res = await http.get(
        Uri.parse('${AppState.apiBaseUrl}/stock/global'),
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as List;
        setState(() {
          _globalStocks.clear();
          _globalStocks.addAll(data.cast<Map<String, dynamic>>());
        });
      } else if (res.statusCode == 429) {
        _handleRateLimit(res);
      }
    } catch (_) {
      setState(() {
        _globalStocks.clear();
      });
    }
  }

  Future<void> _loadTransfers() async {
    try {
      final res = await http.get(
        Uri.parse('${AppState.apiBaseUrl}/stock/transfers'),
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as List;
        setState(() {
          _transfers.clear();
          _transfers.addAll(data.cast<Map<String, dynamic>>());
        });
      } else if (res.statusCode == 429) {
        _handleRateLimit(res);
      }
    } catch (_) {
      setState(() {
        _transfers.clear();
      });
    }
  }

  Future<void> _loadAlerts() async {
    try {
      final res = await http.get(
        Uri.parse('${AppState.apiBaseUrl}/stock/alerts'),
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as List;
        setState(() {
          _alerts.clear();
          _alerts.addAll(data.cast<Map<String, dynamic>>());
        });
      } else if (res.statusCode == 429) {
        _handleRateLimit(res);
      }
    } catch (_) {
      setState(() {
        _alerts.clear();
      });
    }
  }

  Future<void> _loadReferralTree() async {
    try {
      final res = await http.get(
        Uri.parse('${AppState.apiBaseUrl}/referrals/tree'),
      );
      if (res.statusCode == 200) {
        setState(() => _referralTreeData = jsonDecode(res.body));
      }
    } catch (_) {}
  }

  Future<void> _loadReferrals() async {
    _loadReferralTree();
    try {
      final res = await http.get(Uri.parse('${AppState.apiBaseUrl}/referrals'));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as List;
        setState(() {
          _referrals.clear();
          _referrals.addAll(data.cast<Map<String, dynamic>>());
        });
      } else if (res.statusCode == 429) {
        _handleRateLimit(res);
      }
    } catch (_) {
      setState(() {
        _referrals.clear();
      });
    }
  }

  Future<void> _loadAuditLogs() async {
    try {
      final res = await http.get(
        Uri.parse('${AppState.apiBaseUrl}/audit-logs'),
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as List;
        setState(() {
          _auditLogs.clear();
          _auditLogs.addAll(data.cast<Map<String, dynamic>>());
        });
      } else if (res.statusCode == 429) {
        _handleRateLimit(res);
      }
    } catch (_) {
      setState(() {
        _auditLogs.clear();
      });
    }
  }

  Future<void> _togglePermission(
    String role,
    String permissionKey,
    bool currentAllowed,
  ) async {
    final nextAllowed = !currentAllowed;
    try {
      final res = await http.put(
        Uri.parse('${AppState.apiBaseUrl}/permissions'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'role': role,
          'permission_key': permissionKey,
          'is_allowed': nextAllowed,
          'admin_id': AppState.currentUser?['id'],
          'admin_name': AppState.currentUser?['name'],
        }),
      );
      if (res.statusCode == 429) {
        _handleRateLimit(res);
        return;
      }
      _loadPermissions();
      _loadAuditLogs();
    } catch (_) {
      setState(() {
        final item = _permissions.firstWhere(
          (p) => p['role'] == role && p['permission_key'] == permissionKey,
          orElse: () => <String, dynamic>{},
        );
        if (item.isNotEmpty) {
          item['is_allowed'] = nextAllowed;
        } else {
          _permissions.add({
            'role': role,
            'permission_key': permissionKey,
            'is_allowed': nextAllowed,
          });
        }
      });
    }
  }

  Widget _buildHubView() {
    final totalStock =
        (_summary['totalStock'] as num?)?.toInt() ??
        _globalStocks.fold<int>(
          0,
          (sum, item) =>
              sum + (int.tryParse(item['quantity']?.toString() ?? '0') ?? 0),
        );

    final todaySalesAmount =
        (_summary['todaySalesAmount'] as num?)?.toDouble() ?? 0.0;
    final todaySalesBottles =
        (_summary['todaySalesBottles'] as num?)?.toInt() ?? 0;
    final todaySalesCount = (_summary['todaySalesCount'] as num?)?.toInt() ?? 0;

    final pendingSettlementCount =
        (_summary['pendingSettlementCount'] as num?)?.toInt() ??
        _settlements
            .where(
              (s) =>
                  (s['status'] != 'settled' && s['status'] != 'reconciled') ||
                  (double.tryParse(s['difference']?.toString() ?? '0') ?? 0)
                          .abs() >
                      0.01,
            )
            .length;
    final pendingSettlementAmount =
        (_summary['pendingSettlementAmount'] as num?)?.toDouble() ??
        _settlements
            .where(
              (s) =>
                  (s['status'] != 'settled' && s['status'] != 'reconciled') ||
                  (double.tryParse(s['difference']?.toString() ?? '0') ?? 0)
                          .abs() >
                      0.01,
            )
            .fold<double>(
              0.0,
              (sum, s) =>
                  sum +
                  (double.tryParse(s['difference']?.toString() ?? '0') ?? 0.0)
                      .abs(),
            );

    return RefreshIndicator(
      onRefresh: () => _loadAllData(silent: true),
      color: AppColors.primary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Low-stock warning banner if applicable
          if (_alerts.isNotEmpty)
            Card(
              color: Colors.red.shade50,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.red.shade200),
              ),
              margin: const EdgeInsets.only(bottom: 16),
              child: ListTile(
                leading: const Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.red,
                  size: 32,
                ),
                title: Text(
                  '${_alerts.length} Low-Stock Alert(s) Detected!',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
                subtitle: Text(
                  'Items below safety threshold: ${_alerts.map((a) => a['product']?['name']).join(", ")}',
                ),
                trailing: const Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: Colors.red,
                ),
                onTap: () => setState(() {
                  _activeModule = 5;
                  _inventorySubTab = 2; // jump to alerts
                }),
              ),
            ),

          // Offline Sync Banner (if any unsynced actions exist)
          _buildOfflineSyncBanner(),

          // Primary KPI Banner
          Card(
            color: AppColors.primary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const Text(
                    'Total System Revenue',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '₹${_summary['totalRevenue'] ?? _sales.fold<double>(0, (sum, i) => sum + (double.tryParse(i['amount'].toString()) ?? 0))}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 34,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _kpiMiniCol(
                          'Active Workforce',
                          '${_workforce.length} staff',
                          () => setState(() => _activeModule = 1),
                        ),
                      ),
                      Expanded(
                        child: _kpiMiniCol(
                          'Warehouses',
                          '${_warehouses.length} hubs',
                          () => setState(() => _activeModule = 9),
                        ),
                      ),
                      Expanded(
                        child: _kpiMiniCol(
                          'Products',
                          '${_products.length} SKUs',
                          () => setState(() => _activeModule = 3),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // DAILY OPERATIONAL PULSE (User focus: Total Stock, Today's Sale, Pending Settlement)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Daily Operational Pulse',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    const Text(
                      'LIVE',
                      style: TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _dailyPulseCard(
                icon: Icons.inventory_2_rounded,
                iconColor: Colors.teal.shade700,
                iconBg: Colors.teal.shade50,
                title: 'TOTAL STOCK',
                value: '$totalStock units',
                subtitle: '${_warehouses.length} Hubs',
                onTap: () => setState(() => _activeModule = 5),
              ),
              const SizedBox(width: 8),
              _dailyPulseCard(
                icon: Icons.trending_up_rounded,
                iconColor: Colors.blue.shade700,
                iconBg: Colors.blue.shade50,
                title: "TODAY'S SALE",
                value: '₹${todaySalesAmount.toStringAsFixed(0)}',
                subtitle: '$todaySalesBottles btls • $todaySalesCount bills',
                onTap: () => setState(() => _activeModule = 6),
              ),
              const SizedBox(width: 8),
              _dailyPulseCard(
                icon: Icons.pending_actions_rounded,
                iconColor: Colors.orange.shade800,
                iconBg: Colors.orange.shade50,
                title: 'SETTLEMENT',
                value: '$pendingSettlementCount Pending',
                subtitle: pendingSettlementAmount > 0
                    ? '₹${pendingSettlementAmount.toStringAsFixed(0)} diff'
                    : 'Reconciled',
                onTap: () => setState(() => _activeModule = 8),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Executive Module Operations Grid
          const Text(
            'Super Admin Operations',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.08,
            children: [
              _moduleCard(
                Icons.group_outlined,
                'Workforce & Users',
                '${_workforce.length} Accounts',
                () => setState(() => _activeModule = 1),
              ),
              _moduleCard(
                Icons.security_outlined,
                'Role Permissions',
                'Dynamic RBAC Matrix',
                () => setState(() => _activeModule = 2),
              ),
              _moduleCard(
                Icons.inventory_2_outlined,
                'Catalog & Pricing',
                '${_products.length} Products & Tiers',
                () => setState(() => _activeModule = 3),
              ),
              _moduleCard(
                Icons.account_tree_outlined,
                'Workforce Referrals',
                '${_referrals.where((r) => r['status'] == 'unlocked' || r['status'] == 'pending').length} Pending Payouts',
                () => setState(() => _activeModule = 4),
              ),
              _moduleCard(
                Icons.swap_horiz_outlined,
                'Stock & Movement',
                '$totalStock Total Units',
                () => setState(() => _activeModule = 5),
              ),
              _moduleCard(
                Icons.point_of_sale_outlined,
                'Sales Oversight',
                '₹${todaySalesAmount.toStringAsFixed(0)} Today',
                () => setState(() => _activeModule = 6),
              ),
              _moduleCard(
                Icons.assignment_turned_in_outlined,
                'Daily Settlements',
                '$pendingSettlementCount Pending Review',
                () => setState(() => _activeModule = 8),
              ),
              _moduleCard(
                Icons.receipt_long_outlined,
                'Payments History',
                '₹${(double.tryParse(_paymentsSummary['total_collected']?.toString() ?? '0') ?? todaySalesAmount).toStringAsFixed(0)} Inflow',
                () => setState(() => _activeModule = 10),
              ),
              _moduleCard(
                Icons.warehouse_outlined,
                'Warehouses',
                '${_warehouses.length} Active Hubs',
                () => setState(() => _activeModule = 9),
              ),
              _moduleCard(
                Icons.history_edu_outlined,
                'Audit Trail',
                '${_auditLogs.length} Events Logged',
                () => setState(() => _activeModule = 7),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

  Widget _dailyPulseCard({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String title,
    required String value,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: Material(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(14),
        elevation: 1.5,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: iconBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: iconColor, size: 20),
                ),
                const SizedBox(height: 10),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textSecondary,
                    letterSpacing: 0.3,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 9.5,
                    color: AppColors.textSecondary.withValues(alpha: 0.8),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _kpiMiniCol(String label, String value, [VoidCallback? onTap]) {
    final col = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            style: const TextStyle(color: Colors.white60, fontSize: 11),
          ),
        ),
      ],
    );
    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: col,
        ),
      );
    }
    return col;
  }

  Widget _moduleCard(
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap,
  ) {
    return Card(
      color: AppColors.cardBg,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                child: Icon(icon, color: AppColors.primary, size: 20),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 10.5,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActiveModuleContent() {
    switch (_activeModule) {
      case 1:
        return WorkforceRequestsPage(
          showBackButton: true,
          onBack: () {
            _loadAllData();
            setState(() => _activeModule = 0);
          },
        );
      case 2:
        return PermissionsModule(
          permissions: _permissions,
          onTogglePermission: _togglePermission,
          onBack: () => setState(() => _activeModule = 0),
        );
      case 3:
        return CatalogPricingModule(
          products: _products,
          prices: _prices,
          onRefresh: () {
            _loadProducts();
            _loadPrices();
            _loadAlerts();
            _loadAuditLogs();
          },
          onBack: () => setState(() => _activeModule = 0),
        );
      case 4:
        return WorkforceReferralsModule(
          referrals: _referrals,
          referralTreeData: _referralTreeData,
          onRefresh: () {
            _loadReferrals();
            _loadAuditLogs();
            _loadSummary();
          },
          onBack: () => setState(() => _activeModule = 0),
          onPayoutProcessed: () {
            _loadReferrals();
            _loadAuditLogs();
            _loadSummary();
            _loadPayments();
          },
        );
      case 5:
        return InventoryModule(
          globalStocks: _globalStocks,
          transfers: _transfers,
          alerts: _alerts,
          initialSubTab: _inventorySubTab,
          onBack: () => setState(() => _activeModule = 0),
        );
      case 6:
        return SalesOversightModule(
          sales: _sales,
          onBack: () => setState(() => _activeModule = 0),
        );
      case 7:
        return AuditLogsModule(
          auditLogs: _auditLogs,
          onBack: () => setState(() => _activeModule = 0),
        );
      case 8:
        return SettlementOversightModule(
          settlements: _settlements,
          onRefresh: () {
            _loadSettlements();
            _loadAuditLogs();
            _loadSummary();
          },
          onBack: () => setState(() => _activeModule = 0),
        );
      case 9:
        return WarehousesModule(
          warehouses: _warehouses,
          globalStocks: _globalStocks,
          workforce: _workforce,
          onRefresh: () {
            _loadWarehouses();
            _loadGlobalStocks();
            _loadWorkforce();
          },
          onBack: () => setState(() => _activeModule = 0),
          onNavigateToStock: () => setState(() {
            _inventorySubTab = 0;
            _activeModule = 5;
          }),
        );
      case 10:
        return PaymentsHistoryModule(
          payments: _payments,
          paymentsSummary: _paymentsSummary,
          onRefresh: () {
            _loadPayments();
            _loadSales();
            _loadSettlements();
          },
          onBack: () => setState(() => _activeModule = 0),
        );
      case 0:
      default:
        return _buildHubView();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final content = _buildActiveModuleContent();
    if (_activeModule != 0) {
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (bool didPop, dynamic result) {
          if (didPop) return;
          setState(() => _activeModule = 0);
        },
        child: content,
      );
    }

    return content;
  }
}
