import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../core/constants/colors.dart';
import '../../core/state/app_state.dart';

// 6. STOCK INWARD & CONSIGNMENT MANAGEMENT (Executive Suite)
class StockApprovalsPage extends StatefulWidget {
  final bool showBackButton;
  final VoidCallback? onBack;

  const StockApprovalsPage({super.key, this.showBackButton = false, this.onBack});

  @override
  State<StockApprovalsPage> createState() => _StockApprovalsPageState();
}

class _StockApprovalsPageState extends State<StockApprovalsPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<Map<String, dynamic>> _inwards = [];
  final List<Map<String, dynamic>> _warehouses = [];
  final List<Map<String, dynamic>> _products = [];
  final List<Map<String, dynamic>> _intakes = [];
  bool _isLoading = false;

  // Direct Inward Form state
  String? _selectedWarehouseId;
  String? _selectedProductId;
  final TextEditingController _qtyCtrl = TextEditingController();
  final TextEditingController _batchCtrl = TextEditingController();
  final TextEditingController _supplierCtrl = TextEditingController();
  final TextEditingController _challanCtrl = TextEditingController();
  bool _isSubmitting = false;

  // History search & filter
  String _historySearch = '';
  String _selectedWarehouseFilter = 'all';
  final TextEditingController _historySearchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _batchCtrl.text = 'BATCH-${DateTime.now().year}${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}';
    _supplierCtrl.text = 'Central Factory Dispatch';
    _loadAllData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _qtyCtrl.dispose();
    _batchCtrl.dispose();
    _supplierCtrl.dispose();
    _challanCtrl.dispose();
    _historySearchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);
    await Future.wait([
      _loadInwards(),
      _loadWarehouses(),
      _loadProducts(),
      _loadIntakeHistory(),
    ]);
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _loadInwards() async {
    try {
      final res = await http.get(Uri.parse('${AppState.apiBaseUrl}/stock/inward-requests'));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as List;
        setState(() {
          _inwards.clear();
          _inwards.addAll(data.cast<Map<String, dynamic>>());
        });
      }
    } catch (_) {
      _inwards.clear();
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
          if (_selectedWarehouseId == null && _warehouses.isNotEmpty) {
            _selectedWarehouseId = _warehouses.first['id']?.toString();
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _loadProducts() async {
    try {
      final res = await http.get(Uri.parse('${AppState.apiBaseUrl}/products'));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as List;
        setState(() {
          _products.clear();
          _products.addAll(data.cast<Map<String, dynamic>>());
          if (_selectedProductId == null && _products.isNotEmpty) {
            _selectedProductId = _products.first['id']?.toString();
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _loadIntakeHistory() async {
    try {
      final res = await http.get(Uri.parse('${AppState.apiBaseUrl}/stock/intakes'));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as List;
        setState(() {
          _intakes.clear();
          _intakes.addAll(data.cast<Map<String, dynamic>>());
        });
      }
    } catch (_) {
      _intakes.clear();
    }
  }

  Future<void> _handleInwardApproval(String id, bool approve) async {
    try {
      final res = await http.post(
        Uri.parse('${AppState.apiBaseUrl}/stock/inward-approve'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'request_id': id,
          'approve': approve,
          'approved_by': AppState.currentUser?['id'],
        }),
      );
      if (res.statusCode == 200) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(approve ? '✅ Stock consignment approved and credited to warehouse!' : 'Stock consignment rejected.'),
            backgroundColor: approve ? Colors.green : Colors.red,
          ),
        );
        _loadAllData();
      }
    } catch (_) {
      setState(() => _inwards.removeWhere((i) => i['id'] == id));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(approve ? 'Stock credited' : 'Stock rejected')),
      );
    }
  }

  Future<void> _submitDirectIntake() async {
    final qty = int.tryParse(_qtyCtrl.text.trim()) ?? 0;
    if (_selectedWarehouseId == null || _selectedProductId == null || qty <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select warehouse, product, and valid quantity (> 0)')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final res = await http.post(
        Uri.parse('${AppState.apiBaseUrl}/stock/intake'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'warehouse_id': _selectedWarehouseId,
          'product_id': _selectedProductId,
          'quantity': qty,
          'batch_number': _batchCtrl.text.trim(),
          'supplier': _supplierCtrl.text.trim(),
          'date_received': DateTime.now().toIso8601String().split('T')[0],
          'received_by': AppState.currentUser?['id'],
        }),
      );

      if (res.statusCode == 201 || res.statusCode == 200) {
        if (!mounted) return;
        final wh = _warehouses.firstWhere((w) => w['id']?.toString() == _selectedWarehouseId, orElse: () => {});
        final prod = _products.firstWhere((p) => p['id']?.toString() == _selectedProductId, orElse: () => {});
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Successfully inwarded $qty ${prod['unit'] ?? 'units'} into ${wh['name'] ?? 'Hub'}!'),
            backgroundColor: Colors.green,
          ),
        );
        _qtyCtrl.clear();
        _challanCtrl.clear();
        await _loadAllData();
        _tabController.animateTo(2); // View history
      } else {
        throw Exception('Failed to record intake');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error recording inward stock: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  String _getProductName(dynamic pId, Map<String, dynamic> item) {
    if (item['product'] != null && item['product'] is Map && item['product']['name'] != null) {
      return item['product']['name'].toString();
    }
    final found = _products.firstWhere((p) => p['id']?.toString() == pId?.toString(), orElse: () => {});
    return found['name']?.toString() ?? 'Item #$pId';
  }

  String _getProductSku(dynamic pId, Map<String, dynamic> item) {
    if (item['product'] != null && item['product'] is Map && item['product']['sku'] != null) {
      return item['product']['sku'].toString();
    }
    final found = _products.firstWhere((p) => p['id']?.toString() == pId?.toString(), orElse: () => {});
    return found['sku']?.toString() ?? 'SKU';
  }

  String _getProductUnit(dynamic pId, Map<String, dynamic> item) {
    if (item['product'] != null && item['product'] is Map && item['product']['unit'] != null) {
      return item['product']['unit'].toString();
    }
    final found = _products.firstWhere((p) => p['id']?.toString() == pId?.toString(), orElse: () => {});
    return found['unit']?.toString() ?? 'units';
  }

  String _getWarehouseName(dynamic wId, Map<String, dynamic> item) {
    if (item['warehouse'] != null && item['warehouse'] is Map && item['warehouse']['name'] != null) {
      return item['warehouse']['name'].toString();
    }
    final found = _warehouses.firstWhere((w) => w['id']?.toString() == wId?.toString(), orElse: () => {});
    return found['name']?.toString() ?? 'Hub #$wId';
  }

  @override
  Widget build(BuildContext context) {
    final pendingCount = _inwards.length;
    final totalUnitsPending = _inwards.fold<int>(0, (sum, i) => sum + ((i['quantity'] is int ? i['quantity'] : int.tryParse(i['quantity'].toString()) ?? 0) as int));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Stock Inward & Consignments'),
        leading: widget.showBackButton
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: widget.onBack ?? () => Navigator.maybePop(context),
              )
            : null,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAllData,
            tooltip: 'Refresh Inward Data',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
          tabs: [
            Tab(
              icon: Badge(
                isLabelVisible: pendingCount > 0,
                label: Text('$pendingCount'),
                backgroundColor: Colors.red,
                child: const Icon(Icons.pending_actions, size: 20),
              ),
              text: 'Approvals${pendingCount > 0 ? " ($pendingCount)" : ""}',
            ),
            const Tab(
              icon: Icon(Icons.add_business_outlined, size: 20),
              text: 'Direct Inward',
            ),
            Tab(
              icon: const Icon(Icons.receipt_long_outlined, size: 20),
              text: 'History (${_intakes.length})',
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildApprovalsQueueTab(totalUnitsPending),
                _buildDirectIntakeTab(),
                _buildInwardHistoryTab(),
              ],
            ),
    );
  }

  // ==========================================
  // TAB 1: APPROVALS QUEUE
  // ==========================================
  Widget _buildApprovalsQueueTab(int totalUnitsPending) {
    return RefreshIndicator(
      onRefresh: _loadAllData,
      child: Column(
        children: [
          // KPI Metric Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.cardBg,
              border: Border(bottom: BorderSide(color: Colors.grey.withValues(alpha: 0.15))),
            ),
            child: Row(
              children: [
                _kpiMiniCard('Pending', '${_inwards.length}', Colors.orange.shade800, Icons.hourglass_top),
                const SizedBox(width: 8),
                _kpiMiniCard('Inward Units', '$totalUnitsPending', Colors.teal.shade700, Icons.inventory_2),
                const SizedBox(width: 8),
                _kpiMiniCard('Active Hubs', '${_warehouses.length}', Colors.blue.shade700, Icons.warehouse),
                const SizedBox(width: 8),
                _kpiMiniCard('Catalog SKUs', '${_products.length}', Colors.purple.shade700, Icons.category),
              ],
            ),
          ),

          // Inward Requests List
          Expanded(
            child: _inwards.isEmpty
                ? Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(22),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.inventory_outlined, size: 48, color: Colors.green),
                          ),
                          const SizedBox(height: 16),
                          const Text('No Pending Inward Consignments', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                          const SizedBox(height: 8),
                          const Text(
                            'All factory dispatches and warehouse inward requests have been processed.\nYou can record a direct inward intake using the "Direct Inward" tab.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary, height: 1.4),
                          ),
                          const SizedBox(height: 20),
                          ElevatedButton.icon(
                            onPressed: () => _tabController.animateTo(1),
                            icon: const Icon(Icons.add_shopping_cart, size: 18),
                            label: const Text('Record Direct Inward Intake'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          )
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(14),
                    itemCount: _inwards.length,
                    itemBuilder: (ctx, idx) {
                      final item = _inwards[idx];
                      final pName = _getProductName(item['product_id'], item);
                      final pSku = _getProductSku(item['product_id'], item);
                      final pUnit = _getProductUnit(item['product_id'], item);
                      final whName = _getWarehouseName(item['warehouse_id'], item);
                      final qty = item['quantity'] ?? 0;
                      final requesterName = item['requested_by'] is Map ? item['requested_by']['name'] : 'Warehouse Store Admin';
                      final createdDate = (item['created_at'] ?? '').toString().split('T')[0];

                      return Card(
                        color: AppColors.cardBg,
                        elevation: 2,
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: BorderSide(color: Colors.grey.withValues(alpha: 0.15)),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(Icons.local_shipping_outlined, color: AppColors.primary, size: 26),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(pName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textPrimary)),
                                        const SizedBox(height: 2),
                                        Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(4)),
                                              child: Text('SKU: $pSku', style: TextStyle(fontSize: 10, color: Colors.grey.shade800, fontWeight: FontWeight.bold)),
                                            ),
                                            if (createdDate.isNotEmpty) ...[
                                              const SizedBox(width: 8),
                                              Text('📅 $createdDate', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                                            ],
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.green.shade50,
                                      border: Border.all(color: Colors.green.shade300),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      '+$qty $pUnit',
                                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green.shade800, fontSize: 14),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: AppColors.background,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.warehouse_outlined, size: 16, color: AppColors.textSecondary),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        'Hub: $whName',
                                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                                      ),
                                    ),
                                    const Icon(Icons.person_outline, size: 16, color: AppColors.textSecondary),
                                    const SizedBox(width: 4),
                                    Text(
                                      requesterName,
                                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                    ),
                                  ],
                                ),
                              ),
                              const Divider(height: 20),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  OutlinedButton.icon(
                                    onPressed: () => _confirmRejectDialog(item['id']?.toString() ?? ''),
                                    icon: const Icon(Icons.close, size: 16),
                                    label: const Text('Reject'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.red,
                                      side: const BorderSide(color: Colors.red),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  ElevatedButton.icon(
                                    onPressed: () => _handleInwardApproval(item['id']?.toString() ?? '', true),
                                    icon: const Icon(Icons.check, size: 16),
                                    label: const Text('Approve & Credit'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primary,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
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

  void _confirmRejectDialog(String id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Reject Inward Request?'),
        content: const Text('Are you sure you want to reject this incoming stock consignment? This will decline crediting the warehouse.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(ctx);
              _handleInwardApproval(id, false);
            },
            child: const Text('Reject Consignment'),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 2: DIRECT INWARD INTAKE FORM
  // ==========================================
  Widget _buildDirectIntakeTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            color: AppColors.cardBg,
            elevation: 1.5,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                        child: const Icon(Icons.add_business, color: AppColors.primary, size: 24),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Record Stock Inward', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: AppColors.textPrimary)),
                            Text('Credit new factory batches directly into warehouse stock', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),

                  // Destination Warehouse Dropdown
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: _selectedWarehouseId,
                    decoration: InputDecoration(
                      labelText: 'Destination Warehouse *',
                      prefixIcon: const Icon(Icons.warehouse_outlined),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    items: _warehouses.map((w) => DropdownMenuItem(
                      value: w['id']?.toString(),
                      child: Text('${w['name']} (${w['location'] ?? 'Hub'})', overflow: TextOverflow.ellipsis),
                    )).toList(),
                    onChanged: (v) => setState(() => _selectedWarehouseId = v),
                  ),
                  const SizedBox(height: 14),

                  // Product SKU Dropdown
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: _selectedProductId,
                    decoration: InputDecoration(
                      labelText: 'Product SKU *',
                      prefixIcon: const Icon(Icons.inventory_2_outlined),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    items: _products.map((p) => DropdownMenuItem(
                      value: p['id']?.toString(),
                      child: Text('${p['name']} [${p['sku']}]', overflow: TextOverflow.ellipsis),
                    )).toList(),
                    onChanged: (v) => setState(() => _selectedProductId = v),
                  ),
                  const SizedBox(height: 14),

                  // Quantity
                  TextField(
                    controller: _qtyCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Inward Quantity Received *',
                      hintText: 'e.g. 500',
                      prefixIcon: const Icon(Icons.numbers_outlined),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Batch Number
                  TextField(
                    controller: _batchCtrl,
                    decoration: InputDecoration(
                      labelText: 'Batch / Lot Number',
                      prefixIcon: const Icon(Icons.qr_code_outlined),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Supplier
                  TextField(
                    controller: _supplierCtrl,
                    decoration: InputDecoration(
                      labelText: 'Supplier / Factory Name',
                      prefixIcon: const Icon(Icons.business_outlined),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Challan / Invoice
                  TextField(
                    controller: _challanCtrl,
                    decoration: InputDecoration(
                      labelText: 'Challan / Bill Number (Optional)',
                      hintText: 'e.g. CHL-2026-99',
                      prefixIcon: const Icon(Icons.receipt_outlined),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Submit Button
                  ElevatedButton(
                    onPressed: _isSubmitting ? null : _submitDirectIntake,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(50),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('Complete Stock Inward & Credit Hub', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 3: INWARD HISTORY & LEDGER
  // ==========================================
  Widget _buildInwardHistoryTab() {
    final filtered = _intakes.where((i) {
      final matchesWh = _selectedWarehouseFilter == 'all' || i['warehouse_id']?.toString() == _selectedWarehouseFilter;
      final q = _historySearch.toLowerCase();
      final pName = (i['product'] is Map ? i['product']['name'] : '').toString().toLowerCase();
      final batch = (i['batch_number'] ?? '').toString().toLowerCase();
      final supplier = (i['supplier'] ?? '').toString().toLowerCase();
      final matchesSearch = q.isEmpty || pName.contains(q) || batch.contains(q) || supplier.contains(q);
      return matchesWh && matchesSearch;
    }).toList();

    return Column(
      children: [
        // Search & Filter
        Container(
          padding: const EdgeInsets.all(12),
          color: AppColors.cardBg,
          child: Column(
            children: [
              TextField(
                controller: _historySearchCtrl,
                decoration: InputDecoration(
                  hintText: 'Search by product, batch number, supplier...',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: _historySearch.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _historySearchCtrl.clear();
                            setState(() => _historySearch = '');
                          },
                        )
                      : null,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  filled: true,
                  fillColor: AppColors.background,
                ),
                onChanged: (v) => setState(() => _historySearch = v),
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _whFilterChip('all', 'All Hubs (${_intakes.length})'),
                    ..._warehouses.map((w) {
                      final count = _intakes.where((i) => i['warehouse_id']?.toString() == w['id']?.toString()).length;
                      return _whFilterChip(w['id']?.toString() ?? '', '${w['name']} ($count)');
                    }),
                  ],
                ),
              ),
            ],
          ),
        ),

        // List
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.history_outlined, size: 50, color: AppColors.textSecondary.withValues(alpha: 0.4)),
                        const SizedBox(height: 12),
                        const Text('No Inward Records Found', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                        const SizedBox(height: 6),
                        const Text('Recorded stock arrivals will appear in this ledger.', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(14),
                  itemCount: filtered.length,
                  itemBuilder: (ctx, idx) {
                    final item = filtered[idx];
                    final pName = item['product'] is Map ? item['product']['name'] : _getProductName(item['product_id'], item);
                    final pUnit = item['product'] is Map ? (item['product']['unit'] ?? 'units') : _getProductUnit(item['product_id'], item);
                    final batch = item['batch_number'] ?? 'BATCH-DEFAULT';
                    final supplier = item['supplier'] ?? 'Direct Supplier';
                    final date = item['date_received'] ?? (item['created_at'] ?? '').toString().split('T')[0];
                    final qty = item['quantity'] ?? 0;

                    return Card(
                      color: AppColors.cardBg,
                      margin: const EdgeInsets.only(bottom: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                              child: const Icon(Icons.arrow_downward, color: Colors.green, size: 22),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(pName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                  const SizedBox(height: 2),
                                  Text('🏷️ $batch • 🏢 $supplier', style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
                                  Text('📅 $date', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text('+$qty', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green)),
                                Text(pUnit, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
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
    );
  }

  Widget _whFilterChip(String val, String label) {
    final isSelected = _selectedWarehouseFilter == val;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        selectedColor: AppColors.primary.withValues(alpha: 0.15),
        checkmarkColor: AppColors.primary,
        labelStyle: TextStyle(
          color: isSelected ? AppColors.primary : AppColors.textSecondary,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          fontSize: 11.5,
        ),
        onSelected: (selected) {
          if (selected) setState(() => _selectedWarehouseFilter = val);
        },
      ),
    );
  }

  Widget _kpiMiniCard(String label, String value, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 4),
            Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: color)),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(fontSize: 9.5, color: AppColors.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}
