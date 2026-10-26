import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:qr_flutter/qr_flutter.dart';
import '../../../core/constants/colors.dart';
import '../../../core/state/app_state.dart';

class FsmWarehouseReturnDialog {
  static Future<void> show({
    required BuildContext context,
    required String fsmId,
    int availableDepotStock = 0,
    VoidCallback? onSettled,
  }) async {
    String returnCode = '';
    String securityPin = '';
    String qrPayload = '';
    int returnQty = availableDepotStock > 0 ? availableDepotStock : 0;

    try {
      final res = await http.post(
        Uri.parse('${AppState.apiBaseUrl}/fsm/warehouse-return-qr'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'fsm_id': fsmId, 'quantity': returnQty}),
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        returnCode = (data['return_code'] ?? data['qr_token'] ?? '').toString();
        securityPin = (data['security_pin'] ?? '').toString();
        qrPayload = (data['qr_payload'] ?? returnCode).toString();
        returnQty = (data['quantity'] as num?)?.toInt() ?? returnQty;
      }
    } catch (_) {}

    if (returnCode.isEmpty) {
      returnCode = 'WR-RET-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
      securityPin = (returnCode.hashCode.abs() % 900000 + 100000).toString();
      qrPayload = jsonEncode({
        'type': 'FSM_WAREHOUSE_RETURN',
        'return_code': returnCode,
        'security_pin': securityPin,
        'fsm_id': fsmId,
        'quantity': returnQty,
      });
    }

    if (!context.mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        bool isSettled = false;
        Timer? pollTimer;

        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            void startPolling() {
              pollTimer ??= Timer.periodic(const Duration(seconds: 3), (_) async {
                if (isSettled) return;
                try {
                  final res = await http.get(Uri.parse('${AppState.apiBaseUrl}/fsm/settlement/$fsmId'));
                  if (res.statusCode == 200) {
                    final data = jsonDecode(res.body);
                    final wh = data['warehouse'] as Map<String, dynamic>?;
                    if (wh != null && wh['status'] == 'settled') {
                      pollTimer?.cancel();
                      setDialogState(() => isSettled = true);
                      if (onSettled != null) onSettled();
                    }
                  }
                } catch (_) {}
              });
            }

            startPolling();

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
                                child: const Icon(Icons.warehouse, color: AppColors.primary, size: 20),
                              ),
                              const SizedBox(width: 10),
                              const Text(
                                'Warehouse Return QR',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: ClientColors.textDark),
                              ),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.grey),
                            onPressed: () {
                              pollTimer?.cancel();
                              Navigator.pop(dialogCtx);
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // QR Box
                      Center(
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: ClientColors.border, width: 1.5),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 14,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: QrImageView(
                            data: qrPayload,
                            version: QrVersions.auto,
                            size: 190,
                            eyeStyle: const QrEyeStyle(
                              eyeShape: QrEyeShape.square,
                              color: Color(0xFF1B365D),
                            ),
                            dataModuleStyle: const QrDataModuleStyle(
                              dataModuleShape: QrDataModuleShape.square,
                              color: Color(0xFF1B365D),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Return Code & PIN Display
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Return Code:', style: TextStyle(fontSize: 12, color: ClientColors.textMuted)),
                                Text(
                                  returnCode,
                                  style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.primary),
                                ),
                              ],
                            ),
                            if (securityPin.isNotEmpty) ...[
                              const Divider(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Security PIN:', style: TextStyle(fontSize: 12, color: ClientColors.textMuted)),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: Colors.amber.shade100,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      securityPin,
                                      style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 14, color: Colors.amber.shade900),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            const Divider(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Unsold Return Stock:', style: TextStyle(fontSize: 12, color: ClientColors.textMuted)),
                                Text(
                                  '$returnQty Bottles',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.teal),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Status Badge
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                        decoration: BoxDecoration(
                          color: isSettled ? Colors.green.shade50 : Colors.amber.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: isSettled ? Colors.green.shade300 : Colors.amber.shade300),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              isSettled ? Icons.check_circle : Icons.sync,
                              size: 16,
                              color: isSettled ? Colors.green.shade800 : Colors.amber.shade800,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              isSettled ? '✓ Return Accepted & Settled by Store Admin!' : 'Awaiting Store Admin Counter Scan...',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: isSettled ? Colors.green.shade900 : Colors.amber.shade900,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      ElevatedButton(
                        onPressed: () {
                          pollTimer?.cancel();
                          Navigator.pop(dialogCtx);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Close Window', style: TextStyle(fontWeight: FontWeight.bold)),
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

