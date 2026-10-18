import 'package:flutter/material.dart';
import '../../../core/constants/colors.dart';
import '../../../core/services/offline_sales_service.dart';
import '../../../core/state/app_state.dart';

class SalesmanRecordSaleModal {
  static void show({
    required BuildContext context,
    required String salesmanId,
    required double unitPrice,
    required double? bottleUnitPrice,
    required List<Map<String, dynamic>> customers,
    required int totalDispatchedBottles,
    required int currentSettlementSoldBottles,
    required Function(int qty, double totalAmt, int newSettlementSold) onSaleSuccess,
  }) {
    bool isNewCustomer = false;
    String? saleCustomerId = customers.isNotEmpty ? customers.first['id']?.toString() : null;
    final saleCustNameCtrl = TextEditingController();
    final saleCustPhoneCtrl = TextEditingController();
    final saleCustAddressCtrl = TextEditingController();
    final saleQtyCtrl = TextEditingController(text: '1');
    String salePaymentMode = 'cash';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (modalCtx, setModalState) {
          final qty = int.tryParse(saleQtyCtrl.text) ?? 1;
          final totalAmt = qty * unitPrice;

          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(modalCtx).viewInsets.bottom + 20,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Record Sale',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: ClientColors.textDark,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(modalCtx),
                      ),
                    ],
                  ),
                  const Text(
                    'Log bottles sold directly to retail customer.',
                    style: TextStyle(fontSize: 12, color: ClientColors.textMuted),
                  ),
                  const SizedBox(height: 16),

                  // Customer Toggle
                  Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          label: const Center(child: Text('Existing Customer')),
                          selected: !isNewCustomer,
                          selectedColor: ClientColors.alertBg,
                          onSelected: (val) => setModalState(() => isNewCustomer = false),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ChoiceChip(
                          label: const Center(child: Text('+ New Customer')),
                          selected: isNewCustomer,
                          selectedColor: ClientColors.alertBg,
                          onSelected: (val) => setModalState(() => isNewCustomer = true),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  if (!isNewCustomer) ...[
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Select Customer',
                        border: OutlineInputBorder(),
                      ),
                      initialValue: saleCustomerId,
                      items: customers
                          .map(
                            (c) => DropdownMenuItem<String>(
                              value: c['id']?.toString(),
                              child: Text('${c['name']}'),
                            ),
                          )
                          .toList(),
                      onChanged: (val) => setModalState(() => saleCustomerId = val),
                    ),
                  ] else ...[
                    TextField(
                      controller: saleCustNameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Customer / Shop Name *',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: saleCustPhoneCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Phone Number',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: saleCustAddressCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Market Location / Address',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),

                  // Super Admin Price Banner
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.amber.shade200),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.lock, size: 16, color: ClientColors.primary),
                            SizedBox(width: 6),
                            Text(
                              'Retail Price (Super Admin):',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: ClientColors.primary,
                              ),
                            ),
                          ],
                        ),
                        bottleUnitPrice != null
                            ? Text(
                                '₹$bottleUnitPrice / btl',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: ClientColors.textDark,
                                ),
                              )
                            : const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: ClientColors.primary,
                                ),
                              ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Quantity
                  TextField(
                    controller: saleQtyCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Quantity (Bottles)',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setModalState(() {}),
                  ),
                  const SizedBox(height: 10),

                  // Total Amount Box
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: ClientColors.alertBg,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Total Amount to Collect:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '₹${totalAmt.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: ClientColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Payment Mode
                  Row(
                    children: [
                      ChoiceChip(
                        label: const Text('💵 Cash'),
                        selected: salePaymentMode == 'cash',
                        selectedColor: Colors.green.shade100,
                        onSelected: (val) => setModalState(() => salePaymentMode = 'cash'),
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('📱 Online / UPI'),
                        selected: salePaymentMode == 'online',
                        selectedColor: Colors.blue.shade100,
                        onSelected: (val) => setModalState(() => salePaymentMode = 'online'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  ElevatedButton(
                    onPressed: () async {
                      Navigator.pop(modalCtx);
                      await _executeSale(
                        context: context,
                        salesmanId: salesmanId,
                        unitPrice: unitPrice,
                        bottleUnitPrice: bottleUnitPrice,
                        totalDispatchedBottles: totalDispatchedBottles,
                        currentSettlementSoldBottles: currentSettlementSoldBottles,
                        qty: qty,
                        totalAmt: totalAmt,
                        salePaymentMode: salePaymentMode,
                        isNewCustomer: isNewCustomer,
                        saleCustomerId: saleCustomerId,
                        custName: saleCustNameCtrl.text.trim(),
                        custPhone: saleCustPhoneCtrl.text.trim(),
                        custAddress: saleCustAddressCtrl.text.trim(),
                        onSaleSuccess: onSaleSuccess,
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ClientColors.primary,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(48),
                    ),
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

  static Future<void> _executeSale({
    required BuildContext context,
    required String salesmanId,
    required double unitPrice,
    required double? bottleUnitPrice,
    required int totalDispatchedBottles,
    required int currentSettlementSoldBottles,
    required int qty,
    required double totalAmt,
    required String salePaymentMode,
    required bool isNewCustomer,
    required String? saleCustomerId,
    required String custName,
    required String custPhone,
    required String custAddress,
    required Function(int qty, double totalAmt, int newSettlementSold) onSaleSuccess,
  }) async {
    final result = await OfflineSalesService.recordSale(
      apiBaseUrl: AppState.apiBaseUrl,
      salesmanId: salesmanId,
      productId: 'p1',
      quantity: qty,
      amount: totalAmt,
      paymentMethod: salePaymentMode,
      customerId: isNewCustomer ? null : saleCustomerId,
      customerName: isNewCustomer ? custName : null,
      customerPhone: isNewCustomer ? custPhone : null,
      customerAddress: isNewCustomer ? custAddress : null,
    );

    if (result['success'] != true) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('⚠️ ${result['error'] ?? 'Failed to record sale'}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    final bool isOffline = result['is_offline'] == true;
    final String receiptId = result['receipt_id']?.toString() ??
        'RCP-${DateTime.now().millisecondsSinceEpoch % 100000}';
    final int newSettlementSold =
        (currentSettlementSoldBottles + qty).clamp(0, totalDispatchedBottles);

    onSaleSuccess(qty, totalAmt, newSettlementSold);

    if (context.mounted) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(
                isOffline ? Icons.cloud_off_rounded : Icons.check_circle,
                color: isOffline ? Colors.amber.shade700 : Colors.green,
                size: 28,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isOffline ? 'Saved to Offline Queue' : 'Sale Completed',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isOffline)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3CD),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFFEEBA)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.wifi_off_rounded, size: 18, color: Colors.amber.shade900),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Network unavailable. Sale is securely stored on your device and will automatically sync once internet is back.',
                          style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFF451A03),
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              _dialogRow('Receipt ID:', receiptId),
              _dialogRow('Bottles Sold:', '$qty Bottles'),
              _dialogRow(
                'Unit Price:',
                bottleUnitPrice != null ? '₹$bottleUnitPrice' : 'Loading...',
              ),
              _dialogRow('Total Collected:', '₹$totalAmt'),
              _dialogRow('Payment Mode:', salePaymentMode.toUpperCase()),
              _dialogRow('Sync Status:', isOffline ? '⚡ Queued Locally' : '✅ Live on Server'),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(
                backgroundColor: isOffline ? Colors.amber.shade800 : ClientColors.primary,
                foregroundColor: Colors.white,
              ),
              child: Text(isOffline ? 'OK (Stored Safely)' : 'Close & Print Receipt'),
            ),
          ],
        ),
      );
    }
  }

  static Widget _dialogRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: ClientColors.textMuted)),
          Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: ClientColors.textDark,
            ),
          ),
        ],
      ),
    );
  }
}
