import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../../core/constants/colors.dart';
import '../../../core/state/app_state.dart';

class CatalogPricingModule extends StatefulWidget {
  final List<Map<String, dynamic>> products;
  final List<Map<String, dynamic>> prices;
  final VoidCallback onRefresh;
  final VoidCallback onBack;

  const CatalogPricingModule({
    super.key,
    required this.products,
    required this.prices,
    required this.onRefresh,
    required this.onBack,
  });

  @override
  State<CatalogPricingModule> createState() => _CatalogPricingModuleState();
}

class _CatalogPricingModuleState extends State<CatalogPricingModule>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Catalog Tab State
  String _productSearchQuery = '';
  String _productAvailabilityFilter = 'all';
  final TextEditingController _productSearchCtrl = TextEditingController();

  // Commissions Tab State
  String _commissionSearchQuery = '';
  final TextEditingController _commissionSearchCtrl = TextEditingController();
  final Set<String> _expandedCommissionProductIds = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _productSearchCtrl.dispose();
    _commissionSearchCtrl.dispose();
    super.dispose();
  }

  void _showAddOrEditProductDialog({Map<String, dynamic>? editProduct}) {
    final nameCtrl = TextEditingController(text: editProduct?['name'] ?? '');
    final skuCtrl = TextEditingController(text: editProduct?['sku'] ?? '');
    final unitCtrl = TextEditingController(text: editProduct?['unit'] ?? 'pcs');
    final catCtrl = TextEditingController(
      text: editProduct?['category'] ?? 'General',
    );
    final basePriceCtrl = TextEditingController(
      text: editProduct?['base_price']?.toString() ?? '0',
    );
    final alertCtrl = TextEditingController(
      text: editProduct?['min_stock_alert']?.toString() ?? '20',
    );
    final storeAdminCommCtrl = TextEditingController(
      text: editProduct?['store_admin_commission']?.toString() ?? '5.0',
    );
    final fsmCommCtrl = TextEditingController(
      text: editProduct?['fsm_commission']?.toString() ?? '10.0',
    );
    final salesmanCommCtrl = TextEditingController(
      text: editProduct?['salesman_commission']?.toString() ?? '50.0',
    );
    final referralCommCtrl = TextEditingController(
      text: editProduct?['referral_commission']?.toString() ?? '10.0',
    );
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
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Product Name *',
                  ),
                ),
                TextField(
                  controller: skuCtrl,
                  decoration: const InputDecoration(labelText: 'SKU Code *'),
                ),
                TextField(
                  controller: catCtrl,
                  decoration: const InputDecoration(labelText: 'Category'),
                ),
                TextField(
                  controller: unitCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Selling Unit (pcs, packet, etc.)',
                  ),
                ),
                TextField(
                  controller: basePriceCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Base Selling Price (₹)',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
                TextField(
                  controller: alertCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Low Stock Alert Threshold',
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 14),
                // Dynamic Per-Product Commission Rules Section
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blueGrey.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.blueGrey.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.monetization_on_outlined, size: 18, color: AppColors.primary),
                          SizedBox(width: 6),
                          Text(
                            'COMMISSION RULES (Per Unit)',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: storeAdminCommCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Store Admin Commission (₹)',
                          helperText: 'Earned when Store Admin dispatches to FSM',
                          isDense: true,
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: fsmCommCtrl,
                        decoration: const InputDecoration(
                          labelText: 'FSM Commission (₹)',
                          helperText: 'Earned when FSM allocates to Salesman',
                          isDense: true,
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: salesmanCommCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Salesman Direct Commission (₹)',
                          helperText: 'Earned when Salesman sells to customer',
                          isDense: true,
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: referralCommCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Salesman Referral Bonus (₹)',
                          helperText: 'Earned by direct referrer on downline sale (1-level)',
                          isDense: true,
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isAvailable
                        ? Colors.green.shade50
                        : Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isAvailable
                          ? Colors.green.shade300
                          : Colors.red.shade300,
                    ),
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
                                isAvailable
                                    ? Icons.check_circle
                                    : Icons.do_not_disturb_on,
                                size: 16,
                                color: isAvailable
                                    ? Colors.green.shade800
                                    : Colors.red.shade800,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                isAvailable ? 'AVAILABLE' : 'NOT AVAILABLE',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: isAvailable
                                      ? Colors.green.shade800
                                      : Colors.red.shade800,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isAvailable
                                ? 'Item is active in sales catalog'
                                : 'Item is inactive / hidden from sales',
                            style: TextStyle(
                              fontSize: 10.5,
                              color: isAvailable
                                  ? Colors.green.shade700
                                  : Colors.red.shade700,
                            ),
                          ),
                        ],
                      ),
                      Switch(
                        value: isAvailable,
                        activeThumbColor: Colors.green,
                        inactiveThumbColor: Colors.red,
                        onChanged: (val) =>
                            setDlgState(() => isAvailable = val),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                if (nameCtrl.text.isEmpty || skuCtrl.text.isEmpty) return;

                final bodyData = {
                  'name': nameCtrl.text.trim(),
                  'sku': skuCtrl.text.trim(),
                  'category': catCtrl.text.trim(),
                  'unit': unitCtrl.text.trim(),
                  'base_price': double.tryParse(basePriceCtrl.text) ?? 0.0,
                  'min_stock_alert': int.tryParse(alertCtrl.text) ?? 20,
                  'store_admin_commission': double.tryParse(storeAdminCommCtrl.text) ?? 0.0,
                  'fsm_commission': double.tryParse(fsmCommCtrl.text) ?? 0.0,
                  'salesman_commission': double.tryParse(salesmanCommCtrl.text) ?? 0.0,
                  'referral_commission': double.tryParse(referralCommCtrl.text) ?? 0.0,
                  'is_active': isAvailable,
                  'admin_id': AppState.currentUser?['id'],
                  'admin_name': AppState.currentUser?['name'],
                };

                try {
                  if (editProduct != null) {
                    await http.put(
                      Uri.parse(
                        '${AppState.apiBaseUrl}/products/${editProduct['id']}',
                      ),
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
                  widget.onRefresh();
                  if (ctx.mounted) Navigator.pop(ctx);
                } catch (_) {
                  setState(() {
                    if (editProduct != null) {
                      editProduct['name'] = nameCtrl.text.trim();
                      editProduct['sku'] = skuCtrl.text.trim();
                      editProduct['category'] = catCtrl.text.trim();
                      editProduct['unit'] = unitCtrl.text.trim();
                      editProduct['base_price'] =
                          double.tryParse(basePriceCtrl.text) ?? 0.0;
                      editProduct['min_stock_alert'] =
                          int.tryParse(alertCtrl.text) ?? 20;
                      editProduct['store_admin_commission'] =
                          double.tryParse(storeAdminCommCtrl.text) ?? 0.0;
                      editProduct['fsm_commission'] =
                          double.tryParse(fsmCommCtrl.text) ?? 0.0;
                      editProduct['salesman_commission'] =
                          double.tryParse(salesmanCommCtrl.text) ?? 0.0;
                      editProduct['referral_commission'] =
                          double.tryParse(referralCommCtrl.text) ?? 0.0;
                      editProduct['is_active'] = isAvailable;
                    } else {
                      widget.products.add({
                        'id': 'p_${DateTime.now().millisecondsSinceEpoch}',
                        'name': nameCtrl.text.trim(),
                        'sku': skuCtrl.text.trim(),
                        'category': catCtrl.text.trim(),
                        'unit': unitCtrl.text.trim(),
                        'base_price':
                            double.tryParse(basePriceCtrl.text) ?? 0.0,
                        'min_stock_alert': int.tryParse(alertCtrl.text) ?? 20,
                        'store_admin_commission':
                            double.tryParse(storeAdminCommCtrl.text) ?? 0.0,
                        'fsm_commission':
                            double.tryParse(fsmCommCtrl.text) ?? 0.0,
                        'salesman_commission':
                            double.tryParse(salesmanCommCtrl.text) ?? 0.0,
                        'referral_commission':
                            double.tryParse(referralCommCtrl.text) ?? 0.0,
                        'is_active': isAvailable,
                      });
                    }
                  });
                  if (ctx.mounted) Navigator.pop(ctx);
                }
              },
              child: Text(
                editProduct != null ? 'Save Changes' : 'Create Product',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleProductAvailability(
    Map<String, dynamic> p,
    bool nextStatus,
  ) async {
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
            content: Text(
              nextStatus
                  ? '🟢 "${p['name']}" is now AVAILABLE'
                  : '🔴 "${p['name']}" is now NOT AVAILABLE',
            ),
            backgroundColor: nextStatus
                ? Colors.green.shade700
                : Colors.red.shade700,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (_) {}
    widget.onRefresh();
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
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'SKU: ${p['sku']} • Unit: ${p['unit']}\nThis will remove the product and its pricing tiers from the catalog.',
                style: TextStyle(fontSize: 12, color: Colors.red.shade900),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete Permanently'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final res = await http.delete(
          Uri.parse(
            '${AppState.apiBaseUrl}/products/${p['id']}?admin_id=${AppState.currentUser?['id']}&admin_name=${AppState.currentUser?['name']}',
          ),
        );
        if (res.statusCode == 200 && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Product "${p['name']}" deleted successfully'),
              backgroundColor: Colors.red.shade700,
            ),
          );
        }
      } catch (_) {}
      widget.onRefresh();
    }
  }

  void _showTieredPricingDialog(Map<String, dynamic> product) {
    final priceCtrl = TextEditingController();
    final discountCtrl = TextEditingController(text: '0');
    String selectedRole = 'store_admin';

    void updateForm(String role) {
      final existing = widget.prices.firstWhere(
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
                decoration: const InputDecoration(
                  labelText: 'Buyer / Tier Role',
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'store_admin',
                    child: Text(
                      'Warehouse Admin (Store Admin)',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'field_sales_manager',
                    child: Text(
                      'Field Sales Manager',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'salesman',
                    child: Text(
                      'Salesman (Retail Rate)',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'distributor',
                    child: Text(
                      'Distributor (Bulk Wholesale Rate)',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
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
                decoration: const InputDecoration(
                  labelText: 'Selling Price (₹)',
                  prefixText: '₹',
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: discountCtrl,
                decoration: const InputDecoration(
                  labelText: 'Promotional Discount (%)',
                  suffixText: '%',
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
              ),
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
                      'admin_name': AppState.currentUser?['name'],
                    }),
                  );
                  widget.onRefresh();
                  if (ctx.mounted) Navigator.pop(ctx);
                } catch (_) {
                  setState(() {
                    widget.prices.removeWhere(
                      (p) =>
                          p['product_id'] == product['id'] &&
                          p['role'] == selectedRole,
                    );
                    widget.prices.add({
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

  void _showEditCommissionDialog(Map<String, dynamic> product) {
    final storeAdminCommCtrl = TextEditingController(
      text: (product['store_admin_commission'] ?? 0).toString(),
    );
    final fsmCommCtrl = TextEditingController(
      text: (product['fsm_commission'] ?? 0).toString(),
    );
    final salesmanCommCtrl = TextEditingController(
      text: (product['salesman_commission'] ?? 0).toString(),
    );
    final referralCommCtrl = TextEditingController(
      text: (product['referral_commission'] ?? 0).toString(),
    );

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.monetization_on_outlined, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Edit Commissions: ${product['name']}',
                  style: const TextStyle(fontSize: 16),
                  overflow: TextOverflow.ellipsis,
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
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Base Price: ₹${product['base_price']}',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
                      ),
                      Text(
                        'Unit: ${product['unit'] ?? 'pcs'}',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: storeAdminCommCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Store Admin Commission (₹)',
                    helperText: 'Earned when Store Admin dispatches stock to FSM',
                    isDense: true,
                    prefixText: '₹ ',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: fsmCommCtrl,
                  decoration: const InputDecoration(
                    labelText: 'FSM Commission (₹)',
                    helperText: 'Earned when FSM allocates stock to Salesman',
                    isDense: true,
                    prefixText: '₹ ',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: salesmanCommCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Salesman Direct Commission (₹)',
                    helperText: 'Earned when Salesman delivers order to customer',
                    isDense: true,
                    prefixText: '₹ ',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: referralCommCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Salesman Referral Bonus (₹)',
                    helperText: 'Earned by direct 1-level upline referrer on sale',
                    isDense: true,
                    prefixText: '₹ ',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                final storeAdminVal = double.tryParse(storeAdminCommCtrl.text) ?? 0.0;
                final fsmVal = double.tryParse(fsmCommCtrl.text) ?? 0.0;
                final salesmanVal = double.tryParse(salesmanCommCtrl.text) ?? 0.0;
                final referralVal = double.tryParse(referralCommCtrl.text) ?? 0.0;

                final bodyData = {
                  'name': product['name'],
                  'sku': product['sku'],
                  'category': product['category'],
                  'unit': product['unit'],
                  'base_price': product['base_price'],
                  'min_stock_alert': product['min_stock_alert'],
                  'is_active': product['is_active'] != false,
                  'store_admin_commission': storeAdminVal,
                  'fsm_commission': fsmVal,
                  'salesman_commission': salesmanVal,
                  'referral_commission': referralVal,
                  'admin_id': AppState.currentUser?['id'],
                  'admin_name': AppState.currentUser?['name'],
                };

                try {
                  await http.put(
                    Uri.parse('${AppState.apiBaseUrl}/products/${product['id']}'),
                    headers: {'Content-Type': 'application/json'},
                    body: jsonEncode(bodyData),
                  );
                  setState(() {
                    product['store_admin_commission'] = storeAdminVal;
                    product['fsm_commission'] = fsmVal;
                    product['salesman_commission'] = salesmanVal;
                    product['referral_commission'] = referralVal;
                  });
                  widget.onRefresh();
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Updated role commissions for "${product['name']}"'),
                        backgroundColor: Colors.green.shade700,
                      ),
                    );
                  }
                } catch (_) {
                  setState(() {
                    product['store_admin_commission'] = storeAdminVal;
                    product['fsm_commission'] = fsmVal;
                    product['salesman_commission'] = salesmanVal;
                    product['referral_commission'] = referralVal;
                  });
                  if (ctx.mounted) Navigator.pop(ctx);
                }
              },
              child: const Text('Save Commissions'),
            ),
          ],
        ),
      ),
    );
  }

  void _showCommissionBottomSheet(Map<String, dynamic> product) {
    final basePrice = double.tryParse(product['base_price']?.toString() ?? '0') ?? 0.0;
    final storeAdminComm = double.tryParse(product['store_admin_commission']?.toString() ?? '0') ?? 0.0;
    final fsmComm = double.tryParse(product['fsm_commission']?.toString() ?? '0') ?? 0.0;
    final salesmanComm = double.tryParse(product['salesman_commission']?.toString() ?? '0') ?? 0.0;
    final referralComm = double.tryParse(product['referral_commission']?.toString() ?? '0') ?? 0.0;
    final totalComm = storeAdminComm + fsmComm + salesmanComm + referralComm;
    final netRealization = basePrice > totalComm ? (basePrice - totalComm) : 0.0;

    // Filter tier prices for this product
    final prodTierPrices = widget.prices.where((p) => p['product_id'] == product['id']).toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product['name'] ?? 'Product',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'SKU: ${product['sku']} • Category: ${product['category'] ?? 'General'} • Unit: ${product['unit'] ?? 'pcs'}',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit, color: AppColors.primary),
                    tooltip: 'Edit Commissions',
                    onPressed: () {
                      Navigator.pop(ctx);
                      _showEditCommissionDialog(product);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 14),
              // Summary Banner
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primary.withValues(alpha: 0.12),
                      AppColors.accent.withValues(alpha: 0.12),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _metricCol('Base Price', '₹${basePrice.toStringAsFixed(0)}', AppColors.textPrimary),
                    Container(height: 30, width: 1, color: Colors.grey.shade300),
                    _metricCol(
                      'Commission Pool',
                      '₹${totalComm.toStringAsFixed(1)}',
                      Colors.deepOrange.shade800,
                      subText: '${basePrice > 0 ? (totalComm / basePrice * 100).toStringAsFixed(1) : 0}%',
                    ),
                    Container(height: 30, width: 1, color: Colors.grey.shade300),
                    _metricCol('Company Net', '₹${netRealization.toStringAsFixed(1)}', Colors.green.shade800),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'ROLE-WISE COMMISSION MATRIX',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 10),
              _buildRoleItemCard(
                roleName: 'Store Admin',
                roleSubtitle: 'Warehouse / Hub Manager',
                commission: storeAdminComm,
                unit: product['unit'] ?? 'pcs',
                basePrice: basePrice,
                triggerEvent: 'Earned when Store Admin dispatches stock to FSM',
                color: Colors.teal,
                icon: Icons.warehouse_outlined,
              ),
              _buildRoleItemCard(
                roleName: 'Field Sales Manager (FSM)',
                roleSubtitle: 'Regional / Area Distribution Lead',
                commission: fsmComm,
                unit: product['unit'] ?? 'pcs',
                basePrice: basePrice,
                triggerEvent: 'Earned when FSM transfers stock to Salesman field bag',
                color: Colors.indigo,
                icon: Icons.manage_accounts_outlined,
              ),
              _buildRoleItemCard(
                roleName: 'Salesman (Direct Sales)',
                roleSubtitle: 'Field Executive / Order Delivery',
                commission: salesmanComm,
                unit: product['unit'] ?? 'pcs',
                basePrice: basePrice,
                triggerEvent: 'Earned directly upon delivering order to retail customer',
                color: Colors.deepOrange,
                icon: Icons.person_pin_circle_outlined,
              ),
              _buildRoleItemCard(
                roleName: 'Salesman Downline Referrer',
                roleSubtitle: 'Peer Referral Bonus (1-Level)',
                commission: referralComm,
                unit: product['unit'] ?? 'pcs',
                basePrice: basePrice,
                triggerEvent: 'Earned by direct upline referrer on downline sale',
                color: Colors.purple,
                icon: Icons.share_outlined,
              ),
              if (prodTierPrices.isNotEmpty) ...[
                const SizedBox(height: 14),
                const Text(
                  'CONFIGURED ROLE SELLING RATES',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: prodTierPrices.map((tp) {
                    final roleLabel = tp['role'] == 'store_admin'
                        ? 'Warehouse'
                        : tp['role'] == 'field_sales_manager'
                            ? 'FSM'
                            : tp['role'] == 'salesman'
                                ? 'Salesman'
                                : 'Distributor';
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Text(
                        '$roleLabel: ₹${tp['price']} (${tp['discount_percentage'] ?? 0}% off)',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                    );
                  }).toList(),
                ),
              ],
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.edit_note, size: 20),
                  label: const Text('Update Role Commissions', style: TextStyle(fontWeight: FontWeight.bold)),
                  onPressed: () {
                    Navigator.pop(ctx);
                    _showEditCommissionDialog(product);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _metricCol(String title, String val, Color color, {String? subText}) {
    return Column(
      children: [
        Text(
          title,
          style: TextStyle(fontSize: 10.5, color: Colors.grey.shade700, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 3),
        Text(
          val,
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color),
        ),
        if (subText != null)
          Text(
            subText,
            style: TextStyle(fontSize: 10, color: color.withValues(alpha: 0.8)),
          ),
      ],
    );
  }

  Widget _buildRoleItemCard({
    required String roleName,
    required String roleSubtitle,
    required double commission,
    required String unit,
    required double basePrice,
    required String triggerEvent,
    required Color color,
    required IconData icon,
  }) {
    final percent = basePrice > 0 ? (commission / basePrice * 100).toStringAsFixed(1) : '0.0';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 16),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      roleName,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12.5,
                        color: color,
                      ),
                    ),
                    Text(
                      roleSubtitle,
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '₹${commission.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: color,
                    ),
                  ),
                  Text(
                    '$percent% of base',
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.bolt, size: 12, color: color),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    triggerEvent,
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey.shade800,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _commissionBadge(String label, String value, MaterialColor color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.shade50,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.shade200, width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 10,
              color: color.shade800,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 10.5,
              color: color.shade900,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // Commissions Tab View
  Widget _buildCommissionsTab(List<Map<String, dynamic>> products) {
    final query = _commissionSearchQuery.toLowerCase().trim();
    final filtered = products.where((p) {
      if (query.isEmpty) return true;
      final name = (p['name'] ?? '').toString().toLowerCase();
      final sku = (p['sku'] ?? '').toString().toLowerCase();
      final cat = (p['category'] ?? '').toString().toLowerCase();
      return name.contains(query) || sku.contains(query) || cat.contains(query);
    }).toList();

    return Column(
      children: [
        // Commissions Tab Header & Search
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
          color: AppColors.background,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _commissionSearchCtrl,
                decoration: InputDecoration(
                  hintText: 'Search products for role commissions...',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: _commissionSearchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _commissionSearchCtrl.clear();
                            setState(() => _commissionSearchQuery = '');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                ),
                onChanged: (val) => setState(() => _commissionSearchQuery = val),
              ),
              const SizedBox(height: 10),
              // Guide banner
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.touch_app_outlined, size: 16, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Click any product to expand role commissions (Store Admin, FSM, Salesman, Referral).',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary.withValues(alpha: 0.9),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),

        // Productwise Commissions List
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.monetization_on_outlined,
                          size: 50,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _commissionSearchQuery.isNotEmpty
                              ? 'No products match "$_commissionSearchQuery"'
                              : 'No products available for commission mapping',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: filtered.length,
                  itemBuilder: (ctx, idx) {
                    final p = filtered[idx];
                    final pId = p['id']?.toString() ?? 'prod_$idx';
                    final isExpanded = _expandedCommissionProductIds.contains(pId);

                    final basePrice = double.tryParse(p['base_price']?.toString() ?? '0') ?? 0.0;
                    final storeAdminComm = double.tryParse(p['store_admin_commission']?.toString() ?? '0') ?? 0.0;
                    final fsmComm = double.tryParse(p['fsm_commission']?.toString() ?? '0') ?? 0.0;
                    final salesmanComm = double.tryParse(p['salesman_commission']?.toString() ?? '0') ?? 0.0;
                    final referralComm = double.tryParse(p['referral_commission']?.toString() ?? '0') ?? 0.0;
                    final totalComm = storeAdminComm + fsmComm + salesmanComm + referralComm;
                    final commPercent = basePrice > 0 ? (totalComm / basePrice * 100) : 0.0;

                    return Card(
                      color: AppColors.cardBg,
                      elevation: isExpanded ? 3 : 1.5,
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: isExpanded ? AppColors.primary : Colors.grey.shade200,
                          width: isExpanded ? 1.5 : 1.0,
                        ),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () {
                          setState(() {
                            if (isExpanded) {
                              _expandedCommissionProductIds.remove(pId);
                            } else {
                              _expandedCommissionProductIds.add(pId);
                            }
                          });
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Product Header Row
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Product Category Avatar
                                  Container(
                                    width: 42,
                                    height: 42,
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Center(
                                      child: Icon(Icons.inventory_2_outlined, color: AppColors.primary, size: 22),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          p['name'] ?? 'Product',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        Wrap(
                                          spacing: 6,
                                          runSpacing: 2,
                                          children: [
                                            Text(
                                              'SKU: ${p['sku']}',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.brown.shade800,
                                              ),
                                            ),
                                            Text(
                                              '• Unit: ${p['unit'] ?? 'pcs'}',
                                              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                            ),
                                            Text(
                                              '• Base: ₹$basePrice',
                                              style: const TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: AppColors.primary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Expand Indicator
                                  Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: isExpanded
                                          ? AppColors.primary.withValues(alpha: 0.1)
                                          : Colors.grey.shade100,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                                      color: isExpanded ? AppColors.primary : Colors.grey.shade700,
                                      size: 20,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),

                              // Total Commission Summary Row
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.orange.shade50.withValues(alpha: 0.6),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.orange.shade200),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(Icons.pie_chart_outline, size: 14, color: Colors.orange.shade900),
                                        const SizedBox(width: 5),
                                        Text(
                                          'Total Commission Pool:',
                                          style: TextStyle(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.orange.shade900,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Text(
                                      '₹${totalComm.toStringAsFixed(1)} / ${p['unit'] ?? 'unit'} (${commPercent.toStringAsFixed(1)}%)',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.orange.shade900,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 8),

                              // Quick Chips at a glance
                              Wrap(
                                spacing: 5,
                                runSpacing: 4,
                                children: [
                                  _commissionBadge('Store Admin', '₹$storeAdminComm', Colors.teal),
                                  _commissionBadge('FSM', '₹$fsmComm', Colors.indigo),
                                  _commissionBadge('Salesman', '₹$salesmanComm', Colors.deepOrange),
                                  _commissionBadge('Referral', '₹$referralComm', Colors.purple),
                                ],
                              ),

                              // Role Commission Breakdown View on click
                              if (isExpanded) ...[
                                const Divider(height: 20),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'RESPECTIVE ROLES COMMISSIONS',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.textSecondary,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    Text(
                                      'Per ${p['unit'] ?? 'unit'} Sold',
                                      style: TextStyle(fontSize: 10.5, color: Colors.grey.shade600),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                _buildRoleItemCard(
                                  roleName: 'Store Admin (Warehouse Admin)',
                                  roleSubtitle: 'Dispatch & Stock Hub Execution',
                                  commission: storeAdminComm,
                                  unit: p['unit'] ?? 'pcs',
                                  basePrice: basePrice,
                                  triggerEvent: 'Earned when Store Admin dispatches stock to Field Sales Manager',
                                  color: Colors.teal,
                                  icon: Icons.warehouse_outlined,
                                ),
                                _buildRoleItemCard(
                                  roleName: 'Field Sales Manager (FSM)',
                                  roleSubtitle: 'Regional Team & Allocation Lead',
                                  commission: fsmComm,
                                  unit: p['unit'] ?? 'pcs',
                                  basePrice: basePrice,
                                  triggerEvent: 'Earned when FSM allocates stock into active Salesman bag',
                                  color: Colors.indigo,
                                  icon: Icons.manage_accounts_outlined,
                                ),
                                _buildRoleItemCard(
                                  roleName: 'Salesman (Direct Retail Sale)',
                                  roleSubtitle: 'Frontline Customer Order Delivery',
                                  commission: salesmanComm,
                                  unit: p['unit'] ?? 'pcs',
                                  basePrice: basePrice,
                                  triggerEvent: 'Earned directly when Salesman delivers order to retail customer',
                                  color: Colors.deepOrange,
                                  icon: Icons.person_pin_circle_outlined,
                                ),
                                _buildRoleItemCard(
                                  roleName: 'Salesman Peer Referrer',
                                  roleSubtitle: '1-Level Downline Referral Bonus',
                                  commission: referralComm,
                                  unit: p['unit'] ?? 'pcs',
                                  basePrice: basePrice,
                                  triggerEvent: 'Earned by direct upline referrer on downline salesman retail sale',
                                  color: Colors.purple,
                                  icon: Icons.share_outlined,
                                ),
                                const SizedBox(height: 8),

                                // Action Buttons Row
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: AppColors.primary,
                                          side: const BorderSide(color: AppColors.primary),
                                          padding: const EdgeInsets.symmetric(vertical: 8),
                                        ),
                                        icon: const Icon(Icons.fullscreen, size: 16),
                                        label: const Text('Full Details Sheet', style: TextStyle(fontSize: 12)),
                                        onPressed: () => _showCommissionBottomSheet(p),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppColors.primary,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(vertical: 8),
                                        ),
                                        icon: const Icon(Icons.edit, size: 15),
                                        label: const Text('Edit Commissions', style: TextStyle(fontSize: 12)),
                                        onPressed: () => _showEditCommissionDialog(p),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // Catalog Tab View
  Widget _buildCatalogTab(
    List<Map<String, dynamic>> products,
    int availableCount,
    int notAvailableCount,
    List<Map<String, dynamic>> filteredProducts,
  ) {
    return Column(
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
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
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
                      label: Text('All (${products.length})'),
                      selectedColor: AppColors.primary.withValues(
                        alpha: 0.15,
                      ),
                      checkmarkColor: AppColors.primary,
                      labelStyle: TextStyle(
                        fontSize: 12,
                        fontWeight: _productAvailabilityFilter == 'all'
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: _productAvailabilityFilter == 'all'
                            ? AppColors.primary
                            : AppColors.textSecondary,
                      ),
                      onSelected: (_) =>
                          setState(() => _productAvailabilityFilter = 'all'),
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      selected: _productAvailabilityFilter == 'available',
                      avatar: const CircleAvatar(
                        radius: 4,
                        backgroundColor: Colors.green,
                      ),
                      label: Text('Available ($availableCount)'),
                      selectedColor: Colors.green.shade100,
                      checkmarkColor: Colors.green.shade800,
                      labelStyle: TextStyle(
                        fontSize: 12,
                        fontWeight: _productAvailabilityFilter == 'available'
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: _productAvailabilityFilter == 'available'
                            ? Colors.green.shade900
                            : AppColors.textSecondary,
                      ),
                      onSelected: (_) => setState(
                        () => _productAvailabilityFilter = 'available',
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      selected: _productAvailabilityFilter == 'not_available',
                      avatar: const CircleAvatar(
                        radius: 4,
                        backgroundColor: Colors.red,
                      ),
                      label: Text('Not Available ($notAvailableCount)'),
                      selectedColor: Colors.red.shade100,
                      checkmarkColor: Colors.red.shade800,
                      labelStyle: TextStyle(
                        fontSize: 12,
                        fontWeight:
                            _productAvailabilityFilter == 'not_available'
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: _productAvailabilityFilter == 'not_available'
                            ? Colors.red.shade900
                            : AppColors.textSecondary,
                      ),
                      onSelected: (_) => setState(
                        () => _productAvailabilityFilter = 'not_available',
                      ),
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
                        Icon(
                          Icons.inventory_2_outlined,
                          size: 54,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _productSearchQuery.isNotEmpty
                              ? 'No products matching "$_productSearchQuery"'
                              : (_productAvailabilityFilter == 'not_available'
                                    ? 'No unavailable products found'
                                    : 'No products found'),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _productSearchQuery.isNotEmpty
                              ? 'Try clearing your search keyword'
                              : 'Add products to your catalog using the button below',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade500,
                          ),
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
                          color: isAvail
                              ? Colors.transparent
                              : Colors.red.shade200,
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        p['name'] ?? '',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          color: isAvail
                                              ? AppColors.textPrimary
                                              : Colors.grey.shade600,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Wrap(
                                        spacing: 6,
                                        runSpacing: 4,
                                        children: [
                                          Container(
                                            padding:
                                                const EdgeInsets.symmetric(
                                                  horizontal: 7,
                                                  vertical: 2,
                                                ),
                                            decoration: BoxDecoration(
                                              color: Colors.brown.shade50,
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                              border: Border.all(
                                                color: Colors.brown.shade200,
                                              ),
                                            ),
                                            child: Text(
                                              'SKU: ${p['sku']}',
                                              style: TextStyle(
                                                fontSize: 10.5,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.brown.shade900,
                                              ),
                                            ),
                                          ),
                                          Container(
                                            padding:
                                                const EdgeInsets.symmetric(
                                                  horizontal: 7,
                                                  vertical: 2,
                                                ),
                                            decoration: BoxDecoration(
                                              color: Colors.blueGrey.shade50,
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              p['category'] ?? 'General',
                                              style: TextStyle(
                                                fontSize: 10.5,
                                                color:
                                                    Colors.blueGrey.shade800,
                                              ),
                                            ),
                                          ),
                                          Container(
                                            padding:
                                                const EdgeInsets.symmetric(
                                                  horizontal: 7,
                                                  vertical: 2,
                                                ),
                                            decoration: BoxDecoration(
                                              color: Colors.orange.shade50,
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              'Unit: ${p['unit']}',
                                              style: TextStyle(
                                                fontSize: 10.5,
                                                color: Colors.orange.shade900,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                // Status Badge
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isAvail
                                        ? Colors.green.shade50
                                        : Colors.red.shade50,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: isAvail
                                          ? Colors.green.shade300
                                          : Colors.red.shade300,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        isAvail
                                            ? Icons.check_circle
                                            : Icons.do_not_disturb_on,
                                        size: 12,
                                        color: isAvail
                                            ? Colors.green.shade800
                                            : Colors.red.shade800,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        isAvail
                                            ? 'AVAILABLE'
                                            : 'NOT AVAILABLE',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: isAvail
                                              ? Colors.green.shade800
                                              : Colors.red.shade800,
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
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13.5,
                                    color: AppColors.primary,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  'Low Stock Alert: < ${p['min_stock_alert'] ?? 20} ${p['unit']}',
                                  style: TextStyle(
                                    color: Colors.amber.shade900,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),

                            // Dynamic Per-Product Commission Chips
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: [
                                _commissionBadge('Store Admin', '₹${p['store_admin_commission'] ?? 0}', Colors.teal),
                                _commissionBadge('FSM', '₹${p['fsm_commission'] ?? 0}', Colors.indigo),
                                _commissionBadge('Salesman', '₹${p['salesman_commission'] ?? 0}', Colors.deepOrange),
                                _commissionBadge('Referral', '₹${p['referral_commission'] ?? 0}', Colors.purple),
                              ],
                            ),
                            const SizedBox(height: 10),

                            // Availability Toggle Banner
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: isAvail
                                    ? Colors.green.shade50.withValues(
                                        alpha: 0.6,
                                      )
                                    : Colors.red.shade50.withValues(
                                        alpha: 0.6,
                                      ),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isAvail
                                      ? Colors.green.shade200
                                      : Colors.red.shade200,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      isAvail
                                          ? 'Product Available for Ordering'
                                          : 'Product Marked Not Available',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: isAvail
                                            ? Colors.green.shade900
                                            : Colors.red.shade900,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Row(
                                    children: [
                                      Text(
                                        isAvail ? 'Available' : 'Unavailable',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: isAvail
                                              ? Colors.green.shade800
                                              : Colors.red.shade800,
                                        ),
                                      ),
                                      Transform.scale(
                                        scale: 0.8,
                                        child: Switch(
                                          value: isAvail,
                                          activeThumbColor: Colors.green,
                                          inactiveThumbColor: Colors.red,
                                          onChanged: (val) =>
                                              _toggleProductAvailability(
                                                p,
                                                val,
                                              ),
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
                                      side: const BorderSide(
                                        color: AppColors.accent,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 8,
                                      ),
                                    ),
                                    icon: const Icon(Icons.sell, size: 15),
                                    label: const Text(
                                      'Set Role & Bulk Prices',
                                      style: TextStyle(fontSize: 12),
                                    ),
                                    onPressed: () =>
                                        _showTieredPricingDialog(p),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: const Icon(
                                    Icons.edit,
                                    size: 20,
                                    color: Colors.blue,
                                  ),
                                  tooltip: 'Edit Product Details',
                                  onPressed: () =>
                                      _showAddOrEditProductDialog(
                                        editProduct: p,
                                      ),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    size: 20,
                                    color: Colors.red,
                                  ),
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final products = widget.products;
    final availableCount = products
        .where((p) => p['is_active'] != false)
        .length;
    final notAvailableCount = products
        .where((p) => p['is_active'] == false)
        .length;

    // Filter products by search and availability for Catalog tab
    final filteredProducts = products.where((p) {
      final name = (p['name'] ?? '').toString().toLowerCase();
      final sku = (p['sku'] ?? '').toString().toLowerCase();
      final cat = (p['category'] ?? '').toString().toLowerCase();
      final query = _productSearchQuery.toLowerCase().trim();

      final matchesQuery =
          query.isEmpty ||
          name.contains(query) ||
          sku.contains(query) ||
          cat.contains(query);
      if (!matchesQuery) return false;

      final isAvail = p['is_active'] != false;
      if (_productAvailabilityFilter == 'available') return isAvail;
      if (_productAvailabilityFilter == 'not_available') return !isAvail;
      return true; // 'all'
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Product Catalog & Pricing'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: widget.onBack,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: widget.onRefresh,
            tooltip: 'Refresh Products',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: [
            Tab(
              icon: const Icon(Icons.inventory_2_outlined, size: 20),
              text: 'Catalog & Tiers (${products.length})',
            ),
            const Tab(
              icon: Icon(Icons.monetization_on_outlined, size: 20),
              text: 'Commissions',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildCatalogTab(products, availableCount, notAvailableCount, filteredProducts),
          _buildCommissionsTab(products),
        ],
      ),
      floatingActionButton: _tabController.index == 0
          ? FloatingActionButton.extended(
              onPressed: () => _showAddOrEditProductDialog(),
              backgroundColor: AppColors.primary,
              icon: const Icon(Icons.add_shopping_cart, color: Colors.white),
              label: const Text(
                'Add Product',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            )
          : null,
    );
  }
}
