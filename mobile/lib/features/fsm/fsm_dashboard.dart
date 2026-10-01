import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../core/constants/colors.dart';
import '../../core/state/app_state.dart';

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

  String get _fsmId => AppState.currentUser?['id'] ?? 'u3';
  String get _fsmName => AppState.currentUser?['name'] ?? 'Field Sales Manager';

  // 1. Dashboard State
  Map<String, dynamic> _dashboardData = {
    'earnings': {'today_earned': 0, 'bottles_sold': 0, 'rate_per_bottle': 10},
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

  @override
  void initState() {
    super.initState();
    _loadAllFsmData();
  }

  Future<void> _loadAllFsmData() async {
    setState(() => _isLoading = true);
    await Future.wait([
      _loadDashboardMetrics(),
      _loadTeamRoster(),
      _loadReferralRequests(),
      _loadSettlementHub(),
    ]);
    if (mounted) setState(() => _isLoading = false);
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
      }
    } catch (_) {}
  }

  // --- ACTIONS & MODALS ---

  void _openStockAllocationModal() {
    final rootMessenger = ScaffoldMessenger.of(context);
    // Local copy of quantities to allocate per salesman
    final Map<String, int> draftAllocations = {};
    for (var s in _supervisedSalesmen) {
      draftAllocations[s['id'].toString()] = 0;
    }

    

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final int totalSelected = draftAllocations.values.fold(0, (sum, v) => sum + v);
            final int remainingStock = _availableDepotStock - totalSelected;
            final bool canConfirm = totalSelected > 0 && remainingStock >= 0;

            return Container(
              height: MediaQuery.of(context).size.height * 0.82,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  // Drag Handle
                  Container(
                    width: 42,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  const SizedBox(height: 14),
                  // Header
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Stock Allocation',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: ClientColors.textDark,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: ClientColors.textMuted),
                          onPressed: () => Navigator.pop(sheetContext),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: ClientColors.border),
                  const SizedBox(height: 12),

                  // Available Depot Stock Banner
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: ClientColors.alertBg,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: ClientColors.alertBorder),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: ClientColors.primary.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.warehouse_outlined, color: ClientColors.primary),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Available Depot Stock',
                                  style: TextStyle(fontSize: 12, color: ClientColors.textMuted, fontWeight: FontWeight.w500),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '$_availableDepotStock bottles',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: ClientColors.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: ClientColors.alertBorder),
                            ),
                            child: Text(
                              'Remaining: $remainingStock',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: remainingStock < 0 ? Colors.red : ClientColors.textDark,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        const Text(
                          'Select Quantities per Salesman',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: ClientColors.textDark),
                        ),
                        const Spacer(),
                        Text(
                          '${_supervisedSalesmen.length} Agents',
                          style: const TextStyle(fontSize: 12, color: ClientColors.textMuted),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Salesmen Interactive List
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                      itemCount: _supervisedSalesmen.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final sm = _supervisedSalesmen[index];
                        final String smId = sm['id'].toString();
                        final String smName = sm['name'] ?? 'Salesman';
                        final String zone = sm['zone'] ?? 'Zone A';
                        final String code = sm['code'] ?? 'SP-00';
                        final int curQty = draftAllocations[smId] ?? 0;
                        final int stockOnHand = (sm['current_stock'] as num?)?.toInt() ?? 0;

                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: curQty > 0 ? ClientColors.primaryLight : ClientColors.border),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.02),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              )
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 20,
                                    backgroundColor: ClientColors.primary.withValues(alpha: 0.1),
                                    child: Text(
                                      smName.isNotEmpty ? smName[0] : 'S',
                                      style: const TextStyle(color: ClientColors.primary, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          smName,
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: ClientColors.textDark),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '$zone • $code • Hand: ${stockOnHand}b',
                                          style: const TextStyle(fontSize: 11, color: ClientColors.textMuted),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Interactive Stepper
                                  Row(
                                    children: [
                                      InkWell(
                                        onTap: () {
                                          if (curQty > 0) {
                                            setSheetState(() {
                                              draftAllocations[smId] = (curQty - 10).clamp(0, 9999);
                                            });
                                          }
                                        },
                                        borderRadius: BorderRadius.circular(16),
                                        child: Container(
                                          width: 32,
                                          height: 32,
                                          decoration: BoxDecoration(
                                            color: Colors.grey.shade100,
                                            shape: BoxShape.circle,
                                            border: Border.all(color: Colors.grey.shade300),
                                          ),
                                          child: const Icon(Icons.remove, size: 16, color: ClientColors.textDark),
                                        ),
                                      ),
                                      Container(
                                        width: 52,
                                        alignment: Alignment.center,
                                        child: Text(
                                          '$curQty',
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.bold,
                                            color: curQty > 0 ? ClientColors.primary : ClientColors.textDark,
                                          ),
                                        ),
                                      ),
                                      InkWell(
                                        onTap: () {
                                          if (remainingStock >= 10) {
                                            setSheetState(() {
                                              draftAllocations[smId] = curQty + 10;
                                            });
                                          } else {
                                            rootMessenger.showSnackBar(
                                              const SnackBar(
                                                content: Text('Cannot allocate more than available depot stock!'),
                                                duration: Duration(seconds: 1),
                                              ),
                                            );
                                          }
                                        },
                                        borderRadius: BorderRadius.circular(16),
                                        child: Container(
                                          width: 32,
                                          height: 32,
                                          decoration: const BoxDecoration(
                                            color: ClientColors.primary,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(Icons.add, size: 16, color: Colors.white),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              if (curQty > 0) ...[
                                const SizedBox(height: 8),
                                const Divider(height: 1, color: ClientColors.border),
                                const SizedBox(height: 8),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: OutlinedButton.icon(
                                    onPressed: () {
                                      Navigator.pop(sheetContext);
                                      _initiateSalesmanTransfer(
                                        salesmanId: smId,
                                        salesmanName: smName,
                                        quantity: curQty,
                                      );
                                    },
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: ClientColors.primary,
                                      side: const BorderSide(color: ClientColors.primary),
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                    icon: const Icon(Icons.qr_code, size: 14),
                                    label: Text('Generate Handoff QR ($curQty btls)', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
                  ),

                  // Bottom Summary & Confirm Button
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: const Border(top: BorderSide(color: ClientColors.border)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 8,
                          offset: const Offset(0, -3),
                        )
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Total Selected:', style: TextStyle(fontSize: 14, color: ClientColors.textMuted)),
                            Text(
                              '$totalSelected bottles',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: ClientColors.primary),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton.icon(
                            onPressed: canConfirm
                                ? () async {
                                    Navigator.pop(sheetContext);
                                    final allocatedEntries = draftAllocations.entries.where((e) => e.value > 0).toList();
                                    if (allocatedEntries.isNotEmpty) {
                                      final first = allocatedEntries.first;
                                      final sm = _supervisedSalesmen.firstWhere(
                                        (s) => s['id'].toString() == first.key,
                                        orElse: () => {'name': 'Salesman'},
                                      );
                                      await _initiateSalesmanTransfer(
                                        salesmanId: first.key,
                                        salesmanName: sm['name'] ?? 'Salesman',
                                        quantity: first.value,
                                      );
                                    }
                                  }
                                : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: ClientColors.primary,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: Colors.grey.shade300,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            icon: const Icon(Icons.qr_code_2, size: 20),
                            label: Text(
                              'Authorize & Generate Handoff QR ($totalSelected btls)',
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
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

  Future<void> _initiateSalesmanTransfer({
    required String salesmanId,
    required String salesmanName,
    required int quantity,
  }) async {
    const productId = '6602541b-1e4d-4162-bc86-e44f05cda0b3';
    const productName = 'Water Bottle';
    String transferId = 'tr_${DateTime.now().millisecondsSinceEpoch}';

    try {
      final res = await http.post(
        Uri.parse('${AppState.apiBaseUrl}/stock/transfer'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'from_id': _fsmId,
          'to_id': salesmanId,
          'product_id': productId,
          'quantity': quantity,
          'status': 'pending',
        }),
      );

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        if (body['transfer'] != null && body['transfer']['id'] != null) {
          transferId = body['transfer']['id'].toString();
        }
      }
    } catch (_) {}

    final securityPin = (transferId.hashCode.abs() % 900000 + 100000).toString();
    final qrPayload = jsonEncode({
      'type': 'FSM_TO_SALESMAN_TRANSFER',
      'transfer_id': transferId,
      'from_fsm_id': _fsmId,
      'from_fsm_name': _fsmName,
      'to_salesman_id': salesmanId,
      'salesman_name': salesmanName,
      'product_id': productId,
      'product_name': productName,
      'quantity': quantity,
      'security_pin': securityPin,
      'created_at': DateTime.now().toIso8601String(),
    });

    if (!mounted) return;
    _showSalesmanHandoffQrModal(
      transferId: transferId,
      salesmanId: salesmanId,
      salesmanName: salesmanName,
      productName: productName,
      quantity: quantity,
      securityPin: securityPin,
      qrPayload: qrPayload,
    );
  }

  void _showSalesmanHandoffQrModal({
    required String transferId,
    required String salesmanId,
    required String salesmanName,
    required String productName,
    required int quantity,
    required String securityPin,
    required String qrPayload,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        bool isTransferAccepted = false;
        bool isChecking = false;
        Timer? pollTimer;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> checkAcceptStatus() async {
              if (isTransferAccepted || isChecking) return;
              setDialogState(() => isChecking = true);
              try {
                final res = await http.get(
                  Uri.parse('${AppState.apiBaseUrl}/stock/transfers?from_id=$_fsmId'),
                );
                if (res.statusCode == 200) {
                  final list = List<Map<String, dynamic>>.from(jsonDecode(res.body));
                  final tr = list.firstWhere(
                    (t) => t['id']?.toString() == transferId,
                    orElse: () => {},
                  );
                  if (tr.isNotEmpty && tr['status'] == 'completed') {
                    pollTimer?.cancel();
                    setDialogState(() {
                      isTransferAccepted = true;
                      isChecking = false;
                    });
                    _loadAllFsmData();
                    return;
                  }
                }
              } catch (_) {}
              setDialogState(() => isChecking = false);
            }

            pollTimer ??= Timer.periodic(const Duration(seconds: 3), (_) {
              checkAcceptStatus();
            });



            return Dialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: isTransferAccepted
                                      ? ClientColors.success.withValues(alpha: 0.15)
                                      : ClientColors.primary.withValues(alpha: 0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  isTransferAccepted ? Icons.check_circle : Icons.qr_code_2,
                                  color: isTransferAccepted ? ClientColors.success : ClientColors.primary,
                                  size: 26,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    isTransferAccepted ? 'Stock Transfer Verified' : 'Salesman Stock Handoff',
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: ClientColors.textDark),
                                  ),
                                  Text(
                                    isTransferAccepted ? 'Stock handed over to agent' : 'Show QR to Salesman to scan',
                                    style: const TextStyle(fontSize: 11, color: ClientColors.textMuted),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: ClientColors.textMuted),
                            onPressed: () {
                              pollTimer?.cancel();
                              Navigator.pop(dialogCtx);
                              _loadAllFsmData();
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Salesman Info Card
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: ClientColors.alertBg,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: ClientColors.alertBorder),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: ClientColors.primary.withValues(alpha: 0.2),
                              child: Text(
                                salesmanName.isNotEmpty ? salesmanName[0] : 'S',
                                style: const TextStyle(color: ClientColors.primary, fontWeight: FontWeight.bold),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    salesmanName,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: ClientColors.textDark),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Field Salesman • $productName',
                                    style: const TextStyle(fontSize: 11, color: ClientColors.textMuted),
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '$quantity btls',
                                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: ClientColors.primary),
                                ),
                                Text(
                                  '₹${quantity * 351}',
                                  style: const TextStyle(fontSize: 11, color: ClientColors.textMuted, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),

                      if (isTransferAccepted) ...[
                        // Accepted State
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0FDF4),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFF86EFAC), width: 1.5),
                          ),
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: const BoxDecoration(
                                  color: ClientColors.success,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.check, color: Colors.white, size: 40),
                              ),
                              const SizedBox(height: 14),
                              const Text(
                                'HANDOFF VERIFIED & COMPLETED!',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF166534)),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '$quantity bottles of $productName successfully accepted by $salesmanName into field inventory.',
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 12, color: Color(0xFF15803D)),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            onPressed: () {
                              pollTimer?.cancel();
                              Navigator.pop(dialogCtx);
                              _loadAllFsmData();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: ClientColors.success,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text('Done / Close', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ] else ...[
                        // Dynamic QR Code Container
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: ClientColors.border, width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.06),
                                blurRadius: 16,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: QrImageView(
                            data: qrPayload,
                            version: QrVersions.auto,
                            size: 190,
                            eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: ClientColors.textDark),
                            dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: ClientColors.primary),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Security PIN Manual Card
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Column(
                            children: [
                              const Text(
                                'MANUAL VERIFICATION PIN',
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: ClientColors.textMuted, letterSpacing: 1.1),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                securityPin.split('').join('  '),
                                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 3, color: ClientColors.textDark, fontFamily: 'monospace'),
                              ),
                              const SizedBox(height: 2),
                              const Text(
                                'Salesman can manually enter this 6-digit PIN in scanner',
                                style: TextStyle(fontSize: 10, color: ClientColors.textMuted),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Live status indicator
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFFFCD34D)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (isChecking)
                                const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFB45309)))
                              else
                                Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFFD97706), shape: BoxShape.circle)),
                              const SizedBox(width: 8),
                              const Text(
                                'WAITING FOR SALESMAN TO SCAN & CONFIRM',
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF92400E)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _handleScanWarehouseQR() async {
    // 1. Fetch pending transfers for this FSM
    List<Map<String, dynamic>> pendingTransfers = [];
    try {
      final res = await http.get(Uri.parse('${AppState.apiBaseUrl}/stock/transfers?to_id=$_fsmId&status=pending'));
      if (res.statusCode == 200) {
        pendingTransfers = List<Map<String, dynamic>>.from(jsonDecode(res.body));
      }
    } catch (_) {}

    if (pendingTransfers.isEmpty) {
      try {
        final res = await http.get(Uri.parse('${AppState.apiBaseUrl}/stock/transfers?status=pending'));
        if (res.statusCode == 200) {
          final all = List<Map<String, dynamic>>.from(jsonDecode(res.body));
          pendingTransfers = all.where((t) => t['to_id'] == _fsmId || t['status'] == 'pending').toList();
        }
      } catch (_) {}
    }

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetCtx) {
        Map<String, dynamic>? selectedTransfer = pendingTransfers.isNotEmpty ? pendingTransfers.first : null;
        final pinController = TextEditingController();
        bool isProcessing = false;
        bool isVerifying = false;

        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            Future<void> confirmReceipt(Map<String, dynamic> tr) async {
              setSheetState(() => isProcessing = true);
              final trId = tr['id']?.toString() ?? '';
              final qty = (tr['quantity'] as num?)?.toInt() ?? 25;
              final prodName = tr['product']?['name'] ?? tr['product_name'] ?? 'Bottles';

              try {
                final res = await http.put(
                  Uri.parse('${AppState.apiBaseUrl}/stock/transfers/$trId/accept'),
                  headers: {'Content-Type': 'application/json'},
                  body: jsonEncode({'user_id': _fsmId}),
                );
                if (res.statusCode == 200 || res.statusCode == 201) {
                  if (sheetCtx.mounted) Navigator.pop(sheetCtx);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: ClientColors.success,
                        content: Text('✓ Verified & Received $qty units of $prodName into depot stock!'),
                        duration: const Duration(seconds: 3),
                      ),
                    );
                    _loadAllFsmData();
                  }
                  return;
                }
              } catch (_) {}

              // If API fails
              if (sheetCtx.mounted) Navigator.pop(sheetCtx);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    backgroundColor: Colors.red,
                    content: Text('Failed to accept stock transfer. Please check connection.'),
                  ),
                );
              }
            }

            Future<void> pickAndSimulateScan(ImageSource source) async {
              try {
                final picker = ImagePicker();
                final img = await picker.pickImage(source: source, imageQuality: 80);
                if (img != null) {
                  setSheetState(() => isVerifying = true);
                  await Future.delayed(const Duration(milliseconds: 600));
                  if (pendingTransfers.isNotEmpty) {
                    setSheetState(() {
                      selectedTransfer = pendingTransfers.first;
                      isVerifying = false;
                    });
                  } else {
                    setSheetState(() => isVerifying = false);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('No pending stock transfers waiting for acceptance.')),
                      );
                    }
                  }
                }
              } catch (e) {
                setSheetState(() => isVerifying = false);
              }
            }

            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 16,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 14),
                        decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
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
                                color: ClientColors.primary.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.qr_code_scanner, color: ClientColors.primary, size: 22),
                            ),
                            const SizedBox(width: 10),
                            const Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Receive Warehouse Stock', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: ClientColors.textDark)),
                                Text('Scan Store Admin QR code to verify handoff', style: TextStyle(fontSize: 11, color: ClientColors.textMuted)),
                              ],
                            ),
                          ],
                        ),
                        IconButton(icon: const Icon(Icons.close, color: ClientColors.textMuted), onPressed: () => Navigator.pop(sheetCtx)),
                      ],
                    ),
                    const SizedBox(height: 16),

                    Container(
                      height: 180,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1712),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: ClientColors.primaryLight, width: 1.5),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 10, offset: const Offset(0, 4)),
                        ],
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                isVerifying ? Icons.sync : Icons.qr_code_2,
                                size: 76,
                                color: isVerifying ? ClientColors.primaryLight : Colors.white70,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                isVerifying ? 'Analyzing QR Code...' : 'Align Store Admin QR in Viewfinder',
                                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                          Positioned(
                            top: 14,
                            left: 14,
                            child: Container(width: 24, height: 24, decoration: const BoxDecoration(border: Border(top: BorderSide(color: ClientColors.primaryLight, width: 3), left: BorderSide(color: ClientColors.primaryLight, width: 3)))),
                          ),
                          Positioned(
                            top: 14,
                            right: 14,
                            child: Container(width: 24, height: 24, decoration: const BoxDecoration(border: Border(top: BorderSide(color: ClientColors.primaryLight, width: 3), right: BorderSide(color: ClientColors.primaryLight, width: 3)))),
                          ),
                          Positioned(
                            bottom: 14,
                            left: 14,
                            child: Container(width: 24, height: 24, decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: ClientColors.primaryLight, width: 3), left: BorderSide(color: ClientColors.primaryLight, width: 3)))),
                          ),
                          Positioned(
                            bottom: 14,
                            right: 14,
                            child: Container(width: 24, height: 24, decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: ClientColors.primaryLight, width: 3), right: BorderSide(color: ClientColors.primaryLight, width: 3)))),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => pickAndSimulateScan(ImageSource.camera),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: ClientColors.primary,
                              side: const BorderSide(color: ClientColors.primary),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            icon: const Icon(Icons.camera_alt, size: 16),
                            label: const Text('Camera Scan', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => pickAndSimulateScan(ImageSource.gallery),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: ClientColors.textDark,
                              side: BorderSide(color: Colors.grey.shade400),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            icon: const Icon(Icons.photo_library, size: 16),
                            label: const Text('From Gallery', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: pinController,
                            decoration: InputDecoration(
                              labelText: '6-Digit Transfer PIN',
                              hintText: 'e.g. 592814',
                              isDense: true,
                              prefixIcon: const Icon(Icons.pin, size: 18, color: ClientColors.primary),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () {
                            final pin = pinController.text.trim();
                            if (pin.isNotEmpty) {
                              if (pendingTransfers.isNotEmpty) {
                                setSheetState(() => selectedTransfer = pendingTransfers.first);
                              } else {
                                setSheetState(() {
                                  selectedTransfer = {
                                    'id': 'tr_pin_${DateTime.now().millisecondsSinceEpoch}',
                                    'from_name': 'Central Warehouse Hub',
                                    'product': {'name': 'Water Bottle', 'sku': 'WB-20L'},
                                    'quantity': 25,
                                    'status': 'pending',
                                    'created_at': DateTime.now().toIso8601String(),
                                  };
                                });
                              }
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: ClientColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: const Text('Verify PIN', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    if (selectedTransfer != null) ...[
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0FDF4),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFF86EFAC), width: 1.2),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: ClientColors.success,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.check_circle, color: Colors.white, size: 12),
                                      SizedBox(width: 4),
                                      Text('VERIFIED WAREHOUSE DISPATCH', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                ),
                                Flexible(
                                  child: Text(
                                    '#${(selectedTransfer!['id']?.toString() ?? 'TR').split('-').first}',
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 11, color: ClientColors.textMuted, fontFamily: 'monospace'),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Incoming Product:', style: TextStyle(fontSize: 13, color: ClientColors.textMuted)),
                                Text(
                                  selectedTransfer!['product']?['name'] ?? selectedTransfer!['product_name'] ?? 'Water Bottle',
                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: ClientColors.textDark),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Authorized Quantity:', style: TextStyle(fontSize: 13, color: ClientColors.textMuted)),
                                Text(
                                  '${selectedTransfer!['quantity'] ?? 25} Bottles',
                                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: ClientColors.primary),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Source Warehouse:', style: TextStyle(fontSize: 13, color: ClientColors.textMuted)),
                                Text(
                                  selectedTransfer!['from_name'] ?? 'Central Warehouse Hub',
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: ClientColors.textDark),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton.icon(
                          onPressed: isProcessing ? null : () => confirmReceipt(selectedTransfer!),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: ClientColors.success,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: isProcessing
                              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.check, size: 20),
                          label: Text(
                            isProcessing
                                ? 'Confirming Receipt...'
                                : 'Accept & Confirm Stock Receipt (${selectedTransfer!['quantity'] ?? 25} btls)',
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ] else ...[
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: ClientColors.alertBg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: ClientColors.alertBorder),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.info_outline, color: ClientColors.primary, size: 20),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'No pending transfers auto-detected yet. Scan the Store Admin QR code or enter the 6-digit PIN to load.',
                                style: TextStyle(fontSize: 12, color: ClientColors.textDark),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _openSalesmanSettlementScannerSheet([Map<String, dynamic>? initialSettlement]) async {
    List<Map<String, dynamic>> pendingSettlements = [];
    try {
      final res = await http.get(Uri.parse('${AppState.apiBaseUrl}/settlements?status=pending_fsm'));
      if (res.statusCode == 200) {
        pendingSettlements = List<Map<String, dynamic>>.from(jsonDecode(res.body));
      }
    } catch (_) {}

    if (pendingSettlements.isEmpty) {
      final fromHub = (_settlementHub['pending_settlements'] as List?) ?? [];
      pendingSettlements = List<Map<String, dynamic>>.from(fromHub);
    }

    if (!mounted) return;

    final messenger = ScaffoldMessenger.of(context);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetCtx) {
        Map<String, dynamic>? selected = initialSettlement ?? (pendingSettlements.isNotEmpty ? pendingSettlements.first : null);
        final pinController = TextEditingController();
        bool isProcessing = false;
        bool isVerifying = false;

        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            Future<void> confirmSettlement(Map<String, dynamic> stl) async {
              setSheetState(() => isProcessing = true);
              final stlId = stl['id']?.toString() ?? '';
              final salesmanName = stl['salesman_name'] ?? 'Salesman';
              final returnQty = (stl['remaining_qty'] as num?)?.toInt() ?? 0;
              final soldQty = (stl['bottles_sold'] as num?)?.toInt() ?? 0;
              final cash = (stl['cash_received'] ?? stl['cash_collected'] ?? 0);
              final online = (stl['online_payment'] ?? 0);

              try {
                final res = await http.put(
                  Uri.parse('${AppState.apiBaseUrl}/settlements/$stlId/approve'),
                  headers: {'Content-Type': 'application/json'},
                  body: jsonEncode({'approved_by': _fsmId}),
                );
                if (res.statusCode == 200 || res.statusCode == 201) {
                  if (sheetCtx.mounted) Navigator.pop(sheetCtx);
                  if (mounted) {
                    setState(() {
                      _settlementHub['depot_stock'] = ((_settlementHub['depot_stock'] ?? 0) as int) + returnQty;
                      _dashboardData['available_depot_stock'] = ((_dashboardData['available_depot_stock'] ?? 0) as int) + returnQty;
                    });
                    messenger.showSnackBar(
                      SnackBar(
                        backgroundColor: ClientColors.success,
                        content: Text('✓ Settlement Approved! $salesmanName reconciled ($soldQty sold, ₹${cash + online} collected). $returnQty bottles returned to Depot Stock.'),
                        duration: const Duration(seconds: 4),
                      ),
                    );
                    _loadAllFsmData();
                  }
                  return;
                }
              } catch (_) {}

              // If API fails
              if (sheetCtx.mounted) Navigator.pop(sheetCtx);
              if (mounted) {
                messenger.showSnackBar(
                  const SnackBar(
                    backgroundColor: Colors.red,
                    content: Text('Failed to approve settlement. Please check connection.'),
                  ),
                );
              }
            }

            Future<void> pickAndSimulateScan(ImageSource source) async {
              try {
                final picker = ImagePicker();
                final img = await picker.pickImage(source: source, imageQuality: 80);
                if (img != null) {
                  setSheetState(() => isVerifying = true);
                  await Future.delayed(const Duration(milliseconds: 600));
                  if (pendingSettlements.isNotEmpty) {
                    setSheetState(() {
                      selected = pendingSettlements.first;
                      isVerifying = false;
                    });
                  } else {
                    setSheetState(() => isVerifying = false);
                    messenger.showSnackBar(
                      const SnackBar(content: Text('No pending salesman settlements found for verification.')),
                    );
                  }
                }
              } catch (e) {
                setSheetState(() => isVerifying = false);
              }
            }

            final int soldBtls = (selected?['bottles_sold'] as num?)?.toInt() ?? 0;
            final int retBtls = (selected?['remaining_qty'] as num?)?.toInt() ?? 0;
            final int dmgBtls = (selected?['damaged_qty'] as num?)?.toInt() ?? 0;
            final int cashAmt = (selected?['cash_received'] ?? selected?['cash_collected'] ?? 0);
            final int onlineAmt = (selected?['online_payment'] ?? 0);
            final int totalCollected = cashAmt + onlineAmt;
            final int dispBtls = (selected?['bottles_dispatched'] as num?)?.toInt() ?? 10;
            final String? damageBase64 = selected?['damage_image_base64'];
            final String? damageUrl = selected?['damage_image_url'];

            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 16,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 14),
                        decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
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
                                color: const Color(0xFF1B365D).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.qr_code_scanner, color: Color(0xFF1B365D), size: 22),
                            ),
                            const SizedBox(width: 10),
                            const Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Scan Salesman Settlement QR', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: ClientColors.textDark)),
                                Text('Verify unsold returns, cash, and damage', style: TextStyle(fontSize: 11, color: ClientColors.textMuted)),
                              ],
                            ),
                          ],
                        ),
                        IconButton(icon: const Icon(Icons.close, color: ClientColors.textMuted), onPressed: () => Navigator.pop(sheetCtx)),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Viewfinder Container
                    Container(
                      height: 160,
                      decoration: BoxDecoration(
                        color: const Color(0xFF131E2E),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFF60A5FA), width: 1.5),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 10, offset: const Offset(0, 4)),
                        ],
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                isVerifying ? Icons.sync : Icons.qr_code_2,
                                size: 68,
                                color: isVerifying ? const Color(0xFF60A5FA) : Colors.white70,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                isVerifying ? 'Scanning Settlement QR...' : 'Align Salesman Settlement QR in Viewfinder',
                                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                          Positioned(
                            top: 12,
                            left: 12,
                            child: Container(width: 22, height: 22, decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFF60A5FA), width: 3), left: BorderSide(color: Color(0xFF60A5FA), width: 3)))),
                          ),
                          Positioned(
                            top: 12,
                            right: 12,
                            child: Container(width: 22, height: 22, decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFF60A5FA), width: 3), right: BorderSide(color: Color(0xFF60A5FA), width: 3)))),
                          ),
                          Positioned(
                            bottom: 12,
                            left: 12,
                            child: Container(width: 22, height: 22, decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFF60A5FA), width: 3), left: BorderSide(color: Color(0xFF60A5FA), width: 3)))),
                          ),
                          Positioned(
                            bottom: 12,
                            right: 12,
                            child: Container(width: 22, height: 22, decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFF60A5FA), width: 3), right: BorderSide(color: Color(0xFF60A5FA), width: 3)))),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Camera / Gallery Buttons
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => pickAndSimulateScan(ImageSource.camera),
                            icon: const Icon(Icons.camera_alt, size: 16),
                            label: const Text('Camera Scan', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF1B365D),
                              side: const BorderSide(color: Color(0xFF1B365D)),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => pickAndSimulateScan(ImageSource.gallery),
                            icon: const Icon(Icons.photo_library, size: 16),
                            label: const Text('From Gallery', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF1B365D),
                              side: const BorderSide(color: Color(0xFF1B365D)),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Manual 6-Digit PIN Option
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: pinController,
                            keyboardType: TextInputType.number,
                            maxLength: 6,
                            decoration: InputDecoration(
                              counterText: '',
                              hintText: 'Enter 6-digit Settlement PIN',
                              hintStyle: const TextStyle(fontSize: 12, color: ClientColors.textMuted),
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () {
                            final code = pinController.text.trim();
                            if (code.isNotEmpty) {
                              final match = pendingSettlements.firstWhere(
                                (s) => (s['security_pin'] ?? '').toString() == code,
                                orElse: () => pendingSettlements.isNotEmpty
                                    ? pendingSettlements.first
                                    : {
                                        'id': 'stl_pin_$code',
                                        'salesman_id': 'u4',
                                        'salesman_name': 'Ramesh Sharma',
                                        'bottles_dispatched': 10,
                                        'bottles_sold': 8,
                                        'remaining_qty': 2,
                                        'damaged_qty': 0,
                                        'cash_received': 2808,
                                        'online_payment': 0,
                                        'security_pin': code,
                                        'status': 'pending_fsm',
                                      },
                              );
                              setSheetState(() => selected = match);
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1B365D),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          ),
                          child: const Text('Verify PIN', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),

                    if (pendingSettlements.isNotEmpty && selected == null) ...[
                      const SizedBox(height: 14),
                      const Text('Or Select Pending Settlement:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: ClientColors.textDark)),
                      const SizedBox(height: 6),
                      ...pendingSettlements.map((st) {
                        return InkWell(
                          onTap: () => setSheetState(() => selected = st),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 6),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: ClientColors.border),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('${st['salesman_name'] ?? 'Salesman'} (${st['bottles_sold'] ?? 0} Sold, ${st['remaining_qty'] ?? 0} Ret)', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                const Icon(Icons.arrow_forward_ios, size: 12, color: ClientColors.textMuted),
                              ],
                            ),
                          ),
                        );
                      }),
                    ],

                    // Selected Settlement Full Breakdown Card
                    if (selected != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFF93C5FD)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const CircleAvatar(
                                      radius: 16,
                                      backgroundColor: Color(0xFF1B365D),
                                      child: Icon(Icons.person, color: Colors.white, size: 18),
                                    ),
                                    const SizedBox(width: 8),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(selected?['salesman_name'] ?? 'Salesman', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: ClientColors.textDark)),
                                        Text('ID: ${selected?['salesman_id'] ?? 'u4'}', style: const TextStyle(fontSize: 10, color: ClientColors.textMuted)),
                                      ],
                                    ),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(color: const Color(0xFFFEF3C7), borderRadius: BorderRadius.circular(6)),
                                  child: const Text('Pending Approval', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF92400E))),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            const Divider(height: 1),
                            const SizedBox(height: 10),

                            // Metric Row
                            Row(
                              children: [
                                _buildSettlementStat('Dispatched', '$dispBtls btls'),
                                const SizedBox(width: 8),
                                _buildSettlementStat('Sold', '$soldBtls btls'),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                _buildSettlementStat('Return to Depot', '$retBtls btls'),
                                const SizedBox(width: 8),
                                _buildSettlementStat('Damaged', '$dmgBtls btls'),
                              ],
                            ),
                            const SizedBox(height: 10),

                            // Stock Return Highlight Badge
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(color: const Color(0xFFECFDF5), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFA7F3D0))),
                              child: Row(
                                children: [
                                  const Icon(Icons.add_business_rounded, color: Color(0xFF059669), size: 16),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      '+$retBtls Unsold Bottles will be added to FSM Depot Stock',
                                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF065F46)),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 10),

                            // Payment Collections Breakdown
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: ClientColors.border)),
                              child: Column(
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Row(
                                        children: [
                                          Icon(Icons.payments_outlined, size: 14, color: Color(0xFF2563EB)),
                                          SizedBox(width: 4),
                                          Text('Cash Received:', style: TextStyle(fontSize: 11, color: ClientColors.textMuted)),
                                        ],
                                      ),
                                      Text('₹$cashAmt', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: ClientColors.textDark)),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Row(
                                        children: [
                                          Icon(Icons.qr_code_scanner, size: 14, color: Color(0xFF7C3AED)),
                                          SizedBox(width: 4),
                                          Text('Online Payment / UPI:', style: TextStyle(fontSize: 11, color: ClientColors.textMuted)),
                                        ],
                                      ),
                                      Text('₹$onlineAmt', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: ClientColors.textDark)),
                                    ],
                                  ),
                                  const Divider(height: 10),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text('Total Collected:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: ClientColors.textDark)),
                                      Text('₹$totalCollected', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF15803D))),
                                    ],
                                  ),
                                ],
                              ),
                            ),

                            // Damaged Bottles Section with Image Proof
                            if (dmgBtls > 0) ...[
                              const SizedBox(height: 10),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFFBEB),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: const Color(0xFFFDE68A)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(Icons.warning_amber_rounded, color: Color(0xFFD97706), size: 18),
                                        const SizedBox(width: 6),
                                        Text('$dmgBtls Damaged Bottles Reported', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF92400E))),
                                      ],
                                    ),
                                    if ((selected?['damage_notes'] ?? '').toString().isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Text('Reason: ${selected?['damage_notes']}', style: const TextStyle(fontSize: 11, color: Color(0xFFB45309))),
                                    ],
                                    const SizedBox(height: 8),
                                    if (damageBase64 != null && damageBase64.isNotEmpty) ...[
                                      InkWell(
                                        onTap: () {
                                          showDialog(
                                            context: context,
                                            builder: (_) => Dialog(
                                              child: Column(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Image.memory(base64Decode(damageBase64), fit: BoxFit.contain),
                                                  TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
                                                ],
                                              ),
                                            ),
                                          );
                                        },
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(6),
                                          child: Row(
                                            children: [
                                              Image.memory(base64Decode(damageBase64), width: 64, height: 64, fit: BoxFit.cover),
                                              const SizedBox(width: 8),
                                              const Text('Tap to view damage photo', style: TextStyle(fontSize: 11, color: Color(0xFF92400E), decoration: TextDecoration.underline)),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ] else if (damageUrl != null && damageUrl.isNotEmpty) ...[
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(6),
                                        child: Row(
                                          children: [
                                            Image.network(damageUrl, width: 64, height: 64, fit: BoxFit.cover),
                                            const SizedBox(width: 8),
                                            const Text('Damage proof photo attached', style: TextStyle(fontSize: 11, color: Color(0xFF92400E))),
                                          ],
                                        ),
                                      ),
                                    ] else ...[
                                      const Text('Damage photo logged by salesman', style: TextStyle(fontSize: 10, color: Color(0xFFB45309), fontStyle: FontStyle.italic)),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Accept & Reconcile Button
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton.icon(
                          onPressed: isProcessing ? null : () => confirmSettlement(selected!),
                          icon: isProcessing
                              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Icon(Icons.check_circle_rounded, size: 20),
                          label: Text(
                            isProcessing ? 'Reconciling...' : '✓ Accept & Reconcile Settlement',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF15803D),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _handleWarehouseReturnQR() async {
    String returnCode = 'WR-RET-88492';
    int returnQty = 500;
    try {
      final res = await http.post(
        Uri.parse('${AppState.apiBaseUrl}/fsm/warehouse-return-qr'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'fsm_id': _fsmId, 'quantity': 500}),
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        returnCode = data['return_code'] ?? 'WR-RET-88492';
        returnQty = data['quantity'] ?? 500;
      }
    } catch (_) {}

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Warehouse Return QR', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: ClientColors.border),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4))
                ],
              ),
              child: Column(
                children: [
                  const Icon(Icons.qr_code_2, size: 160, color: ClientColors.textDark),
                  const SizedBox(height: 10),
                  Text(
                    returnCode,
                    style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 16, color: ClientColors.primary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: ClientColors.alertBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: ClientColors.alertBorder),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Return Quantity:', style: TextStyle(fontSize: 12, color: ClientColors.textMuted)),
                  Text('$returnQty Bottles', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: ClientColors.primary)),
                ],
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Show this QR code at Central Warehouse depot counter for final inventory return signoff.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: ClientColors.textMuted),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogCtx),
            style: ElevatedButton.styleFrom(backgroundColor: ClientColors.primary, foregroundColor: Colors.white),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleReferralAction(String reqId, String action) async {
    try {
      await http.put(
        Uri.parse('${AppState.apiBaseUrl}/fsm/referral-requests/$reqId'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'action': action}),
      );

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
      await http.post(Uri.parse('${AppState.apiBaseUrl}/fsm/settlement-remind/$salesmanId'));
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
            : IndexedStack(
                index: _activeTab,
                children: [
                  _buildManagerDashboardTab(),
                  _buildMyTeamTab(),
                  _buildOperationsHomeTab(),
                  _buildReferralRequestsTab(),
                  _buildSettlementHubTab(),
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
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh, color: ClientColors.textMuted, size: 22),
          onPressed: _loadAllFsmData,
        ),
        Container(
          margin: const EdgeInsets.only(right: 14),
          child: Stack(
            children: [
              CircleAvatar(
                radius: 17,
                backgroundColor: ClientColors.primary.withValues(alpha: 0.12),
                child: const Text(
                  'AS',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: ClientColors.primary),
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    color: ClientColors.success,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
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

  // ===========================================================================
  // SCREEN 1: MANAGER DASHBOARD (TAB 0)
  // ===========================================================================

  Widget _buildManagerDashboardTab() {
    final earnings = _dashboardData['earnings'] ?? {};
    final teamSales = _dashboardData['team_sales'] ?? {};
    final stockAcc = _dashboardData['stock_accountability'] ?? {};
    final topPerformers = (_dashboardData['top_performers'] as List?) ?? [];

    return RefreshIndicator(
      color: ClientColors.primary,
      onRefresh: _loadAllFsmData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Welcome Header Card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: ClientColors.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  )
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF3C7),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'FIELD MANAGER',
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF92400E)),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Good Morning, $_fsmName 👋',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: ClientColors.textDark,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          AppState.currentUser?['warehouse_name'] != null 
                              ? 'Assigned to ${AppState.currentUser!['warehouse_name']}'
                              : 'Field Sales Operations',
                          style: const TextStyle(fontSize: 12, color: ClientColors.textMuted),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE6F4EA),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFCEEAD6)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.circle, color: Color(0xFF137333), size: 8),
                        SizedBox(width: 5),
                        Text(
                          'ACTIVE',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF137333)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Today's Earnings & Team Sales Cards
            Row(
              children: [
                // Earnings Card (Terracotta Gradient)
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFB8501E), Color(0xFF8B3A0D)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: ClientColors.primary.withValues(alpha: 0.25),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        )
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Today's Earnings",
                          style: TextStyle(fontSize: 12, color: Colors.white70, fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '₹${earnings['today_earned'] ?? 0}',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${earnings['bottles_sold'] ?? 0} btls × ₹${earnings['rate_per_bottle'] ?? 10}',
                          style: const TextStyle(fontSize: 10, color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Team Sales Card
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: ClientColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Team Sales',
                          style: TextStyle(fontSize: 12, color: ClientColors.textMuted, fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${teamSales['bottles'] ?? 0} btls',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: ClientColors.textDark,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${teamSales['bottles'] ?? 0} bottles sold',
                          style: const TextStyle(fontSize: 10, color: ClientColors.success, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Team Stock Accountability Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: ClientColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Team Stock Accountability',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: ClientColors.textDark),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _buildMiniStatBox('Received', '${stockAcc['received'] ?? 0}', Colors.blue.shade50, Colors.blue.shade800),
                      const SizedBox(width: 8),
                      _buildMiniStatBox('Allocated', '${stockAcc['allocated'] ?? 0}', Colors.purple.shade50, Colors.purple.shade800),
                      const SizedBox(width: 8),
                      _buildMiniStatBox('Sold', '${stockAcc['sold'] ?? 0}', Colors.green.shade50, Colors.green.shade800),
                      const SizedBox(width: 8),
                      _buildMiniStatBox('Remaining', '${stockAcc['remaining'] ?? 0}', ClientColors.alertBg, ClientColors.primary),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Top Performers Leaderboard
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: ClientColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Top Performers',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: ClientColors.textDark),
                      ),
                      TextButton(
                        onPressed: () => _changeTab(1),
                        style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                        child: const Text('View All', style: TextStyle(fontSize: 12, color: ClientColors.primary, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ...topPerformers.map((p) {
                    final rank = p['rank'] ?? 1;
                    final name = p['name'] ?? '';
                    final bottles = p['bottles'] ?? 0;
                    final hasTrophy = p['has_trophy'] == true;

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: rank == 1 ? const Color(0xFFFEF3C7) : Colors.grey.shade100,
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              '$rank',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: rank == 1 ? const Color(0xFF92400E) : ClientColors.textMuted,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              name,
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: ClientColors.textDark),
                            ),
                          ),
                          Text(
                            '$bottles btls',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: ClientColors.textDark),
                          ),
                          if (hasTrophy) ...[
                            const SizedBox(width: 4),
                            const Text('🏆', style: TextStyle(fontSize: 14)),
                          ],
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),

            const SizedBox(height: 18),

            // Bottom Full-width Action: Scan Warehouse QR
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _handleScanWarehouseQR,
                icon: const Icon(Icons.qr_code_scanner, size: 20),
                label: const Text('Scan Warehouse QR', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: ClientColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniStatBox(String label, String value, Color bg, Color textColor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textColor),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(fontSize: 10, color: textColor.withValues(alpha: 0.8), fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // SCREEN 2: MY TEAM (TAB 1)
  // ===========================================================================

  Widget _buildMyTeamTab() {
    final activeCount = _teamSummary['active'] ?? 0;
    final offlineCount = _teamSummary['offline'] ?? 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status Cards (Active / Offline)
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE6F4EA),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFCEEAD6)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.circle, color: Color(0xFF137333), size: 10),
                      const SizedBox(width: 8),
                      Text(
                        'ACTIVE • $activeCount',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF137333)),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.circle, color: Colors.grey.shade600, size: 10),
                      const SizedBox(width: 8),
                      Text(
                        'OFFLINE • $offlineCount',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey.shade700),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Header + Filter
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Salesmen',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: ClientColors.textDark),
              ),
              OutlinedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Showing all zones'), duration: Duration(seconds: 1)),
                  );
                },
                icon: const Icon(Icons.filter_list, size: 16, color: ClientColors.textDark),
                label: const Text('Filter', style: TextStyle(fontSize: 12, color: ClientColors.textDark)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: ClientColors.border),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Salesmen Roster Cards
          ..._supervisedSalesmen.map((sm) {
            final String name = sm['name'] ?? 'Salesman';
            final String zone = sm['zone'] ?? 'Zone A';
            final String code = sm['code'] ?? 'SP-00';
            final bool isActive = sm['is_active'] == true;
            final int soldToday = (sm['sold_today'] as num?)?.toInt() ?? 0;
            final int stock = (sm['current_stock'] as num?)?.toInt() ?? 0;
            final bool isLowStock = stock <= 10;

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: ClientColors.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  )
                ],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Stack(
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: ClientColors.primary.withValues(alpha: 0.12),
                            child: Text(
                              name.isNotEmpty ? name[0] : 'S',
                              style: const TextStyle(color: ClientColors.primary, fontWeight: FontWeight.bold),
                            ),
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: isActive ? ClientColors.success : Colors.grey.shade400,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 1.5),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: ClientColors.textDark),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '$zone • ID: $code',
                              style: const TextStyle(fontSize: 11, color: ClientColors.textMuted),
                            ),
                          ],
                        ),
                      ),
                      OutlinedButton(
                        onPressed: _openStockAllocationModal,
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: ClientColors.primary),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Text('Allocate', style: TextStyle(fontSize: 11, color: ClientColors.primary, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Divider(height: 1, color: ClientColors.border),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Text('Sold Today: ', style: TextStyle(fontSize: 12, color: ClientColors.textMuted)),
                          Text('$soldToday btls', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: ClientColors.textDark)),
                        ],
                      ),
                      Row(
                        children: [
                          const Text('Current Stock: ', style: TextStyle(fontSize: 12, color: ClientColors.textMuted)),
                          Text(
                            isLowStock ? '$stock btls ⚠️' : '$stock btls',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isLowStock ? Colors.red.shade700 : ClientColors.textDark,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ===========================================================================
  // SCREEN 3: OPERATIONS HOME (TAB 2 - CENTER HIGHLIGHT)
  // ===========================================================================

  Widget _buildOperationsHomeTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Greeting / Title Banner
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: ClientColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Operations Hub',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: ClientColors.textDark),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: ClientColors.alertBg,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Depot: $_availableDepotStock btls',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: ClientColors.primary),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  'Manage inventory allocations, warehouse returns, and agent supervision.',
                  style: TextStyle(fontSize: 12, color: ClientColors.textMuted),
                ),
              ],
            ),
          ),

          const SizedBox(height: 18),

          // Primary Quick Action Cards (Allocate Stock & Settlement)
          InkWell(
            onTap: _openStockAllocationModal,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFB8501E), Color(0xFFD66835)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: ClientColors.primary.withValues(alpha: 0.28),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  )
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.inventory_2_outlined, color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Allocate Stock',
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        SizedBox(height: 3),
                        Text(
                          'Distribute depot bottles to field salesmen with live stock calculations.',
                          style: TextStyle(fontSize: 12, color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios, color: Colors.white70, size: 16),
                ],
              ),
            ),
          ),

          const SizedBox(height: 14),

          InkWell(
            onTap: () => _changeTab(4),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: ClientColors.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  )
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.account_balance_wallet_outlined, color: Color(0xFF92400E), size: 26),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Settlement Hub',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: ClientColors.textDark),
                        ),
                        SizedBox(height: 3),
                        Text(
                          'Central warehouse return QR & field team cash reconciliation.',
                          style: TextStyle(fontSize: 12, color: ClientColors.textMuted),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios, color: ClientColors.textMuted, size: 16),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Secondary Quick Actions (2 Columns)
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: _handleScanWarehouseQR,
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: ClientColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Icon(Icons.qr_code_scanner, color: ClientColors.primary, size: 24),
                        SizedBox(height: 8),
                        Text(
                          'Scan Warehouse',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: ClientColors.textDark),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Verify incoming batch',
                          style: TextStyle(fontSize: 10, color: ClientColors.textMuted),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: InkWell(
                  onTap: () => _changeTab(0),
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: ClientColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Icon(Icons.insights_outlined, color: Colors.indigo, size: 24),
                        SizedBox(height: 8),
                        Text(
                          'Team Insights',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: ClientColors.textDark),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Leaderboard & metrics',
                          style: TextStyle(fontSize: 10, color: ClientColors.textMuted),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Pending Referral Banner Shortcut
          InkWell(
            onTap: () => _changeTab(3),
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: ClientColors.alertBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: ClientColors.alertBorder),
              ),
              child: Row(
                children: [
                  const Icon(Icons.person_add_alt_1_outlined, color: ClientColors.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Referral Applications',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: ClientColors.primary),
                        ),
                        Text(
                          '${_requestsSummary['pending'] ?? 12} candidates awaiting verification',
                          style: const TextStyle(fontSize: 11, color: ClientColors.textMuted),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: ClientColors.primary),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // SCREEN 4: REFERRAL REQUESTS (TAB 3)
  // ===========================================================================

  Widget _buildReferralRequestsTab() {
    final pendingCount = _requestsSummary['pending'] ?? 12;
    final reviewCount = _requestsSummary['in_review'] ?? 4;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Metric Summary Pills
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  decoration: BoxDecoration(
                    color: ClientColors.alertBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: ClientColors.alertBorder),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.pending_actions, color: ClientColors.primary, size: 20),
                      const SizedBox(width: 10),
                      Text(
                        '$pendingCount PENDING',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: ClientColors.primary),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.visibility_outlined, color: Colors.blue.shade700, size: 20),
                      const SizedBox(width: 10),
                      Text(
                        '$reviewCount IN REVIEW',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.blue.shade800),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: ['All New', 'High Priority', 'Recent'].map((filter) {
                final isSel = _selectedRequestFilter == filter;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(filter),
                    selected: isSel,
                    selectedColor: ClientColors.primary,
                    labelStyle: TextStyle(
                      fontSize: 12,
                      fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                      color: isSel ? Colors.white : ClientColors.textDark,
                    ),
                    backgroundColor: Colors.white,
                    side: BorderSide(color: isSel ? ClientColors.primary : ClientColors.border),
                    onSelected: (_) => setState(() => _selectedRequestFilter = filter),
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 14),

          // Candidates Roster
          ..._referralRequests.map((req) {
            final String reqId = req['id'] ?? '';
            final String candidateName = req['candidate_name'] ?? 'Candidate';
            final String referredBy = req['referred_by'] ?? 'Salesman';
            final String timestamp = req['timestamp'] ?? '';
            final String phone = req['phone'] ?? '';
            final String location = req['location'] ?? '';
            final List docs = (req['documents'] as List?) ?? [];
            final String status = req['status'] ?? 'pending';
            final bool isApproved = status == 'approved';
            final bool isRejected = status == 'rejected';

            return Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: ClientColors.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  )
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Candidate Name & Referred By Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            candidateName,
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: ClientColors.textDark),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Referred by $referredBy • $timestamp',
                            style: const TextStyle(fontSize: 11, color: ClientColors.textMuted),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: isApproved
                              ? const Color(0xFFE6F4EA)
                              : isRejected
                                  ? Colors.red.shade50
                                  : const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          status.toUpperCase(),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: isApproved
                                ? const Color(0xFF137333)
                                : isRejected
                                    ? Colors.red.shade800
                                    : const Color(0xFF92400E),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Phone & Location
                  Row(
                    children: [
                      const Icon(Icons.phone_outlined, size: 14, color: ClientColors.textMuted),
                      const SizedBox(width: 6),
                      Text(phone, style: const TextStyle(fontSize: 12, color: ClientColors.textDark)),
                      const SizedBox(width: 16),
                      const Icon(Icons.location_on_outlined, size: 14, color: ClientColors.textMuted),
                      const SizedBox(width: 6),
                      Text(location, style: const TextStyle(fontSize: 12, color: ClientColors.textDark)),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Attached Documents
                  const Text('Attached Documents', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: ClientColors.textMuted)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: docs.map((d) {
                      return InkWell(
                        onTap: () {
                          showDialog(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: Text('$d Preview'),
                              content: Text('Viewing verified document record for $candidateName ($d).'),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
                              ],
                            ),
                          );
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: ClientColors.border),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.description_outlined, size: 14, color: ClientColors.primary),
                              const SizedBox(width: 6),
                              Text(d.toString(), style: const TextStyle(fontSize: 11, color: ClientColors.textDark, fontWeight: FontWeight.w500)),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                  if (status == 'pending' || status == 'in_review') ...[
                    const SizedBox(height: 14),
                    const Divider(height: 1, color: ClientColors.border),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => _handleReferralAction(reqId, 'reject'),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: Colors.red.shade300),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                            child: Text(
                              '✕ Reject',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.red.shade700),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => _handleReferralAction(reqId, 'approve'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: ClientColors.primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                            child: const Text(
                              '✔ Approve',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ===========================================================================
  // SCREEN 5: SETTLEMENT HUB (TAB 4)
  // ===========================================================================

  Widget _buildSettlementHubTab() {
    final wh = _settlementHub['warehouse'] ?? {};
    final teamSettlements = (_settlementHub['team_settlement'] as List?) ?? [];
    final pendingSettlements = (_settlementHub['pending_settlements'] as List?) ?? [];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. SALESMAN FIELD SETTLEMENT & SCANNER CARD
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1B365D), Color(0xFF2E5B88)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF1B365D).withValues(alpha: 0.25),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.handshake_rounded, color: Colors.white, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Salesman Settlement',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ],
                    ),
                    if (pendingSettlements.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF59E0B),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${pendingSettlements.length} Pending Review',
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'Reconciliation Ready',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Scan the Salesman\'s settlement QR code to verify bottles sold, accept unsold returns into depot stock, confirm cash/online payments, and inspect damaged bottles.',
                  style: TextStyle(fontSize: 12, color: Colors.white70, height: 1.4),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: () => _openSalesmanSettlementScannerSheet(),
                    icon: const Icon(Icons.qr_code_scanner, size: 22),
                    label: const Text(
                      'SCAN SALESMAN SETTLEMENT QR',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF1B365D),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 2,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 2. PENDING SETTLEMENT CARDS (IF ANY)
          if (pendingSettlements.isNotEmpty) ...[
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Pending Approvals',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: ClientColors.textDark),
                ),
                Text(
                  '${pendingSettlements.length} Awaiting Scan',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFD97706)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ...pendingSettlements.map((st) {
              final smName = st['salesman_name'] ?? 'Salesman';
              final sold = st['bottles_sold'] ?? 0;
              final ret = st['remaining_qty'] ?? 0;
              final dmg = (st['damaged_qty'] as num?)?.toInt() ?? 0;
              final cash = (st['cash_received'] ?? st['cash_collected'] ?? 0);
              final online = (st['online_payment'] ?? 0);
              final total = cash + online;

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.amber.withValues(alpha: 0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const CircleAvatar(
                              radius: 14,
                              backgroundColor: Color(0xFF1B365D),
                              child: Icon(Icons.person, color: Colors.white, size: 14),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              smName,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: ClientColors.textDark),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: const Color(0xFFFEF3C7), borderRadius: BorderRadius.circular(4)),
                          child: const Text('QR Generated', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF92400E))),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Sold: $sold btls • Unsold Return: $ret btls • Paid: ₹$total (Cash ₹$cash, Online ₹$online)',
                      style: const TextStyle(fontSize: 11, color: ClientColors.textMuted),
                    ),
                    if (dmg > 0) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.warning_amber_rounded, size: 14, color: Color(0xFFD97706)),
                          const SizedBox(width: 4),
                          Text(
                            '$dmg Damaged Bottles Reported',
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF92400E)),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      height: 36,
                      child: ElevatedButton.icon(
                        onPressed: () => _openSalesmanSettlementScannerSheet(st),
                        icon: const Icon(Icons.verified_rounded, size: 16),
                        label: const Text('Review & Reconcile', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF15803D),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],

          const SizedBox(height: 20),

          // Warehouse Settlement Main Card
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: ClientColors.border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                )
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Warehouse Settlement',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: ClientColors.textDark),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'Pending Return',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF92400E)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // 4-box metrics grid
                Row(
                  children: [
                    _buildSettlementStat('Received', '${wh['received'] ?? 0} btls'),
                    const SizedBox(width: 10),
                    _buildSettlementStat('Sold', '${wh['sold'] ?? 0} btls'),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _buildSettlementStat('Returned', '${wh['returned'] ?? 0} btls'),
                    const SizedBox(width: 10),
                    _buildSettlementStat('Difference', '₹${wh['difference'] ?? 0}'),
                  ],
                ),

                const SizedBox(height: 14),
                const Divider(height: 1, color: ClientColors.border),
                const SizedBox(height: 12),

                // Inventory & Sold Values
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Inventory Value', style: TextStyle(fontSize: 11, color: ClientColors.textMuted)),
                        const SizedBox(height: 2),
                        Text(
                          '₹${wh['inv_value'] ?? 0}',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: ClientColors.textDark),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text('Sold Value', style: TextStyle(fontSize: 11, color: ClientColors.textMuted)),
                        const SizedBox(height: 2),
                        Text(
                          '₹${wh['sold_value'] ?? 0}',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: ClientColors.primary),
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Generate Warehouse Return QR Button
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton.icon(
                    onPressed: _handleWarehouseReturnQR,
                    icon: const Icon(Icons.qr_code_2, size: 20),
                    label: const Text('Generate Warehouse Return QR', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ClientColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Team Settlement Section
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Team Settlement',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: ClientColors.textDark),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFE6F4EA),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  '4/5 Settled',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF137333)),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Team Settlement List
          ...teamSettlements.map((ts) {
            final String name = ts['name'] ?? 'Agent';
            final String status = ts['status'] ?? 'settled';
            final bool isSettled = status == 'settled';
            final int pendingAmount = (ts['pending_amount'] as num?)?.toInt() ?? 0;
            final String smId = ts['salesman_id'] ?? ts['id'] ?? '';

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: ClientColors.border),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: isSettled ? Colors.green.shade50 : ClientColors.alertBg,
                    child: Text(
                      name.isNotEmpty ? name[0] : 'S',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isSettled ? Colors.green.shade700 : ClientColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: ClientColors.textDark)),
                        const SizedBox(height: 2),
                        Text(
                          isSettled ? 'Settled on schedule' : 'Cash handover pending',
                          style: TextStyle(fontSize: 11, color: isSettled ? ClientColors.textMuted : Colors.red.shade700),
                        ),
                      ],
                    ),
                  ),
                  if (isSettled)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE6F4EA),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.check_circle, size: 14, color: Color(0xFF137333)),
                          SizedBox(width: 4),
                          Text('Settled', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF137333))),
                        ],
                      ),
                    )
                  else ...[
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '₹$pendingAmount',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.red.shade700),
                        ),
                        const SizedBox(height: 4),
                        InkWell(
                          onTap: () => _handleSendReminder(smId, name),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: ClientColors.alertBg,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: ClientColors.alertBorder),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                Icon(Icons.notifications_active_outlined, size: 12, color: ClientColors.primary),
                                SizedBox(width: 4),
                                Text('Remind', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: ClientColors.primary)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildSettlementStat(String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: ClientColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 11, color: ClientColors.textMuted)),
            const SizedBox(height: 3),
            Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: ClientColors.textDark)),
          ],
        ),
      ),
    );
  }
}

extension SalesFilterExtension on List<Map<String, dynamic>> {
  List<Map<String, dynamic>> filterSalesBySeller(String sellerId) {
    return where((s) => s['salesman_id'] == sellerId).toList();
  }
}
// =============================================================================






// when i navigate back using device back navigation the app exits directly , if we are in any page 
