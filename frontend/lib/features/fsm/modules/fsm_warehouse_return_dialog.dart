import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../../core/constants/colors.dart';
import '../../../core/state/app_state.dart';

class FsmWarehouseReturnDialog {
  static Future<void> show({
    required BuildContext context,
    required String fsmId,
    int availableDepotStock = 0,
  }) async {
    String returnCode = '';
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
        returnQty = (data['quantity'] as num?)?.toInt() ?? returnQty;
      }
    } catch (_) {}

    if (returnCode.isEmpty) {
      returnCode = 'WR-RET-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
    }

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Warehouse Return QR', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: ClientColors.border),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4))
                ],
              ),
              child: Column(
                children: [
                  const Icon(Icons.qr_code_2, size: 160, color: ClientColors.textDark),
                  const SizedBox(height: 10),
                  Text(
                    returnCode,
                    style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 16, color: ClientColors.primary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: ClientColors.alertBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: ClientColors.alertBorder),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Return Quantity:', style: TextStyle(fontSize: 12, color: ClientColors.textMuted)),
                  Text('$returnQty Bottles', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: ClientColors.primary)),
                ],
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Show this QR code at Central Warehouse depot counter for final inventory return signoff.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: ClientColors.textMuted),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogCtx),
            style: ElevatedButton.styleFrom(backgroundColor: ClientColors.primary, foregroundColor: Colors.white),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
