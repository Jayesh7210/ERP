import 'package:flutter/material.dart';
import '../../../core/constants/colors.dart';
import '../../../core/state/app_state.dart';
import '../../../core/services/offline_sync_service.dart';

// ---------------------------------------------------------
// DIRECT RETAIL SALE VIEW (LOCKED PRICE, REFERRAL CODE)
// ---------------------------------------------------------
class DirectRetailSaleView extends StatefulWidget {
  final String warehouseId;
  final List<Map<String, dynamic>> products;
  final List<Map<String, dynamic>> customers;
  final List<Map<String, dynamic>> sales;
  final int Function(String) getStockForProduct;
  final double Function(String) getRetailPrice;
  final VoidCallback onSaleComplete;

  const DirectRetailSaleView({
    super.key,
    required this.warehouseId,
    required this.products,
    required this.customers,
    required this.sales,
    required this.getStockForProduct,
    required this.getRetailPrice,
    required this.onSaleComplete,
  });

  @override
  State<DirectRetailSaleView> createState() => _DirectRetailSaleViewState();
}

class _DirectRetailSaleViewState extends State<DirectRetailSaleView> {
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
      final result = await OfflineSyncService.executeWithOfflineFallback(
        apiBaseUrl: AppState.apiBaseUrl,
        endpoint: '/sales',
        method: 'POST',
        role: 'store_admin',
        type: 'sale',
        title: 'Retail Sale ($qty units)',
        userId: AppState.currentUser?['id'],
        payload: {
          'warehouse_id': widget.warehouseId,
          'customer_id': _isNewCustomer ? null : _selectedCustomerId,
          'customer_name': _isNewCustomer ? _custNameController.text.trim() : null,
          'customer_phone': _isNewCustomer ? _custPhoneController.text.trim() : null,
          'customer_type': 'retail',
          'product_id': _selectedProductId,
          'quantity': qty,
          'amount': totalAmount,
          'payment_method': _paymentMethod,
        },
      );

      if (result['success'] == true) {
        if (mounted) {
          final isOffline = result['is_offline'] == true;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(isOffline
                  ? '⚡ Direct Sale saved offline! Queued to sync once connected.'
                  : 'Direct Customer Sale Recorded! Stock deducted.'),
              backgroundColor: isOffline ? Colors.amber.shade800 : Colors.green,
            ),
          );
          _qtyController.text = '1';
          if (_isNewCustomer) _custNameController.clear();
          widget.onSaleComplete();
        }
        return;
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('⚠️ ${result['error'] ?? 'Failed to record sale'}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to record sale. Please try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }
}
