import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../core/constants/colors.dart';
import '../../core/state/app_state.dart';

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

  String get _warehouseId => AppState.currentUser?['warehouse_id'] ?? 'w1';

  @override
  void initState() {
    super.initState();
    _loadAllStoreData();
  }

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
    ]);
    if (mounted) setState(() => _isLoading = false);
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
                child: _buildBody(),
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
        return _buildInventoryAndIntakeTab();
      case 1:
        return _buildFsmDistributionTab();
      case 2:
        return _buildDirectRetailSaleTab();
      case 3:
        return _buildDistributorSaleTab();
      case 4:
        return _buildReportsTab();
      default:
        return _buildInventoryAndIntakeTab();
    }
  }

  // ==========================================
  // TAB 0: INVENTORY & STOCK INTAKE
  // ==========================================
  Widget _buildInventoryAndIntakeTab() {
    final totalUnits = _warehouseStocks.fold<int>(0, (sum, item) {
      final q = item['quantity'] is int ? item['quantity'] : int.tryParse(item['quantity'].toString()) ?? 0;
      return sum + (q as int);
    });

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Warehouse Header Card
          Card(
            color: AppColors.primary,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(18.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(12)),
                        child: const Icon(Icons.warehouse, color: Colors.white, size: 28),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Central Warehouse Hub', style: TextStyle(color: Colors.white70, fontSize: 13)),
                            Text(
                              'Warehouse #$_warehouseId',
                              style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(20)),
                        child: const Text('Store Admin', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                      )
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(color: Colors.white24),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildHeaderStat('Products', '${_products.length} SKUs'),
                      _buildHeaderStat('Total Stock', '$totalUnits Units'),
                      _buildHeaderStat('Low Stock', '${_alerts.length} Items', alert: _alerts.isNotEmpty),
                    ],
                  )
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Low Stock Alert Banner
          if (_alerts.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.shade300),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Low Warehouse Stock Alert!', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 14)),
                        Text(
                          '${_alerts.length} item(s) below threshold. Immediate stock intake recommended.',
                          style: TextStyle(color: Colors.red.shade800, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Quick Action: Add Stock Intake
          ElevatedButton.icon(
            onPressed: _showStockIntakeModal,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.add_shopping_cart),
            label: const Text('Add New Stock Intake (Batch/Supplier)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          ),
          const SizedBox(height: 20),

          // Section: Current Warehouse Stock Levels
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Current Stock Levels', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              Text('${_products.length} Products', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 12),

          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _products.length,
            itemBuilder: (context, index) {
              final product = _products[index];
              final pId = product['id'];
              final stock = _getStockForProduct(pId);
              final minAlert = product['min_stock_alert'] ?? 20;
              final isLow = stock <= minAlert;
              final retailPrice = _getRetailPriceForProduct(pId);
              final distPrice = _getDistributorPriceForProduct(pId);

              return Card(
                color: Colors.white,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: isLow ? Colors.red.shade300 : Colors.grey.shade200, width: isLow ? 1.5 : 1),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              product['name'] ?? 'Product',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textPrimary),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: isLow ? Colors.red.shade100 : Colors.green.shade100,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              isLow ? 'LOW STOCK' : 'IN STOCK',
                              style: TextStyle(
                                color: isLow ? Colors.red.shade900 : Colors.green.shade900,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text('SKU: ${product['sku'] ?? 'N/A'} • Unit: ${product['unit'] ?? 'packet'} • Category: ${product['category'] ?? 'General'}',
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Available Stock', style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                              Text('$stock ${product['unit'] ?? 'units'}',
                                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isLow ? Colors.red : AppColors.primary)),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.lock, size: 12, color: Colors.amber),
                                  const SizedBox(width: 4),
                                  Text('Retail: ₹$retailPrice', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                ],
                              ),
                              Row(
                                children: [
                                  const Icon(Icons.lock, size: 12, color: Colors.amber),
                                  const SizedBox(width: 4),
                                  Text('Distributor: ₹$distPrice', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.accent)),
                                ],
                              ),
                            ],
                          )
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderStat(String label, String value, {bool alert = false}) {
    return Column(
      children: [
        Text(value, style: TextStyle(color: alert ? Colors.amberAccent : Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
      ],
    );
  }

  // Stock Intake Bottom Sheet Modal
  void _showStockIntakeModal() {
    String selectedProduct = _products.isNotEmpty ? _products.first['id'] : 'p1';
    final qtyController = TextEditingController();
    final batchController = TextEditingController(text: 'BATCH-${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}');
    final supplierController = TextEditingController();
    final dateController = TextEditingController(text: DateTime.now().toIso8601String().split('T').first);
    XFile? receiptFile;
    Uint8List? receiptBytes;
    bool isSubmitting = false;

    Future<void> pickInvoice(ImageSource source, StateSetter setModalState) async {
      try {
        final picker = ImagePicker();
        final img = await picker.pickImage(
          source: source,
          imageQuality: 85,
          maxWidth: 1920,
          maxHeight: 1920,
        );
        if (img != null) {
          final bytes = await img.readAsBytes();
          setModalState(() {
            receiptFile = img;
            receiptBytes = bytes;
          });
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not attach image: $e')),
          );
        }
      }
    }

    void showSourceSelectionSheet(BuildContext parentCtx, StateSetter setModalState) {
      showModalBottomSheet(
        context: parentCtx,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (sheetCtx) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const Text(
                    'Attach Supplier Invoice / Challan',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Select upload method for document proof',
                    style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Colors.grey.shade200),
                    ),
                    tileColor: AppColors.background,
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.camera_alt, color: AppColors.primary),
                    ),
                    title: const Text(
                      'Capture with Camera',
                      style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                    ),
                    subtitle: const Text('Take a photo of physical challan / invoice'),
                    trailing: const Icon(Icons.chevron_right, color: AppColors.textSecondary),
                    onTap: () {
                      Navigator.pop(sheetCtx);
                      pickInvoice(ImageSource.camera, setModalState);
                    },
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Colors.grey.shade200),
                    ),
                    tileColor: AppColors.background,
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.photo_library, color: AppColors.accent),
                    ),
                    title: const Text(
                      'Select from Gallery',
                      style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                    ),
                    subtitle: const Text('Choose existing photo from device gallery'),
                    trailing: const Icon(Icons.chevron_right, color: AppColors.textSecondary),
                    onTap: () {
                      Navigator.pop(sheetCtx);
                      pickInvoice(ImageSource.gallery, setModalState);
                    },
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          );
        },
      );
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Stock Intake Entry', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                        IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                      ],
                    ),
                    const Text('Add new supplier stock arrival to warehouse inventory with batch tracking.', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                    const SizedBox(height: 16),

                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: selectedProduct,
                      decoration: const InputDecoration(labelText: 'Product', border: OutlineInputBorder()),
                      items: _products.map((p) {
                        return DropdownMenuItem<String>(
                          value: p['id'].toString(),
                          child: Text('${p['name']} (${p['sku']})', overflow: TextOverflow.ellipsis),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setModalState(() => selectedProduct = val);
                      },
                    ),
                    const SizedBox(height: 14),

                    TextField(
                      controller: qtyController,
                      decoration: const InputDecoration(labelText: 'Received Quantity (Units)', border: OutlineInputBorder()),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 14),

                    TextField(
                      controller: batchController,
                      decoration: const InputDecoration(labelText: 'Batch / Lot Number', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 14),

                    TextField(
                      controller: supplierController,
                      decoration: const InputDecoration(labelText: 'Supplier / Vendor Name', hintText: 'e.g., Atlas Coffee Exporters Ltd', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 14),

                    TextField(
                      controller: dateController,
                      decoration: const InputDecoration(labelText: 'Date Received (YYYY-MM-DD)', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 14),

                    // Attachment Section (Camera or Gallery)
                    if (receiptFile == null)
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: ClientColors.border, width: 1.2),
                        ),
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.receipt_long, color: AppColors.primary, size: 20),
                                ),
                                const SizedBox(width: 10),
                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Supplier Invoice / Challan',
                                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                      ),
                                      Text(
                                        'Attach physical proof (Camera or Gallery)',
                                        style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () => pickInvoice(ImageSource.camera, setModalState),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: AppColors.primary,
                                      side: const BorderSide(color: AppColors.primary),
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                    icon: const Icon(Icons.camera_alt, size: 18),
                                    label: const Text('Camera', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () => pickInvoice(ImageSource.gallery, setModalState),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primary,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      elevation: 0,
                                    ),
                                    icon: const Icon(Icons.photo_library, size: 18),
                                    label: const Text('Gallery', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      )
                    else
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.green.shade50.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.green.shade300, width: 1.2),
                        ),
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                if (receiptBytes != null)
                                  GestureDetector(
                                    onTap: () {
                                      showDialog(
                                        context: context,
                                        builder: (previewCtx) => Dialog(
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                          clipBehavior: Clip.antiAlias,
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              AppBar(
                                                title: Text(receiptFile!.name, style: const TextStyle(fontSize: 14)),
                                                backgroundColor: AppColors.primary,
                                                foregroundColor: Colors.white,
                                                elevation: 0,
                                                actions: [
                                                  IconButton(
                                                    icon: const Icon(Icons.close),
                                                    onPressed: () => Navigator.pop(previewCtx),
                                                  ),
                                                ],
                                              ),
                                              Image.memory(receiptBytes!, fit: BoxFit.contain),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                    child: Stack(
                                      children: [
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(8),
                                          child: Image.memory(
                                            receiptBytes!,
                                            width: 58,
                                            height: 58,
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                        Positioned(
                                          right: 2,
                                          bottom: 2,
                                          child: Container(
                                            padding: const EdgeInsets.all(2),
                                            decoration: const BoxDecoration(
                                              color: Colors.black54,
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(Icons.zoom_in, color: Colors.white, size: 12),
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                else
                                  Container(
                                    width: 58,
                                    height: 58,
                                    decoration: BoxDecoration(
                                      color: Colors.green.shade100,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(Icons.receipt_long, color: Colors.green, size: 28),
                                  ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: Colors.green.shade700,
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: const Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(Icons.check_circle, color: Colors.white, size: 11),
                                                SizedBox(width: 4),
                                                Text('ATTACHED', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          if (receiptBytes != null)
                                            Text(
                                              '${(receiptBytes!.lengthInBytes / 1024).toStringAsFixed(1)} KB',
                                              style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        receiptFile!.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary),
                                      ),
                                      const Text(
                                        'Tap thumbnail to view full image',
                                        style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                                  tooltip: 'Remove Invoice',
                                  onPressed: () {
                                    setModalState(() {
                                      receiptFile = null;
                                      receiptBytes = null;
                                    });
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            InkWell(
                              onTap: () => showSourceSelectionSheet(ctx, setModalState),
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 6),
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.green.shade200),
                                ),
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.sync, size: 14, color: AppColors.primary),
                                    SizedBox(width: 6),
                                    Text('Change Invoice (Camera / Gallery)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary)),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 20),

                    ElevatedButton(
                      onPressed: isSubmitting
                          ? null
                          : () async {
                              final qty = int.tryParse(qtyController.text);
                              if (qty == null || qty <= 0) {
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter valid quantity')));
                                return;
                              }
                              setModalState(() => isSubmitting = true);

                              final messenger = ScaffoldMessenger.of(context);
                              String? base64Data;
                              if (receiptBytes != null) {
                                base64Data = base64Encode(receiptBytes!);
                              } else if (receiptFile != null) {
                                final bytes = await receiptFile!.readAsBytes();
                                base64Data = base64Encode(bytes);
                              }

                              try {
                                final res = await http.post(
                                  Uri.parse('${AppState.apiBaseUrl}/stock/intake'),
                                  headers: {'Content-Type': 'application/json'},
                                  body: jsonEncode({
                                    'warehouse_id': _warehouseId,
                                    'product_id': selectedProduct,
                                    'quantity': qty,
                                    'batch_number': batchController.text.trim(),
                                    'supplier': supplierController.text.trim().isEmpty ? 'Direct Supplier' : supplierController.text.trim(),
                                    'date_received': dateController.text.trim(),
                                    'receipt_base64': base64Data,
                                    'receipt_filename': receiptFile?.name,
                                    'received_by': AppState.currentUser?['id'],
                                  }),
                                );

                                if (res.statusCode == 201) {
                                  if (ctx.mounted) Navigator.pop(ctx);
                                  messenger.showSnackBar(const SnackBar(content: Text('Stock Intake Recorded Successfully!')));
                                  _loadAllStoreData();
                                  return;
                                }
                              } catch (_) {}

                              // Fallback Mock Update
                              final prodStock = _warehouseStocks.firstWhere((s) => s['product_id'] == selectedProduct, orElse: () => {});
                              if (prodStock.isNotEmpty) {
                                prodStock['quantity'] = (prodStock['quantity'] as int) + qty;
                              } else {
                                _warehouseStocks.add({'owner_id': _warehouseId, 'product_id': selectedProduct, 'quantity': qty});
                              }
                              _intakes.insert(0, {
                                'id': 'intake_${DateTime.now().millisecondsSinceEpoch}',
                                'warehouse_id': _warehouseId,
                                'product_id': selectedProduct,
                                'quantity': qty,
                                'batch_number': batchController.text.trim(),
                                'supplier': supplierController.text.trim().isEmpty ? 'Direct Supplier' : supplierController.text.trim(),
                                'date_received': dateController.text.trim(),
                                'created_at': DateTime.now().toIso8601String(),
                              });

                              if (ctx.mounted) Navigator.pop(ctx);
                              messenger.showSnackBar(const SnackBar(content: Text('Stock Intake Recorded (Offline Fallback)!')));
                              if (mounted) setState(() {});
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: isSubmitting
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Text('Confirm Stock Intake', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ==========================================
  // TAB 1: FSM STOCK DISTRIBUTION
  // ==========================================
  Widget _buildFsmDistributionTab() {
    return _FsmDistributionView(
      warehouseId: _warehouseId,
      products: _products,
      fsmUsers: _fsmUsers,
      transfers: _transfers,
      getStockForProduct: _getStockForProduct,
      onTransferComplete: _loadAllStoreData,
    );
  }

  // ==========================================
  // TAB 2: DIRECT RETAIL CUSTOMER SALE
  // ==========================================
  Widget _buildDirectRetailSaleTab() {
    return _DirectRetailSaleView(
      warehouseId: _warehouseId,
      products: _products,
      customers: _retailCustomers,
      sales: _sales.where((s) => (s['customer_type'] ?? 'retail') == 'retail').toList(),
      getStockForProduct: _getStockForProduct,
      getRetailPrice: _getRetailPriceForProduct,
      onSaleComplete: _loadAllStoreData,
    );
  }

  // ==========================================
  // TAB 3: DISTRIBUTOR BULK SALE
  // ==========================================
  Widget _buildDistributorSaleTab() {
    return _DistributorSaleView(
      warehouseId: _warehouseId,
      products: _products,
      distributors: _distributors,
      sales: _sales.where((s) => s['customer_type'] == 'distributor').toList(),
      getStockForProduct: _getStockForProduct,
      getDistributorPrice: _getDistributorPriceForProduct,
      onSaleComplete: _loadAllStoreData,
    );
  }

  // ==========================================
  // TAB 4: REPORTS & LEDGER (WAREHOUSE SCOPED)
  // ==========================================
  Widget _buildReportsTab() {
    return _StoreReportsView(
      warehouseId: _warehouseId,
      intakes: _intakes,
      transfers: _transfers,
      sales: _sales,
      alerts: _alerts,
      getProductName: _getProductName,
      getProductUnit: _getProductUnit,
    );
  }
}

// ---------------------------------------------------------
// FSM DISTRIBUTION VIEW (FSM SELECTOR ONLY, REMAINING CALC)
// ---------------------------------------------------------
class _FsmDistributionView extends StatefulWidget {
  final String warehouseId;
  final List<Map<String, dynamic>> products;
  final List<Map<String, dynamic>> fsmUsers;
  final List<Map<String, dynamic>> transfers;
  final int Function(String) getStockForProduct;
  final VoidCallback onTransferComplete;

  const _FsmDistributionView({
    required this.warehouseId,
    required this.products,
    required this.fsmUsers,
    required this.transfers,
    required this.getStockForProduct,
    required this.onTransferComplete,
  });

  @override
  State<_FsmDistributionView> createState() => _FsmDistributionViewState();
}

class _FsmDistributionViewState extends State<_FsmDistributionView> {
  String? _selectedFsmId;
  String? _selectedProductId;
  final TextEditingController _qtyController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    if (widget.fsmUsers.isNotEmpty) _selectedFsmId = widget.fsmUsers.first['id'];
    if (widget.products.isNotEmpty) _selectedProductId = widget.products.first['id'];
  }

  @override
  Widget build(BuildContext context) {
    final availableStock = _selectedProductId != null ? widget.getStockForProduct(_selectedProductId!) : 0;
    final enteredQty = int.tryParse(_qtyController.text) ?? 0;
    final remainingStock = availableStock - enteredQty;
    final isInvalidQty = enteredQty > availableStock || enteredQty <= 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Governance Rule Notice Card
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.shade300),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.shield_outlined, color: Colors.blue, size: 24),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Role Governance Rule', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 2),
                      Text(
                        'Store Admin can transfer stock ONLY to Field Sales Managers. Direct stock transfer to Salesmen is restricted by system policy.',
                        style: TextStyle(color: Colors.blue.shade900, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Transfer Card
          Card(
            color: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: Padding(
              padding: const EdgeInsets.all(18.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('New Stock Transfer to FSM', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                  const SizedBox(height: 14),

                  // FSM Selector (Strictly filtered)
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: _selectedFsmId,
                    decoration: const InputDecoration(
                      labelText: 'Select Field Sales Manager',
                      prefixIcon: Icon(Icons.person, color: AppColors.primary),
                      border: OutlineInputBorder(),
                    ),
                    items: widget.fsmUsers.map((u) {
                      return DropdownMenuItem<String>(
                        value: u['id'],
                        child: Text('${u['name']} (FSM)', overflow: TextOverflow.ellipsis),
                      );
                    }).toList(),
                    onChanged: (val) => setState(() => _selectedFsmId = val),
                  ),
                  const SizedBox(height: 14),

                  // Product Selector
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: _selectedProductId,
                    decoration: const InputDecoration(
                      labelText: 'Select Product',
                      prefixIcon: Icon(Icons.inventory_2, color: AppColors.primary),
                      border: OutlineInputBorder(),
                    ),
                    items: widget.products.map((p) {
                      final stock = widget.getStockForProduct(p['id']);
                      return DropdownMenuItem<String>(
                        value: p['id'],
                        child: Text('${p['name']} (Stock: $stock)', overflow: TextOverflow.ellipsis),
                      );
                    }).toList(),
                    onChanged: (val) => setState(() => _selectedProductId = val),
                  ),
                  const SizedBox(height: 14),

                  // Quantity Field with live remaining stock feedback
                  TextField(
                    controller: _qtyController,
                    decoration: const InputDecoration(
                      labelText: 'Transfer Quantity',
                      prefixIcon: Icon(Icons.numbers, color: AppColors.primary),
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 14),

                  // Live Remaining Stock Calculator Display
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: remainingStock < 0 ? Colors.red.shade50 : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: remainingStock < 0 ? Colors.red.shade300 : Colors.grey.shade300),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Remaining Warehouse Stock:', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                        Text(
                          '$remainingStock units',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: remainingStock < 0 ? Colors.red : AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  ElevatedButton.icon(
                    onPressed: (_isSubmitting || isInvalidQty || _selectedFsmId == null || _selectedProductId == null)
                        ? null
                        : _handleTransfer,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: _isSubmitting
                        ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.send),
                    label: const Text('Authorize & Transfer to FSM', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Outgoing Transfers History Ledger
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Outgoing Transfers to FSMs', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              Text('${widget.transfers.length} records', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 10),

          if (widget.transfers.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              alignment: Alignment.center,
              child: const Text('No outgoing transfers recorded yet.', style: TextStyle(color: AppColors.textSecondary)),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: widget.transfers.length,
              itemBuilder: (context, idx) {
                final t = widget.transfers[idx];
                final pName = t['product']?['name'] ?? 'Product #${t['product_id']}';
                final qty = t['quantity'];
                final date = t['created_at'] != null ? t['created_at'].toString().split('T').first : 'Today';
                final destName = t['to_name'] ?? 'FSM Alpha';

                return Card(
                  color: Colors.white,
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFFF3E5D8),
                      child: Icon(Icons.local_shipping, color: AppColors.primary),
                    ),
                    title: Text('$qty units • $pName', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    subtitle: Text('To: $destName • $date', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: Colors.green.shade100, borderRadius: BorderRadius.circular(8)),
                      child: Text('TRANSFERRED', style: TextStyle(color: Colors.green.shade900, fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Future<void> _handleTransfer() async {
    final qty = int.tryParse(_qtyController.text) ?? 0;
    if (qty <= 0 || _selectedFsmId == null || _selectedProductId == null) return;
    setState(() => _isSubmitting = true);

    try {
      final res = await http.post(
        Uri.parse('${AppState.apiBaseUrl}/stock/transfer'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'from_id': widget.warehouseId,
          'to_id': _selectedFsmId,
          'product_id': _selectedProductId,
          'quantity': qty,
          'status': 'pending',
        }),
      );

      String transferId = 'tr_${DateTime.now().millisecondsSinceEpoch}';
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        if (body['transfer'] != null && body['transfer']['id'] != null) {
          transferId = body['transfer']['id'].toString();
        }
      }

      final selectedFsm = widget.fsmUsers.firstWhere(
        (u) => u['id'] == _selectedFsmId,
        orElse: () => {'name': 'Field Sales Manager'},
      );
      final selectedProd = widget.products.firstWhere(
        (p) => p['id'] == _selectedProductId,
        orElse: () => {'name': 'Product', 'sku': ''},
      );

      final securityPin = (transferId.hashCode.abs() % 900000 + 100000).toString();

      final qrPayload = jsonEncode({
        'type': 'STOCK_TRANSFER_HANDOFF',
        'transfer_id': transferId,
        'from_warehouse_id': widget.warehouseId,
        'to_fsm_id': _selectedFsmId,
        'fsm_name': selectedFsm['name'],
        'product_id': _selectedProductId,
        'product_name': selectedProd['name'],
        'quantity': qty,
        'security_pin': securityPin,
        'created_at': DateTime.now().toIso8601String(),
      });

      if (!mounted) return;
      setState(() => _isSubmitting = false);

      _showTransferQrModal(
        transferId: transferId,
        fsmName: selectedFsm['name'] ?? 'FSM',
        productName: selectedProd['name'] ?? 'Product',
        quantity: qty,
        securityPin: securityPin,
        qrPayload: qrPayload,
      );
    } catch (_) {
      // Offline fallback
      final transferId = 'tr_${DateTime.now().millisecondsSinceEpoch}';
      final selectedFsm = widget.fsmUsers.firstWhere(
        (u) => u['id'] == _selectedFsmId,
        orElse: () => {'name': 'Field Sales Manager'},
      );
      final selectedProd = widget.products.firstWhere(
        (p) => p['id'] == _selectedProductId,
        orElse: () => {'name': 'Product', 'sku': ''},
      );
      final securityPin = (transferId.hashCode.abs() % 900000 + 100000).toString();
      final qrPayload = jsonEncode({
        'type': 'STOCK_TRANSFER_HANDOFF',
        'transfer_id': transferId,
        'from_warehouse_id': widget.warehouseId,
        'to_fsm_id': _selectedFsmId,
        'fsm_name': selectedFsm['name'],
        'product_id': _selectedProductId,
        'product_name': selectedProd['name'],
        'quantity': qty,
        'security_pin': securityPin,
        'created_at': DateTime.now().toIso8601String(),
      });

      if (mounted) {
        setState(() => _isSubmitting = false);
        _showTransferQrModal(
          transferId: transferId,
          fsmName: selectedFsm['name'] ?? 'FSM',
          productName: selectedProd['name'] ?? 'Product',
          quantity: qty,
          securityPin: securityPin,
          qrPayload: qrPayload,
        );
      }
    }
  }

  void _showTransferQrModal({
    required String transferId,
    required String fsmName,
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
                  Uri.parse('${AppState.apiBaseUrl}/stock/transfers?from_id=${widget.warehouseId}'),
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
                    widget.onTransferComplete();
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
                  padding: const EdgeInsets.all(22.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
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
                                child: const Icon(Icons.qr_code_2, color: AppColors.primary, size: 24),
                              ),
                              const SizedBox(width: 10),
                              const Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Handoff Authorization QR',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  Text(
                                    'FSM scans to receive stock into depot',
                                    style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: AppColors.textSecondary),
                            onPressed: () {
                              pollTimer?.cancel();
                              Navigator.pop(dialogCtx);
                              _qtyController.clear();
                              widget.onTransferComplete();
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Center(
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: isTransferAccepted ? Colors.green.shade300 : ClientColors.border,
                              width: isTransferAccepted ? 2.0 : 1.2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: isTransferAccepted
                                    ? Colors.green.withValues(alpha: 0.15)
                                    : AppColors.primary.withValues(alpha: 0.06),
                                blurRadius: 18,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              QrImageView(
                                data: qrPayload,
                                version: QrVersions.auto,
                                size: 195.0,
                                backgroundColor: Colors.white,
                                eyeStyle: QrEyeStyle(
                                  eyeShape: QrEyeShape.square,
                                  color: isTransferAccepted ? Colors.green.shade700 : AppColors.primary,
                                ),
                                dataModuleStyle: QrDataModuleStyle(
                                  dataModuleShape: QrDataModuleShape.square,
                                  color: isTransferAccepted ? Colors.green.shade900 : AppColors.textPrimary,
                                ),
                              ),
                              if (isTransferAccepted)
                                Container(
                                  width: 195,
                                  height: 195,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.92),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.check_circle, color: Colors.green.shade600, size: 68),
                                      const SizedBox(height: 8),
                                      const Text(
                                        'HANDOFF VERIFIED!',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          color: Colors.green,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.key, size: 16, color: AppColors.accent),
                                SizedBox(width: 6),
                                Text(
                                  'Security PIN:',
                                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                            Text(
                              securityPin,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 3.0,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Transfer Quantity:', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                Text(
                                  '$quantity Units • $productName',
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Recipient FSM:', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                Text(
                                  fsmName,
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primary),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: isTransferAccepted ? Colors.green.shade50 : Colors.amber.shade50,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isTransferAccepted ? Colors.green.shade300 : Colors.amber.shade300,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (isChecking)
                              const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent),
                              )
                            else
                              Icon(
                                isTransferAccepted ? Icons.check_circle : Icons.sensors,
                                size: 16,
                                color: isTransferAccepted ? Colors.green.shade700 : Colors.amber.shade900,
                              ),
                            const SizedBox(width: 8),
                            Text(
                              isTransferAccepted
                                  ? 'STOCK RECEIVED & CREDITED TO FSM'
                                  : 'WAITING FOR FSM TO SCAN & CONFIRM',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isTransferAccepted ? Colors.green.shade700 : Colors.amber.shade900,
                              ),
                            ),
                          ],
                        ),
                      ),

                      ElevatedButton(
                        onPressed: () {
                          pollTimer?.cancel();
                          Navigator.pop(dialogCtx);
                          _qtyController.clear();
                          widget.onTransferComplete();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isTransferAccepted ? Colors.green.shade700 : AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: Text(
                          isTransferAccepted ? 'Done (Handoff Complete)' : 'Close Window',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ),
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
}

// ---------------------------------------------------------
// DIRECT RETAIL SALE VIEW (LOCKED PRICE, REFERRAL CODE)
// ---------------------------------------------------------
class _DirectRetailSaleView extends StatefulWidget {
  final String warehouseId;
  final List<Map<String, dynamic>> products;
  final List<Map<String, dynamic>> customers;
  final List<Map<String, dynamic>> sales;
  final int Function(String) getStockForProduct;
  final double Function(String) getRetailPrice;
  final VoidCallback onSaleComplete;

  const _DirectRetailSaleView({
    required this.warehouseId,
    required this.products,
    required this.customers,
    required this.sales,
    required this.getStockForProduct,
    required this.getRetailPrice,
    required this.onSaleComplete,
  });

  @override
  State<_DirectRetailSaleView> createState() => _DirectRetailSaleViewState();
}

class _DirectRetailSaleViewState extends State<_DirectRetailSaleView> {
  bool _isNewCustomer = false;
  String? _selectedCustomerId;
  final TextEditingController _custNameController = TextEditingController();
  final TextEditingController _custPhoneController = TextEditingController();

  String? _selectedProductId;
  final TextEditingController _qtyController = TextEditingController(text: '1');
  String _paymentMethod = 'cash'; // cash | online
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    if (widget.customers.isNotEmpty) _selectedCustomerId = widget.customers.first['id'];
    if (widget.products.isNotEmpty) _selectedProductId = widget.products.first['id'];
  }

  @override
  Widget build(BuildContext context) {
    final availableStock = _selectedProductId != null ? widget.getStockForProduct(_selectedProductId!) : 0;
    final unitPrice = _selectedProductId != null ? widget.getRetailPrice(_selectedProductId!) : 0.0;
    final qty = int.tryParse(_qtyController.text) ?? 0;
    final totalAmount = qty * unitPrice;
    final isInvalidQty = qty > availableStock || qty <= 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Pricing Policy Lock Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.amber.shade400),
            ),
            child: Row(
              children: [
                const Icon(Icons.lock, color: Colors.amber, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Retail Price Locked: Unit pricing is governed exclusively by Super Admin and cannot be edited.',
                    style: TextStyle(color: Colors.amber.shade900, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          Card(
            color: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: Padding(
              padding: const EdgeInsets.all(18.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Record Direct Retail Sale', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                  const SizedBox(height: 12),

                  // Toggle New vs Existing Customer
                  Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          label: const Text('Existing Customer'),
                          selected: !_isNewCustomer,
                          onSelected: (val) => setState(() => _isNewCustomer = !val),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ChoiceChip(
                          label: const Text('New Customer Walk-in'),
                          selected: _isNewCustomer,
                          onSelected: (val) => setState(() => _isNewCustomer = val),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  if (!_isNewCustomer)
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: _selectedCustomerId,
                      decoration: const InputDecoration(labelText: 'Select Customer', border: OutlineInputBorder()),
                      items: widget.customers.map((c) {
                        return DropdownMenuItem<String>(
                          value: c['id'],
                          child: Text('${c['name']} (${c['phone']})', overflow: TextOverflow.ellipsis),
                        );
                      }).toList(),
                      onChanged: (val) => setState(() => _selectedCustomerId = val),
                    )
                  else ...[
                    TextField(
                      controller: _custNameController,
                      decoration: const InputDecoration(labelText: 'Customer Full Name', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _custPhoneController,
                      decoration: const InputDecoration(labelText: 'Phone Number', border: OutlineInputBorder()),
                      keyboardType: TextInputType.phone,
                    ),
                  ],
                  const SizedBox(height: 14),

                  // Product Selector
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: _selectedProductId,
                    decoration: const InputDecoration(labelText: 'Select Product', border: OutlineInputBorder()),
                    items: widget.products.map((p) {
                      final stock = widget.getStockForProduct(p['id']);
                      return DropdownMenuItem<String>(
                        value: p['id'],
                        child: Text('${p['name']} (Stock: $stock)', overflow: TextOverflow.ellipsis),
                      );
                    }).toList(),
                    onChanged: (val) => setState(() => _selectedProductId = val),
                  ),
                  const SizedBox(height: 14),

                  // Quantity Field
                  TextField(
                    controller: _qtyController,
                    decoration: InputDecoration(
                      labelText: 'Sale Quantity',
                      border: const OutlineInputBorder(),
                      helperText: 'Available: $availableStock units',
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 14),

                  // Read-Only Locked Price Display
                  TextField(
                    readOnly: true,
                    enabled: false,
                    decoration: InputDecoration(
                      labelText: 'Unit Price (Super Admin Pricing)',
                      hintText: '₹$unitPrice per unit',
                      prefixIcon: const Icon(Icons.lock, color: Colors.amber),
                      border: const OutlineInputBorder(),
                      filled: true,
                      fillColor: Colors.grey.shade100,
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Payment Method Selector
                  const Text('Payment Mode', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textSecondary)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          label: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.money, size: 16), SizedBox(width: 4), Text('Cash')]),
                          selected: _paymentMethod == 'cash',
                          onSelected: (val) => setState(() => _paymentMethod = 'cash'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ChoiceChip(
                          label: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.qr_code, size: 16), SizedBox(width: 4), Text('Online / UPI')]),
                          selected: _paymentMethod == 'online',
                          onSelected: (val) => setState(() => _paymentMethod = 'online'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // Invoice Total Card
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: const Color(0xFFFBF4ED), borderRadius: BorderRadius.circular(10)),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Total Payable:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textPrimary)),
                        Text('₹${totalAmount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: AppColors.primary)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  ElevatedButton(
                    onPressed: (_isSubmitting || isInvalidQty || _selectedProductId == null) ? null : _handleRetailSale,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('Complete Retail Sale & Issue Receipt', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Retail Sales History
          const Text('Recent Direct Customer Sales', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          const SizedBox(height: 10),

          if (widget.sales.isEmpty)
            Container(padding: const EdgeInsets.all(20), alignment: Alignment.center, child: const Text('No direct retail sales yet.', style: TextStyle(color: AppColors.textSecondary)))
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: widget.sales.length,
              itemBuilder: (context, idx) {
                final s = widget.sales[idx];
                final custName = s['customer']?['name'] ?? (s['customer_name'] ?? 'Walk-in Customer');
                final amt = s['amount'];
                final qty = s['quantity'];
                final pMethod = (s['payment_method'] ?? 'cash').toString().toUpperCase();

                return Card(
                  color: Colors.white,
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: const CircleAvatar(backgroundColor: Color(0xFFEDF7ED), child: Icon(Icons.receipt, color: Colors.green)),
                    title: Text('$custName • ₹$amt', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    subtitle: Text('$qty units • $pMethod', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    trailing: const Icon(Icons.check_circle, color: Colors.green, size: 20),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Future<void> _handleRetailSale() async {
    final qty = int.tryParse(_qtyController.text) ?? 0;
    final unitPrice = widget.getRetailPrice(_selectedProductId!);
    final totalAmount = qty * unitPrice;

    setState(() => _isSubmitting = true);

    try {
      final res = await http.post(
        Uri.parse('${AppState.apiBaseUrl}/sales'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'warehouse_id': widget.warehouseId,
          'customer_id': _isNewCustomer ? null : _selectedCustomerId,
          'customer_name': _isNewCustomer ? _custNameController.text.trim() : null,
          'customer_phone': _isNewCustomer ? _custPhoneController.text.trim() : null,
          'customer_type': 'retail',
          'product_id': _selectedProductId,
          'quantity': qty,
          'amount': totalAmount,
          'payment_method': _paymentMethod,
        }),
      );

      if (res.statusCode == 201) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Direct Customer Sale Recorded! Stock deducted.')));
          _qtyController.text = '1';
          if (_isNewCustomer) _custNameController.clear();
          widget.onSaleComplete();
        }
        return;
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to record sale. Please check your network connection.')));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }
}

// ---------------------------------------------------------
// DISTRIBUTOR BULK SALE VIEW (TIER PRICING, BULK ORDERS)
// ---------------------------------------------------------
class _DistributorSaleView extends StatefulWidget {
  final String warehouseId;
  final List<Map<String, dynamic>> products;
  final List<Map<String, dynamic>> distributors;
  final List<Map<String, dynamic>> sales;
  final int Function(String) getStockForProduct;
  final double Function(String) getDistributorPrice;
  final VoidCallback onSaleComplete;

  const _DistributorSaleView({
    required this.warehouseId,
    required this.products,
    required this.distributors,
    required this.sales,
    required this.getStockForProduct,
    required this.getDistributorPrice,
    required this.onSaleComplete,
  });

  @override
  State<_DistributorSaleView> createState() => _DistributorSaleViewState();
}

class _DistributorSaleViewState extends State<_DistributorSaleView> {
  bool _isNewDistributor = false;
  String? _selectedDistributorId;
  final TextEditingController _distNameController = TextEditingController();
  final TextEditingController _distPhoneController = TextEditingController();

  String? _selectedProductId;
  final TextEditingController _qtyController = TextEditingController(text: '50');
  String _paymentMethod = 'online';
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    if (widget.distributors.isNotEmpty) _selectedDistributorId = widget.distributors.first['id'];
    if (widget.products.isNotEmpty) _selectedProductId = widget.products.first['id'];
  }

  @override
  Widget build(BuildContext context) {
    final availableStock = _selectedProductId != null ? widget.getStockForProduct(_selectedProductId!) : 0;
    final distPrice = _selectedProductId != null ? widget.getDistributorPrice(_selectedProductId!) : 0.0;
    final qty = int.tryParse(_qtyController.text) ?? 0;
    final totalAmount = qty * distPrice;
    final isInvalidQty = qty > availableStock || qty <= 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Distributor Tier Notice
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.purple.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.purple.shade300),
            ),
            child: Row(
              children: [
                const Icon(Icons.business_center, color: Colors.purple, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Distributor Pricing Tier: Sourced directly from Super Admin price schedules. Not editable by Store Admin.',
                    style: TextStyle(color: Colors.purple.shade900, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          Card(
            color: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: Padding(
              padding: const EdgeInsets.all(18.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Record Bulk Distributor Sale', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                  const SizedBox(height: 12),

                  // Toggle Existing vs New Distributor
                  Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          label: const Center(child: Text('Registered Firm')),
                          selected: !_isNewDistributor,
                          onSelected: (val) => setState(() => _isNewDistributor = !val),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ChoiceChip(
                          label: const Center(child: Text('New Firm Walk-in')),
                          selected: _isNewDistributor,
                          onSelected: (val) => setState(() => _isNewDistributor = val),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  if (!_isNewDistributor)
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: _selectedDistributorId,
                      decoration: const InputDecoration(labelText: 'Select Distributor Firm', border: OutlineInputBorder()),
                      items: widget.distributors.map((d) {
                        return DropdownMenuItem<String>(
                          value: d['id'],
                          child: Text('${d['name']} (${d['phone']})', overflow: TextOverflow.ellipsis),
                        );
                      }).toList(),
                      onChanged: (val) => setState(() => _selectedDistributorId = val),
                    )
                  else ...[
                    TextField(
                      controller: _distNameController,
                      decoration: const InputDecoration(labelText: 'Distributor Firm Name', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _distPhoneController,
                      decoration: const InputDecoration(labelText: 'Contact Phone', border: OutlineInputBorder()),
                      keyboardType: TextInputType.phone,
                    ),
                  ],
                  const SizedBox(height: 14),

                  // Product Selector
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: _selectedProductId,
                    decoration: const InputDecoration(labelText: 'Select Product', border: OutlineInputBorder()),
                    items: widget.products.map((p) {
                      final stock = widget.getStockForProduct(p['id']);
                      return DropdownMenuItem<String>(
                        value: p['id'],
                        child: Text('${p['name']} (Stock: $stock)', overflow: TextOverflow.ellipsis),
                      );
                    }).toList(),
                    onChanged: (val) => setState(() => _selectedProductId = val),
                  ),
                  const SizedBox(height: 14),

                  // Bulk Quantity Field
                  TextField(
                    controller: _qtyController,
                    decoration: InputDecoration(
                      labelText: 'Bulk Quantity (Units)',
                      border: const OutlineInputBorder(),
                      helperText: 'Available: $availableStock units',
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 14),

                  // Read-Only Distributor Price
                  TextField(
                    readOnly: true,
                    enabled: false,
                    decoration: InputDecoration(
                      labelText: 'Distributor Tier Rate (Locked)',
                      hintText: '₹$distPrice per unit',
                      prefixIcon: const Icon(Icons.lock, color: Colors.purple),
                      border: const OutlineInputBorder(),
                      filled: true,
                      fillColor: Colors.grey.shade100,
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Payment Method
                  const Text('Payment Mode', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textSecondary)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          label: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.account_balance, size: 16), SizedBox(width: 4), Text('Online / Bank')]),
                          selected: _paymentMethod == 'online',
                          onSelected: (val) => setState(() => _paymentMethod = 'online'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ChoiceChip(
                          label: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.money, size: 16), SizedBox(width: 4), Text('Cash')]),
                          selected: _paymentMethod == 'cash',
                          onSelected: (val) => setState(() => _paymentMethod = 'cash'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // Invoice Total Card
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: Colors.purple.shade50, borderRadius: BorderRadius.circular(10)),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Distributor Invoice Total:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textPrimary)),
                        Text('₹${totalAmount.toStringAsFixed(2)}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Colors.purple.shade900)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  ElevatedButton(
                    onPressed: (_isSubmitting || isInvalidQty || _selectedProductId == null) ? null : _handleDistributorSale,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('Generate Bulk Distributor Invoice', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Distributor Sales History
          const Text('Distributor Sales History', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          const SizedBox(height: 10),

          if (widget.sales.isEmpty)
            Container(padding: const EdgeInsets.all(20), alignment: Alignment.center, child: const Text('No distributor bulk sales yet.', style: TextStyle(color: AppColors.textSecondary)))
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: widget.sales.length,
              itemBuilder: (context, idx) {
                final s = widget.sales[idx];
                final distName = s['customer']?['name'] ?? (s['customer_name'] ?? 'Distributor Partner');
                final amt = s['amount'];
                final qty = s['quantity'];
                final pMethod = (s['payment_method'] ?? 'online').toString().toUpperCase();

                return Card(
                  color: Colors.white,
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(backgroundColor: Colors.purple.shade100, child: Icon(Icons.business, color: Colors.purple.shade800)),
                    title: Text('$distName • ₹$amt', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    subtitle: Text('$qty units bulk order • $pMethod', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    trailing: const Icon(Icons.verified, color: Colors.purple, size: 20),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Future<void> _handleDistributorSale() async {
    final qty = int.tryParse(_qtyController.text) ?? 0;
    final distPrice = widget.getDistributorPrice(_selectedProductId!);
    final totalAmount = qty * distPrice;

    setState(() => _isSubmitting = true);

    try {
      final res = await http.post(
        Uri.parse('${AppState.apiBaseUrl}/sales'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'warehouse_id': widget.warehouseId,
          'customer_id': _isNewDistributor ? null : _selectedDistributorId,
          'customer_name': _isNewDistributor ? _distNameController.text.trim() : null,
          'customer_phone': _isNewDistributor ? _distPhoneController.text.trim() : null,
          'customer_type': 'distributor',
          'product_id': _selectedProductId,
          'quantity': qty,
          'amount': totalAmount,
          'payment_method': _paymentMethod,
        }),
      );

      if (res.statusCode == 201) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Distributor Bulk Sale Processed! Invoice Created.')));
          _qtyController.text = '50';
          if (_isNewDistributor) _distNameController.clear();
          widget.onSaleComplete();
        }
        return;
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to process bulk sale. Please check your network connection.')));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }
}

// ---------------------------------------------------------
// REPORTS & AUDITING VIEW (STORE ADMIN SCOPE ONLY)
// ---------------------------------------------------------
class _StoreReportsView extends StatefulWidget {
  final String warehouseId;
  final List<Map<String, dynamic>> intakes;
  final List<Map<String, dynamic>> transfers;
  final List<Map<String, dynamic>> sales;
  final List<Map<String, dynamic>> alerts;
  final String Function(String) getProductName;
  final String Function(String) getProductUnit;

  const _StoreReportsView({
    required this.warehouseId,
    required this.intakes,
    required this.transfers,
    required this.sales,
    required this.alerts,
    required this.getProductName,
    required this.getProductUnit,
  });

  @override
  State<_StoreReportsView> createState() => _StoreReportsViewState();
}

class _StoreReportsViewState extends State<_StoreReportsView> {
  int _selectedFilter = 0; // 0: All Ledgers, 1: Stock Intake, 2: FSM Transfers, 3: Retail Sales, 4: Distributor Sales, 5: Low Stock

  @override
  Widget build(BuildContext context) {
    final retailSales = widget.sales.where((s) => (s['customer_type'] ?? 'retail') == 'retail').toList();
    final distributorSales = widget.sales.where((s) => s['customer_type'] == 'distributor').toList();
    final totalRetailRev = retailSales.fold<double>(0.0, (sum, s) => sum + (double.tryParse(s['amount'].toString()) ?? 0.0));
    final totalDistRev = distributorSales.fold<double>(0.0, (sum, s) => sum + (double.tryParse(s['amount'].toString()) ?? 0.0));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Warehouse Scoping Header
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: const Color(0xFFF3EAE0), borderRadius: BorderRadius.circular(10)),
            child: Row(
              children: [
                const Icon(Icons.analytics_outlined, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Reports & audit records are strictly scoped to Warehouse #${widget.warehouseId}.',
                    style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Summary Grid
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.6,
            children: [
              _buildReportMetric('Stock Intake', '${widget.intakes.length} Batches', Icons.add_business, Colors.teal),
              _buildReportMetric('FSM Transfers', '${widget.transfers.length} Outgoing', Icons.local_shipping, Colors.blue),
              _buildReportMetric('Retail Revenue', '₹${totalRetailRev.toStringAsFixed(0)}', Icons.point_of_sale, Colors.green),
              _buildReportMetric('Distributor Rev', '₹${totalDistRev.toStringAsFixed(0)}', Icons.storefront, Colors.purple),
            ],
          ),
          const SizedBox(height: 18),

          // Segmented Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('All Activity', 0),
                _buildFilterChip('Intakes (${widget.intakes.length})', 1),
                _buildFilterChip('FSM Transfers (${widget.transfers.length})', 2),
                _buildFilterChip('Retail Sales (${retailSales.length})', 3),
                _buildFilterChip('Distributor Sales (${distributorSales.length})', 4),
                _buildFilterChip('Low Stock Alerts (${widget.alerts.length})', 5),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Ledger Content
          _buildLedgerContent(retailSales, distributorSales),
        ],
      ),
    );
  }

  Widget _buildReportMetric(String title, String val, IconData icon, Color color) {
    return Card(
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 6),
                Expanded(child: Text(title, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary))),
              ],
            ),
            const SizedBox(height: 8),
            Text(val, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, int index) {
    final isSelected = _selectedFilter == index;
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        selectedColor: AppColors.primary,
        labelStyle: TextStyle(color: isSelected ? Colors.white : AppColors.textPrimary, fontSize: 12, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
        onSelected: (_) => setState(() => _selectedFilter = index),
      ),
    );
  }

  Widget _buildLedgerContent(List<Map<String, dynamic>> retailSales, List<Map<String, dynamic>> distSales) {
    if (_selectedFilter == 1) {
      return _buildIntakeLedger();
    } else if (_selectedFilter == 2) {
      return _buildTransfersLedger();
    } else if (_selectedFilter == 3) {
      return _buildSalesList(retailSales, 'Retail');
    } else if (_selectedFilter == 4) {
      return _buildSalesList(distSales, 'Distributor');
    } else if (_selectedFilter == 5) {
      return _buildAlertsLedger();
    }

    // Default: Combined overview
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Recent Stock Intakes', widget.intakes.length),
        _buildIntakeLedger(limit: 3),
        const SizedBox(height: 16),
        _buildSectionHeader('Recent Outgoing Transfers to FSMs', widget.transfers.length),
        _buildTransfersLedger(limit: 3),
        const SizedBox(height: 16),
        _buildSectionHeader('Recent Retail Direct Sales', retailSales.length),
        _buildSalesList(retailSales, 'Retail', limit: 3),
      ],
    );
  }

  Widget _buildSectionHeader(String title, int count) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary)),
          Text('$count total', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildIntakeLedger({int? limit}) {
    final list = limit != null ? widget.intakes.take(limit).toList() : widget.intakes;
    if (list.isEmpty) return const Text('No intakes recorded.', style: TextStyle(color: AppColors.textSecondary));
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: list.length,
      itemBuilder: (context, idx) {
        final item = list[idx];
        final pName = widget.getProductName(item['product_id'] ?? '');
        final qty = item['quantity'];
        final batch = item['batch_number'] ?? 'N/A';
        final supplier = item['supplier'] ?? 'Direct';
        final date = item['date_received'] ?? item['created_at']?.toString().split('T').first ?? 'N/A';

        return Card(
          color: Colors.white,
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: const CircleAvatar(backgroundColor: Color(0xFFE0F2F1), child: Icon(Icons.inventory, color: Colors.teal)),
            title: Text('$qty units • $pName', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            subtitle: Text('Batch: $batch • Supplier: $supplier • Date: $date', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: Colors.teal.shade50, borderRadius: BorderRadius.circular(6)),
              child: Text('INTAKE', style: TextStyle(color: Colors.teal.shade800, fontSize: 10, fontWeight: FontWeight.bold)),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTransfersLedger({int? limit}) {
    final list = limit != null ? widget.transfers.take(limit).toList() : widget.transfers;
    if (list.isEmpty) return const Text('No transfers recorded.', style: TextStyle(color: AppColors.textSecondary));
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: list.length,
      itemBuilder: (context, idx) {
        final t = list[idx];
        final pName = t['product']?['name'] ?? widget.getProductName(t['product_id'] ?? '');
        final qty = t['quantity'];
        final dest = t['to_name'] ?? 'FSM';
        final date = t['created_at']?.toString().split('T').first ?? 'N/A';

        return Card(
          color: Colors.white,
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: const CircleAvatar(backgroundColor: Color(0xFFE3F2FD), child: Icon(Icons.local_shipping, color: Colors.blue)),
            title: Text('$qty units • $pName', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            subtitle: Text('To FSM: $dest • Date: $date', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(6)),
              child: Text('COMPLETED', style: TextStyle(color: Colors.green.shade800, fontSize: 10, fontWeight: FontWeight.bold)),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSalesList(List<Map<String, dynamic>> sales, String type, {int? limit}) {
    final list = limit != null ? sales.take(limit).toList() : sales;
    if (list.isEmpty) return Text('No $type sales recorded.', style: const TextStyle(color: AppColors.textSecondary));
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: list.length,
      itemBuilder: (context, idx) {
        final s = list[idx];
        final custName = s['customer']?['name'] ?? (s['customer_name'] ?? 'Customer');
        final amt = s['amount'];
        final qty = s['quantity'];
        final pName = s['product']?['name'] ?? widget.getProductName(s['product_id'] ?? '');
        final pMethod = (s['payment_method'] ?? 'cash').toString().toUpperCase();

        return Card(
          color: Colors.white,
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: type == 'Retail' ? const Color(0xFFE8F5E9) : const Color(0xFFF3E5F5),
              child: Icon(type == 'Retail' ? Icons.person : Icons.business, color: type == 'Retail' ? Colors.green : Colors.purple),
            ),
            title: Text('$custName • ₹$amt', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            subtitle: Text('$qty units • $pName • $pMethod', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: type == 'Retail' ? Colors.green.shade50 : Colors.purple.shade50,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(type.toUpperCase(), style: TextStyle(color: type == 'Retail' ? Colors.green.shade800 : Colors.purple.shade800, fontSize: 10, fontWeight: FontWeight.bold)),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAlertsLedger() {
    if (widget.alerts.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        alignment: Alignment.center,
        child: const Text('All products are healthy above their minimum threshold.', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
      );
    }
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: widget.alerts.length,
      itemBuilder: (context, idx) {
        final a = widget.alerts[idx];
        final pName = a['product']?['name'] ?? 'Product';
        final stock = a['total_quantity'];
        final threshold = a['threshold'];
        final deficit = a['deficit'];

        return Card(
          color: Colors.red.shade50,
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: const CircleAvatar(backgroundColor: Colors.red, child: Icon(Icons.warning, color: Colors.white)),
            title: Text(pName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.red)),
            subtitle: Text('Current: $stock • Min Alert: $threshold (Deficit: -$deficit units)', style: TextStyle(fontSize: 12, color: Colors.red.shade900)),
          ),
        );
      },
    );
  }
}

// =============================================================================