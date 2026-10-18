import 'package:flutter/material.dart';
import '../../../core/constants/colors.dart';
import '../../../core/state/app_state.dart';
import '../../../core/services/offline_sync_service.dart';

// ---------------------------------------------------------
// DISTRIBUTOR BULK SALE VIEW (TIER PRICING, BULK ORDERS)
// ---------------------------------------------------------
class DistributorSaleView extends StatefulWidget {
  final String warehouseId;
  final List<Map<String, dynamic>> products;
  final List<Map<String, dynamic>> distributors;
  final List<Map<String, dynamic>> sales;
  final int Function(String) getStockForProduct;
  final double Function(String) getDistributorPrice;
  final VoidCallback onSaleComplete;

  const DistributorSaleView({
    super.key,
    required this.warehouseId,
    required this.products,
    required this.distributors,
    required this.sales,
    required this.getStockForProduct,
    required this.getDistributorPrice,
    required this.onSaleComplete,
  });

  @override
  State<DistributorSaleView> createState() => _DistributorSaleViewState();
}

class _DistributorSaleViewState extends State<DistributorSaleView> {
  bool _isNewDistributor = false;
  String? _selectedDistributorId;
  final TextEditingController _distNameController = TextEditingController();
  final TextEditingController _distPhoneController = TextEditingController();

  String? _selectedProductId;
  final TextEditingController _qtyController = TextEditingController(text: '1');
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
      final result = await OfflineSyncService.executeWithOfflineFallback(
        apiBaseUrl: AppState.apiBaseUrl,
        endpoint: '/sales',
        method: 'POST',
        role: 'store_admin',
        type: 'sale',
        title: 'Distributor Sale ($qty units)',
        userId: AppState.currentUser?['id'],
        payload: {
          'warehouse_id': widget.warehouseId,
          'customer_id': _isNewDistributor ? null : _selectedDistributorId,
          'customer_name': _isNewDistributor ? _distNameController.text.trim() : null,
          'customer_phone': _isNewDistributor ? _distPhoneController.text.trim() : null,
          'customer_type': 'distributor',
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
                  ? '⚡ Distributor bulk sale saved offline! Queued to sync once online.'
                  : 'Distributor Bulk Sale Processed! Invoice Created.'),
              backgroundColor: isOffline ? Colors.amber.shade800 : Colors.green,
            ),
          );
          _qtyController.text = '50';
          if (_isNewDistributor) _distNameController.clear();
          widget.onSaleComplete();
        }
        return;
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('⚠️ ${result['error'] ?? 'Failed to process bulk sale'}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to process bulk sale. Please try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }
}
