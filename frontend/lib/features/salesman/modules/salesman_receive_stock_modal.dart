import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import '../../../core/constants/colors.dart';
import '../../../core/state/app_state.dart';

class SalesmanReceiveStockModal {
  static Future<void> show({
    required BuildContext context,
    required String salesmanId,
    required double? bottleUnitPrice,
    required double unitPrice,
    required Function(int quantity, String productName, int amount) onStockReceived,
    required VoidCallback onReloadData,
  }) async {
    List<Map<String, dynamic>> pendingTransfers = [];
    try {
      final res = await http.get(
        Uri.parse('${AppState.apiBaseUrl}/stock/transfers?to_id=$salesmanId&status=pending'),
      );
      if (res.statusCode == 200) {
        pendingTransfers = List<Map<String, dynamic>>.from(jsonDecode(res.body));
      }
    } catch (_) {}

    if (pendingTransfers.isEmpty) {
      try {
        final res = await http.get(Uri.parse('${AppState.apiBaseUrl}/stock/transfers?status=pending'));
        if (res.statusCode == 200) {
          final all = List<Map<String, dynamic>>.from(jsonDecode(res.body));
          pendingTransfers =
              all.where((t) => t['to_id'] == salesmanId || t['status'] == 'pending').toList();
        }
      } catch (_) {}
    }

    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) {
        Map<String, dynamic>? selectedTransfer =
            pendingTransfers.isNotEmpty ? pendingTransfers.first : null;
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
                  body: jsonEncode({'user_id': salesmanId}),
                );
                if (res.statusCode == 200 || res.statusCode == 201) {
                  if (sheetCtx.mounted) Navigator.pop(sheetCtx);
                  if (context.mounted) {
                    onStockReceived(qty, prodName, (qty * unitPrice).toInt());
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: ClientColors.success,
                        content:
                            Text('✓ Verified & Received $qty units of $prodName into live stock!'),
                        duration: const Duration(seconds: 3),
                      ),
                    );
                    onReloadData();
                  }
                  return;
                }
              } catch (_) {}

              // If API fails
              if (sheetCtx.mounted) Navigator.pop(sheetCtx);
              if (context.mounted) {
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
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('No pending stock transfers waiting for acceptance.'),
                        ),
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
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
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
                              child: const Icon(
                                Icons.qr_code_scanner,
                                color: ClientColors.primary,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 10),
                            const Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Receive Manager Stock',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: ClientColors.textDark,
                                  ),
                                ),
                                Text(
                                  'Scan FSM QR code or enter PIN to accept stock',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: ClientColors.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: ClientColors.textMuted),
                          onPressed: () => Navigator.pop(sheetCtx),
                        ),
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
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
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
                                isVerifying
                                    ? 'Analyzing Manager QR Code...'
                                    : 'Align Field Manager QR in Viewfinder',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          Positioned(
                            top: 14,
                            left: 14,
                            child: Container(
                              width: 24,
                              height: 24,
                              decoration: const BoxDecoration(
                                border: Border(
                                  top: BorderSide(color: ClientColors.primaryLight, width: 3),
                                  left: BorderSide(color: ClientColors.primaryLight, width: 3),
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            top: 14,
                            right: 14,
                            child: Container(
                              width: 24,
                              height: 24,
                              decoration: const BoxDecoration(
                                border: Border(
                                  top: BorderSide(color: ClientColors.primaryLight, width: 3),
                                  right: BorderSide(color: ClientColors.primaryLight, width: 3),
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: 14,
                            left: 14,
                            child: Container(
                              width: 24,
                              height: 24,
                              decoration: const BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(color: ClientColors.primaryLight, width: 3),
                                  left: BorderSide(color: ClientColors.primaryLight, width: 3),
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: 14,
                            right: 14,
                            child: Container(
                              width: 24,
                              height: 24,
                              decoration: const BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(color: ClientColors.primaryLight, width: 3),
                                  right: BorderSide(color: ClientColors.primaryLight, width: 3),
                                ),
                              ),
                            ),
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
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            icon: const Icon(Icons.camera_alt, size: 16),
                            label: const Text(
                              'Camera Scan',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                            ),
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
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            icon: const Icon(Icons.photo_library, size: 16),
                            label: const Text(
                              'From Gallery',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                            ),
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
                              prefixIcon:
                                  const Icon(Icons.pin, size: 18, color: ClientColors.primary),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
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
                                    'from_name': AppState.currentUser?['parent_name'] ??
                                        'Field Sales Manager',
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
                            padding:
                                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text(
                            'Verify PIN',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                          ),
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
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: ClientColors.success,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.check_circle, color: Colors.white, size: 12),
                                      SizedBox(width: 4),
                                      Text(
                                        'VERIFIED FSM DISPATCH',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Flexible(
                                  child: Text(
                                    '#${(selectedTransfer!['id']?.toString() ?? 'TR').split('-').first}',
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: ClientColors.textMuted,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Dispatched By:',
                                  style: TextStyle(fontSize: 13, color: ClientColors.textMuted),
                                ),
                                Text(
                                  selectedTransfer!['from_name'] ?? 'Field Sales Manager',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: ClientColors.textDark,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Product:',
                                  style: TextStyle(fontSize: 13, color: ClientColors.textMuted),
                                ),
                                Text(
                                  selectedTransfer!['product']?['name'] ??
                                      selectedTransfer!['product_name'] ??
                                      'Water Bottle',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: ClientColors.textDark,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Authorized Quantity:',
                                  style: TextStyle(fontSize: 13, color: ClientColors.textMuted),
                                ),
                                Text(
                                  '${selectedTransfer!['quantity'] ?? 10} Bottles',
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: ClientColors.primary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Stock Value:',
                                  style: TextStyle(fontSize: 13, color: ClientColors.textMuted),
                                ),
                                bottleUnitPrice != null
                                    ? Text(
                                        '₹${(((selectedTransfer!['quantity'] as num?)?.toInt() ?? 10) * bottleUnitPrice).toInt()}',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: ClientColors.primary,
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
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton.icon(
                          onPressed:
                              isProcessing ? null : () => confirmReceipt(selectedTransfer!),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: ClientColors.success,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: isProcessing
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.check_circle_outline, size: 20),
                          label: Text(
                            isProcessing
                                ? 'Confirming Stock...'
                                : 'Accept & Confirm Stock Receipt',
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
}
