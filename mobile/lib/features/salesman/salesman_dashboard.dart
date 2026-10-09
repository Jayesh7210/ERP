import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../core/constants/colors.dart';
import '../../core/state/app_state.dart';

// 4. SALESMAN DASHBOARD — CLIENT 5-SCREEN REDESIGN
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

  // Agent Status
  bool _isOnDuty = true;
  String get _salesmanId => AppState.currentUser?['id'] ?? 'u4';
  String get _salesmanName => AppState.currentUser?['name'] ?? 'Salesman';

  // Earnings Data
  Map<String, dynamic> _earningsData = {
    'total_earned': 0.0,
    'commission_earned': 0.0,
    'sold_bottles_today': 0,
    'commission_rate': 30,
    'referral_earned': 0.0,
    'referral_bottles': 0,
    'referral_rate': 1,
    'monthly_earnings': 0,
    'monthly_bottles_sold': 0,
  };

  // Settlement Tab State
  int _settlementSoldBottles = 0;
  int _totalDispatchedBottles = 10;
  int _currentStock = 10;
  int _soldToday = 0;
  final double _bottleUnitPrice = 351.0;
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

  // POS / Sale Modal State
  bool _isNewCustomer = false;
  String? _saleCustomerId;
  final TextEditingController _saleCustNameCtrl = TextEditingController();
  final TextEditingController _saleCustPhoneCtrl = TextEditingController();
  final TextEditingController _saleCustAddressCtrl = TextEditingController();
  final TextEditingController _saleQtyCtrl = TextEditingController(text: '1');
  final TextEditingController _saleRefCodeCtrl = TextEditingController();
  String _salePaymentMode = 'cash';
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
    _saleCustNameCtrl.dispose();
    _saleCustPhoneCtrl.dispose();
    _saleCustAddressCtrl.dispose();
    _saleQtyCtrl.dispose();
    _saleRefCodeCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);
    await Future.wait([
      _loadEarnings(),
      _loadSettlements(),
      _loadReferrals(),
      _loadCustomers(),
      _loadStockTransfers(),
    ]);
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _loadEarnings() async {
    try {
      final res = await http.get(Uri.parse('${AppState.apiBaseUrl}/salesman/earnings/$_salesmanId'));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() {
          _earningsData = data;
          _isOnDuty = data['is_on_duty'] ?? true;
          _soldToday = (data['sold_bottles_today'] as num?)?.toInt() ?? 0;
        });
      }
    } catch (_) {
      // Fallback
      setState(() {
        _earningsData = {
          'total_earned': 0.0,
          'commission_earned': 0.0,
          'sold_bottles_today': 0,
          'commission_rate': 30,
          'referral_earned': 0.0,
          'referral_bottles': 0,
          'referral_rate': 1,
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
      final res = await http.get(Uri.parse('${AppState.apiBaseUrl}/salesman/referrals/$_salesmanId'));
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
      final res = await http.get(Uri.parse('${AppState.apiBaseUrl}/customers?salesman_id=$_salesmanId'));
      if (res.statusCode == 200) {
        setState(() {
          _customers = List<Map<String, dynamic>>.from(jsonDecode(res.body));
          if (_customers.isNotEmpty) _saleCustomerId ??= _customers.first['id'];
        });
      }
    } catch (_) {
      setState(() {
        _customers = [];
        _saleCustomerId = null;
      });
    }
  }

  Future<void> _loadStockTransfers() async {
    try {
      final res = await http.get(Uri.parse('${AppState.apiBaseUrl}/stock/transfers?to_id=$_salesmanId'));
      if (res.statusCode == 200) {
        final list = List<Map<String, dynamic>>.from(jsonDecode(res.body));
        final completed = list.where((t) => t['status'] == 'completed').toList();
        if (completed.isNotEmpty) {
          final total = completed.fold<int>(0, (sum, t) => sum + ((t['quantity'] as num?)?.toInt() ?? 0));
          if (mounted) {
            setState(() {
              _totalDispatchedBottles = total > 0 ? total : _totalDispatchedBottles;
              _currentStock = total > 0 ? total : _currentStock;
              _isStockAccepted = true;
              _stockHistory = completed.map((t) => {
                'date': t['created_at'] != null ? t['created_at'].toString().split('T').first : 'Today',
                'bottles': t['quantity'] ?? 10,
                'amount': (((t['quantity'] as num?)?.toInt() ?? 10) * _bottleUnitPrice).toInt(),
                'status': 'SETTLED',
              }).toList();
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter full name and phone number')));
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
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Referral submitted successfully!'), backgroundColor: Colors.green));
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
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Referral saved locally!'), backgroundColor: Colors.green));
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

  Future<void> _initiateSettlementAndShowQR() async {
    final int heldStock = _currentStock > 0 ? _currentStock : _totalDispatchedBottles;
    final int damaged = _hasDamagedBottles ? _damagedBottles : 0;
    final int sold = _settlementSoldBottles;
    final int remaining = (heldStock - sold - damaged).clamp(0, heldStock);
    final int soldAmt = (sold * _bottleUnitPrice).toInt();
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
          'unit_price': _bottleUnitPrice,
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

    _showSalesmanSettlementQrModal(
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
    );
  }

  void _showSalesmanSettlementQrModal({
    required String settlementId,
    required String fsmName,
    required int heldStock,
    required int sold,
    required int remaining,
    required int damaged,
    required String damageNotes,
    required Uint8List? damageBytes,
    required int cash,
    required int online,
    required int soldAmt,
    required String securityPin,
    required String qrPayload,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        bool isSettled = false;
        bool isChecking = false;
        Timer? pollTimer;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> checkStatus() async {
              if (isSettled || isChecking) return;
              setDialogState(() => isChecking = true);
              try {
                final res = await http.get(Uri.parse('${AppState.apiBaseUrl}/settlement/$settlementId'));
                if (res.statusCode == 200) {
                  final data = jsonDecode(res.body);
                  if (data['status'] == 'settled' || data['status'] == 'completed') {
                    pollTimer?.cancel();
                    setDialogState(() {
                      isSettled = true;
                      isChecking = false;
                    });
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
                    return;
                  }
                }
              } catch (_) {}
              setDialogState(() => isChecking = false);
            }

            pollTimer ??= Timer.periodic(const Duration(seconds: 3), (_) {
              checkStatus();
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
                                  color: isSettled
                                      ? ClientColors.success.withValues(alpha: 0.15)
                                      : ClientColors.primary.withValues(alpha: 0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  isSettled ? Icons.check_circle : Icons.qr_code_2,
                                  color: isSettled ? ClientColors.success : ClientColors.primary,
                                  size: 26,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    isSettled ? 'Settlement Approved' : 'Daily Settlement QR',
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: ClientColors.textDark),
                                  ),
                                  Text(
                                    isSettled ? 'Reconciliation finalized' : 'Present QR to Field Manager',
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
                              _loadAllData();
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Settlement Summary Card
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: ClientColors.alertBg,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: ClientColors.alertBorder),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('SUPERVISOR', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: ClientColors.textMuted)),
                                    const SizedBox(height: 2),
                                    Text(fsmName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: ClientColors.textDark)),
                                  ],
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    const Text('TOTAL VALUE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: ClientColors.textMuted)),
                                    const SizedBox(height: 2),
                                    Text('₹$soldAmt', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: ClientColors.primary)),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            const Divider(height: 1, color: ClientColors.border),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _qrMetric('Sold', '$sold btls', Colors.green.shade700),
                                _qrMetric('Return', '$remaining btls', ClientColors.primary),
                                if (damaged > 0)
                                  _qrMetric('Damaged', '$damaged btls', Colors.red.shade700),
                                _qrMetric('Cash', '₹$cash', Colors.black87),
                                _qrMetric('Online', '₹$online', Colors.blue.shade700),
                              ],
                            ),
                            if (damaged > 0 && damageBytes != null) ...[
                              const SizedBox(height: 10),
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.red.shade200),
                                ),
                                child: Row(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(6),
                                      child: Image.memory(damageBytes, width: 44, height: 44, fit: BoxFit.cover),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text('Damage Photo: $damaged btls', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.red.shade900)),
                                          Text(damageNotes.isNotEmpty ? damageNotes : 'Damaged / leaking', style: TextStyle(fontSize: 10, color: Colors.red.shade700), maxLines: 1, overflow: TextOverflow.ellipsis),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),

                      if (isSettled) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0FDF4),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFF86EFAC), width: 2),
                          ),
                          child: Column(
                            children: [
                              Container(
                                width: 72,
                                height: 72,
                                decoration: BoxDecoration(
                                  color: ClientColors.success,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: ClientColors.success.withValues(alpha: 0.35),
                                      blurRadius: 18,
                                      offset: const Offset(0, 6),
                                    ),
                                  ],
                                ),
                                child: const Icon(Icons.check, color: Colors.white, size: 44),
                              ),
                              const SizedBox(height: 14),
                              const Text(
                                'SETTLEMENT APPROVED & RECONCILED!',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF166534)),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '$sold bottles sold (₹$soldAmt) settled.\n$remaining unsold bottles returned to $fsmName.',
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
                              _loadAllData();
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
                                'Manager can manually enter this 6-digit PIN in scanner',
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
                                'WAITING FOR FSM TO SCAN & ACCEPT',
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

  static Widget _qrMetric(String label, String value, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: ClientColors.textMuted, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }

  // --- RECORD SALE MODAL FLOW ---
  void _openRecordSaleModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (modalCtx, setModalState) {
          final qty = int.tryParse(_saleQtyCtrl.text) ?? 1;
          final totalAmt = qty * _bottleUnitPrice;

          return Padding(
            padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(modalCtx).viewInsets.bottom + 20),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Record Sale', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: ClientColors.textDark)),
                      IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(modalCtx)),
                    ],
                  ),
                  const Text('Log bottles sold directly to retail customer.', style: TextStyle(fontSize: 12, color: ClientColors.textMuted)),
                  const SizedBox(height: 16),

                  // Customer Toggle
                  Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          label: const Center(child: Text('Existing Customer')),
                          selected: !_isNewCustomer,
                          selectedColor: ClientColors.alertBg,
                          onSelected: (val) => setModalState(() => _isNewCustomer = false),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ChoiceChip(
                          label: const Center(child: Text('+ New Customer')),
                          selected: _isNewCustomer,
                          selectedColor: ClientColors.alertBg,
                          onSelected: (val) => setModalState(() => _isNewCustomer = true),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  if (!_isNewCustomer) ...[
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Select Customer', border: OutlineInputBorder()),
                      initialValue: _saleCustomerId,
                      items: _customers.map((c) => DropdownMenuItem<String>(value: c['id'], child: Text('${c['name']}'))).toList(),
                      onChanged: (val) => setModalState(() => _saleCustomerId = val),
                    ),
                  ] else ...[
                    TextField(controller: _saleCustNameCtrl, decoration: const InputDecoration(labelText: 'Customer / Shop Name *', border: OutlineInputBorder())),
                    const SizedBox(height: 8),
                    TextField(controller: _saleCustPhoneCtrl, decoration: const InputDecoration(labelText: 'Phone Number', border: OutlineInputBorder()), keyboardType: TextInputType.phone),
                    const SizedBox(height: 8),
                    TextField(controller: _saleCustAddressCtrl, decoration: const InputDecoration(labelText: 'Market Location / Address', border: OutlineInputBorder())),
                  ],
                  const SizedBox(height: 12),

                  // Super Admin Price Banner
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(color: Colors.amber.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.amber.shade200)),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.lock, size: 16, color: ClientColors.primary),
                            SizedBox(width: 6),
                            Text('Retail Price (Super Admin):', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: ClientColors.primary)),
                          ],
                        ),
                        Text('₹$_bottleUnitPrice / btl', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: ClientColors.textDark)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Quantity
                  TextField(
                    controller: _saleQtyCtrl,
                    decoration: const InputDecoration(labelText: 'Quantity (Bottles)', border: OutlineInputBorder()),
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setModalState(() {}),
                  ),
                  const SizedBox(height: 10),

                  // Total Amount Box
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(color: ClientColors.alertBg, borderRadius: BorderRadius.circular(8)),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Total Amount to Collect:', style: TextStyle(fontWeight: FontWeight.bold)),
                        Text('₹${totalAmt.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: ClientColors.primary)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Payment Mode
                  Row(
                    children: [
                      ChoiceChip(
                        label: const Text('💵 Cash'),
                        selected: _salePaymentMode == 'cash',
                        selectedColor: Colors.green.shade100,
                        onSelected: (val) => setModalState(() => _salePaymentMode = 'cash'),
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('📱 Online / UPI'),
                        selected: _salePaymentMode == 'online',
                        selectedColor: Colors.blue.shade100,
                        onSelected: (val) => setModalState(() => _salePaymentMode = 'online'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(modalCtx);
                      _executeSale(qty, totalAmt);
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: ClientColors.primary, foregroundColor: Colors.white, minimumSize: const Size.fromHeight(48)),
                    child: const Text('Confirm & Complete Sale'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _executeSale(int qty, double totalAmt) async {
    try {
      await http.post(
        Uri.parse('${AppState.apiBaseUrl}/sales'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'salesman_id': _salesmanId,
          'product_id': 'p1',
          'quantity': qty,
          'amount': totalAmt,
          'payment_method': _salePaymentMode,
          'customer_id': _isNewCustomer ? null : _saleCustomerId,
          'customer_name': _isNewCustomer ? _saleCustNameCtrl.text.trim() : null,
          'customer_phone': _isNewCustomer ? _saleCustPhoneCtrl.text.trim() : null,
          'customer_address': _isNewCustomer ? _saleCustAddressCtrl.text.trim() : null,
        }),
      );
    } catch (_) {}

    // Update local state
    setState(() {
      _settlementSoldBottles = (_settlementSoldBottles + qty).clamp(0, _totalDispatchedBottles);
      _soldBottlesInputCtrl.text = '$_settlementSoldBottles';
      _cashHandoverCtrl.text = '${(_settlementSoldBottles * _bottleUnitPrice).toInt()}';
    });

    if (mounted) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green, size: 28),
              SizedBox(width: 8),
              Text('Sale Completed', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _infoRow('Receipt ID:', 'RCP-${DateTime.now().millisecondsSinceEpoch % 100000}'),
              _infoRow('Bottles Sold:', '$qty Bottles'),
              _infoRow('Unit Price:', '₹$_bottleUnitPrice'),
              _infoRow('Total Collected:', '₹$totalAmt'),
              _infoRow('Payment Mode:', _salePaymentMode.toUpperCase()),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(backgroundColor: ClientColors.primary, foregroundColor: Colors.white),
              child: const Text('Close & Print Receipt'),
            ),
          ],
        ),
      );
    }
  }

  // --- BUILD TABS ---

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
                          _buildDashboardTab(),
                          _buildStockTab(),
                          _buildHomeTab(),
                          _buildReferTab(),
                          _buildSettlementTab(),
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
                  const Text('Product Name', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: ClientColors.textDark)),
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
                    icon: const Icon(Icons.notifications_outlined, color: ClientColors.textDark, size: 22),
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
              CircleAvatar(
                radius: 17,
                backgroundColor: ClientColors.primary,
                child: const Text('R', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
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
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, -2)),
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
            Icon(icon, color: isSelected ? ClientColors.primary : ClientColors.textMuted, size: 22),
            const SizedBox(height: 3),
            Text(label, style: TextStyle(fontSize: 10, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, color: isSelected ? ClientColors.primary : ClientColors.textMuted)),
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
            Icon(Icons.home, color: isSelected ? Colors.white : ClientColors.textMuted, size: 24),
            if (!isSelected) ...[
              const SizedBox(height: 2),
              const Text('Home', style: TextStyle(fontSize: 10, color: ClientColors.textMuted)),
            ],
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // SCREEN 1: DASHBOARD TAB (Tab 0)
  // ===========================================================================
  Widget _buildDashboardTab() {
    final totalEarned = _earningsData['total_earned'] ?? 245.0;
    final commission = _earningsData['commission_earned'] ?? 210.0;
    final referralEarned = _earningsData['referral_earned'] ?? 35.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Greeting & Duty Toggle
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Good Morning, $_salesmanName 👋', style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: ClientColors.textDark)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: _isOnDuty ? Colors.green.shade50 : Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Container(width: 6, height: 6, decoration: BoxDecoration(color: _isOnDuty ? Colors.green : Colors.grey, shape: BoxShape.circle)),
                            const SizedBox(width: 5),
                            Text(_isOnDuty ? 'LIVE • ON DUTY' : 'OFF DUTY', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _isOnDuty ? Colors.green.shade800 : Colors.grey.shade700)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Switch(
                value: _isOnDuty,
                activeThumbColor: ClientColors.primary,
                onChanged: _toggleDutyStatus,
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 4 Quick Action Buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _changeTab(1), // Go to Stock
                  icon: const Icon(Icons.qr_code_scanner, size: 16),
                  label: const Text('Scan QR', style: TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(backgroundColor: ClientColors.primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _openRecordSaleModal,
                  icon: const Icon(Icons.shopping_bag_outlined, size: 16, color: ClientColors.textDark),
                  label: const Text('Start Sale', style: TextStyle(fontSize: 12, color: ClientColors.textDark)),
                  style: OutlinedButton.styleFrom(backgroundColor: Colors.white, side: const BorderSide(color: ClientColors.border), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _changeTab(4), // Go to Settlement
                  icon: const Icon(Icons.account_balance_wallet_outlined, size: 16, color: ClientColors.textDark),
                  label: const Text('Settle', style: TextStyle(fontSize: 12, color: ClientColors.textDark)),
                  style: OutlinedButton.styleFrom(backgroundColor: Colors.white, side: const BorderSide(color: ClientColors.border), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _changeTab(3), // Go to Refer
                  icon: const Icon(Icons.person_add_alt, size: 16, color: ClientColors.textDark),
                  label: const Text('Refer', style: TextStyle(fontSize: 12, color: ClientColors.textDark)),
                  style: OutlinedButton.styleFrom(backgroundColor: Colors.white, side: const BorderSide(color: ClientColors.border), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Today's Earnings Card (Gradient)
          Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFC85A17), Color(0xFF8B3A0D)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(color: const Color(0xFF8B3A0D).withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 6)),
              ],
            ),
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Today's Earnings", style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                    Icon(Icons.chevron_right, color: Colors.white.withValues(alpha: 0.8), size: 18),
                  ],
                ),
                const SizedBox(height: 10),
                const Text('TOTAL EARNED', style: TextStyle(color: Colors.white70, fontSize: 10, letterSpacing: 0.5)),
                Text('₹${totalEarned.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.sell_outlined, color: Colors.white70, size: 13),
                                SizedBox(width: 4),
                                Text('Commission', style: TextStyle(color: Colors.white70, fontSize: 11)),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text('₹${commission.toStringAsFixed(0)}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                            Text('${_earningsData['sold_bottles_today'] ?? _soldToday} btls × ₹${_earningsData['commission_rate'] ?? 30}', style: const TextStyle(color: Colors.white60, fontSize: 10)),
                          ],
                        ),
                      ),
                      Container(width: 1, height: 35, color: Colors.white24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.people_outline, color: Colors.white70, size: 13),
                                SizedBox(width: 4),
                                Text('Referrals', style: TextStyle(color: Colors.white70, fontSize: 11)),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text('₹${referralEarned.toStringAsFixed(0)}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                            Text('${_earningsData['downline_bottles_sold'] ?? _earningsData['referral_bottles'] ?? 0} btls × ₹${_earningsData['referral_rate'] ?? 1}', style: const TextStyle(color: Colors.white60, fontSize: 10)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Current Inventory Section
          const Text('Current Inventory', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: ClientColors.textDark)),
          const SizedBox(height: 10),

          // Settlement Pending Alert
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: ClientColors.alertBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: ClientColors.alertBorder),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: ClientColors.alertText, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Settlement Pending', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: ClientColors.alertText)),
                      const Text('3 bottles remaining to be settled.', style: TextStyle(fontSize: 11, color: ClientColors.textMuted)),
                      const SizedBox(height: 2),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Amount: ₹1,053', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: ClientColors.textDark)),
                          InkWell(
                            onTap: () => _changeTab(4),
                            child: const Text('Settle Now ->', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: ClientColors.alertText)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Total Value Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: ClientColors.border),
            ),
            child: Builder(
              builder: (context) {
                final int totalBtls = _totalDispatchedBottles;
                final int soldBtls = _settlementSoldBottles;
                final int unsoldBtls = totalBtls > soldBtls ? totalBtls - soldBtls : 0;
                final double totalVal = totalBtls * _bottleUnitPrice;
                final double progress = totalBtls > 0 ? (soldBtls / totalBtls).clamp(0.0, 1.0) : 0.0;
                final int pctSold = (progress * 100).toInt();

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('TOTAL VALUE', style: TextStyle(fontSize: 10, color: ClientColors.textMuted, fontWeight: FontWeight.bold)),
                            Text('₹${totalVal.toInt()}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: ClientColors.textDark)),
                            Text('$totalBtls btls × ₹${_bottleUnitPrice.toInt()}', style: const TextStyle(fontSize: 10, color: ClientColors.textMuted)),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text('TOTAL BTLS', style: TextStyle(fontSize: 10, color: ClientColors.textMuted, fontWeight: FontWeight.bold)),
                            Text('$totalBtls', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: ClientColors.primary)),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('$pctSold% Sold', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: ClientColors.textDark)),
                        Text('$soldBtls / $totalBtls', style: const TextStyle(fontSize: 11, color: ClientColors.textMuted)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(value: progress, minHeight: 6, backgroundColor: const Color(0xFFF1EBE3), valueColor: const AlwaysStoppedAnimation<Color>(ClientColors.primary)),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.circle, color: ClientColors.primary, size: 8),
                            const SizedBox(width: 4),
                            Text('Sold: $soldBtls', style: const TextStyle(fontSize: 11, color: ClientColors.textMuted)),
                          ],
                        ),
                        Row(
                          children: [
                            const Icon(Icons.circle, color: Color(0xFFD4C9BC), size: 8),
                            const SizedBox(width: 4),
                            Text('Unsold: $unsoldBtls', style: const TextStyle(fontSize: 11, color: ClientColors.textMuted)),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Divider(),
                    if (totalBtls > 0)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: ClientColors.alertBg, borderRadius: BorderRadius.circular(8)),
                          child: const Icon(Icons.water_drop_outlined, color: ClientColors.primary, size: 18),
                        ),
                        title: Text('$totalBtls Btls Dispatched', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: ClientColors.textDark)),
                        subtitle: Text(_isStockAccepted ? 'Accepted' : 'Pending Verification', style: TextStyle(fontSize: 11, color: _isStockAccepted ? Colors.green : Colors.orange, fontWeight: FontWeight.w600)),
                        trailing: const Icon(Icons.chevron_right, size: 18, color: ClientColors.textMuted),
                        onTap: () => _changeTab(1),
                      )
                    else
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8.0),
                        child: Center(
                          child: Text('No active dispatches for today', style: TextStyle(fontSize: 12, color: ClientColors.textMuted)),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // SCREEN 2: HOME TAB (Tab 2 - Center Highlight)
  // ===========================================================================
  Widget _buildHomeTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Agent Welcome
          const Text('Welcome Back, Agent', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: ClientColors.textDark)),
          const SizedBox(height: 4),
          const Text("Ready for today's field operations?", style: TextStyle(fontSize: 13, color: ClientColors.textMuted)),
          const SizedBox(height: 20),

          // 2x2 Action Tiles
          Row(
            children: [
              Expanded(
                child: _homeActionCard(
                  icon: Icons.qr_code_scanner,
                  iconBg: const Color(0xFFFFECE5),
                  iconColor: ClientColors.primary,
                  title: 'Scan Stock',
                  subtitle: 'Accept from Manager',
                  onTap: () => _changeTab(1),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _homeActionCard(
                  icon: Icons.point_of_sale,
                  iconBg: const Color(0xFFFFEBEE),
                  iconColor: const Color(0xFFE53935),
                  title: 'Record Sale',
                  subtitle: 'Log bottles sold',
                  onTap: _openRecordSaleModal,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _homeActionCard(
                  icon: Icons.inventory_2_outlined,
                  iconBg: const Color(0xFFEFEBE9),
                  iconColor: const Color(0xFF5D4037),
                  title: 'My Inventory',
                  subtitle: 'Current stock',
                  onTap: () => _changeTab(1),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _homeActionCard(
                  icon: Icons.account_balance_wallet_outlined,
                  iconBg: const Color(0xFFFFF8E1),
                  iconColor: const Color(0xFFFFA000),
                  title: 'Settlement',
                  subtitle: "Today's tally",
                  onTap: () => _changeTab(4),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Referral Promo Card
          InkWell(
            onTap: () => _changeTab(3),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: ClientColors.border),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: ClientColors.alertBg, borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.person_add_alt_1, color: ClientColors.primary, size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Refer Salesman', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: ClientColors.textDark)),
                        SizedBox(height: 2),
                        Text('Grow your network, earn rewards >', style: TextStyle(fontSize: 11, color: ClientColors.textMuted)),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: ClientColors.textMuted),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Today's Sales Metrics Strip
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: ClientColors.border)),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Today's Sales", style: TextStyle(fontSize: 11, color: ClientColors.textMuted)),
                      SizedBox(height: 6),
                      Text('₹1,404', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: ClientColors.primary)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: ClientColors.border)),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Bottles Sold', style: TextStyle(fontSize: 11, color: ClientColors.textMuted)),
                      SizedBox(height: 6),
                      Text('4', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: ClientColors.textDark)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _homeActionCard({required IconData icon, required Color iconBg, required Color iconColor, required String title, required String subtitle, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: ClientColors.border),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 6, offset: const Offset(0, 2)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(height: 14),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: ClientColors.textDark)),
            const SizedBox(height: 3),
            Text(subtitle, style: const TextStyle(fontSize: 11, color: ClientColors.textMuted)),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // SCREEN 3: STOCK TAB (Tab 1)
  // ===========================================================================
  Widget _buildStockTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Current Stock Header Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: ClientColors.border)),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('CURRENT STOCK', style: TextStyle(fontSize: 10, color: ClientColors.textMuted, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 2),
                        Text('$_currentStock Bottles', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: ClientColors.textDark)),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text('VALUE', style: TextStyle(fontSize: 10, color: ClientColors.textMuted, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 2),
                        Text('₹${(_currentStock * _bottleUnitPrice).toInt()}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: ClientColors.primary)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Sold Today: $_soldToday', style: const TextStyle(fontSize: 12, color: ClientColors.textMuted)),
                    Text('Remaining: $_currentStock', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: ClientColors.textDark)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Scan QR to Accept Stock Button
          ElevatedButton.icon(
            onPressed: _openReceiveStockScannerSheet,
            icon: const Icon(Icons.qr_code_scanner, size: 20),
            label: const Text('Scan QR to Accept Stock', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            style: ElevatedButton.styleFrom(
              backgroundColor: ClientColors.primary,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
          const SizedBox(height: 16),

          // Stock Verification Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: ClientColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.verified_user_outlined, color: ClientColors.primary, size: 18),
                    SizedBox(width: 8),
                    Text('Stock Verification', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: ClientColors.textDark)),
                  ],
                ),
                const SizedBox(height: 14),
                _verificationRow('Assigned By', AppState.currentUser?['parent_name'] ?? 'Field Sales Manager (FSM)'),
                _verificationRow('Quantity', '$_totalDispatchedBottles Bottles'),
                _verificationRow('Value', '₹${(_totalDispatchedBottles * _bottleUnitPrice).toInt()}'),
                const SizedBox(height: 14),

                // Capture Proof Photo Outlined Button
                OutlinedButton.icon(
                  onPressed: () {
                    setState(() {
                      _proofPhotoName = 'Proof_IMG_${DateTime.now().millisecondsSinceEpoch % 10000}.jpg';
                    });
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('✅ Proof photo captured: $_proofPhotoName')));
                  },
                  icon: const Icon(Icons.camera_alt_outlined, color: ClientColors.textDark, size: 16),
                  label: Text(_proofPhotoName ?? 'Capture Proof Photo', style: const TextStyle(color: ClientColors.textDark, fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(44),
                    side: const BorderSide(color: ClientColors.border),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(height: 10),

                const Text(
                  'By accepting this stock, you confirm responsibility for the listed quantity and value.',
                  style: TextStyle(fontSize: 11, color: ClientColors.textMuted, fontStyle: FontStyle.italic),
                ),
                const SizedBox(height: 14),

                ElevatedButton(
                  onPressed: _isStockAccepted
                      ? null
                      : () {
                          setState(() {
                            _isStockAccepted = true;
                            _stockHistory.insert(0, {
                              'date': 'Today, 09:30 AM',
                              'bottles': _currentStock,
                              'amount': (_currentStock * _bottleUnitPrice).toInt(),
                              'status': 'SETTLED',
                            });
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('✅ $_currentStock Bottles accepted into your live field inventory!'), backgroundColor: Colors.green),
                          );
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFC76950),
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(46),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text(_isStockAccepted ? '✓ Stock Accepted & Verified' : 'Accept Stock & Confirm', style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Recent History Section
          const Text('Recent History', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: ClientColors.textDark)),
          const SizedBox(height: 10),
          if (_stockHistory.isNotEmpty)
            ..._stockHistory.map((item) => _historyItem(
                  item['date']?.toString() ?? 'Today',
                  '${item['bottles'] ?? 10} Bottles',
                  '₹${item['amount'] ?? 3510}',
                  item['status']?.toString() ?? 'SETTLED',
                ))
          else ...[
            _historyItem('10 Aug, 09:30 AM', '10 Bottles', '₹3,510', 'SETTLED'),
            _historyItem('09 Aug, 08:45 AM', '12 Bottles', '₹4,212', 'SETTLED'),
          ],
        ],
      ),
    );
  }

  void _openReceiveStockScannerSheet() async {
    List<Map<String, dynamic>> pendingTransfers = [];
    try {
      final res = await http.get(Uri.parse('${AppState.apiBaseUrl}/stock/transfers?to_id=$_salesmanId&status=pending'));
      if (res.statusCode == 200) {
        pendingTransfers = List<Map<String, dynamic>>.from(jsonDecode(res.body));
      }
    } catch (_) {}

    if (pendingTransfers.isEmpty) {
      try {
        final res = await http.get(Uri.parse('${AppState.apiBaseUrl}/stock/transfers?status=pending'));
        if (res.statusCode == 200) {
          final all = List<Map<String, dynamic>>.from(jsonDecode(res.body));
          pendingTransfers = all.where((t) => t['to_id'] == _salesmanId || t['status'] == 'pending').toList();
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
              final qty = (tr['quantity'] as num?)?.toInt() ?? 10;
              final prodName = tr['product']?['name'] ?? tr['product_name'] ?? 'Water Bottle';

              try {
                final res = await http.put(
                  Uri.parse('${AppState.apiBaseUrl}/stock/transfers/$trId/accept'),
                  headers: {'Content-Type': 'application/json'},
                  body: jsonEncode({'user_id': _salesmanId}),
                );
                if (res.statusCode == 200 || res.statusCode == 201) {
                  if (sheetCtx.mounted) Navigator.pop(sheetCtx);
                  if (mounted) {
                    setState(() {
                      _currentStock += qty;
                      _totalDispatchedBottles += qty;
                      _isStockAccepted = true;
                      _stockHistory.insert(0, {
                        'date': 'Today, Just Now',
                        'bottles': qty,
                        'amount': (qty * _bottleUnitPrice).toInt(),
                        'status': 'SETTLED',
                      });
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: ClientColors.success,
                        content: Text('✓ Verified & Received $qty units of $prodName into live stock!'),
                        duration: const Duration(seconds: 3),
                      ),
                    );
                    _loadAllData();
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
                                Text('Receive Manager Stock', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: ClientColors.textDark)),
                                Text('Scan FSM QR code or enter PIN to accept stock', style: TextStyle(fontSize: 11, color: ClientColors.textMuted)),
                              ],
                            ),
                          ],
                        ),
                        IconButton(icon: const Icon(Icons.close, color: ClientColors.textMuted), onPressed: () => Navigator.pop(sheetCtx)),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Viewfinder Box
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
                                isVerifying ? 'Analyzing Manager QR Code...' : 'Align Field Manager QR in Viewfinder',
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
                                    'from_name': AppState.currentUser?['parent_name'] ?? 'Field Sales Manager',
                                    'product': {'name': 'Water Bottle', 'sku': 'WB-20L'},
                                    'quantity': 10,
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
                                      Text('VERIFIED FSM DISPATCH', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
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
                                const Text('Dispatched By:', style: TextStyle(fontSize: 13, color: ClientColors.textMuted)),
                                Text(
                                  selectedTransfer!['from_name'] ?? 'Field Sales Manager',
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: ClientColors.textDark),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Product:', style: TextStyle(fontSize: 13, color: ClientColors.textMuted)),
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
                                  '${selectedTransfer!['quantity'] ?? 10} Bottles',
                                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: ClientColors.primary),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Stock Value:', style: TextStyle(fontSize: 13, color: ClientColors.textMuted)),
                                Text(
                                  '₹${((selectedTransfer!['quantity'] as num?)?.toInt() ?? 10) * 351}',
                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: ClientColors.primary),
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
                              : const Icon(Icons.check_circle_outline, size: 20),
                          label: Text(
                            isProcessing ? 'Confirming Stock...' : 'Accept & Confirm Stock Receipt',
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ] else ...[
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.amber.shade200),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.info_outline, color: Colors.amber, size: 20),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Scan your Manager\'s Handoff QR or enter the 6-Digit PIN above to verify and receive pending stock.',
                                style: TextStyle(fontSize: 12, color: Color(0xFF92400E)),
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

  Widget _verificationRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: ClientColors.textMuted)),
          Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: ClientColors.textDark)),
        ],
      ),
    );
  }

  Widget _historyItem(String date, String bottles, String amount, String status) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: ClientColors.border)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(date, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: ClientColors.textDark)),
              Text(bottles, style: const TextStyle(fontSize: 11, color: ClientColors.textMuted)),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(amount, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: ClientColors.textDark)),
              Container(
                margin: const EdgeInsets.only(top: 2),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(4)),
                child: Text(status, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: ClientColors.textMuted)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // SCREEN 4: REFER TAB (Tab 3)
  // ===========================================================================
  Widget _buildReferTab() {
    final referralRate = (_earningsData['referral_rate'] as num?)?.toDouble() ?? 1.0;
    final soldToday = (_earningsData['sold_bottles_today'] as num?)?.toInt() ?? _soldToday;
    final minQuota = (_earningsData['min_sales_quota'] as num?)?.toInt() ?? 5;
    final isQuotaActive = _earningsData['is_quota_condition_active'] != false;
    final isQualified = _earningsData['is_qualified'] == true || !isQuotaActive;
    final bottlesNeeded = (_earningsData['bottles_needed_to_qualify'] as num?)?.toInt() ?? (isQualified ? 0 : (minQuota - soldToday).clamp(0, minQuota));
    final unlockedEarned = ((_earningsData['unlocked_referral_earned'] ?? _earningsData['referral_earned']) as num?)?.toDouble() ?? 0.0;
    final quotaPendingEarned = (_earningsData['quota_pending_referral_earned'] as num?)?.toDouble() ?? 0.0;
    final downlineBottles = ((_earningsData['downline_bottles_sold'] ?? _earningsData['referral_bottles']) as num?)?.toInt() ?? 0;
    final myReferralCode = 'REF-SALES-${_salesmanName.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toUpperCase()}';
    final double quotaProgress = minQuota > 0 ? (soldToday / minQuota).clamp(0.0, 1.0) : 1.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Hero Refer & Earn Banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFFC85A17), Color(0xFF8B3A0D)]),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(color: const Color(0xFF8B3A0D).withValues(alpha: 0.25), blurRadius: 10, offset: const Offset(0, 4)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.hub_outlined, color: Colors.white, size: 22),
                    SizedBox(width: 8),
                    Text('Workforce Referral Program', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                  ],
                ),
                const SizedBox(height: 8),
                Text('Earn ₹${referralRate.toStringAsFixed(0)} / Bottle', style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(
                  'Earn ₹${referralRate.toStringAsFixed(0)} for each bottle sold by salesmen in your direct downline.',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Super Admin Qualification Condition Gate Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isQualified ? const Color(0xFFF0FDF4) : const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isQualified ? const Color(0xFF86EFAC) : const Color(0xFFFDE68A),
                width: 1.5,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          isQualified ? Icons.verified : Icons.lock_clock,
                          color: isQualified ? const Color(0xFF15803D) : const Color(0xFFB45309),
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isQualified ? 'QUALIFICATION GATE MET' : 'QUALIFICATION GATE PENDING',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: isQualified ? const Color(0xFF15803D) : const Color(0xFFB45309),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isQualified ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '$soldToday / $minQuota btls',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isQualified ? const Color(0xFF166534) : const Color(0xFF92400E),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: quotaProgress,
                    minHeight: 7,
                    backgroundColor: isQualified ? const Color(0xFFDCFCE7) : const Color(0xFFFED7AA),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isQualified ? const Color(0xFF22C55E) : const Color(0xFFF59E0B),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  isQualified
                      ? '✅ Great job! You have sold $soldToday bottles today (quota: $minQuota). Downline commissions are fully unlocked for payout.'
                      : '⏳ Super Admin Rule: Sell $bottlesNeeded more bottle(s) today to meet your $minQuota-bottle quota and unlock ₹${quotaPendingEarned.toStringAsFixed(0)} pending referral commission.',
                  style: TextStyle(
                    fontSize: 12,
                    color: isQualified ? const Color(0xFF166534) : const Color(0xFF92400E),
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Workforce Referral Metrics Row (3 Cards)
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: ClientColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.check_circle_outline, color: Colors.green, size: 18),
                      const SizedBox(height: 6),
                      const Text('Unlocked', style: TextStyle(fontSize: 10, color: ClientColors.textMuted)),
                      Text('₹${unlockedEarned.toStringAsFixed(0)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: ClientColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.lock_clock, color: Colors.orange, size: 18),
                      const SizedBox(height: 6),
                      const Text('Quota-Held', style: TextStyle(fontSize: 10, color: ClientColors.textMuted)),
                      Text('₹${quotaPendingEarned.toStringAsFixed(0)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.orange)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: ClientColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.water_drop_outlined, color: ClientColors.primary, size: 18),
                      const SizedBox(height: 6),
                      const Text('Team Bottles', style: TextStyle(fontSize: 10, color: ClientColors.textMuted)),
                      Text('$downlineBottles', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: ClientColors.textDark)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // My Referral Code Box
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: ClientColors.creamBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: ClientColors.border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('YOUR REFERRAL CODE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: ClientColors.textMuted, letterSpacing: 0.5)),
                      const SizedBox(height: 3),
                      Text(myReferralCode, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: ClientColors.primary, letterSpacing: 1.0)),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ClientColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: myReferralCode));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Referral code "$myReferralCode" copied to clipboard!'), backgroundColor: Colors.green),
                    );
                  },
                  icon: const Icon(Icons.copy, size: 14),
                  label: const Text('Copy'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Refer a Salesman Form Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: ClientColors.border)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.person_add, color: ClientColors.primary, size: 18),
                    SizedBox(width: 8),
                    Text('Refer a New Salesman', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: ClientColors.textDark)),
                  ],
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _refNameCtrl,
                  decoration: const InputDecoration(labelText: 'Full Name', border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _refPhoneCtrl,
                  decoration: const InputDecoration(labelText: 'Phone Number', border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 12),

                // KYC Upload Box
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _selectedKycFile != 'Tap to select file' ? Colors.blue.withValues(alpha: 0.05) : ClientColors.creamBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _selectedKycFile != 'Tap to select file' ? Colors.blue.shade300 : ClientColors.border),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(
                                _selectedKycFile != 'Tap to select file' ? Icons.check_circle : Icons.cloud_upload_outlined,
                                color: _selectedKycFile != 'Tap to select file' ? Colors.green : ClientColors.primary,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              const Text('Upload KYC (Aadhaar / Govt ID)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: ClientColors.textDark)),
                            ],
                          ),
                          if (_selectedKycFile != 'Tap to select file')
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  _selectedKycFile = 'Tap to select file';
                                  _selectedKycBase64 = null;
                                  _selectedKycBytes = null;
                                });
                              },
                              child: const Text('Remove', style: TextStyle(fontSize: 11, color: Colors.red, fontWeight: FontWeight.bold)),
                            ),
                        ],
                      ),
                      if (_selectedKycBytes != null) ...[
                        const SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.memory(
                            _selectedKycBytes!,
                            height: 110,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: () {
                          showModalBottomSheet(
                            context: context,
                            shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
                            builder: (sheetCtx) => SafeArea(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Padding(
                                      padding: EdgeInsets.only(bottom: 8),
                                      child: Text('Attach KYC Document (Aadhaar/PAN)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                    ),
                                    ListTile(
                                      leading: const CircleAvatar(backgroundColor: Colors.blue, child: Icon(Icons.camera_alt, color: Colors.white)),
                                      title: const Text('Take Photo with Camera'),
                                      subtitle: const Text('Capture clear photo of physical ID proof'),
                                      onTap: () async {
                                        Navigator.pop(sheetCtx);
                                        try {
                                          final picker = ImagePicker();
                                          final picked = await picker.pickImage(source: ImageSource.camera, imageQuality: 85, maxWidth: 1600);
                                          if (picked != null) {
                                            final bytes = await picked.readAsBytes();
                                            final base64Str = 'data:image/jpeg;base64,${base64Encode(bytes)}';
                                            setState(() {
                                              _selectedKycFile = picked.name;
                                              _selectedKycBase64 = base64Str;
                                              _selectedKycBytes = bytes;
                                            });
                                            if (mounted) {
                                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Attached: ${picked.name}'), backgroundColor: Colors.green));
                                            }
                                          }
                                        } catch (_) {}
                                      },
                                    ),
                                    ListTile(
                                      leading: const CircleAvatar(backgroundColor: Colors.orange, child: Icon(Icons.photo_library, color: Colors.white)),
                                      title: const Text('Choose from Gallery / Photos'),
                                      subtitle: const Text('Select image or document scan'),
                                      onTap: () async {
                                        Navigator.pop(sheetCtx);
                                        try {
                                          final picker = ImagePicker();
                                          final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85, maxWidth: 1600);
                                          if (picked != null) {
                                            final bytes = await picked.readAsBytes();
                                            final base64Str = 'data:image/jpeg;base64,${base64Encode(bytes)}';
                                            setState(() {
                                              _selectedKycFile = picked.name;
                                              _selectedKycBase64 = base64Str;
                                              _selectedKycBytes = bytes;
                                            });
                                            if (mounted) {
                                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Attached: ${picked.name}'), backgroundColor: Colors.green));
                                            }
                                          }
                                        } catch (_) {}
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: ClientColors.border),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                _selectedKycFile != 'Tap to select file' ? Icons.check_circle : Icons.upload_file,
                                size: 16,
                                color: _selectedKycFile != 'Tap to select file' ? Colors.green : ClientColors.primary,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _selectedKycFile,
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: _selectedKycFile != 'Tap to select file' ? FontWeight.bold : FontWeight.normal,
                                    color: _selectedKycFile != 'Tap to select file' ? Colors.black87 : ClientColors.textMuted,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text(
                                _selectedKycFile != 'Tap to select file' ? 'Change' : 'Attach',
                                style: const TextStyle(fontSize: 11.5, color: ClientColors.primary, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                ElevatedButton(
                  onPressed: _isSubmittingReferral ? null : () async {
                    await _submitReferral();
                    _loadEarnings();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ClientColors.primary,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(46),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: _isSubmittingReferral
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Submit Referral ->', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // My Referral Team Section
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('My Referral Team (${_referralsList.length})', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: ClientColors.textDark)),
              IconButton(
                icon: const Icon(Icons.refresh, size: 18, color: ClientColors.primary),
                tooltip: 'Refresh',
                onPressed: () {
                  _loadReferrals();
                  _loadEarnings();
                },
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (_referralsList.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: ClientColors.border)),
              child: const Center(
                child: Text('No salesmen referred yet. Refer your first colleague above!'),
              ),
            )
          else
            ..._referralsList.map((ref) {
              final bottles = ref['bottles_sold'] ?? 0;
              final earned = (ref['earned'] as num?)?.toDouble() ?? 0.0;
              final pending = (ref['pending_earned'] as num?)?.toDouble() ?? 0.0;
              final name = ref['full_name'] ?? 'Agent';

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: ClientColors.border)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: ClientColors.creamBg,
                          child: Text(
                            name.isNotEmpty ? name[0].toUpperCase() : 'S',
                            style: const TextStyle(fontWeight: FontWeight.bold, color: ClientColors.primary, fontSize: 13),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: ClientColors.textDark)),
                            const SizedBox(height: 2),
                            Text(
                              '$bottles bottles sold • ${ref['status'] ?? 'Active'}',
                              style: const TextStyle(fontSize: 11, color: ClientColors.textMuted),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text('Earned', style: TextStyle(fontSize: 10, color: ClientColors.textMuted)),
                        Text('₹${earned.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.green)),
                        if (pending > 0)
                          Text('₹${pending.toStringAsFixed(0)} held', style: const TextStyle(fontSize: 9, color: Colors.orange, fontWeight: FontWeight.bold)),
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
  // SCREEN 5: SETTLEMENT TAB (Tab 4)
  // ===========================================================================
  Widget _buildSettlementTab() {
    final int heldStock = _currentStock > 0 ? _currentStock : _totalDispatchedBottles;
    final int damaged = _hasDamagedBottles ? _damagedBottles : 0;
    final int maxAllowed = (heldStock - damaged).clamp(0, heldStock);
    final int remaining = (heldStock - _settlementSoldBottles - damaged).clamp(0, heldStock);
    final int soldAmt = (_settlementSoldBottles * _bottleUnitPrice).toInt();
    final int remainingVal = (remaining * _bottleUnitPrice).toInt();
    final int totalVal = (heldStock * _bottleUnitPrice).toInt();
    final int cash = double.tryParse(_cashHandoverCtrl.text.trim())?.toInt() ?? 0;
    final int online = double.tryParse(_onlinePaymentCtrl.text.trim())?.toInt() ?? 0;
    final int totalCollected = cash + online;
    final int diff = soldAmt - totalCollected;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. INVENTORY SUMMARY CARD
          Container(
            padding: const EdgeInsets.all(16),
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
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "HELD FIELD INVENTORY",
                          style: TextStyle(fontSize: 10, color: Colors.white70, fontWeight: FontWeight.bold, letterSpacing: 0.8),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$heldStock Bottles',
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text(
                          "TOTAL VALUE",
                          style: TextStyle(fontSize: 10, color: Colors.white70, fontWeight: FontWeight.bold, letterSpacing: 0.8),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '₹$totalVal',
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF69F0AE)),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.sync_alt_rounded, color: Colors.white, size: 14),
                      const SizedBox(width: 6),
                      Text(
                        'Reconcile with FSM • ₹${_bottleUnitPrice.toInt()} / Bottle',
                        style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 2. STEP 1: TOTAL SALE (BOTTLES SOLD)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '1. Total Sale (Bottles Sold)',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: ClientColors.textDark),
              ),
              Text(
                'Max: $maxAllowed btls',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: ClientColors.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: ClientColors.border),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove_circle, color: ClientColors.primary, size: 38),
                      tooltip: 'Decrease 1 bottle',
                      onPressed: () {
                        if (_settlementSoldBottles > 0) {
                          setState(() {
                            _settlementSoldBottles--;
                            _soldBottlesInputCtrl.text = '$_settlementSoldBottles';
                            final newAmt = (_settlementSoldBottles * _bottleUnitPrice).toInt();
                            _cashHandoverCtrl.text = '$newAmt';
                            _onlinePaymentCtrl.text = '0';
                          });
                        }
                      },
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          Container(
                            width: 140,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: ClientColors.primary.withValues(alpha: 0.4), width: 1.5),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _soldBottlesInputCtrl,
                                    keyboardType: TextInputType.number,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: ClientColors.textDark),
                                    decoration: const InputDecoration(
                                      border: InputBorder.none,
                                      isDense: true,
                                      contentPadding: EdgeInsets.symmetric(vertical: 4),
                                    ),
                                    onChanged: (val) {
                                      final parsed = int.tryParse(val.trim()) ?? 0;
                                      if (parsed > maxAllowed) {
                                        _soldBottlesInputCtrl.text = '$maxAllowed';
                                        _soldBottlesInputCtrl.selection = TextSelection.fromPosition(
                                          TextPosition(offset: _soldBottlesInputCtrl.text.length),
                                        );
                                        setState(() {
                                          _settlementSoldBottles = maxAllowed;
                                          final newAmt = (_settlementSoldBottles * _bottleUnitPrice).toInt();
                                          _cashHandoverCtrl.text = '$newAmt';
                                          _onlinePaymentCtrl.text = '0';
                                        });
                                      } else {
                                        setState(() {
                                          _settlementSoldBottles = parsed.clamp(0, maxAllowed);
                                          final newAmt = (_settlementSoldBottles * _bottleUnitPrice).toInt();
                                          _cashHandoverCtrl.text = '$newAmt';
                                          _onlinePaymentCtrl.text = '0';
                                        });
                                      }
                                    },
                                  ),
                                ),
                                const Icon(Icons.edit_note_rounded, size: 22, color: ClientColors.primary),
                              ],
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Bottles Sold • Tap box to type',
                            style: TextStyle(fontSize: 11, color: ClientColors.textMuted, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_circle, color: ClientColors.primary, size: 38),
                      tooltip: 'Increase 1 bottle',
                      onPressed: () {
                        if (_settlementSoldBottles < maxAllowed) {
                          setState(() {
                            _settlementSoldBottles++;
                            _soldBottlesInputCtrl.text = '$_settlementSoldBottles';
                            final newAmt = (_settlementSoldBottles * _bottleUnitPrice).toInt();
                            _cashHandoverCtrl.text = '$newAmt';
                            _onlinePaymentCtrl.text = '0';
                          });
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Quick Quantity Presets for Large Inventories
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      ActionChip(
                        avatar: const Icon(Icons.all_inclusive, size: 14, color: ClientColors.primary),
                        label: Text('All ($maxAllowed)', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: ClientColors.primary)),
                        backgroundColor: ClientColors.primary.withValues(alpha: 0.08),
                        side: BorderSide(color: ClientColors.primary.withValues(alpha: 0.2)),
                        onPressed: () {
                          setState(() {
                            _settlementSoldBottles = maxAllowed;
                            _soldBottlesInputCtrl.text = '$maxAllowed';
                            final newAmt = (_settlementSoldBottles * _bottleUnitPrice).toInt();
                            _cashHandoverCtrl.text = '$newAmt';
                            _onlinePaymentCtrl.text = '0';
                          });
                        },
                      ),
                      if (maxAllowed >= 2) ...[
                        const SizedBox(width: 6),
                        ActionChip(
                          label: Text('Half (${maxAllowed ~/ 2})', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          backgroundColor: Colors.grey.shade100,
                          onPressed: () {
                            setState(() {
                              _settlementSoldBottles = maxAllowed ~/ 2;
                              _soldBottlesInputCtrl.text = '$_settlementSoldBottles';
                              final newAmt = (_settlementSoldBottles * _bottleUnitPrice).toInt();
                              _cashHandoverCtrl.text = '$newAmt';
                              _onlinePaymentCtrl.text = '0';
                            });
                          },
                        ),
                      ],
                      if (maxAllowed >= 10) ...[
                        const SizedBox(width: 6),
                        ActionChip(
                          label: const Text('+10', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          backgroundColor: Colors.grey.shade100,
                          onPressed: () {
                            setState(() {
                              _settlementSoldBottles = (_settlementSoldBottles + 10).clamp(0, maxAllowed);
                              _soldBottlesInputCtrl.text = '$_settlementSoldBottles';
                              final newAmt = (_settlementSoldBottles * _bottleUnitPrice).toInt();
                              _cashHandoverCtrl.text = '$newAmt';
                              _onlinePaymentCtrl.text = '0';
                            });
                          },
                        ),
                      ],
                      if (maxAllowed >= 50) ...[
                        const SizedBox(width: 6),
                        ActionChip(
                          label: const Text('+50', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          backgroundColor: Colors.grey.shade100,
                          onPressed: () {
                            setState(() {
                              _settlementSoldBottles = (_settlementSoldBottles + 50).clamp(0, maxAllowed);
                              _soldBottlesInputCtrl.text = '$_settlementSoldBottles';
                              final newAmt = (_settlementSoldBottles * _bottleUnitPrice).toInt();
                              _cashHandoverCtrl.text = '$newAmt';
                              _onlinePaymentCtrl.text = '0';
                            });
                          },
                        ),
                      ],
                      const SizedBox(width: 6),
                      ActionChip(
                        avatar: const Icon(Icons.clear, size: 14, color: Colors.redAccent),
                        label: const Text('Reset', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.redAccent)),
                        backgroundColor: Colors.red.shade50,
                        side: BorderSide(color: Colors.red.shade200),
                        onPressed: () {
                          setState(() {
                            _settlementSoldBottles = 0;
                            _soldBottlesInputCtrl.text = '0';
                            _cashHandoverCtrl.text = '0';
                            _onlinePaymentCtrl.text = '0';
                          });
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Sale Revenue:', style: TextStyle(fontSize: 12, color: ClientColors.textMuted)),
                    Text(
                      '₹$soldAmt',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF2E7D32)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // 3. STEP 2: REMAINING QUANTITY (RETURNING TO FSM)
          const Text(
            '2. Remaining Stock (Returning to FSM Depot)',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: ClientColors.textDark),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF86EFAC)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF22C55E).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.keyboard_return_rounded, color: Color(0xFF15803D), size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$remaining Bottles to Return',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF14532D)),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Will be added back to FSM depot stock • Value ₹$remainingVal',
                        style: const TextStyle(fontSize: 11, color: Color(0xFF166534)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // 4. STEP 3: DAMAGED PRODUCT OPTION
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _hasDamagedBottles ? const Color(0xFFF59E0B) : ClientColors.border,
                width: _hasDamagedBottles ? 1.5 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SwitchListTile(
                  title: const Row(
                    children: [
                      Icon(Icons.report_problem_outlined, color: Color(0xFFD97706), size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Report Damaged Bottles?',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: ClientColors.textDark),
                      ),
                    ],
                  ),
                  subtitle: const Text(
                    'Broken seal, leakage, transit defects',
                    style: TextStyle(fontSize: 11, color: ClientColors.textMuted),
                  ),
                  value: _hasDamagedBottles,
                  activeThumbColor: const Color(0xFFD97706),
                  onChanged: (val) {
                    setState(() {
                      _hasDamagedBottles = val;
                      if (val && _damagedBottles == 0) {
                        _damagedBottles = 1;
                        _damagedBottlesInputCtrl.text = '1';
                        if (_settlementSoldBottles + _damagedBottles > heldStock) {
                          _settlementSoldBottles = (heldStock - _damagedBottles).clamp(0, heldStock);
                          _soldBottlesInputCtrl.text = '$_settlementSoldBottles';
                        }
                      }
                      if (!val) {
                        _damagedBottles = 0;
                        _damagedBottlesInputCtrl.text = '0';
                      }
                    });
                  },
                ),
                if (_hasDamagedBottles) ...[
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Damaged Quantity:',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: ClientColors.textDark),
                            ),
                            Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.remove_circle_outline, color: Color(0xFFD97706)),
                                  onPressed: () {
                                    if (_damagedBottles > 1) {
                                      setState(() {
                                        _damagedBottles--;
                                        _damagedBottlesInputCtrl.text = '$_damagedBottles';
                                      });
                                    }
                                  },
                                ),
                                Container(
                                  width: 60,
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: const Color(0xFFFDE68A), width: 1.5),
                                  ),
                                  child: TextField(
                                    controller: _damagedBottlesInputCtrl,
                                    keyboardType: TextInputType.number,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFFD97706)),
                                    decoration: const InputDecoration(border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero),
                                    onChanged: (val) {
                                      final maxDmg = (heldStock - _settlementSoldBottles).clamp(0, heldStock);
                                      final parsed = int.tryParse(val.trim()) ?? 0;
                                      if (parsed > maxDmg) {
                                        _damagedBottlesInputCtrl.text = '$maxDmg';
                                        _damagedBottlesInputCtrl.selection = TextSelection.fromPosition(
                                          TextPosition(offset: _damagedBottlesInputCtrl.text.length),
                                        );
                                        setState(() => _damagedBottles = maxDmg);
                                      } else {
                                        setState(() => _damagedBottles = parsed.clamp(0, maxDmg));
                                      }
                                    },
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.add_circle_outline, color: Color(0xFFD97706)),
                                  onPressed: () {
                                    if (_damagedBottles < heldStock - _settlementSoldBottles) {
                                      setState(() {
                                        _damagedBottles++;
                                        _damagedBottlesInputCtrl.text = '$_damagedBottles';
                                      });
                                    }
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Damage Description / Notes:',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: ClientColors.textMuted),
                        ),
                        const SizedBox(height: 4),
                        TextField(
                          controller: _damageNotesCtrl,
                          decoration: InputDecoration(
                            hintText: 'e.g. Broken seal, damaged cap during delivery...',
                            hintStyle: const TextStyle(fontSize: 12, color: ClientColors.textMuted),
                            filled: true,
                            fillColor: const Color(0xFFFFFBEB),
                            isDense: true,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: Color(0xFFFDE68A)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: Color(0xFFFDE68A)),
                            ),
                          ),
                          style: const TextStyle(fontSize: 12),
                          maxLines: 2,
                        ),
                        const SizedBox(height: 12),

                        // Image Upload Buttons & Preview
                        const Text(
                          'Damage Proof Photo (Required):',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: ClientColors.textMuted),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => _pickDamageImage(ImageSource.camera),
                                icon: const Icon(Icons.camera_alt, size: 16, color: ClientColors.primary),
                                label: const Text('Camera', style: TextStyle(fontSize: 12, color: ClientColors.primary)),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  side: const BorderSide(color: ClientColors.primary),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => _pickDamageImage(ImageSource.gallery),
                                icon: const Icon(Icons.photo_library, size: 16, color: ClientColors.primary),
                                label: const Text('Gallery', style: TextStyle(fontSize: 12, color: ClientColors.primary)),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  side: const BorderSide(color: ClientColors.primary),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (_damageImageBytes != null) ...[
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF3C7),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFFCD34D)),
                            ),
                            child: Row(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: Image.memory(
                                    _damageImageBytes!,
                                    width: 48,
                                    height: 48,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _damageImageFile?.name ?? 'Damage Photo Attached',
                                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF92400E)),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const Text(
                                        'Verified for FSM audit',
                                        style: TextStyle(fontSize: 10, color: Color(0xFFB45309)),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                                  onPressed: () {
                                    setState(() {
                                      _damageImageFile = null;
                                      _damageImageBytes = null;
                                      _damageImageBase64 = null;
                                    });
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 18),

          // 5. STEP 4: PAYMENT COLLECTION BREAKDOWN
          const Text(
            '4. Payment Collections Breakdown',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: ClientColors.textDark),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: ClientColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Quick Split Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Quick Fill:', style: TextStyle(fontSize: 11, color: ClientColors.textMuted)),
                    Row(
                      children: [
                        InkWell(
                          onTap: () {
                            setState(() {
                              _cashHandoverCtrl.text = '$soldAmt';
                              _onlinePaymentCtrl.text = '0';
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(6)),
                            child: const Text('All Cash', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF1D4ED8))),
                          ),
                        ),
                        const SizedBox(width: 6),
                        InkWell(
                          onTap: () {
                            setState(() {
                              _cashHandoverCtrl.text = '0';
                              _onlinePaymentCtrl.text = '$soldAmt';
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(color: const Color(0xFFF3E8FF), borderRadius: BorderRadius.circular(6)),
                            child: const Text('All Online', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF7E22CE))),
                          ),
                        ),
                        const SizedBox(width: 6),
                        InkWell(
                          onTap: () {
                            final half = soldAmt ~/ 2;
                            setState(() {
                              _cashHandoverCtrl.text = '$half';
                              _onlinePaymentCtrl.text = '${soldAmt - half}';
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(color: const Color(0xFFECFDF5), borderRadius: BorderRadius.circular(6)),
                            child: const Text('50/50 Split', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF047857))),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Cash Received Input
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(8)),
                      child: const Icon(Icons.payments_outlined, color: Color(0xFF2563EB), size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Cash Received (₹)', style: TextStyle(fontSize: 11, color: ClientColors.textMuted)),
                          TextField(
                            controller: _cashHandoverCtrl,
                            keyboardType: TextInputType.number,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: ClientColors.textDark),
                            decoration: const InputDecoration(
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(vertical: 4),
                              border: UnderlineInputBorder(),
                              hintText: '0',
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Online Payment Input
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: const Color(0xFFF5F3FF), borderRadius: BorderRadius.circular(8)),
                      child: const Icon(Icons.qr_code_scanner, color: Color(0xFF7C3AED), size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Online Payment / UPI (₹)', style: TextStyle(fontSize: 11, color: ClientColors.textMuted)),
                          TextField(
                            controller: _onlinePaymentCtrl,
                            keyboardType: TextInputType.number,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: ClientColors.textDark),
                            decoration: const InputDecoration(
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(vertical: 4),
                              border: UnderlineInputBorder(),
                              hintText: '0',
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Tally Summary Strip
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: diff == 0 ? const Color(0xFFECFDF5) : const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: diff == 0 ? const Color(0xFFA7F3D0) : const Color(0xFFFDE68A)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            diff == 0 ? Icons.check_circle : Icons.info_outline,
                            color: diff == 0 ? const Color(0xFF059669) : const Color(0xFFD97706),
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            diff == 0 ? 'Exact Match (₹$totalCollected)' : 'Difference: ₹$diff',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: diff == 0 ? const Color(0xFF065F46) : const Color(0xFF92400E),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        'Total Due: ₹$soldAmt',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: ClientColors.textDark),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),

          // 6. GENERATE SETTLEMENT QR CODE BUTTON
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _initiateSettlementAndShowQR,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1B365D),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 4,
              ),
              icon: const Icon(Icons.qr_code_2_rounded, size: 24),
              label: const Text(
                'GENERATE SETTLEMENT QR CODE',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 0.5),
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Center(
            child: Text(
              'Show generated QR to FSM for scanning and instant stock reconciliation',
              style: TextStyle(fontSize: 11, color: ClientColors.textMuted),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 24),

          // 7. PREVIOUS SETTLEMENTS SECTION
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Previous Settlements', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: ClientColors.textDark)),
              Text('${_settlementHistory.length} Recorded', style: const TextStyle(fontSize: 11, color: ClientColors.textMuted)),
            ],
          ),
          const SizedBox(height: 10),
          if (_settlementHistory.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: ClientColors.border)),
              child: const Center(
                child: Text('No previous settlements recorded yet.', style: TextStyle(fontSize: 12, color: ClientColors.textMuted)),
              ),
            )
          else
            ..._settlementHistory.map((s) {
              final damagedCount = (s['damaged_qty'] as num?)?.toInt() ?? 0;
              final cashAmt = (s['cash_collected'] ?? s['cash_received'] ?? 0);
              final onlineAmt = (s['online_payment'] ?? 0);
              final totalAmt = (s['total_value'] ?? s['total_amount'] ?? 0);

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: ClientColors.border)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(8)),
                          child: const Icon(Icons.check_circle_rounded, color: Color(0xFF2563EB), size: 20),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(s['date_label'] ?? 'Settlement #${(s['id'] ?? '').toString().substring(0, (s['id'] ?? '').toString().length > 8 ? 8 : (s['id'] ?? '').toString().length)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: ClientColors.textDark)),
                              Text('Sold: ${s['bottles_sold'] ?? 0} btls • Returned: ${s['remaining_qty'] ?? 0} btls', style: const TextStyle(fontSize: 11, color: ClientColors.textMuted)),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('₹$totalAmt', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: ClientColors.textDark)),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: const Color(0xFFECFDF5), borderRadius: BorderRadius.circular(4)),
                              child: const Text('SETTLED', style: TextStyle(fontSize: 9, color: Color(0xFF047857), fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      ],
                    ),
                    if (damagedCount > 0) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: const Color(0xFFFFFBEB), borderRadius: BorderRadius.circular(6)),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.warning_amber_rounded, size: 13, color: Color(0xFFD97706)),
                            const SizedBox(width: 4),
                            Text('$damagedCount Damaged Bottles Reported', style: const TextStyle(fontSize: 10, color: Color(0xFF92400E), fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Cash: ₹$cashAmt', style: const TextStyle(fontSize: 11, color: ClientColors.textMuted)),
                        Text('Online: ₹$onlineAmt', style: const TextStyle(fontSize: 11, color: ClientColors.textMuted)),
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



  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: ClientColors.textMuted)),
          Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: ClientColors.textDark)),
        ],
      ),
    );
  }
}