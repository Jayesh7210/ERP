import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:qr_flutter/qr_flutter.dart';
import '../../../core/constants/colors.dart';
import '../../../core/state/app_state.dart';

class SalesmanSettlementQrModal {
  static void show({
    required BuildContext context,
    required String settlementId,
    required String fsmName,
    required int heldStock,
    required int sold,
    required int remaining,
    required int damaged,
    required String damageNotes,
    required Uint8List? damageBytes,
    required int cash,
    required int online,
    required int soldAmt,
    required String securityPin,
    required String qrPayload,
    required VoidCallback onSettled,
    required VoidCallback onClose,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        bool isSettled = false;
        bool isChecking = false;
        Timer? pollTimer;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> checkStatus() async {
              if (isSettled || isChecking) return;
              setDialogState(() => isChecking = true);
              try {
                final res = await http.get(
                  Uri.parse('${AppState.apiBaseUrl}/settlement/$settlementId'),
                );
                if (res.statusCode == 200) {
                  final data = jsonDecode(res.body);
                  if (data['status'] == 'settled' || data['status'] == 'completed') {
                    pollTimer?.cancel();
                    setDialogState(() {
                      isSettled = true;
                      isChecking = false;
                    });
                    onSettled();
                    return;
                  }
                }
              } catch (_) {}
              setDialogState(() => isChecking = false);
            }

            pollTimer ??= Timer.periodic(const Duration(seconds: 3), (_) {
              checkStatus();
            });

            return Dialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: isSettled
                                      ? ClientColors.success.withValues(alpha: 0.15)
                                      : ClientColors.primary.withValues(alpha: 0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  isSettled ? Icons.check_circle : Icons.qr_code_2,
                                  color: isSettled ? ClientColors.success : ClientColors.primary,
                                  size: 26,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    isSettled ? 'Settlement Approved' : 'Daily Settlement QR',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: ClientColors.textDark,
                                    ),
                                  ),
                                  Text(
                                    isSettled
                                        ? 'Reconciliation finalized'
                                        : 'Present QR to Field Manager',
                                    style: const TextStyle(
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
                            onPressed: () {
                              pollTimer?.cancel();
                              Navigator.pop(dialogCtx);
                              onClose();
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Settlement Summary Card
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: ClientColors.alertBg,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: ClientColors.alertBorder),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'SUPERVISOR',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: ClientColors.textMuted,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      fsmName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                        color: ClientColors.textDark,
                                      ),
                                    ),
                                  ],
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    const Text(
                                      'TOTAL VALUE',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: ClientColors.textMuted,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '₹$soldAmt',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        color: ClientColors.primary,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            const Divider(height: 1, color: ClientColors.border),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _qrMetric('Sold', '$sold btls', Colors.green.shade700),
                                _qrMetric('Return', '$remaining btls', ClientColors.primary),
                                if (damaged > 0)
                                  _qrMetric('Damaged', '$damaged btls', Colors.red.shade700),
                                _qrMetric('Cash', '₹$cash', Colors.black87),
                                _qrMetric('Online', '₹$online', Colors.blue.shade700),
                              ],
                            ),
                            if (damaged > 0 && damageBytes != null) ...[
                              const SizedBox(height: 10),
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.red.shade200),
                                ),
                                child: Row(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(6),
                                      child: Image.memory(
                                        damageBytes,
                                        width: 44,
                                        height: 44,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Damage Photo: $damaged btls',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.red.shade900,
                                            ),
                                          ),
                                          Text(
                                            damageNotes.isNotEmpty
                                                ? damageNotes
                                                : 'Damaged / leaking',
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: Colors.red.shade700,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),

                      if (isSettled) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0FDF4),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFF86EFAC), width: 2),
                          ),
                          child: Column(
                            children: [
                              Container(
                                width: 72,
                                height: 72,
                                decoration: BoxDecoration(
                                  color: ClientColors.success,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: ClientColors.success.withValues(alpha: 0.35),
                                      blurRadius: 18,
                                      offset: const Offset(0, 6),
                                    ),
                                  ],
                                ),
                                child: const Icon(Icons.check, color: Colors.white, size: 44),
                              ),
                              const SizedBox(height: 14),
                              const Text(
                                'SETTLEMENT APPROVED & RECONCILED!',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF166534),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '$sold bottles sold (₹$soldAmt) settled.\n$remaining unsold bottles returned to $fsmName.',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF15803D),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            onPressed: () {
                              pollTimer?.cancel();
                              Navigator.pop(dialogCtx);
                              onClose();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: ClientColors.success,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              'Done / Close',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ] else ...[
                        // Dynamic QR Code Container
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: ClientColors.border, width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.06),
                                blurRadius: 16,
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
                              color: ClientColors.textDark,
                            ),
                            dataModuleStyle: const QrDataModuleStyle(
                              dataModuleShape: QrDataModuleShape.square,
                              color: ClientColors.primary,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Security PIN Manual Card
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Column(
                            children: [
                              const Text(
                                'MANUAL VERIFICATION PIN',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: ClientColors.textMuted,
                                  letterSpacing: 1.1,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                securityPin.split('').join('  '),
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 3,
                                  color: ClientColors.textDark,
                                  fontFamily: 'monospace',
                                ),
                              ),
                              const SizedBox(height: 2),
                              const Text(
                                'Manager can manually enter this 6-digit PIN in scanner',
                                style: TextStyle(fontSize: 10, color: ClientColors.textMuted),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Live status indicator
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFFFCD34D)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (isChecking)
                                const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Color(0xFFB45309),
                                  ),
                                )
                              else
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFD97706),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              const SizedBox(width: 8),
                              const Text(
                                'WAITING FOR FSM TO SCAN & ACCEPT',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF92400E),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
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

  static Widget _qrMetric(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            color: ClientColors.textMuted,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}
