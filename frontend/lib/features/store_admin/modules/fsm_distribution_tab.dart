import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:qr_flutter/qr_flutter.dart';
import '../../../core/constants/colors.dart';
import '../../../core/state/app_state.dart';
import '../../../core/services/offline_sync_service.dart';

// ---------------------------------------------------------
// FSM DISTRIBUTION VIEW (FSM SELECTOR ONLY, REMAINING CALC)
// ---------------------------------------------------------
class FsmDistributionView extends StatefulWidget {
  final String warehouseId;
  final List<Map<String, dynamic>> products;
  final List<Map<String, dynamic>> fsmUsers;
  final List<Map<String, dynamic>> transfers;
  final int Function(String) getStockForProduct;
  final VoidCallback onTransferComplete;

  const FsmDistributionView({
    super.key,
    required this.warehouseId,
    required this.products,
    required this.fsmUsers,
    required this.transfers,
    required this.getStockForProduct,
    required this.onTransferComplete,
  });

  @override
  State<FsmDistributionView> createState() => _FsmDistributionViewState();
}

class _FsmDistributionViewState extends State<FsmDistributionView> {
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
  void dispose() {
    _qtyController.dispose();
    super.dispose();
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
                final prod = widget.products.firstWhere((p) => p['id']?.toString() == t['product_id']?.toString(), orElse: () => {});
                final pName = t['product']?['name'] ?? prod['name'] ?? 'Product';
                final qty = t['quantity'];
                final date = t['created_at'] != null ? t['created_at'].toString().split('T').first : 'Today';
                final destName = t['to_name'] ?? 'Field Sales Manager';
                final status = (t['status'] ?? 'completed').toString().toUpperCase();
                final isPending = status == 'PENDING';

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
                      decoration: BoxDecoration(
                        color: isPending ? Colors.amber.shade100 : Colors.green.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        status,
                        style: TextStyle(
                          color: isPending ? Colors.amber.shade900 : Colors.green.shade900,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
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
      final result = await OfflineSyncService.executeWithOfflineFallback(
        apiBaseUrl: AppState.apiBaseUrl,
        endpoint: '/stock/transfer',
        method: 'POST',
        role: 'store_admin',
        type: 'stock_transfer',
        title: 'FSM Stock Transfer ($qty units)',
        userId: AppState.currentUser?['id'],
        payload: {
          'from_id': widget.warehouseId,
          'to_id': _selectedFsmId,
          'product_id': _selectedProductId,
          'quantity': qty,
          'status': 'pending',
        },
      );

      if (result['success'] != true) {
        if (!mounted) return;
        setState(() => _isSubmitting = false);
        final err = result['error']?.toString() ?? 'Failed to initiate stock transfer.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red.shade800,
            content: Text('⚠️ $err'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      String transferId = 'tr_${DateTime.now().millisecondsSinceEpoch}';
      final body = result['data'];
      if (body != null && body['transfer'] != null && body['transfer']['id'] != null) {
        transferId = body['transfer']['id'].toString();
      } else if (result['action_id'] != null) {
        transferId = result['action_id'].toString();
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
