import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import '../../core/constants/colors.dart';
import '../../core/services/offline_sales_service.dart';
import '../../core/state/app_state.dart';
import 'modules/salesman_dashboard_tab.dart';
import 'modules/salesman_home_tab.dart';
import 'modules/salesman_receive_stock_modal.dart';
import 'modules/salesman_record_sale_modal.dart';
import 'modules/salesman_refer_tab.dart';
import 'modules/salesman_settlement_qr_modal.dart';
import 'modules/salesman_settlement_tab.dart';
import 'modules/salesman_stock_tab.dart';

// 4. SALESMAN DASHBOARD — MODULAR COORDINATOR
// =============================================================================

class SalesmanDashboard extends StatefulWidget {
  const SalesmanDashboard({super.key});

  @override
  State<SalesmanDashboard> createState() => _SalesmanDashboardState();
}

class _SalesmanDashboardState extends State<SalesmanDashboard> {
  // Navigation Tabs: 0: Dashboard, 1: Stock, 2: Home (Center), 3: Refer, 4: Settlement
  int _activeTab = 2; // Default to Home as shown in client's center highlight
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
    if (_lastBackPressTime == null ||
        now.difference(_lastBackPressTime!) > const Duration(seconds: 2)) {
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

  // Agent Status
  bool _isOnDuty = true;
  String get _salesmanId => AppState.currentUser?['id'] ?? 'u4';
  String get _salesmanName => AppState.currentUser?['name'] ?? 'Salesman';

  // Earnings Data
  Map<String, dynamic> _earningsData = {
    'total_earned': 0.0,
    'commission_earned': 0.0,
    'sold_bottles_today': 0,
    'referral_earned': 0.0,
    'referral_bottles': 0,
    'monthly_earnings': 0,
    'monthly_bottles_sold': 0,
  };

  // Settlement Tab State
  int _settlementSoldBottles = 0;
  int _totalDispatchedBottles = 10;
  int _currentStock = 10;
  int _soldToday = 0;
  double? _bottleUnitPrice;
  double get _unitPrice => _bottleUnitPrice ?? 0.0;
  late TextEditingController _cashHandoverCtrl;
  late TextEditingController _onlinePaymentCtrl;
  late TextEditingController _soldBottlesInputCtrl;
  late TextEditingController _damagedBottlesInputCtrl;
  List<Map<String, dynamic>> _settlementHistory = [];

  // Damaged Products State
  bool _hasDamagedBottles = false;
  int _damagedBottles = 0;
  late TextEditingController _damageNotesCtrl;
  XFile? _damageImageFile;
  Uint8List? _damageImageBytes;
  String? _damageImageBase64;

  // Stock Tab State
  String? _proofPhotoName;
  Uint8List? _proofPhotoBytes;
  String? _proofPhotoBase64;
  bool _isStockAccepted = false;
  List<Map<String, dynamic>> _stockHistory = [];

  // Refer Tab State
  final TextEditingController _refNameCtrl = TextEditingController();
  final TextEditingController _refPhoneCtrl = TextEditingController();
  String _selectedKycFile = 'Tap to select file';
  String? _selectedKycBase64;
  Uint8List? _selectedKycBytes;
  bool _isSubmittingReferral = false;
  List<Map<String, dynamic>> _referralsList = [];

  // POS / Customers State
  List<Map<String, dynamic>> _customers = [];

  @override
  void initState() {
    super.initState();
    _cashHandoverCtrl = TextEditingController(text: '0');
    _onlinePaymentCtrl = TextEditingController(text: '0');
    _soldBottlesInputCtrl = TextEditingController(text: '$_settlementSoldBottles');
    _damagedBottlesInputCtrl = TextEditingController(text: '$_damagedBottles');
    _damageNotesCtrl = TextEditingController();
    _loadAllData();
  }

  @override
  void dispose() {
    _cashHandoverCtrl.dispose();
    _onlinePaymentCtrl.dispose();
    _soldBottlesInputCtrl.dispose();
    _damagedBottlesInputCtrl.dispose();
    _damageNotesCtrl.dispose();
    _refNameCtrl.dispose();
    _refPhoneCtrl.dispose();
    super.dispose();
  }

  bool _isSyncingOfflineSales = false;

  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);
    await Future.wait([
      _loadEarnings(),
      _loadSettlements(),
      _loadReferrals(),
      _loadCustomers(),
      _loadStockTransfers(),
      _loadProductPricing(),
      _restoreOfflineSalesState(),
    ]);
    if (mounted) setState(() => _isLoading = false);

    // Auto-sync pending offline sales in background
    _syncPendingSales(silent: true);
  }

  Future<void> _loadProductPricing() async {
    try {
      final res = await http.get(Uri.parse('${AppState.apiBaseUrl}/products'));
      if (res.statusCode == 200) {
        final list = jsonDecode(res.body);
        if (list is List && list.isNotEmpty) {
          final first = list.first;
          final basePrice = (first['base_price'] as num?)?.toDouble();
          if (basePrice != null && basePrice > 0) {
            if (mounted) {
              setState(() {
                _bottleUnitPrice = basePrice;
                _cashHandoverCtrl.text = '${(_settlementSoldBottles * _unitPrice).toInt()}';
              });
            }
          }
        }
      }
    } catch (_) {}
  }

  /// Restore any unsynced offline sales into the local settlement counter
  Future<void> _restoreOfflineSalesState() async {
    try {
      final queue = await OfflineSalesService.getQueue(salesmanId: _salesmanId);
      final offlineQty = queue.fold<int>(0, (sum, s) => sum + (s['quantity'] as int? ?? 0));
      if (offlineQty > 0 && mounted) {
        setState(() {
          _settlementSoldBottles =
              (_settlementSoldBottles + offlineQty).clamp(0, _totalDispatchedBottles);
          _soldBottlesInputCtrl.text = '$_settlementSoldBottles';
          _cashHandoverCtrl.text = '${(_settlementSoldBottles * _unitPrice).toInt()}';
        });
      }
    } catch (_) {}
  }

  /// Synchronize all pending offline sales to the server
  Future<void> _syncPendingSales({bool silent = false}) async {
    if (_isSyncingOfflineSales) return;
    final count = await OfflineSalesService.getPendingCount(salesmanId: _salesmanId);
    if (count == 0) return;

    if (mounted) setState(() => _isSyncingOfflineSales = true);

    try {
      final res = await OfflineSalesService.syncAll(
        apiBaseUrl: AppState.apiBaseUrl,
        salesmanId: _salesmanId,
      );

      if (mounted) {
        if (res.synced > 0) {
          await _loadEarnings();
          if (!mounted) return;
          if (!silent) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                    '✅ Synced ${res.synced} offline sale${res.synced > 1 ? 's' : ''} to server!'),
                backgroundColor: Colors.green,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        } else if (!silent && res.failed > 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  '⚠️ Sync issue: ${res.errors.isNotEmpty ? res.errors.first : 'Connection failed'}'),
              backgroundColor: Colors.orange,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isSyncingOfflineSales = false);
    }
  }

  Future<void> _loadEarnings() async {
    try {
      final res =
          await http.get(Uri.parse('${AppState.apiBaseUrl}/salesman/earnings/$_salesmanId'));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() {
          _earningsData = data;
          _isOnDuty = data['is_on_duty'] ?? true;
          _soldToday = (data['sold_bottles_today'] as num?)?.toInt() ?? 0;
        });
      }
    } catch (_) {
      setState(() {
        _earningsData = {
          'total_earned': 0.0,
          'commission_earned': 0.0,
          'sold_bottles_today': 0,
          'referral_earned': 0.0,
          'referral_bottles': 0,
          'monthly_earnings': 0,
          'monthly_bottles_sold': 0,
        };
      });
    }
  }

  Future<void> _loadSettlements() async {
    try {
      final res = await http.get(Uri.parse('${AppState.apiBaseUrl}/settlements/$_salesmanId'));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final todayData = data['today'];
        if (todayData != null && todayData['unit_price'] != null) {
          final p = (todayData['unit_price'] as num).toDouble();
          if (p > 0) {
            _bottleUnitPrice = p;
          }
        }
        setState(() {
          _settlementHistory = List<Map<String, dynamic>>.from(data['history'] ?? []);
        });
      }
    } catch (_) {
      setState(() {
        _settlementHistory = [];
      });
    }
  }

  Future<void> _loadReferrals() async {
    try {
      final res =
          await http.get(Uri.parse('${AppState.apiBaseUrl}/salesman/referrals/$_salesmanId'));
      if (res.statusCode == 200) {
        setState(() {
          _referralsList = List<Map<String, dynamic>>.from(jsonDecode(res.body));
        });
      }
    } catch (_) {
      setState(() {
        _referralsList = [];
      });
    }
  }

  Future<void> _loadCustomers() async {
    try {
      final res =
          await http.get(Uri.parse('${AppState.apiBaseUrl}/customers?salesman_id=$_salesmanId'));
      if (res.statusCode == 200) {
        setState(() {
          _customers = List<Map<String, dynamic>>.from(jsonDecode(res.body));
        });
      }
    } catch (_) {
      setState(() {
        _customers = [];
      });
    }
  }

  Future<void> _loadStockTransfers() async {
    try {
      final res =
          await http.get(Uri.parse('${AppState.apiBaseUrl}/stock/transfers?to_id=$_salesmanId'));
      if (res.statusCode == 200) {
        final list = List<Map<String, dynamic>>.from(jsonDecode(res.body));
        final completed = list.where((t) => t['status'] == 'completed').toList();
        if (completed.isNotEmpty) {
          final total = completed.fold<int>(
              0, (sum, t) => sum + ((t['quantity'] as num?)?.toInt() ?? 0));
          if (mounted) {
            setState(() {
              _totalDispatchedBottles = total > 0 ? total : _totalDispatchedBottles;
              _currentStock = total > 0 ? total : _currentStock;
              _isStockAccepted = true;
              _stockHistory = completed
                  .map((t) => {
                        'date': t['created_at'] != null
                            ? t['created_at'].toString().split('T').first
                            : 'Today',
                        'bottles': t['quantity'] ?? 10,
                        'amount': (((t['quantity'] as num?)?.toInt() ?? 10) * _unitPrice).toInt(),
                        'status': 'SETTLED',
                      })
                  .toList();
            });
          }
        }
      }
    } catch (_) {}
  }

  Future<void> _toggleDutyStatus(bool val) async {
    setState(() => _isOnDuty = val);
    try {
      await http.put(
        Uri.parse('${AppState.apiBaseUrl}/users/$_salesmanId/duty'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'is_on_duty': val}),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isOnDuty ? '🟢 You are now ON DUTY' : '⚪ You are now OFF DUTY'),
            backgroundColor: _isOnDuty ? Colors.green : Colors.grey.shade800,
          ),
        );
      }
    } catch (_) {}
  }

  Future<void> _submitReferral() async {
    if (_refNameCtrl.text.trim().isEmpty || _refPhoneCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter full name and phone number')),
      );
      return;
    }
    setState(() => _isSubmittingReferral = true);
    try {
      final res = await http.post(
        Uri.parse('${AppState.apiBaseUrl}/salesman/referrals'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'referrer_id': _salesmanId,
          'full_name': _refNameCtrl.text.trim(),
          'phone': _refPhoneCtrl.text.trim(),
          'kyc_doc': _selectedKycBase64 ?? _selectedKycFile,
        }),
      );
      if (res.statusCode == 201) {
        final newRef = jsonDecode(res.body);
        setState(() {
          _referralsList.insert(0, newRef);
          _refNameCtrl.clear();
          _refPhoneCtrl.clear();
          _selectedKycFile = 'Tap to select file';
          _selectedKycBase64 = null;
          _selectedKycBytes = null;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Referral submitted successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (_) {
      setState(() {
        _referralsList.insert(0, {
          'id': 'ref_${DateTime.now().millisecondsSinceEpoch}',
          'full_name': _refNameCtrl.text.trim(),
          'status': 'Active',
          'earned': 0,
        });
        _refNameCtrl.clear();
        _refPhoneCtrl.clear();
        _selectedKycFile = 'Tap to select file';
        _selectedKycBase64 = null;
        _selectedKycBytes = null;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Referral saved locally!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmittingReferral = false);
    }
  }

  Future<void> _pickDamageImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: source, imageQuality: 75, maxWidth: 900);
      if (picked != null) {
        final bytes = await picked.readAsBytes();
        final base64Str = base64Encode(bytes);
        setState(() {
          _damageImageFile = picked;
          _damageImageBytes = bytes;
          _damageImageBase64 = base64Str;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not attach photo: $e')),
        );
      }
    }
  }

  void _openRecordSaleModal() {
    SalesmanRecordSaleModal.show(
      context: context,
      salesmanId: _salesmanId,
      unitPrice: _unitPrice,
      bottleUnitPrice: _bottleUnitPrice,
      customers: _customers,
      totalDispatchedBottles: _totalDispatchedBottles,
      currentSettlementSoldBottles: _settlementSoldBottles,
      onSaleSuccess: (qty, totalAmt, newSettlementSold) {
        setState(() {
          _settlementSoldBottles = newSettlementSold;
          _soldBottlesInputCtrl.text = '$_settlementSoldBottles';
          _cashHandoverCtrl.text = '${(_settlementSoldBottles * _unitPrice).toInt()}';
        });
      },
    );
  }

  void _openReceiveStockScannerSheet() {
    SalesmanReceiveStockModal.show(
      context: context,
      salesmanId: _salesmanId,
      bottleUnitPrice: _bottleUnitPrice,
      unitPrice: _unitPrice,
      onStockReceived: (qty, prodName, amount) {
        setState(() {
          _currentStock += qty;
          _totalDispatchedBottles += qty;
          _isStockAccepted = true;
          _stockHistory.insert(0, {
            'date': 'Today, Just Now',
            'bottles': qty,
            'amount': amount,
            'status': 'SETTLED',
          });
        });
      },
      onReloadData: _loadAllData,
    );
  }

  Future<void> _initiateSettlementAndShowQR() async {
    final int heldStock = _currentStock > 0 ? _currentStock : _totalDispatchedBottles;
    final int damaged = _hasDamagedBottles ? _damagedBottles : 0;
    final int sold = _settlementSoldBottles;
    final int remaining = (heldStock - sold - damaged).clamp(0, heldStock);
    final int soldAmt = (sold * _unitPrice).toInt();
    final int cash = double.tryParse(_cashHandoverCtrl.text.trim())?.toInt() ?? 0;
    final int online = double.tryParse(_onlinePaymentCtrl.text.trim())?.toInt() ?? 0;

    String settlementId = 'stl_${DateTime.now().millisecondsSinceEpoch}';
    final securityPin = (settlementId.hashCode.abs() % 900000 + 100000).toString();
    final fsmId = AppState.currentUser?['parent_id'] ?? 'c3456789-de23-45ff-67ff-8901abcdef23';
    final fsmName = AppState.currentUser?['parent_name'] ?? 'Field Sales Manager';

    try {
      final res = await http.post(
        Uri.parse('${AppState.apiBaseUrl}/settlements'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'salesman_id': _salesmanId,
          'salesman_name': _salesmanName,
          'fsm_id': fsmId,
          'fsm_name': fsmName,
          'bottles_dispatched': heldStock,
          'bottles_sold': sold,
          'remaining_qty': remaining,
          'damaged_qty': damaged,
          'damage_notes': _hasDamagedBottles ? _damageNotesCtrl.text.trim() : '',
          'damage_image_base64': _damageImageBase64,
          'unit_price': _unitPrice,
          'cash_received': cash,
          'online_payment': online,
          'security_pin': securityPin,
          'status': 'pending_fsm',
        }),
      );

      if (res.statusCode == 200 || res.statusCode == 201) {
        final body = jsonDecode(res.body);
        if (body['id'] != null) {
          settlementId = body['id'].toString();
        }
      }
    } catch (_) {}

    final qrPayload = jsonEncode({
      'type': 'SALESMAN_TO_FSM_SETTLEMENT',
      'settlement_id': settlementId,
      'salesman_id': _salesmanId,
      'salesman_name': _salesmanName,
      'fsm_id': fsmId,
      'fsm_name': fsmName,
      'bottles_dispatched': heldStock,
      'bottles_sold': sold,
      'remaining_qty': remaining,
      'damaged_qty': damaged,
      'damage_notes': _hasDamagedBottles ? _damageNotesCtrl.text.trim() : '',
      'cash_received': cash,
      'online_payment': online,
      'total_amount': soldAmt,
      'security_pin': securityPin,
      'created_at': DateTime.now().toIso8601String(),
    });

    if (!mounted) return;

    SalesmanSettlementQrModal.show(
      context: context,
      settlementId: settlementId,
      fsmName: fsmName,
      heldStock: heldStock,
      sold: sold,
      remaining: remaining,
      damaged: damaged,
      damageNotes: _hasDamagedBottles ? _damageNotesCtrl.text.trim() : '',
      damageBytes: _damageImageBytes,
      cash: cash,
      online: online,
      soldAmt: soldAmt,
      securityPin: securityPin,
      qrPayload: qrPayload,
      onSettled: () {
        setState(() {
          _currentStock = remaining;
          _totalDispatchedBottles = remaining;
          _settlementSoldBottles = 0;
          _soldBottlesInputCtrl.text = '0';
          _damagedBottles = 0;
          _damagedBottlesInputCtrl.text = '0';
          _hasDamagedBottles = false;
          _damageImageFile = null;
          _damageImageBytes = null;
          _damageImageBase64 = null;
          _cashHandoverCtrl.text = '0';
          _onlinePaymentCtrl.text = '0';
          _settlementHistory.insert(0, {
            'id': settlementId,
            'date_label': 'Today, Just Now',
            'bottles_dispatched': heldStock,
            'bottles_sold': sold,
            'remaining_qty': remaining,
            'damaged_qty': damaged,
            'total_value': soldAmt,
            'cash_collected': cash,
            'online_payment': online,
            'status': 'SETTLED',
          });
        });
        _loadAllData();
      },
      onClose: _loadAllData,
    );
  }

  @override
  Widget build(BuildContext context) {
    final tabTitles = ['Dashboard', 'Stock', 'Home', 'Refer', 'Settlement'];

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, dynamic result) {
        if (didPop) return;
        _handleBackNavigation();
      },
      child: Scaffold(
        backgroundColor: ClientColors.creamBg,
        body: SafeArea(
          child: Column(
            children: [
              _buildTopAppBar(tabTitles[_activeTab]),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator(color: ClientColors.primary))
                    : IndexedStack(
                        index: _activeTab,
                        children: [
                          SalesmanDashboardTab(
                            salesmanName: _salesmanName,
                            isOnDuty: _isOnDuty,
                            earningsData: _earningsData,
                            soldToday: _soldToday,
                            currentStock: _currentStock,
                            totalDispatchedBottles: _totalDispatchedBottles,
                            settlementSoldBottles: _settlementSoldBottles,
                            bottleUnitPrice: _bottleUnitPrice,
                            unitPrice: _unitPrice,
                            isStockAccepted: _isStockAccepted,
                            offlineSyncBanner: _buildOfflineSyncBanner(),
                            onDutyToggle: _toggleDutyStatus,
                            onNavigateTab: _changeTab,
                            onRecordSale: _openRecordSaleModal,
                          ),
                          SalesmanStockTab(
                            currentStock: _currentStock,
                            soldToday: _soldToday,
                            totalDispatchedBottles: _totalDispatchedBottles,
                            bottleUnitPrice: _bottleUnitPrice,
                            unitPrice: _unitPrice,
                            isStockAccepted: _isStockAccepted,
                            parentName: AppState.currentUser?['parent_name'] ??
                                'Field Sales Manager (FSM)',
                            proofPhotoName: _proofPhotoName,
                            proofPhotoBytes: _proofPhotoBytes,
                            proofPhotoBase64: _proofPhotoBase64,
                            stockHistory: _stockHistory,
                            onOpenReceiveStockScanner: _openReceiveStockScannerSheet,
                            onProofPhotoChanged: (name, base64, bytes) {
                              setState(() {
                                _proofPhotoName = name;
                                _proofPhotoBase64 = base64;
                                _proofPhotoBytes = bytes;
                              });
                            },
                            onAcceptStock: () {
                              setState(() {
                                _isStockAccepted = true;
                                _stockHistory.insert(0, {
                                  'date': 'Today, 09:30 AM',
                                  'bottles': _currentStock,
                                  'amount': (_currentStock * _unitPrice).toInt(),
                                  'status': 'SETTLED',
                                  'proof_photo': _proofPhotoBase64 ?? _proofPhotoName,
                                });
                              });
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                      '✅ $_currentStock Bottles accepted into your live field inventory!'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            },
                          ),
                          SalesmanHomeTab(
                            offlineSyncBanner: _buildOfflineSyncBanner(),
                            soldToday: _soldToday,
                            bottleUnitPrice: _bottleUnitPrice,
                            onNavigateTab: _changeTab,
                            onRecordSale: _openRecordSaleModal,
                          ),
                          SalesmanReferTab(
                            salesmanName: _salesmanName,
                            earningsData: _earningsData,
                            soldToday: _soldToday,
                            referralsList: _referralsList,
                            refNameCtrl: _refNameCtrl,
                            refPhoneCtrl: _refPhoneCtrl,
                            selectedKycFile: _selectedKycFile,
                            selectedKycBase64: _selectedKycBase64,
                            selectedKycBytes: _selectedKycBytes,
                            isSubmittingReferral: _isSubmittingReferral,
                            onKycChanged: (name, base64, bytes) {
                              setState(() {
                                _selectedKycFile = name;
                                _selectedKycBase64 = base64;
                                _selectedKycBytes = bytes;
                              });
                            },
                            onSubmitReferral: () async {
                              await _submitReferral();
                              _loadEarnings();
                            },
                            onRefreshReferrals: () {
                              _loadReferrals();
                              _loadEarnings();
                            },
                          ),
                          SalesmanSettlementTab(
                            currentStock: _currentStock,
                            totalDispatchedBottles: _totalDispatchedBottles,
                            settlementSoldBottles: _settlementSoldBottles,
                            bottleUnitPrice: _bottleUnitPrice,
                            unitPrice: _unitPrice,
                            cashHandoverCtrl: _cashHandoverCtrl,
                            onlinePaymentCtrl: _onlinePaymentCtrl,
                            soldBottlesInputCtrl: _soldBottlesInputCtrl,
                            damagedBottlesInputCtrl: _damagedBottlesInputCtrl,
                            damageNotesCtrl: _damageNotesCtrl,
                            hasDamagedBottles: _hasDamagedBottles,
                            damagedBottles: _damagedBottles,
                            damageImageFile: _damageImageFile,
                            damageImageBytes: _damageImageBytes,
                            settlementHistory: _settlementHistory,
                            onPickDamageImage: _pickDamageImage,
                            onDeleteDamageImage: () {
                              setState(() {
                                _damageImageFile = null;
                                _damageImageBytes = null;
                                _damageImageBase64 = null;
                              });
                            },
                            onUpdateSettlementState: ({soldBottles, hasDamaged, damagedCount}) {
                              setState(() {
                                if (soldBottles != null) _settlementSoldBottles = soldBottles;
                                if (hasDamaged != null) _hasDamagedBottles = hasDamaged;
                                if (damagedCount != null) _damagedBottles = damagedCount;
                              });
                            },
                            onInitiateSettlement: _initiateSettlementAndShowQR,
                          ),
                        ],
                      ),
              ),
              _buildBottomNav(),
            ],
          ),
        ),
      ),
    );
  }

  // TOP APP BAR
  Widget _buildTopAppBar(String title) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      color: ClientColors.creamBg,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              if (_activeTab != 2) ...[
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: ClientColors.textDark, size: 22),
                  onPressed: _handleBackNavigation,
                  tooltip: 'Back',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 10),
              ],
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: Colors.amber.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.shield, color: ClientColors.primary, size: 20),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Product Name',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: ClientColors.textDark,
                    ),
                  ),
                  Text(title, style: const TextStyle(fontSize: 11, color: ClientColors.textMuted)),
                ],
              ),
            ],
          ),
          Row(
            children: [
              Stack(
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications_outlined,
                        color: ClientColors.textDark, size: 22),
                    onPressed: () {},
                  ),
                  Positioned(
                    right: 12,
                    top: 12,
                    child: Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 2),
              const CircleAvatar(
                radius: 17,
                backgroundColor: ClientColors.primary,
                child: Text(
                  'R',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // BOTTOM NAVIGATION BAR (5 Tabs with Center Home Highlight)
  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _navItem(0, Icons.grid_view_outlined, 'Dashboard'),
          _navItem(1, Icons.inventory_2_outlined, 'Stock'),
          _navHomeItem(2),
          _navItem(3, Icons.person_add_alt_1_outlined, 'Refer'),
          _navItem(4, Icons.account_balance_wallet_outlined, 'Settlement'),
        ],
      ),
    );
  }

  Widget _navItem(int index, IconData icon, String label) {
    final isSelected = _activeTab == index;
    return InkWell(
      onTap: () => _changeTab(index),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                color: isSelected ? ClientColors.primary : ClientColors.textMuted, size: 22),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? ClientColors.primary : ClientColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _navHomeItem(int index) {
    final isSelected = _activeTab == index;
    return GestureDetector(
      onTap: () => _changeTab(index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? ClientColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.home,
                color: isSelected ? Colors.white : ClientColors.textMuted, size: 24),
            if (!isSelected) ...[
              const SizedBox(height: 2),
              const Text('Home', style: TextStyle(fontSize: 10, color: ClientColors.textMuted)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildOfflineSyncBanner() {
    return ValueListenableBuilder<int>(
      valueListenable: OfflineSalesService.pendingCountNotifier,
      builder: (context, pendingCount, _) {
        if (pendingCount == 0) return const SizedBox.shrink();
        return Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF3CD),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFFFEEBA)),
            boxShadow: [
              BoxShadow(
                color: Colors.amber.withValues(alpha: 0.12),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: Colors.amber.shade700.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.cloud_upload_outlined, color: Colors.amber.shade900, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$pendingCount Offline Sale${pendingCount > 1 ? 's' : ''} Stored',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Color(0xFF451A03),
                      ),
                    ),
                    Text(
                      'Saved on device. Tap to sync to server.',
                      style: TextStyle(fontSize: 11, color: Colors.amber.shade900),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: _isSyncingOfflineSales ? null : () => _syncPendingSales(silent: false),
                icon: _isSyncingOfflineSales
                    ? const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.sync, size: 14),
                label: Text(
                  _isSyncingOfflineSales ? 'Syncing...' : 'Sync Now',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber.shade800,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}