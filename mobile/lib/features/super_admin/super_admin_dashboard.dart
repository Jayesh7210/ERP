
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../core/constants/colors.dart';
import '../../core/state/app_state.dart';
import 'workforce_requests_page.dart';

class SuperAdminDashboard extends StatefulWidget {
  const SuperAdminDashboard({super.key});

  @override
  State<SuperAdminDashboard> createState() => _SuperAdminDashboardState();
}

class _SuperAdminDashboardState extends State<SuperAdminDashboard> {
  int _activeModule = 0; // 0: Hub, 1: Users, 2: Permissions, 3: Products/Pricing, 4: Referrals, 5: Inventory/Transfers, 6: Sales, 7: Audit Logs

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
  Map<String, dynamic> _summary = {};
  Map<String, dynamic> _referralRules = {
    'commission_per_bottle': 1.0,
    'min_sales_quota': 5,
    'is_quota_condition_active': true,
    'is_active': true
  };
  int _referralSubTab = 0; // 0: Workforce Tree, 1: Commission Ledger
  Map<String, dynamic> _referralTreeData = {};

  bool _isLoading = false;

  // Filter States
  String _salesPaymentFilter = 'all';
  String _salesCustomerFilter = 'all';
  String _settlementFilter = 'all';
  int _inventorySubTab = 0; // 0: Global Stock, 1: Transfers, 2: Alerts
  String _productSearchQuery = '';
  String _productAvailabilityFilter = 'all'; // 'all', 'available', 'not_available'
  final TextEditingController _productSearchCtrl = TextEditingController();
  String _warehouseSearchQuery = '';
  final TextEditingController _warehouseSearchCtrl = TextEditingController();
  final List<Map<String, dynamic>> _payments = [];
  Map<String, dynamic> _paymentsSummary = {};
  String _paymentTypeFilter = 'all'; // 'all', 'sale', 'settlement', 'referral_payout'
  String _paymentMethodFilter = 'all'; // 'all', 'online', 'cash'
  String _paymentSearchQuery = '';
  final TextEditingController _paymentSearchCtrl = TextEditingController();

  @override
  void dispose() {
    _productSearchCtrl.dispose();
    _warehouseSearchCtrl.dispose();
    _paymentSearchCtrl.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);
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
      _loadReferralRules(),
      _loadReferrals(),
      _loadAuditLogs(),
      _loadSettlements(),
      _loadPayments(),
    ]);
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _loadSummary() async {
    try {
      final res = await http.get(Uri.parse('${AppState.apiBaseUrl}/reports/summary'));
      if (res.statusCode == 200) {
        setState(() => _summary = jsonDecode(res.body));
      }
    } catch (_) {
      setState(() => _summary = {
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
      });
    }
  }

  Future<void> _loadSales() async {
    try {
      final res = await http.get(Uri.parse('${AppState.apiBaseUrl}/sales/report'));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as List;
        setState(() {
          _sales.clear();
          _sales.addAll(data.cast<Map<String, dynamic>>());
        });
      }
    } catch (_) {
      setState(() {
        _sales.clear();
      });
    }
  }

  Future<void> _loadSettlements() async {
    try {
      final res = await http.get(Uri.parse('${AppState.apiBaseUrl}/settlements'));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as List;
        setState(() {
          _settlements.clear();
          _settlements.addAll(data.cast<Map<String, dynamic>>());
        });
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
              _payments.addAll((data['payments'] as List).cast<Map<String, dynamic>>());
            }
            if (data['summary'] is Map<String, dynamic>) {
              _paymentsSummary = data['summary'];
            }
          });
          return;
        }
      }
    } catch (_) {}

    // Fallback if network or offline
    final List<Map<String, dynamic>> synthesized = [];
    for (final s in _sales) {
      synthesized.add({
        'id': 'pay_${s['id']}',
        'payment_no': 'PAY-SAL-${s['id'].toString().length > 5 ? s['id'].toString().substring(s['id'].toString().length - 5).toUpperCase() : s['id']}',
        'type': 'sale',
        'category': (s['customer_type'] == 'distributor') ? 'Wholesale Bulk Sale' : 'Retail Sale',
        'amount': double.tryParse(s['amount']?.toString() ?? '0') ?? 0.0,
        'payment_method': s['payment_method'] ?? 'online',
        'status': 'completed',
        'payer_name': s['customer']?['name'] ?? s['customer_name'] ?? 'Retail Customer',
        'payer_phone': s['customer']?['phone'] ?? '',
        'payer_type': s['customer_type'] ?? 'retail',
        'collector_name': s['salesman']?['name'] ?? 'Staff',
        'collector_role': s['salesman']?['role'] ?? 'salesman',
        'item_description': '${s['quantity'] ?? 1}x ${s['product']?['name'] ?? 'Product'}',
        'reference_id': s['id'],
        'notes': s['referral_code'] != null ? 'Ref: ${s['referral_code']}' : 'Payment received',
        'created_at': s['created_at'] ?? DateTime.now().toIso8601String(),
      });
    }

    for (final stl in _settlements) {
      synthesized.add({
        'id': 'pay_${stl['id']}',
        'payment_no': 'PAY-STL-${stl['id'].toString().length > 5 ? stl['id'].toString().substring(stl['id'].toString().length - 5).toUpperCase() : stl['id']}',
        'type': 'settlement',
        'category': 'Daily Cash Settlement',
        'amount': double.tryParse(stl['cash_collected']?.toString() ?? stl['sold_amount']?.toString() ?? '0') ?? 0.0,
        'payment_method': 'cash',
        'status': (stl['status'] == 'settled' || stl['status'] == 'tally_zero') ? 'completed' : 'pending',
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

    double totalVol = 0.0;
    double onlineVol = 0.0;
    double cashVol = 0.0;
    double payoutsVol = 0.0;
    for (final p in synthesized) {
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

    setState(() {
      _payments.clear();
      _payments.addAll(synthesized);
      _paymentsSummary = {
        'total_volume': totalVol,
        'total_collected': totalVol - payoutsVol,
        'online_total': onlineVol,
        'cash_total': cashVol,
        'payouts_total': payoutsVol,
        'count': synthesized.length,
      };
    });
  }

  Future<void> _handleApproveSettlement(String id) async {
    try {
      final res = await http.put(
        Uri.parse('${AppState.apiBaseUrl}/settlements/$id/approve'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'approved_by': AppState.currentUser?['id']}),
      );
      if (res.statusCode == 200) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Settlement approved and marked settled!'), backgroundColor: Colors.green),
        );
        _loadAllData();
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Settlement reconciled!'), backgroundColor: Colors.green),
      );
      setState(() {
        final item = _settlements.firstWhere((s) => s['id'] == id, orElse: () => {});
        if (item.isNotEmpty) {
          item['status'] = 'settled';
          item['difference'] = 0;
        }
      });
    }
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
      }
    } catch (_) {
      setState(() {
        _workforce.clear();
        _workforce.add({'id': 'u1', 'name': 'Super Admin', 'email': 'admin@erp.com', 'phone': '', 'role': 'super_admin', 'status': 'approved'});
      });
    }
  }

  Future<void> _loadPermissions() async {
    try {
      final res = await http.get(Uri.parse('${AppState.apiBaseUrl}/permissions'));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as List;
        setState(() {
          _permissions.clear();
          _permissions.addAll(data.cast<Map<String, dynamic>>());
        });
      }
    } catch (_) {
      setState(() {
        _permissions.clear();
        _permissions.addAll([
          {'role': 'store_admin', 'permission_key': 'add_stock', 'is_allowed': true},
          {'role': 'store_admin', 'permission_key': 'transfer_fsm', 'is_allowed': true},
          {'role': 'store_admin', 'permission_key': 'direct_sale', 'is_allowed': true},
          {'role': 'store_admin', 'permission_key': 'bulk_sale_distributor', 'is_allowed': true},
          {'role': 'field_sales_manager', 'permission_key': 'receive_stock', 'is_allowed': true},
          {'role': 'field_sales_manager', 'permission_key': 'transfer_salesman', 'is_allowed': true},
          {'role': 'field_sales_manager', 'permission_key': 'direct_sale', 'is_allowed': true},
          {'role': 'salesman', 'permission_key': 'view_assigned_stock', 'is_allowed': true},
          {'role': 'salesman', 'permission_key': 'sell_to_customer', 'is_allowed': true},
          {'role': 'salesman', 'permission_key': 'onboard_customer', 'is_allowed': true},
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
      }
    } catch (_) {
      setState(() {
        _products.clear();
      });
    }
  }

  Future<void> _loadPrices() async {
    try {
      final res = await http.get(Uri.parse('${AppState.apiBaseUrl}/products/prices'));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as List;
        setState(() {
          _prices.clear();
          _prices.addAll(data.cast<Map<String, dynamic>>());
        });
      }
    } catch (_) {
      setState(() {
        _prices.clear();
      });
    }
  }

  Future<void> _loadWarehouses() async {
    try {
      final res = await http.get(Uri.parse('${AppState.apiBaseUrl}/warehouses'));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as List;
        setState(() {
          _warehouses.clear();
          _warehouses.addAll(data.cast<Map<String, dynamic>>());
        });
      }
    } catch (_) {
      setState(() {
        _warehouses.clear();
      });
    }
  }

  Future<void> _loadGlobalStocks() async {
    try {
      final res = await http.get(Uri.parse('${AppState.apiBaseUrl}/stock/global'));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as List;
        setState(() {
          _globalStocks.clear();
          _globalStocks.addAll(data.cast<Map<String, dynamic>>());
        });
      }
    } catch (_) {
      setState(() {
        _globalStocks.clear();
      });
    }
  }

  Future<void> _loadTransfers() async {
    try {
      final res = await http.get(Uri.parse('${AppState.apiBaseUrl}/stock/transfers'));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as List;
        setState(() {
          _transfers.clear();
          _transfers.addAll(data.cast<Map<String, dynamic>>());
        });
      }
    } catch (_) {
      setState(() {
        _transfers.clear();
      });
    }
  }

  Future<void> _loadAlerts() async {
    try {
      final res = await http.get(Uri.parse('${AppState.apiBaseUrl}/stock/alerts'));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as List;
        setState(() {
          _alerts.clear();
          _alerts.addAll(data.cast<Map<String, dynamic>>());
        });
      }
    } catch (_) {
      setState(() {
        _alerts.clear();
      });
    }
  }

  Future<void> _loadReferralRules() async {
    try {
      final res = await http.get(Uri.parse('${AppState.apiBaseUrl}/referrals/rules'));
      if (res.statusCode == 200) {
        setState(() => _referralRules = jsonDecode(res.body));
      }
    } catch (_) {}
  }

  Future<void> _loadReferralTree() async {
    try {
      final res = await http.get(Uri.parse('${AppState.apiBaseUrl}/referrals/tree'));
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
      }
    } catch (_) {
      setState(() {
        _referrals.clear();
      });
    }
  }

  Future<void> _loadAuditLogs() async {
    try {
      final res = await http.get(Uri.parse('${AppState.apiBaseUrl}/audit-logs'));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as List;
        setState(() {
          _auditLogs.clear();
          _auditLogs.addAll(data.cast<Map<String, dynamic>>());
        });
      }
    } catch (_) {
      setState(() {
        _auditLogs.clear();
      });
    }
  }

  // --- ACTIONS & DIALOGS ---

  Future<void> _togglePermission(String role, String permissionKey, bool currentAllowed) async {
    final nextAllowed = !currentAllowed;
    try {
      await http.put(
        Uri.parse('${AppState.apiBaseUrl}/permissions'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'role': role,
          'permission_key': permissionKey,
          'is_allowed': nextAllowed,
          'admin_id': AppState.currentUser?['id'],
          'admin_name': AppState.currentUser?['name']
        }),
      );
      _loadPermissions();
      _loadAuditLogs();
    } catch (_) {
      setState(() {
        final item = _permissions.firstWhere((p) => p['role'] == role && p['permission_key'] == permissionKey, orElse: () => <String, dynamic>{});
        if (item.isNotEmpty) {
          item['is_allowed'] = nextAllowed;
        } else {
          _permissions.add({'role': role, 'permission_key': permissionKey, 'is_allowed': nextAllowed});
        }
      });
    }
  }

  void _showAddOrEditProductDialog({Map<String, dynamic>? editProduct}) {
    final nameCtrl = TextEditingController(text: editProduct?['name'] ?? '');
    final skuCtrl = TextEditingController(text: editProduct?['sku'] ?? '');
    final unitCtrl = TextEditingController(text: editProduct?['unit'] ?? 'pcs');
    final catCtrl = TextEditingController(text: editProduct?['category'] ?? 'General');
    final basePriceCtrl = TextEditingController(text: editProduct?['base_price']?.toString() ?? '0');
    final alertCtrl = TextEditingController(text: editProduct?['min_stock_alert']?.toString() ?? '20');
    bool isAvailable = editProduct?['is_active'] != false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: Text(editProduct != null ? 'Edit Product' : 'Add New Product'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Product Name *')),
                TextField(controller: skuCtrl, decoration: const InputDecoration(labelText: 'SKU Code *')),
                TextField(controller: catCtrl, decoration: const InputDecoration(labelText: 'Category')),
                TextField(controller: unitCtrl, decoration: const InputDecoration(labelText: 'Selling Unit (pcs, packet, etc.)')),
                TextField(controller: basePriceCtrl, decoration: const InputDecoration(labelText: 'Base Selling Price (₹)'), keyboardType: const TextInputType.numberWithOptions(decimal: true)),
                TextField(controller: alertCtrl, decoration: const InputDecoration(labelText: 'Low Stock Alert Threshold'), keyboardType: TextInputType.number),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isAvailable ? Colors.green.shade50 : Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: isAvailable ? Colors.green.shade300 : Colors.red.shade300),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                isAvailable ? Icons.check_circle : Icons.do_not_disturb_on,
                                size: 16,
                                color: isAvailable ? Colors.green.shade800 : Colors.red.shade800,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                isAvailable ? 'AVAILABLE' : 'NOT AVAILABLE',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: isAvailable ? Colors.green.shade800 : Colors.red.shade800,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isAvailable ? 'Item is active in sales catalog' : 'Item is inactive / hidden from sales',
                            style: TextStyle(fontSize: 10.5, color: isAvailable ? Colors.green.shade700 : Colors.red.shade700),
                          ),
                        ],
                      ),
                      Switch(
                        value: isAvailable,
                        activeThumbColor: Colors.green,
                        inactiveThumbColor: Colors.red,
                        onChanged: (val) => setDlgState(() => isAvailable = val),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
              onPressed: () async {
                if (nameCtrl.text.isEmpty || skuCtrl.text.isEmpty) return;

                final bodyData = {
                  'name': nameCtrl.text.trim(),
                  'sku': skuCtrl.text.trim(),
                  'category': catCtrl.text.trim(),
                  'unit': unitCtrl.text.trim(),
                  'base_price': double.tryParse(basePriceCtrl.text) ?? 0.0,
                  'min_stock_alert': int.tryParse(alertCtrl.text) ?? 20,
                  'is_active': isAvailable,
                  'admin_id': AppState.currentUser?['id'],
                  'admin_name': AppState.currentUser?['name'],
                };

                try {
                  if (editProduct != null) {
                    await http.put(
                      Uri.parse('${AppState.apiBaseUrl}/products/${editProduct['id']}'),
                      headers: {'Content-Type': 'application/json'},
                      body: jsonEncode(bodyData),
                    );
                  } else {
                    await http.post(
                      Uri.parse('${AppState.apiBaseUrl}/products'),
                      headers: {'Content-Type': 'application/json'},
                      body: jsonEncode(bodyData),
                    );
                  }
                  _loadProducts();
                  _loadAlerts();
                  _loadAuditLogs();
                  if (ctx.mounted) Navigator.pop(ctx);
                } catch (_) {
                  setState(() {
                    if (editProduct != null) {
                      editProduct['name'] = nameCtrl.text.trim();
                      editProduct['sku'] = skuCtrl.text.trim();
                      editProduct['category'] = catCtrl.text.trim();
                      editProduct['unit'] = unitCtrl.text.trim();
                      editProduct['base_price'] = double.tryParse(basePriceCtrl.text) ?? 0.0;
                      editProduct['min_stock_alert'] = int.tryParse(alertCtrl.text) ?? 20;
                      editProduct['is_active'] = isAvailable;
                    } else {
                      _products.add({
                        'id': 'p_${DateTime.now().millisecondsSinceEpoch}',
                        'name': nameCtrl.text.trim(),
                        'sku': skuCtrl.text.trim(),
                        'category': catCtrl.text.trim(),
                        'unit': unitCtrl.text.trim(),
                        'base_price': double.tryParse(basePriceCtrl.text) ?? 0.0,
                        'min_stock_alert': int.tryParse(alertCtrl.text) ?? 20,
                        'is_active': isAvailable,
                      });
                    }
                  });
                  if (ctx.mounted) Navigator.pop(ctx);
                }
              },
              child: Text(editProduct != null ? 'Save Changes' : 'Create Product'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleProductAvailability(Map<String, dynamic> p, bool nextStatus) async {
    setState(() {
      p['is_active'] = nextStatus;
    });

    try {
      final res = await http.put(
        Uri.parse('${AppState.apiBaseUrl}/products/${p['id']}'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'is_active': nextStatus,
          'admin_id': AppState.currentUser?['id'],
          'admin_name': AppState.currentUser?['name'],
        }),
      );

      if (res.statusCode == 200 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(nextStatus ? '🟢 "${p['name']}" is now AVAILABLE' : '🔴 "${p['name']}" is now NOT AVAILABLE'),
            backgroundColor: nextStatus ? Colors.green.shade700 : Colors.red.shade700,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (_) {}
    _loadProducts();
  }

  Future<void> _confirmDeleteProduct(Map<String, dynamic> p) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: const [
            Icon(Icons.delete_outline, color: Colors.red),
            SizedBox(width: 8),
            Text('Delete Product'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Are you sure you want to permanently delete "${p['name']}"?'),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)),
              child: Text(
                'SKU: ${p['sku']} • Unit: ${p['unit']}\nThis will remove the product and its pricing tiers from the catalog.',
                style: TextStyle(fontSize: 12, color: Colors.red.shade900),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete Permanently'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final res = await http.delete(
          Uri.parse('${AppState.apiBaseUrl}/products/${p['id']}?admin_id=${AppState.currentUser?['id']}&admin_name=${AppState.currentUser?['name']}'),
        );
        if (res.statusCode == 200 && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Product "${p['name']}" deleted successfully'), backgroundColor: Colors.red.shade700),
          );
        }
      } catch (_) {}
      _loadProducts();
      _loadAlerts();
      _loadAuditLogs();
    }
  }

  void _showTieredPricingDialog(Map<String, dynamic> product) {
    final priceCtrl = TextEditingController();
    final discountCtrl = TextEditingController(text: '0');
    String selectedRole = 'store_admin';

    void updateForm(String role) {
      final existing = _prices.firstWhere(
        (p) => p['product_id'] == product['id'] && p['role'] == role,
        orElse: () => <String, dynamic>{},
      );
      if (existing.isNotEmpty) {
        priceCtrl.text = existing['price']?.toString() ?? '';
        discountCtrl.text = existing['discount_percentage']?.toString() ?? '0';
      } else {
        priceCtrl.text = product['base_price']?.toString() ?? '';
        discountCtrl.text = '0';
      }
    }

    updateForm(selectedRole);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('Role & Tier Pricing: ${product['name']}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: selectedRole,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Buyer / Tier Role'),
                items: const [
                  DropdownMenuItem(value: 'store_admin', child: Text('Warehouse Admin (Store Admin)', overflow: TextOverflow.ellipsis)),
                  DropdownMenuItem(value: 'field_sales_manager', child: Text('Field Sales Manager', overflow: TextOverflow.ellipsis)),
                  DropdownMenuItem(value: 'salesman', child: Text('Salesman (Retail Rate)', overflow: TextOverflow.ellipsis)),
                  DropdownMenuItem(value: 'distributor', child: Text('Distributor (Bulk Wholesale Rate)', overflow: TextOverflow.ellipsis)),
                ],
                onChanged: (v) {
                  if (v != null) {
                    setDialogState(() {
                      selectedRole = v;
                      updateForm(selectedRole);
                    });
                  }
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: priceCtrl,
                decoration: const InputDecoration(labelText: 'Selling Price (₹)', prefixText: '₹'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: discountCtrl,
                decoration: const InputDecoration(labelText: 'Promotional Discount (%)', suffixText: '%'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent, foregroundColor: Colors.white),
              onPressed: () async {
                final priceVal = double.tryParse(priceCtrl.text);
                final discountVal = double.tryParse(discountCtrl.text) ?? 0.0;
                if (priceVal == null || priceVal <= 0) return;

                try {
                  await http.post(
                    Uri.parse('${AppState.apiBaseUrl}/products/prices'),
                    headers: {'Content-Type': 'application/json'},
                    body: jsonEncode({
                      'product_id': product['id'],
                      'role': selectedRole,
                      'price': priceVal,
                      'discount_percentage': discountVal,
                      'admin_id': AppState.currentUser?['id'],
                      'admin_name': AppState.currentUser?['name']
                    }),
                  );
                  _loadPrices();
                  _loadAuditLogs();
                  if (ctx.mounted) Navigator.pop(ctx);
                } catch (_) {
                  setState(() {
                    _prices.removeWhere((p) => p['product_id'] == product['id'] && p['role'] == selectedRole);
                    _prices.add({
                      'product_id': product['id'],
                      'role': selectedRole,
                      'price': priceVal,
                      'discount_percentage': discountVal,
                    });
                  });
                  if (ctx.mounted) Navigator.pop(ctx);
                }
              },
              child: const Text('Set Tier Price'),
            ),
          ],
        ),
      ),
    );
  }

  void _showReferralConfigDialog() {
    final rateCtrl = TextEditingController(text: (_referralRules['commission_per_bottle'] ?? _referralRules['bonus_value'] ?? 1.0).toString());
    final quotaCtrl = TextEditingController(text: (_referralRules['min_sales_quota'] ?? _referralRules['min_purchase_amount'] ?? 5).toString());
    bool isActive = _referralRules['is_active'] ?? true;
    bool isQuotaConditionActive = _referralRules['is_quota_condition_active'] ?? true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.tune, color: AppColors.primary),
              SizedBox(width: 8),
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text('Workforce Referral Policy'),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: const Color(0xFFFBF4ED), borderRadius: BorderRadius.circular(8)),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, size: 18, color: AppColors.primary),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Applicable strictly to Store Admin, FSM & Salesmen. Customers have NO referral policy.',
                          style: TextStyle(fontSize: 11, color: AppColors.textPrimary),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Program Active', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: const Text('Enable or pause downline bottle commissions', style: TextStyle(fontSize: 12)),
                  value: isActive,
                  activeThumbColor: AppColors.accent,
                  onChanged: (v) => setDialogState(() => isActive = v),
                ),
                const Divider(),
                const SizedBox(height: 6),
                TextField(
                  controller: rateCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Commission per Bottle Sold (₹)',
                    hintText: 'e.g. 1.00',
                    prefixText: '₹ ',
                    border: OutlineInputBorder(),
                    helperText: 'Referrer earns this amount per bottle sold by their referral',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Enforce Minimum Sales Quota', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: const Text('Referrer must sell minimum bottles to qualify for downline commission', style: TextStyle(fontSize: 12)),
                  value: isQuotaConditionActive,
                  activeThumbColor: AppColors.accent,
                  onChanged: (v) => setDialogState(() => isQuotaConditionActive = v),
                ),
                if (isQuotaConditionActive) ...[
                  const SizedBox(height: 8),
                  TextField(
                    controller: quotaCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Minimum Personal Sales Quota (Bottles)',
                      hintText: 'e.g. 5',
                      suffixText: 'bottles',
                      border: OutlineInputBorder(),
                      helperText: 'If personal sales < quota, downline commission is held as Quota Pending',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
              onPressed: () async {
                final rateVal = double.tryParse(rateCtrl.text) ?? 1.0;
                final quotaVal = int.tryParse(quotaCtrl.text) ?? 5;

                final bodyData = {
                  'commission_per_bottle': rateVal,
                  'min_sales_quota': quotaVal,
                  'is_quota_condition_active': isQuotaConditionActive,
                  'is_active': isActive,
                  'admin_id': AppState.currentUser?['id'],
                  'admin_name': AppState.currentUser?['name'],
                };

                try {
                  await http.post(
                    Uri.parse('${AppState.apiBaseUrl}/referrals/rules'),
                    headers: {'Content-Type': 'application/json'},
                    body: jsonEncode(bodyData),
                  );
                  _loadReferralRules();
                  _loadReferralTree();
                  _loadReferrals();
                  _loadAuditLogs();
                  if (ctx.mounted) Navigator.pop(ctx);
                } catch (_) {
                  setState(() => _referralRules = bodyData);
                  if (ctx.mounted) Navigator.pop(ctx);
                }
              },
              child: const Text('Save Policy'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _processReferralPayout(String id) async {
    try {
      await http.post(
        Uri.parse('${AppState.apiBaseUrl}/referrals/$id/payout'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'admin_id': AppState.currentUser?['id'],
          'admin_name': AppState.currentUser?['name']
        }),
      );
      _loadReferrals();
      _loadAuditLogs();
      _loadSummary();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Referral payout processed!')));
      }
    } catch (_) {
      setState(() {
        final r = _referrals.firstWhere((x) => x['id'] == id, orElse: () => <String, dynamic>{});
        if (r.isNotEmpty) r['status'] = 'paid';
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payout recorded locally!')));
      }
    }
  }

  void _showAddWarehouseDialog([Map<String, dynamic>? editWarehouse]) {
    final nameCtrl = TextEditingController(text: editWarehouse?['name']?.toString() ?? '');
    final locCtrl = TextEditingController(text: editWarehouse?['location']?.toString() ?? '');
    final isEdit = editWarehouse != null;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(isEdit ? Icons.edit_outlined : Icons.warehouse_outlined, color: AppColors.primary),
            const SizedBox(width: 8),
            Text(isEdit ? 'Edit Warehouse' : 'Register Warehouse', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: InputDecoration(
                labelText: 'Warehouse Name',
                hintText: 'e.g. South Central Hub',
                prefixIcon: const Icon(Icons.business_outlined),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: locCtrl,
              decoration: InputDecoration(
                labelText: 'Location / City',
                hintText: 'e.g. Pune, Maharashtra',
                prefixIcon: const Icon(Icons.location_on_outlined),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
            onPressed: () async {
              final name = nameCtrl.text.trim();
              final location = locCtrl.text.trim();
              if (name.isEmpty) return;

              try {
                if (isEdit) {
                  final whId = editWarehouse['id'];
                  await http.put(
                    Uri.parse('${AppState.apiBaseUrl}/warehouses/$whId'),
                    headers: {'Content-Type': 'application/json'},
                    body: jsonEncode({'name': name, 'location': location}),
                  );
                } else {
                  await http.post(
                    Uri.parse('${AppState.apiBaseUrl}/warehouses'),
                    headers: {'Content-Type': 'application/json'},
                    body: jsonEncode({'name': name, 'location': location}),
                  );
                }
                _loadWarehouses();
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(isEdit ? 'Warehouse updated successfully!' : 'Warehouse registered successfully!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (_) {
                if (isEdit) {
                  setState(() {
                    final idx = _warehouses.indexWhere((w) => w['id'] == editWarehouse['id']);
                    if (idx != -1) {
                      _warehouses[idx]['name'] = name;
                      _warehouses[idx]['location'] = location;
                    }
                  });
                } else {
                  setState(() => _warehouses.add({
                    'id': 'w_${DateTime.now().millisecondsSinceEpoch}',
                    'name': name,
                    'location': location,
                  }));
                }
                if (ctx.mounted) Navigator.pop(ctx);
              }
            },
            child: Text(isEdit ? 'Save Changes' : 'Register'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteWarehouse(Map<String, dynamic> w) {
    final whId = w['id']?.toString() ?? '';
    final whName = w['name']?.toString() ?? 'Warehouse';
    final whLoc = w['location']?.toString() ?? '';

    final stockCount = _globalStocks
        .where((s) => s['warehouse_id']?.toString() == whId)
        .fold<int>(0, (sum, item) => sum + (int.tryParse(item['quantity']?.toString() ?? '0') ?? 0));
    final staffCount = _workforce.where((u) => u['warehouse_id']?.toString() == whId).length;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.delete_forever, color: Colors.red.shade700, size: 26),
            const SizedBox(width: 8),
            const Text('Delete Warehouse', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Are you sure you want to permanently delete "$whName"?', style: const TextStyle(fontSize: 14)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Location: $whLoc', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.red.shade900)),
                  const SizedBox(height: 4),
                  Text('Current Inventory: $stockCount units', style: TextStyle(fontSize: 12, color: Colors.red.shade800)),
                  Text('Assigned Personnel: $staffCount staff members', style: TextStyle(fontSize: 12, color: Colors.red.shade800)),
                  const SizedBox(height: 6),
                  const Text('Deleting will unlink staff and purge stock associated with this hub.', style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.red)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx);
              final prevList = List<Map<String, dynamic>>.from(_warehouses);
              setState(() => _warehouses.removeWhere((item) => item['id']?.toString() == whId));
              try {
                final res = await http.delete(Uri.parse('${AppState.apiBaseUrl}/warehouses/$whId'));
                if (res.statusCode == 200) {
                  _loadWarehouses();
                  _loadGlobalStocks();
                  _loadWorkforce();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Warehouse "$whName" deleted successfully!'), backgroundColor: Colors.red.shade700),
                    );
                  }
                } else {
                  setState(() {
                    _warehouses.clear();
                    _warehouses.addAll(prevList);
                  });
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Failed to delete warehouse on server.')),
                    );
                  }
                }
              } catch (_) {
                _loadWarehouses();
              }
            },
            child: const Text('Delete Permanently'),
          ),
        ],
      ),
    );
  }

  // --- BUILD VIEWS ---

  Widget _buildHubView() {
    final totalStock = (_summary['totalStock'] as num?)?.toInt() ??
        _globalStocks.fold<int>(0, (sum, item) => sum + (int.tryParse(item['quantity']?.toString() ?? '0') ?? 0));

    final todaySalesAmount = (_summary['todaySalesAmount'] as num?)?.toDouble() ?? 0.0;
    final todaySalesBottles = (_summary['todaySalesBottles'] as num?)?.toInt() ?? 0;
    final todaySalesCount = (_summary['todaySalesCount'] as num?)?.toInt() ?? 0;

    final pendingSettlementCount = (_summary['pendingSettlementCount'] as num?)?.toInt() ??
        _settlements.where((s) => (s['status'] != 'settled' && s['status'] != 'reconciled') || (double.tryParse(s['difference']?.toString() ?? '0') ?? 0).abs() > 0.01).length;
    final pendingSettlementAmount = (_summary['pendingSettlementAmount'] as num?)?.toDouble() ??
        _settlements.where((s) => (s['status'] != 'settled' && s['status'] != 'reconciled') || (double.tryParse(s['difference']?.toString() ?? '0') ?? 0).abs() > 0.01)
            .fold<double>(0.0, (sum, s) => sum + (double.tryParse(s['difference']?.toString() ?? '0') ?? 0.0).abs());

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Low-stock warning banner if applicable
          if (_alerts.isNotEmpty)
            Card(
              color: Colors.red.shade50,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.red.shade200)),
              margin: const EdgeInsets.only(bottom: 16),
              child: ListTile(
                leading: const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 32),
                title: Text('${_alerts.length} Low-Stock Alert(s) Detected!', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                subtitle: Text('Items below safety threshold: ${_alerts.map((a) => a['product']?['name']).join(", ")}'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.red),
                onTap: () => setState(() {
                  _activeModule = 5;
                  _inventorySubTab = 2; // jump to alerts
                }),
              ),
            ),

          // Primary KPI Banner
          Card(
            color: AppColors.primary,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const Text('Total System Revenue', style: TextStyle(color: Colors.white70, fontSize: 14)),
                  const SizedBox(height: 8),
                  Text(
                    '₹${_summary['totalRevenue'] ?? _sales.fold<double>(0, (sum, i) => sum + (double.tryParse(i['amount'].toString()) ?? 0))}',
                    style: const TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(child: _kpiMiniCol('Active Workforce', '${_workforce.length} staff', () => setState(() => _activeModule = 1))),
                      Expanded(child: _kpiMiniCol('Warehouses', '${_warehouses.length} hubs', () => setState(() => _activeModule = 9))),
                      Expanded(child: _kpiMiniCol('Products', '${_products.length} SKUs', () => setState(() => _activeModule = 3))),
                    ],
                  )
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // DAILY OPERATIONAL PULSE (User focus: Total Stock, Today's Sale, Pending Settlement)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Daily Operational Pulse', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle)),
                    const SizedBox(width: 5),
                    const Text('LIVE', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 11)),
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
                subtitle: pendingSettlementAmount > 0 ? '₹${pendingSettlementAmount.toStringAsFixed(0)} diff' : 'Reconciled',
                onTap: () => setState(() => _activeModule = 8),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Executive Module Operations Grid
          const Text('Super Admin Operations', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.08,
            children: [
              _moduleCard(Icons.group_outlined, 'Workforce & Users', '${_workforce.length} Accounts', () => setState(() => _activeModule = 1)),
              _moduleCard(Icons.security_outlined, 'Role Permissions', 'Dynamic RBAC Matrix', () => setState(() => _activeModule = 2)),
              _moduleCard(Icons.inventory_2_outlined, 'Catalog & Pricing', '${_products.length} Products & Tiers', () => setState(() => _activeModule = 3)),
              _moduleCard(Icons.account_tree_outlined, 'Workforce Referrals', '${_referrals.where((r) => r['status'] == 'unlocked' || r['status'] == 'pending').length} Pending Payouts', () => setState(() => _activeModule = 4)),
              _moduleCard(Icons.swap_horiz_outlined, 'Stock & Movement', '$totalStock Total Units', () => setState(() => _activeModule = 5)),
              _moduleCard(Icons.point_of_sale_outlined, 'Sales Oversight', '₹${todaySalesAmount.toStringAsFixed(0)} Today', () => setState(() => _activeModule = 6)),
              _moduleCard(Icons.assignment_turned_in_outlined, 'Daily Settlements', '$pendingSettlementCount Pending Review', () => setState(() => _activeModule = 8)),
              _moduleCard(Icons.receipt_long_outlined, 'Payments History', '₹${(double.tryParse(_paymentsSummary['total_collected']?.toString() ?? '0') ?? todaySalesAmount).toStringAsFixed(0)} Inflow', () => setState(() => _activeModule = 10)),
              _moduleCard(Icons.warehouse_outlined, 'Warehouses', '${_warehouses.length} Active Hubs', () => setState(() => _activeModule = 9)),
              _moduleCard(Icons.history_edu_outlined, 'Audit Trail', '${_auditLogs.length} Events Logged', () => setState(() => _activeModule = 7)),
            ],
          ),
        ],
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
                  style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: AppColors.textSecondary, letterSpacing: 0.3),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 9.5, color: AppColors.textSecondary.withValues(alpha: 0.8)),
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
          child: Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(label, style: const TextStyle(color: Colors.white60, fontSize: 11)),
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

  Widget _moduleCard(IconData icon, String title, String subtitle, VoidCallback onTap) {
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
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 10.5),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- MODULE 1: WORKFORCE MANAGEMENT ---
  Widget _buildWorkforceModule() {
    return WorkforceRequestsPage(
      showBackButton: true,
      onBack: () {
        _loadAllData();
        setState(() => _activeModule = 0);
      },
    );
  }

  // --- MODULE 2: ROLE PERMISSIONS MATRIX ---
  Widget _buildPermissionsModule() {
    final roles = ['store_admin', 'field_sales_manager', 'salesman'];
    final capabilities = [
      {'key': 'add_stock', 'title': 'Intake & Add Stock'},
      {'key': 'transfer_fsm', 'title': 'Transfer Stock to FSM'},
      {'key': 'transfer_salesman', 'title': 'Transfer Stock to Salesman'},
      {'key': 'direct_sale', 'title': 'Direct Sale to Customer'},
      {'key': 'bulk_sale_distributor', 'title': 'Bulk Wholesale to Distributor'},
      {'key': 'onboard_customer', 'title': 'Onboard New Customer'},
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Role & Permission Matrix'),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => setState(() => _activeModule = 0)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Dynamic Access Control (RBAC)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.textPrimary)),
          const SizedBox(height: 6),
          const Text('Toggle capabilities per role in real-time. Changes are logged to the audit trail immediately.', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          const SizedBox(height: 20),
          for (final r in roles) ...[
            Card(
              color: AppColors.cardBg,
              margin: const EdgeInsets.only(bottom: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ExpansionTile(
                initiallyExpanded: true,
                title: Text(r.replaceAll('_', ' ').toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
                subtitle: const Text('Tap to configure capabilities'),
                children: [
                  const Divider(height: 1),
                  for (final cap in capabilities) ...[
                    SwitchListTile(
                      title: Text(cap['title']!),
                      value: _permissions.any((p) => p['role'] == r && p['permission_key'] == cap['key'] && p['is_allowed'] == true),
                      activeThumbColor: AppColors.accent,
                      onChanged: (_) {
                        final curr = _permissions.any((p) => p['role'] == r && p['permission_key'] == cap['key'] && p['is_allowed'] == true);
                        _togglePermission(r, cap['key']!, curr);
                      },
                    ),
                  ]
                ],
              ),
            ),
          ]
        ],
      ),
    );
  }

  // --- MODULE 3: PRODUCT CATALOG & TIERED PRICING ---
  Widget _buildProductsModule() {
    final availableCount = _products.where((p) => p['is_active'] != false).length;
    final notAvailableCount = _products.where((p) => p['is_active'] == false).length;

    // Filter products by search and availability
    final filteredProducts = _products.where((p) {
      final name = (p['name'] ?? '').toString().toLowerCase();
      final sku = (p['sku'] ?? '').toString().toLowerCase();
      final cat = (p['category'] ?? '').toString().toLowerCase();
      final query = _productSearchQuery.toLowerCase().trim();

      final matchesQuery = query.isEmpty || name.contains(query) || sku.contains(query) || cat.contains(query);
      if (!matchesQuery) return false;

      final isAvail = p['is_active'] != false;
      if (_productAvailabilityFilter == 'available') return isAvail;
      if (_productAvailabilityFilter == 'not_available') return !isAvail;
      return true; // 'all'
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Product Catalog & Pricing'),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => setState(() => _activeModule = 0)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _loadProducts();
              _loadAlerts();
            },
            tooltip: 'Refresh Products',
          ),
        ],
      ),
      body: Column(
        children: [
          // Search & Filter Header
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            color: AppColors.background,
            child: Column(
              children: [
                TextField(
                  controller: _productSearchCtrl,
                  decoration: InputDecoration(
                    hintText: 'Search products by name, SKU, category...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: _productSearchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _productSearchCtrl.clear();
                              setState(() => _productSearchQuery = '');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
                  ),
                  onChanged: (val) => setState(() => _productSearchQuery = val),
                ),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      FilterChip(
                        selected: _productAvailabilityFilter == 'all',
                        label: Text('All (${_products.length})'),
                        selectedColor: AppColors.primary.withValues(alpha: 0.15),
                        checkmarkColor: AppColors.primary,
                        labelStyle: TextStyle(
                          fontSize: 12,
                          fontWeight: _productAvailabilityFilter == 'all' ? FontWeight.bold : FontWeight.normal,
                          color: _productAvailabilityFilter == 'all' ? AppColors.primary : AppColors.textSecondary,
                        ),
                        onSelected: (_) => setState(() => _productAvailabilityFilter = 'all'),
                      ),
                      const SizedBox(width: 8),
                      FilterChip(
                        selected: _productAvailabilityFilter == 'available',
                        avatar: const CircleAvatar(radius: 4, backgroundColor: Colors.green),
                        label: Text('Available ($availableCount)'),
                        selectedColor: Colors.green.shade100,
                        checkmarkColor: Colors.green.shade800,
                        labelStyle: TextStyle(
                          fontSize: 12,
                          fontWeight: _productAvailabilityFilter == 'available' ? FontWeight.bold : FontWeight.normal,
                          color: _productAvailabilityFilter == 'available' ? Colors.green.shade900 : AppColors.textSecondary,
                        ),
                        onSelected: (_) => setState(() => _productAvailabilityFilter = 'available'),
                      ),
                      const SizedBox(width: 8),
                      FilterChip(
                        selected: _productAvailabilityFilter == 'not_available',
                        avatar: const CircleAvatar(radius: 4, backgroundColor: Colors.red),
                        label: Text('Not Available ($notAvailableCount)'),
                        selectedColor: Colors.red.shade100,
                        checkmarkColor: Colors.red.shade800,
                        labelStyle: TextStyle(
                          fontSize: 12,
                          fontWeight: _productAvailabilityFilter == 'not_available' ? FontWeight.bold : FontWeight.normal,
                          color: _productAvailabilityFilter == 'not_available' ? Colors.red.shade900 : AppColors.textSecondary,
                        ),
                        onSelected: (_) => setState(() => _productAvailabilityFilter = 'not_available'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Products List
          Expanded(
            child: filteredProducts.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.inventory_2_outlined, size: 54, color: Colors.grey.shade400),
                          const SizedBox(height: 12),
                          Text(
                            _productSearchQuery.isNotEmpty
                                ? 'No products matching "$_productSearchQuery"'
                                : (_productAvailabilityFilter == 'not_available'
                                    ? 'No unavailable products found'
                                    : 'No products found'),
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.grey.shade700),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _productSearchQuery.isNotEmpty
                                ? 'Try clearing your search keyword'
                                : 'Add products to your catalog using the button below',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: filteredProducts.length,
                    itemBuilder: (ctx, idx) {
                      final p = filteredProducts[idx];
                      final isAvail = p['is_active'] != false;

                      return Card(
                        color: AppColors.cardBg,
                        elevation: isAvail ? 2 : 1,
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: isAvail ? Colors.transparent : Colors.red.shade200,
                            width: isAvail ? 0 : 1.2,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Top Title & Badges Row
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          p['name'] ?? '',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                            color: isAvail ? AppColors.textPrimary : Colors.grey.shade600,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Wrap(
                                          spacing: 6,
                                          runSpacing: 4,
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: Colors.brown.shade50,
                                                borderRadius: BorderRadius.circular(4),
                                                border: Border.all(color: Colors.brown.shade200),
                                              ),
                                              child: Text('SKU: ${p['sku']}', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Colors.brown.shade900)),
                                            ),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: Colors.blueGrey.shade50,
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Text(p['category'] ?? 'General', style: TextStyle(fontSize: 10.5, color: Colors.blueGrey.shade800)),
                                            ),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: Colors.orange.shade50,
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Text('Unit: ${p['unit']}', style: TextStyle(fontSize: 10.5, color: Colors.orange.shade900)),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  // Status Badge
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: isAvail ? Colors.green.shade50 : Colors.red.shade50,
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(color: isAvail ? Colors.green.shade300 : Colors.red.shade300),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(isAvail ? Icons.check_circle : Icons.do_not_disturb_on, size: 12, color: isAvail ? Colors.green.shade800 : Colors.red.shade800),
                                        const SizedBox(width: 4),
                                        Text(
                                          isAvail ? 'AVAILABLE' : 'NOT AVAILABLE',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: isAvail ? Colors.green.shade800 : Colors.red.shade800,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),

                              // Pricing & Low Stock Indicator
                              Row(
                                children: [
                                  Text(
                                    'Base Price: ₹${p['base_price']}',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: AppColors.primary),
                                  ),
                                  const Spacer(),
                                  Text(
                                    'Low Stock Alert: < ${p['min_stock_alert'] ?? 20} ${p['unit']}',
                                    style: TextStyle(color: Colors.amber.shade900, fontSize: 11.5, fontWeight: FontWeight.w500),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),

                              // Availability Toggle Banner
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isAvail ? Colors.green.shade50.withValues(alpha: 0.6) : Colors.red.shade50.withValues(alpha: 0.6),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: isAvail ? Colors.green.shade200 : Colors.red.shade200),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        isAvail ? 'Product Available for Ordering' : 'Product Marked Not Available',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: isAvail ? Colors.green.shade900 : Colors.red.shade900,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Row(
                                      children: [
                                        Text(
                                          isAvail ? 'Available' : 'Unavailable',
                                          style: TextStyle(fontSize: 11, color: isAvail ? Colors.green.shade800 : Colors.red.shade800),
                                        ),
                                        Transform.scale(
                                          scale: 0.8,
                                          child: Switch(
                                            value: isAvail,
                                            activeThumbColor: Colors.green,
                                            inactiveThumbColor: Colors.red,
                                            onChanged: (val) => _toggleProductAvailability(p, val),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const Divider(height: 18),

                              // Action Row: Tiered Prices, Edit, Delete
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: AppColors.accent,
                                        side: const BorderSide(color: AppColors.accent),
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                      ),
                                      icon: const Icon(Icons.sell, size: 15),
                                      label: const Text('Set Role & Bulk Prices', style: TextStyle(fontSize: 12)),
                                      onPressed: () => _showTieredPricingDialog(p),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    icon: const Icon(Icons.edit, size: 20, color: Colors.blue),
                                    tooltip: 'Edit Product Details',
                                    onPressed: () => _showAddOrEditProductDialog(editProduct: p),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                                    tooltip: 'Delete Product',
                                    onPressed: () => _confirmDeleteProduct(p),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddOrEditProductDialog(),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add_shopping_cart, color: Colors.white),
        label: const Text('Add Product', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  // --- MODULE 4: WORKFORCE REFERRAL & COMMISSION MANAGEMENT ---
  Widget _buildReferralsModule() {
    final rate = _referralRules['commission_per_bottle'] ?? 1.0;
    final quota = _referralRules['min_sales_quota'] ?? 5;
    final isQuotaActive = _referralRules['is_quota_condition_active'] != false;
    final isProgramActive = _referralRules['is_active'] != false;
    final treeList = (_referralTreeData['tree'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Workforce Referrals'),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => setState(() => _activeModule = 0)),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune),
            tooltip: 'Configure Policy',
            onPressed: _showReferralConfigDialog,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () {
              _loadReferralRules();
              _loadReferralTree();
              _loadReferrals();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Sub-tab Navigation
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _referralSubTab == 0 ? AppColors.primary : Colors.grey.shade100,
                      foregroundColor: _referralSubTab == 0 ? Colors.white : Colors.black87,
                      elevation: _referralSubTab == 0 ? 2 : 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () => setState(() => _referralSubTab = 0),
                    icon: const Icon(Icons.account_tree_outlined, size: 18),
                    label: const Text('Workforce Tree'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _referralSubTab == 1 ? AppColors.primary : Colors.grey.shade100,
                      foregroundColor: _referralSubTab == 1 ? Colors.white : Colors.black87,
                      elevation: _referralSubTab == 1 ? 2 : 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () => setState(() => _referralSubTab = 1),
                    icon: const Icon(Icons.receipt_long_outlined, size: 18),
                    label: Text('Ledger (${_referrals.length})'),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Super Admin Policy Overview Card
                  Card(
                    color: AppColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 3,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Expanded(
                                child: Row(
                                  children: [
                                    Icon(Icons.shield_outlined, color: Colors.white70, size: 16),
                                    SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        'WORKFORCE REFERRAL POLICY',
                                        style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 0.5),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Chip(
                                label: Text(isProgramActive ? 'ACTIVE' : 'PAUSED'),
                                backgroundColor: isProgramActive ? Colors.green : Colors.grey,
                                labelStyle: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                visualDensity: VisualDensity.compact,
                                padding: EdgeInsets.zero,
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '₹$rate per Bottle Sold',
                            style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  isQuotaActive ? Icons.lock_clock : Icons.lock_open,
                                  color: isQuotaActive ? Colors.amber.shade200 : Colors.green.shade200,
                                  size: 16,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    isQuotaActive
                                        ? 'Condition Gate Active: Referrer must sell >= $quota bottles today for downline commissions to unlock.'
                                        : 'Gate Inactive: Commissions unlock immediately with no sales quota.',
                                    style: const TextStyle(color: Colors.white, fontSize: 11),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                          Align(
                            alignment: Alignment.centerRight,
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                side: const BorderSide(color: Colors.white70),
                                visualDensity: VisualDensity.compact,
                              ),
                              onPressed: _showReferralConfigDialog,
                              icon: const Icon(Icons.edit, size: 14),
                              label: const Text('Edit Policy & Quota'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // SUBTAB 0: WORKFORCE TREE VIEW
                  if (_referralSubTab == 0) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Workforce Tree Hierarchy',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: AppColors.textPrimary),
                        ),
                        Text(
                          '${_referralTreeData['total_salesmen'] ?? treeList.length} Salesmen',
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Tree displays direct downlines (A ➔ B, D; B ➔ C). Referrer receives ₹$rate per bottle sold by their referral.',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 12),
                    if (treeList.isEmpty)
                      Card(
                        color: AppColors.cardBg,
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            children: [
                              Icon(Icons.account_tree_outlined, size: 48, color: Colors.grey.shade400),
                              const SizedBox(height: 12),
                              const Text('No workforce tree nodes found', style: TextStyle(fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              Text('Salesmen referral relationships will appear here.', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                            ],
                          ),
                        ),
                      )
                    else
                      ...treeList.map((rootNode) => _buildWorkforceTreeNode(rootNode, 0)),
                  ],

                  // SUBTAB 1: COMMISSION LEDGER & PAYOUTS
                  if (_referralSubTab == 1) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Commissions Ledger',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: AppColors.textPrimary),
                        ),
                        Text(
                          '${_referrals.length} Transactions',
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_referrals.isEmpty)
                      Card(
                        color: AppColors.cardBg,
                        child: const Padding(
                          padding: EdgeInsets.all(24),
                          child: Center(
                            child: Text('No referral commissions recorded yet.'),
                          ),
                        ),
                      )
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _referrals.length,
                        itemBuilder: (ctx, idx) {
                          final ref = _referrals[idx];
                          final status = (ref['status'] ?? 'pending').toString().toLowerCase();
                          final isPaid = status == 'paid';
                          final isUnlocked = status == 'unlocked' || status == 'pending';
                          final isQuotaPending = status == 'quota_pending';

                          Color statusColor = Colors.orange;
                          String statusLabel = 'QUOTA PENDING';
                          IconData statusIcon = Icons.lock_clock;

                          if (isPaid) {
                            statusColor = Colors.green;
                            statusLabel = 'PAID';
                            statusIcon = Icons.check_circle;
                          } else if (isUnlocked) {
                            statusColor = Colors.blue;
                            statusLabel = 'UNLOCKED';
                            statusIcon = Icons.lock_open;
                          }

                          return Card(
                            color: AppColors.cardBg,
                            margin: const EdgeInsets.only(bottom: 12),
                            elevation: 1,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 16,
                                        backgroundColor: statusColor.withValues(alpha: 0.15),
                                        child: Icon(statusIcon, color: statusColor, size: 18),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              '${ref['referrer_name'] ?? 'Referrer'} ➔ ${ref['referred_name'] ?? ref['seller_name'] ?? 'Seller'}',
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              'Sold: ${ref['bottles_sold'] ?? 0} bottles @ ₹${ref['rate_per_bottle'] ?? rate}/bottle',
                                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            '₹${(ref['commission_amount'] ?? ref['bonus_amount'] ?? 0)}',
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.primary),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: statusColor.withValues(alpha: 0.1),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              statusLabel,
                                              style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: statusColor),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  if (isQuotaPending) ...[
                                    const SizedBox(height: 8),
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.amber.shade50,
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: Colors.amber.shade200),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(Icons.info_outline, size: 14, color: Colors.amber.shade900),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Text(
                                              'Held: Referrer has not yet met the minimum quota of $quota personal bottles sold.',
                                              style: TextStyle(fontSize: 11, color: Colors.amber.shade900),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                  if (isUnlocked) ...[
                                    const SizedBox(height: 10),
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppColors.accent,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                          visualDensity: VisualDensity.compact,
                                        ),
                                        onPressed: () => _processReferralPayout(ref['id']),
                                        icon: const Icon(Icons.payments, size: 14),
                                        label: const Text('Disburse Payout'),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkforceTreeNode(Map<String, dynamic> node, int depth) {
    final name = node['name']?.toString() ?? 'Salesman';
    final bottlesSold = node['bottles_sold_today'] ?? 0;
    final minQuota = node['min_quota'] ?? 5;
    final isQualified = node['is_qualified'] == true;
    final unlockedComm = (node['unlocked_commission'] as num?)?.toDouble() ?? 0.0;
    final pendingComm = (node['pending_commission'] as num?)?.toDouble() ?? 0.0;
    final children = (node['children'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    return Container(
      margin: EdgeInsets.only(left: depth * 16.0, bottom: 10),
      decoration: BoxDecoration(
        color: depth == 0 ? Colors.white : AppColors.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: depth == 0 ? AppColors.primary.withValues(alpha: 0.35) : Colors.grey.shade300,
          width: depth == 0 ? 1.5 : 1,
        ),
        boxShadow: depth == 0 ? [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 4, offset: const Offset(0, 2))
        ] : null,
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 17,
                  backgroundColor: depth == 0 ? AppColors.primary : AppColors.accent,
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : 'S',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              name,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (depth == 0) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                              decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(4)),
                              child: const Text('ROOT', style: TextStyle(color: AppColors.primary, fontSize: 9, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Sales: $bottlesSold / $minQuota btls sold today',
                        style: TextStyle(color: Colors.grey.shade700, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isQualified ? Colors.green.shade50 : Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: isQualified ? Colors.green.shade300 : Colors.amber.shade300),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(isQualified ? Icons.verified : Icons.hourglass_empty, size: 12, color: isQualified ? Colors.green.shade700 : Colors.amber.shade800),
                      const SizedBox(width: 4),
                      Text(
                        isQualified ? 'Qualified' : 'Pending Quota',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isQualified ? Colors.green.shade800 : Colors.amber.shade900,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                _treeStatChip(Icons.people_outline, '${node['downline_count'] ?? 0} Downlines', Colors.blueGrey),
                _treeStatChip(Icons.payments_outlined, '₹${unlockedComm.toStringAsFixed(0)} Earned', Colors.green),
                if (pendingComm > 0)
                  _treeStatChip(Icons.lock_clock, '₹${pendingComm.toStringAsFixed(0)} Quota-Held', Colors.orange),
              ],
            ),
            if (children.isNotEmpty) ...[
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Row(
                  children: [
                    const Icon(Icons.subdirectory_arrow_right, size: 15, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(
                      'Referred Downlines (${children.length}):',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade700),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              ...children.map((child) => _buildWorkforceTreeNode(child, depth + 1)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _treeStatChip(IconData icon, String label, MaterialColor color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(
        color: color.shade50,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color.shade700),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color.shade900)),
        ],
      ),
    );
  }

  // --- MODULE 5: INVENTORY OVERSIGHT & TRANSFERS ---
  Widget _buildInventoryModule() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventory & Stock Movement'),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => setState(() => _activeModule = 0)),
      ),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            width: double.infinity,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _subTabButton(0, 'Global Balances'),
                  _subTabButton(1, 'Transfer Ledger'),
                  _subTabButton(2, 'Low Stock (${_alerts.length})'),
                ],
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _inventorySubTab == 0
                ? _buildGlobalStockList()
                : _inventorySubTab == 1
                    ? _buildTransferLedgerList()
                    : _buildAlertsList(),
          )
        ],
      ),
    );
  }

  Widget _subTabButton(int idx, String title) {
    final isSelected = _inventorySubTab == idx;
    return TextButton(
      onPressed: () => setState(() => _inventorySubTab = idx),
      child: Text(
        title,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? AppColors.accent : AppColors.textSecondary,
          decoration: isSelected ? TextDecoration.underline : TextDecoration.none,
        ),
      ),
    );
  }

  Widget _buildGlobalStockList() {
    return _globalStocks.isEmpty
        ? const Center(child: Text('No stock recorded'))
        : ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: _globalStocks.length,
            itemBuilder: (ctx, idx) {
              final s = _globalStocks[idx];
              return Card(
                color: AppColors.cardBg,
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  title: Text(s['product']?['name'] ?? 'Product'),
                  subtitle: Text('Held by: ${s['owner_name']}'),
                  trailing: Chip(
                    label: Text('${s['quantity']} units', style: const TextStyle(fontWeight: FontWeight.bold)),
                    backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                  ),
                ),
              );
            },
          );
  }

  Widget _buildTransferLedgerList() {
    return _transfers.isEmpty
        ? const Center(child: Text('No transfer movements recorded'))
        : ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: _transfers.length,
            itemBuilder: (ctx, idx) {
              final t = _transfers[idx];
              return Card(
                color: AppColors.cardBg,
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  leading: const CircleAvatar(backgroundColor: Colors.blueGrey, child: Icon(Icons.swap_horiz, color: Colors.white)),
                  title: Text('${t['from_name']} ➔ ${t['to_name']}'),
                  subtitle: Text('Item: ${t['product']?['name'] ?? 'Product'} • Qty: ${t['quantity']}'),
                  trailing: const Chip(label: Text('Completed', style: TextStyle(fontSize: 10, color: Colors.green))),
                ),
              );
            },
          );
  }

  Widget _buildAlertsList() {
    return _alerts.isEmpty
        ? const Center(child: Text('All stock levels are above safety thresholds!'))
        : ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: _alerts.length,
            itemBuilder: (ctx, idx) {
              final a = _alerts[idx];
              return Card(
                color: Colors.red.shade50,
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  leading: const Icon(Icons.warning, color: Colors.red),
                  title: Text(a['product']?['name'] ?? 'Product', style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('Total Available: ${a['total_quantity']} • Threshold: ${a['threshold']}'),
                  trailing: Chip(label: Text('Deficit: -${a['deficit']}', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold))),
                ),
              );
            },
          );
  }

  // --- MODULE 6: SALES OVERSIGHT ---
  Widget _buildSalesModule() {
    final filteredSales = _sales.filterSales(_salesPaymentFilter, _salesCustomerFilter);

    return Scaffold(
      appBar: AppBar(
        title: const Text('System Sales Oversight'),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => setState(() => _activeModule = 0)),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _salesPaymentFilter,
                    decoration: const InputDecoration(labelText: 'Payment Mode', contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 4)),
                    items: const [
                      DropdownMenuItem(value: 'all', child: Text('All Payments')),
                      DropdownMenuItem(value: 'online', child: Text('Online Only')),
                      DropdownMenuItem(value: 'cash', child: Text('Cash Only')),
                    ],
                    onChanged: (v) => setState(() => _salesPaymentFilter = v ?? 'all'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _salesCustomerFilter,
                    decoration: const InputDecoration(labelText: 'Customer Tier', contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 4)),
                    items: const [
                      DropdownMenuItem(value: 'all', child: Text('All Customers')),
                      DropdownMenuItem(value: 'retail', child: Text('Retail')),
                      DropdownMenuItem(value: 'distributor', child: Text('Distributor')),
                    ],
                    onChanged: (v) => setState(() => _salesCustomerFilter = v ?? 'all'),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: filteredSales.isEmpty
                ? const Center(child: Text('No sales found matching criteria'))
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: filteredSales.length,
                    itemBuilder: (ctx, idx) {
                      final s = filteredSales[idx];
                      final isOnline = s['payment_method'] == 'online';
                      return Card(
                        color: AppColors.cardBg,
                        margin: const EdgeInsets.only(bottom: 10),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: isOnline ? Colors.green.shade100 : Colors.amber.shade100,
                            child: Icon(isOnline ? Icons.payment : Icons.money, color: isOnline ? Colors.green : Colors.amber.shade800),
                          ),
                          title: Text(s['product']?['name'] ?? 'Product'),
                          subtitle: Text('Sold by: ${s['salesman']?['name'] ?? 'Salesman'} • Qty: ${s['quantity']} • ${s['customer_type'] ?? 'retail'}'),
                          trailing: Text('₹${s['amount']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        ),
                      );
                    },
                  ),
          )
        ],
      ),
    );
  }

  // --- MODULE 7: AUDIT TRAIL VIEWER ---
  Widget _buildAuditLogsModule() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('System Audit Trail & Logs'),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => setState(() => _activeModule = 0)),
      ),
      body: _auditLogs.isEmpty
          ? const Center(child: Text('No audit events logged yet'))
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _auditLogs.length,
              itemBuilder: (ctx, idx) {
                final log = _auditLogs[idx];
                return Card(
                  color: AppColors.cardBg,
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    leading: const CircleAvatar(backgroundColor: Colors.indigo, child: Icon(Icons.history, color: Colors.white)),
                    title: Text(log['action'] ?? 'ACTION', style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('By: ${log['user_name'] ?? 'Admin'} on ${log['entity_name']}'),
                        Text('${log['details'] ?? ''}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  // --- MODULE 8: SALESMEN SETTLEMENT & DAILY RECONCILIATION ---
  Widget _buildSettlementOversightModule() {
    final filtered = _settlements.where((s) {
      if (_settlementFilter == 'pending') {
        return s['status'] != 'settled' && s['status'] != 'reconciled';
      } else if (_settlementFilter == 'tally_zero') {
        return (double.tryParse(s['difference']?.toString() ?? '0') ?? 0) == 0;
      } else if (_settlementFilter == 'has_diff') {
        return (double.tryParse(s['difference']?.toString() ?? '0') ?? 0).abs() > 0.01;
      } else if (_settlementFilter == 'settled') {
        return s['status'] == 'settled' || s['status'] == 'reconciled';
      }
      return true;
    }).toList();

    final pendingCount = _settlements.where((s) => s['status'] != 'settled' && s['status'] != 'reconciled').length;
    final totalDiff = _settlements.fold<double>(0.0, (sum, s) => sum + (double.tryParse(s['difference']?.toString() ?? '0') ?? 0.0).abs());

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settlements & Reconciliation'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => setState(() => _activeModule = 0),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAllData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                _stlFilterChip('all', 'All (${_settlements.length})'),
                _stlFilterChip('pending', 'Pending Review ($pendingCount)'),
                _stlFilterChip('has_diff', 'Discrepancies'),
                _stlFilterChip('tally_zero', 'Zero Difference'),
                _stlFilterChip('settled', 'Settled / Reconciled'),
              ],
            ),
          ),
          if (totalDiff > 0)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.amber.shade300),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Unsettled difference of ₹${totalDiff.toStringAsFixed(0)} pending reconciliation across salesmen.',
                      style: TextStyle(color: Colors.orange.shade900, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.assignment_turned_in_outlined, size: 54, color: AppColors.textSecondary.withValues(alpha: 0.5)),
                          const SizedBox(height: 12),
                          const Text(
                            'No Settlement Records Found',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Salesmen daily tally reports and end-of-day bottle settlements will be submitted here for Super Admin approval.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: filtered.length,
                    itemBuilder: (ctx, idx) {
                      final s = filtered[idx];
                      final salesman = s['salesman'] as Map<String, dynamic>?;
                      final salesmanName = salesman?['name'] ?? s['salesman_name'] ?? 'Salesman (${s['salesman_id'] ?? 'Unknown'})';
                      final dispatched = s['bottles_dispatched'] ?? 0;
                      final sold = s['bottles_sold'] ?? 0;
                      final unsold = s['unsold_bottles'] ?? 0;
                      final cash = double.tryParse(s['cash_collected']?.toString() ?? '0') ?? 0;
                      final diff = double.tryParse(s['difference']?.toString() ?? '0') ?? 0;
                      final status = (s['status'] ?? 'pending').toString().toLowerCase();
                      final isSettled = status == 'settled' || status == 'reconciled';
                      final hasDiff = diff.abs() > 0.01;

                      return Card(
                        color: AppColors.cardBg,
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: isSettled
                                ? Colors.green.shade200
                                : (hasDiff ? Colors.orange.shade300 : Colors.blue.shade200),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 18,
                                    backgroundColor: isSettled
                                        ? Colors.green.shade50
                                        : (hasDiff ? Colors.orange.shade50 : Colors.blue.shade50),
                                    child: Icon(
                                      isSettled
                                          ? Icons.check_circle_rounded
                                          : (hasDiff ? Icons.error_outline_rounded : Icons.pending_rounded),
                                      color: isSettled
                                          ? Colors.green
                                          : (hasDiff ? Colors.orange : Colors.blue),
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(salesmanName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                        Text('ID: ${s['id']} • Date: ${s['date_label'] ?? 'Today'}',
                                            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: isSettled
                                          ? Colors.green.withValues(alpha: 0.1)
                                          : (hasDiff ? Colors.orange.withValues(alpha: 0.1) : Colors.blue.withValues(alpha: 0.1)),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      isSettled ? 'SETTLED' : (hasDiff ? 'DIFFERENCE' : 'TALLY ZERO'),
                                      style: TextStyle(
                                        color: isSettled ? Colors.green : (hasDiff ? Colors.orange.shade800 : Colors.blue),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const Divider(height: 20),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceAround,
                                children: [
                                  _stlStatCol('Dispatched', '$dispatched btls'),
                                  _stlStatCol('Sold', '$sold btls'),
                                  _stlStatCol('Returned', '$unsold btls'),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.grey.withValues(alpha: 0.06),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('Cash Handover', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                                        Text('₹${cash.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.green)),
                                      ],
                                    ),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        const Text('Difference / Shortfall', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                                        Text(
                                          diff == 0 ? '₹0 (Perfect)' : '₹${diff.toStringAsFixed(0)}',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                            color: diff == 0 ? Colors.green : Colors.red,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              if (!isSettled) ...[
                                const SizedBox(height: 12),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    onPressed: () => _handleApproveSettlement(s['id']?.toString() ?? ''),
                                    icon: const Icon(Icons.verified, size: 16),
                                    label: const Text('Approve & Mark Reconciled'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primary,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 10),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _stlFilterChip(String value, String label) {
    final isSelected = _settlementFilter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        selectedColor: AppColors.primary.withValues(alpha: 0.15),
        checkmarkColor: AppColors.primary,
        labelStyle: TextStyle(
          color: isSelected ? AppColors.primary : AppColors.textSecondary,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          fontSize: 12,
        ),
        onSelected: (selected) {
          if (selected) setState(() => _settlementFilter = value);
        },
      ),
    );
  }

  Widget _stlStatCol(String label, String value) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
      ],
    );
  }

  Widget _buildWarehousesModule() {
    final query = _warehouseSearchQuery.trim().toLowerCase();
    final filteredWarehouses = _warehouses.where((w) {
      if (query.isEmpty) return true;
      final name = (w['name'] ?? '').toString().toLowerCase();
      final loc = (w['location'] ?? '').toString().toLowerCase();
      return name.contains(query) || loc.contains(query);
    }).toList();

    final totalSystemUnits = _globalStocks.fold<int>(
      0,
      (sum, item) => sum + (int.tryParse(item['quantity']?.toString() ?? '0') ?? 0),
    );
    final totalAssignedStaff = _workforce.where((u) => u['warehouse_id'] != null).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Warehouses & Hubs'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => setState(() => _activeModule = 0),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _loadWarehouses();
              _loadGlobalStocks();
              _loadWorkforce();
            },
            tooltip: 'Refresh Warehouses',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddWarehouseDialog(),
        icon: const Icon(Icons.add_business_outlined),
        label: const Text('Register Warehouse', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Search & Summary Area
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            color: AppColors.background,
            child: Column(
              children: [
                TextField(
                  controller: _warehouseSearchCtrl,
                  decoration: InputDecoration(
                    hintText: 'Search warehouses by name or location...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: _warehouseSearchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _warehouseSearchCtrl.clear();
                              setState(() => _warehouseSearchQuery = '');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                  ),
                  onChanged: (val) => setState(() => _warehouseSearchQuery = val),
                ),
                const SizedBox(height: 12),
                // Network Metrics summary row
                Row(
                  children: [
                    _whStatCard('Active Hubs', '${_warehouses.length}', Icons.warehouse, Colors.teal),
                    const SizedBox(width: 8),
                    _whStatCard('Total Units', '$totalSystemUnits', Icons.inventory_2, Colors.blue.shade700),
                    const SizedBox(width: 8),
                    _whStatCard('Assigned Staff', '$totalAssignedStaff', Icons.badge, Colors.purple.shade700),
                  ],
                ),
              ],
            ),
          ),

          // Warehouse Cards List
          Expanded(
            child: filteredWarehouses.isEmpty
                ? Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.warehouse_outlined, size: 64, color: Colors.grey.shade400),
                          const SizedBox(height: 16),
                          Text(
                            _warehouses.isEmpty ? 'No Warehouses Registered' : 'No Warehouses Found',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _warehouses.isEmpty
                                ? 'Add regional hubs and central warehouses to manage storage and distribution.'
                                : 'Try searching with a different name or location.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                          ),
                          const SizedBox(height: 20),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                            onPressed: () => _showAddWarehouseDialog(),
                            icon: const Icon(Icons.add),
                            label: const Text('Register Warehouse Now'),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
                    itemCount: filteredWarehouses.length,
                    itemBuilder: (ctx, index) {
                      final w = filteredWarehouses[index];
                      final whId = w['id']?.toString() ?? '';
                      final whName = w['name']?.toString() ?? 'Unnamed Warehouse';
                      final whLocation = w['location']?.toString() ?? 'Unknown';

                      // Find stocks in this warehouse
                      final whStocks = _globalStocks.where((s) => s['warehouse_id']?.toString() == whId).toList();
                      final whUnits = whStocks.fold<int>(0, (sum, s) => sum + (int.tryParse(s['quantity']?.toString() ?? '0') ?? 0));
                      final distinctSkus = whStocks.map((s) => s['product_id']).toSet().length;

                      // Find staff assigned
                      final whStaff = _workforce.where((u) => u['warehouse_id']?.toString() == whId).toList();
                      final storeAdmins = whStaff.where((u) => u['role'] == 'store_admin').toList();

                      return Card(
                        margin: const EdgeInsets.only(bottom: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(color: Colors.grey.shade200),
                        ),
                        elevation: 1.5,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Top Header: Icon, Name, City & Active Badge
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(Icons.warehouse, color: AppColors.primary, size: 26),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          whName,
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            const Icon(Icons.location_on, size: 14, color: AppColors.textSecondary),
                                            const SizedBox(width: 3),
                                            Text(
                                              whLocation.isNotEmpty ? whLocation : 'City unassigned',
                                              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.green.shade50,
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(color: Colors.green.shade300),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.check_circle, size: 12, color: Colors.green.shade700),
                                        const SizedBox(width: 4),
                                        Text(
                                          'ACTIVE HUB',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.green.shade800,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const Divider(height: 24),

                              // Quick Metrics Grid for this Warehouse
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: Colors.grey.shade200),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                                  children: [
                                    _whMiniMetric('Stocked Units', '$whUnits', Icons.inventory_2_outlined, Colors.blue.shade700),
                                    Container(height: 28, width: 1, color: Colors.grey.shade300),
                                    _whMiniMetric('SKU Types', '$distinctSkus', Icons.category_outlined, Colors.indigo.shade700),
                                    Container(height: 28, width: 1, color: Colors.grey.shade300),
                                    _whMiniMetric('Staff', '${whStaff.length}', Icons.people_outline, Colors.teal.shade700),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),

                              // In-charge staff banner
                              Row(
                                children: [
                                  const Icon(Icons.person_pin_outlined, size: 15, color: AppColors.textSecondary),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      storeAdmins.isNotEmpty
                                          ? 'Admin: ${storeAdmins.map((a) => a['name']).join(", ")}'
                                          : whStaff.isNotEmpty
                                              ? 'Assigned: ${whStaff.map((a) => a['name']).join(", ")}'
                                              : 'No Store Admin assigned yet',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: storeAdmins.isNotEmpty ? AppColors.textPrimary : Colors.orange.shade800,
                                        fontWeight: storeAdmins.isNotEmpty ? FontWeight.w500 : FontWeight.normal,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              const Divider(height: 20),

                              // Actions Row: View Stock, Edit, Delete
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: AppColors.primary,
                                        side: const BorderSide(color: AppColors.primary),
                                        padding: const EdgeInsets.symmetric(vertical: 8),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      ),
                                      icon: const Icon(Icons.swap_horiz, size: 16),
                                      label: const Text('View Stock', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                      onPressed: () {
                                        setState(() {
                                          _activeModule = 5; // Stock & Movement
                                          _inventorySubTab = 0;
                                        });
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined, size: 20, color: AppColors.primary),
                                    tooltip: 'Edit Warehouse',
                                    onPressed: () => _showAddWarehouseDialog(w),
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.delete_outline, size: 20, color: Colors.red.shade700),
                                    tooltip: 'Delete Warehouse',
                                    onPressed: () => _confirmDeleteWarehouse(w),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _whStatCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(height: 4),
            Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 1),
            Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary), maxLines: 1),
          ],
        ),
      ),
    );
  }

  Widget _whMiniMetric(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 4),
            Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
      ],
    );
  }

  // --- MODULE 10: PAYMENTS & COLLECTIONS HISTORY ---
  Widget _buildPaymentsHistoryModule() {
    final filtered = _payments.where((p) {
      if (_paymentTypeFilter != 'all') {
        if (p['type'] != _paymentTypeFilter) return false;
      }
      if (_paymentMethodFilter != 'all') {
        if (p['payment_method'] != _paymentMethodFilter) return false;
      }
      if (_paymentSearchQuery.isNotEmpty) {
        final q = _paymentSearchQuery.toLowerCase();
        final payer = (p['payer_name'] ?? '').toString().toLowerCase();
        final no = (p['payment_no'] ?? '').toString().toLowerCase();
        final collector = (p['collector_name'] ?? '').toString().toLowerCase();
        final item = (p['item_description'] ?? '').toString().toLowerCase();
        final notes = (p['notes'] ?? '').toString().toLowerCase();
        if (!payer.contains(q) && !no.contains(q) && !collector.contains(q) && !item.contains(q) && !notes.contains(q)) {
          return false;
        }
      }
      return true;
    }).toList();

    final totalCollected = double.tryParse(_paymentsSummary['total_collected']?.toString() ?? '0') ??
        _payments.where((p) => p['type'] != 'referral_payout').fold<double>(0.0, (sum, p) => sum + (double.tryParse(p['amount']?.toString() ?? '0') ?? 0.0));
    final onlineTotal = double.tryParse(_paymentsSummary['online_total']?.toString() ?? '0') ??
        _payments.where((p) => p['payment_method'] == 'online' || p['payment_method'] == 'upi').fold<double>(0.0, (sum, p) => sum + (double.tryParse(p['amount']?.toString() ?? '0') ?? 0.0));
    final cashTotal = double.tryParse(_paymentsSummary['cash_total']?.toString() ?? '0') ??
        _payments.where((p) => p['payment_method'] == 'cash').fold<double>(0.0, (sum, p) => sum + (double.tryParse(p['amount']?.toString() ?? '0') ?? 0.0));
    final payoutsTotal = double.tryParse(_paymentsSummary['payouts_total']?.toString() ?? '0') ??
        _payments.where((p) => p['type'] == 'referral_payout').fold<double>(0.0, (sum, p) => sum + (double.tryParse(p['amount']?.toString() ?? '0') ?? 0.0));

    return Scaffold(
      backgroundColor: const Color(0xFFF9F7F5),
      appBar: AppBar(
        title: const Text('Payments History'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => setState(() => _activeModule = 0),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadPayments,
            tooltip: 'Refresh Ledger',
          ),
        ],
      ),
      body: Column(
        children: [
          // 1. KPI Financial Header
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _payKpiCard('Total Inflow', '₹${totalCollected.toStringAsFixed(0)}', Icons.arrow_downward, Colors.green),
                  const SizedBox(width: 10),
                  _payKpiCard('Online / UPI', '₹${onlineTotal.toStringAsFixed(0)}', Icons.qr_code_2, Colors.blue),
                  const SizedBox(width: 10),
                  _payKpiCard('Cash Handover', '₹${cashTotal.toStringAsFixed(0)}', Icons.payments_outlined, Colors.amber.shade800),
                  const SizedBox(width: 10),
                  _payKpiCard('Payouts Outflow', '₹${payoutsTotal.toStringAsFixed(0)}', Icons.arrow_upward, Colors.purple),
                ],
              ),
            ),
          ),
          const Divider(height: 1),

          // 2. Search Field
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
            child: TextField(
              controller: _paymentSearchCtrl,
              decoration: InputDecoration(
                hintText: 'Search by payer, receipt #, collector, notes...',
                prefixIcon: const Icon(Icons.search, size: 20, color: AppColors.textSecondary),
                suffixIcon: _paymentSearchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _paymentSearchCtrl.clear();
                          setState(() => _paymentSearchQuery = '');
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                ),
              ),
              onChanged: (v) => setState(() => _paymentSearchQuery = v),
            ),
          ),

          // 3. Category Filter Chips (Horizontal)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            child: Row(
              children: [
                _payTypeChip('all', 'All (${_payments.length})'),
                const SizedBox(width: 6),
                _payTypeChip('sale', 'Sales Receipts'),
                const SizedBox(width: 6),
                _payTypeChip('settlement', 'Cash Settlements'),
                const SizedBox(width: 6),
                _payTypeChip('referral_payout', 'Referral Payouts'),
              ],
            ),
          ),

          // 4. Payment Mode Secondary Filter
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            child: Row(
              children: [
                Text(
                  'Mode: ',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
                ),
                const SizedBox(width: 6),
                _payModePill('all', 'All Modes'),
                const SizedBox(width: 6),
                _payModePill('online', 'Online / UPI'),
                const SizedBox(width: 6),
                _payModePill('cash', 'Cash Only'),
                const Spacer(),
                Text(
                  '${filtered.length} records',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),

          // 5. Payment Cards List
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey.shade400),
                          const SizedBox(height: 12),
                          const Text(
                            'No payment records found',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _paymentSearchQuery.isNotEmpty
                                ? 'No transactions match "$_paymentSearchQuery"'
                                : 'No payments recorded in this category yet',
                            style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(14, 4, 14, 20),
                    itemCount: filtered.length,
                    itemBuilder: (ctx, idx) {
                      final item = filtered[idx];
                      return _buildPaymentCard(item);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _payKpiCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: color.withValues(alpha: 0.15),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color),
              ),
              const SizedBox(height: 1),
              Text(
                label,
                style: TextStyle(fontSize: 10.5, color: Colors.grey.shade700, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _payTypeChip(String key, String label) {
    final isSelected = _paymentTypeFilter == key;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? Colors.white : AppColors.textPrimary,
        ),
      ),
      selected: isSelected,
      selectedColor: AppColors.primary,
      backgroundColor: Colors.white,
      side: BorderSide(color: isSelected ? AppColors.primary : Colors.grey.shade300),
      onSelected: (_) => setState(() => _paymentTypeFilter = key),
    );
  }

  Widget _payModePill(String key, String label) {
    final isSelected = _paymentMethodFilter == key;
    return InkWell(
      onTap: () => setState(() => _paymentMethodFilter = key),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.accent.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? AppColors.accent : Colors.grey.shade300),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? AppColors.accent : Colors.grey.shade700,
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentCard(Map<String, dynamic> item) {
    final isPayout = item['type'] == 'referral_payout';
    final isSettlement = item['type'] == 'settlement';
    final isOnline = item['payment_method'] == 'online' || item['payment_method'] == 'upi';

    IconData icon;
    Color iconColor;
    Color iconBg;
    String prefix;
    Color amountColor;

    if (isPayout) {
      icon = Icons.card_giftcard;
      iconColor = Colors.purple;
      iconBg = Colors.purple.shade50;
      prefix = '- ';
      amountColor = Colors.purple.shade700;
    } else if (isSettlement) {
      icon = Icons.account_balance_wallet_outlined;
      iconColor = Colors.blue.shade700;
      iconBg = Colors.blue.shade50;
      prefix = '+ ';
      amountColor = Colors.teal.shade800;
    } else {
      icon = isOnline ? Icons.qr_code_2 : Icons.payments_outlined;
      iconColor = isOnline ? Colors.green.shade700 : Colors.amber.shade800;
      iconBg = isOnline ? Colors.green.shade50 : Colors.amber.shade50;
      prefix = '+ ';
      amountColor = Colors.green.shade800;
    }

    final double amount = double.tryParse(item['amount']?.toString() ?? '0') ?? 0.0;
    final isCompleted = item['status'] == 'completed';

    return Card(
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      elevation: 1,
      child: InkWell(
        onTap: () => _showPaymentReceiptModal(item),
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Row: Avatar, Payer Name, Receipt Pill
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: iconBg,
                    child: Icon(icon, color: iconColor, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item['payer_name'] ?? 'Direct Customer',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textPrimary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item['item_description'] ?? 'Product Sale',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '$prefix₹${amount.toStringAsFixed(0)}',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: amountColor),
                      ),
                      const SizedBox(height: 3),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isCompleted ? Colors.green.shade50 : Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: isCompleted ? Colors.green.shade200 : Colors.orange.shade200),
                        ),
                        child: Text(
                          isCompleted ? 'COMPLETED' : 'PENDING',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: isCompleted ? Colors.green.shade800 : Colors.orange.shade800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const Divider(height: 20),

              // Bottom Details Row: Mode Pill, Collector, Date & View Receipt Link
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: isOnline ? Colors.blue.shade50 : Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      (item['payment_method'] ?? 'cash').toString().toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: isOnline ? Colors.blue.shade800 : Colors.amber.shade900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'By: ${item['collector_name'] ?? 'Staff'} • ${_formatPayDate(item['created_at'])}',
                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios, size: 12, color: AppColors.textSecondary),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPaymentReceiptModal(Map<String, dynamic> item) {
    final double amount = double.tryParse(item['amount']?.toString() ?? '0') ?? 0.0;
    final isPayout = item['type'] == 'referral_payout';
    final isOnline = item['payment_method'] == 'online' || item['payment_method'] == 'upi';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Drag Handle
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),

              // Receipt Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                        child: const Icon(Icons.receipt_long, color: AppColors.primary, size: 22),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Official Payment Receipt', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          Text(item['payment_no'] ?? 'PAY-00000', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                        ],
                      ),
                    ],
                  ),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
              const SizedBox(height: 16),

              // Amount Card
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      isPayout ? Colors.purple.shade700 : AppColors.primary,
                      isPayout ? Colors.purple.shade900 : const Color(0xFF3E2723),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Text(
                      isPayout ? 'Payout Disbursed' : 'Payment Received',
                      style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '₹${amount.toStringAsFixed(2)}',
                      style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.check_circle, color: Colors.greenAccent, size: 14),
                          const SizedBox(width: 5),
                          Text(
                            (item['status'] ?? 'completed').toString().toUpperCase(),
                            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // Transaction Detail Grid
              _receiptRow('Transaction Type', item['category'] ?? (isPayout ? 'Referral Payout' : 'Sales Receipt')),
              _receiptRow('Payer / Customer', item['payer_name'] ?? 'Direct Customer'),
              if ((item['payer_phone'] ?? '').toString().isNotEmpty)
                _receiptRow('Payer Contact', item['payer_phone']),
              _receiptRow('Payment Channel', isOnline ? 'Online / UPI Digital Transfer' : 'Cash In Hand'),
              _receiptRow('Staff / Collector', '${item['collector_name']} (${(item['collector_role'] ?? 'Staff').toString().replaceAll('_', ' ').toUpperCase()})'),
              _receiptRow('Item / Purpose', item['item_description'] ?? 'Supply Chain Transaction'),
              _receiptRow('Date & Time', _formatPayDate(item['created_at'])),
              if (item['reference_id'] != null)
                _receiptRow('Reference ID', item['reference_id']),
              if ((item['notes'] ?? '').toString().isNotEmpty)
                _receiptRow('Audit Notes', item['notes']),

              const SizedBox(height: 20),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.check, size: 18),
                label: const Text('Done', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                onPressed: () => Navigator.pop(ctx),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _receiptRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 125,
            child: Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }

  String _formatPayDate(dynamic raw) {
    if (raw == null) return 'Recent';
    try {
      final dt = DateTime.parse(raw.toString()).toLocal();
      final now = DateTime.now();
      final hour = dt.hour.toString().padLeft(2, '0');
      final minute = dt.minute.toString().padLeft(2, '0');
      if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
        return 'Today, $hour:$minute';
      }
      return '${dt.day}/${dt.month}/${dt.year} $hour:$minute';
    } catch (_) {
      return raw.toString().split('T').first;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    switch (_activeModule) {
      case 1:
        return _buildWorkforceModule();
      case 2:
        return _buildPermissionsModule();
      case 3:
        return _buildProductsModule();
      case 4:
        return _buildReferralsModule();
      case 5:
        return _buildInventoryModule();
      case 6:
        return _buildSalesModule();
      case 7:
        return _buildAuditLogsModule();
      case 8:
        return _buildSettlementOversightModule();
      case 9:
        return _buildWarehousesModule();
      case 10:
        return _buildPaymentsHistoryModule();
      case 0:
      default:
        return _buildHubView();
    }
  }
}

// Extension helpers for in-memory filtering
extension WorkforceFilter on List<Map<String, dynamic>> {
  List<Map<String, dynamic>> filterUsers(String role, String search) {
    return where((u) {
      final matchRole = role == 'all' || u['role'] == role;
      final matchSearch = search.isEmpty ||
          (u['name']?.toString().toLowerCase().contains(search.toLowerCase()) ?? false) ||
          (u['email']?.toString().toLowerCase().contains(search.toLowerCase()) ?? false);
      return matchRole && matchSearch;
    }).toList();
  }
}

extension SalesFilter on List<Map<String, dynamic>> {
  List<Map<String, dynamic>> filterSales(String payment, String customerType) {
    return where((s) {
      final matchPayment = payment == 'all' || s['payment_method'] == payment;
      final matchCust = customerType == 'all' || (s['customer_type'] ?? 'retail') == customerType;
      return matchPayment && matchCust;
    }).toList();
  }
}
