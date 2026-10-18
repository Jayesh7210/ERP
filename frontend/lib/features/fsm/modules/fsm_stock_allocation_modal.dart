import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:qr_flutter/qr_flutter.dart';
import '../../../core/constants/colors.dart';
import '../../../core/state/app_state.dart';
import '../../../core/services/offline_sync_service.dart';

class FsmStockAllocationModal {
  static void open({
    required BuildContext context,
    required String fsmId,
    required String fsmName,
    required int availableDepotStock,
    required List<Map<String, dynamic>> supervisedSalesmen,
    required double? bottleUnitPrice,
    required VoidCallback onStockUpdated,
  }) {
    final rootMessenger = ScaffoldMessenger.of(context);
    final Map<String, int> draftAllocations = {};
    for (var s in supervisedSalesmen) {
      draftAllocations[s['id'].toString()] = 0;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final int totalSelected = draftAllocations.values.fold(0, (sum, v) => sum + v);
            final int remainingStock = availableDepotStock - totalSelected;
            final bool canConfirm = totalSelected > 0 && remainingStock >= 0;

            return Container(
              height: MediaQuery.of(context).size.height * 0.82,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  // Drag Handle
                  Container(
                    width: 42,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  const SizedBox(height: 14),
                  // Header
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Stock Allocation',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: ClientColors.textDark,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: ClientColors.textMuted),
                          onPressed: () => Navigator.pop(sheetContext),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: ClientColors.border),
                  const SizedBox(height: 12),

                  // Available Depot Stock Banner
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: ClientColors.alertBg,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: ClientColors.alertBorder),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: ClientColors.primary.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.warehouse_outlined, color: ClientColors.primary),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Available Depot Stock',
                                  style: TextStyle(fontSize: 12, color: ClientColors.textMuted, fontWeight: FontWeight.w500),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '$availableDepotStock bottles',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: ClientColors.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: ClientColors.alertBorder),
                            ),
                            child: Text(
                              'Remaining: $remainingStock',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: remainingStock < 0 ? Colors.red : ClientColors.textDark,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        const Text(
                          'Select Quantities per Salesman',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: ClientColors.textDark),
                        ),
                        const Spacer(),
                        Text(
                          '${supervisedSalesmen.length} Agents',
                          style: const TextStyle(fontSize: 12, color: ClientColors.textMuted),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Salesmen Interactive List
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                      itemCount: supervisedSalesmen.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final sm = supervisedSalesmen[index];
                        final String smId = sm['id'].toString();
                        final String smName = sm['name'] ?? 'Salesman';
                        final String zone = sm['zone'] ?? 'Zone A';
                        final String code = sm['code'] ?? 'SP-00';
                        final int curQty = draftAllocations[smId] ?? 0;
                        final int stockOnHand = (sm['current_stock'] as num?)?.toInt() ?? 0;

                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: curQty > 0 ? ClientColors.primaryLight : ClientColors.border),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.02),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              )
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 20,
                                    backgroundColor: ClientColors.primary.withValues(alpha: 0.1),
                                    child: Text(
                                      smName.isNotEmpty ? smName[0] : 'S',
                                      style: const TextStyle(color: ClientColors.primary, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          smName,
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: ClientColors.textDark),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '$zone • $code • Hand: ${stockOnHand}b',
                                          style: const TextStyle(fontSize: 11, color: ClientColors.textMuted),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Interactive Stepper
                                  Row(
                                    children: [
                                      InkWell(
                                        onTap: () {
                                          if (curQty > 0) {
                                            setSheetState(() {
                                              draftAllocations[smId] = (curQty - 10).clamp(0, 9999);
                                            });
                                          }
                                        },
                                        borderRadius: BorderRadius.circular(16),
                                        child: Container(
                                          width: 32,
                                          height: 32,
                                          decoration: BoxDecoration(
                                            color: Colors.grey.shade100,
                                            shape: BoxShape.circle,
                                            border: Border.all(color: Colors.grey.shade300),
                                          ),
                                          child: const Icon(Icons.remove, size: 16, color: ClientColors.textDark),
                                        ),
                                      ),
                                      Container(
                                        width: 52,
                                        alignment: Alignment.center,
                                        child: Text(
                                          '$curQty',
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.bold,
                                            color: curQty > 0 ? ClientColors.primary : ClientColors.textDark,
                                          ),
                                        ),
                                      ),
                                      InkWell(
                                        onTap: () {
                                          if (remainingStock >= 10) {
                                            setSheetState(() {
                                              draftAllocations[smId] = curQty + 10;
                                            });
                                          } else {
                                            rootMessenger.showSnackBar(
                                              const SnackBar(
                                                content: Text('Cannot allocate more than available depot stock!'),
                                                duration: Duration(seconds: 1),
                                              ),
                                            );
                                          }
                                        },
                                        borderRadius: BorderRadius.circular(16),
                                        child: Container(
                                          width: 32,
                                          height: 32,
                                          decoration: const BoxDecoration(
                                            color: ClientColors.primary,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(Icons.add, size: 16, color: Colors.white),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              if (curQty > 0) ...[
                                const SizedBox(height: 8),
                                const Divider(height: 1, color: ClientColors.border),
                                const SizedBox(height: 8),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: OutlinedButton.icon(
                                    onPressed: () {
                                      Navigator.pop(sheetContext);
                                      _initiateSalesmanTransfer(
                                        context: context,
                                        fsmId: fsmId,
                                        fsmName: fsmName,
                                        bottleUnitPrice: bottleUnitPrice,
                                        salesmanId: smId,
                                        salesmanName: smName,
                                        quantity: curQty,
                                        onStockUpdated: onStockUpdated,
                                      );
                                    },
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: ClientColors.primary,
                                      side: const BorderSide(color: ClientColors.primary),
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                    icon: const Icon(Icons.qr_code, size: 14),
                                    label: Text('Generate Handoff QR ($curQty btls)', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
                  ),

                  // Bottom Summary & Confirm Button
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: const Border(top: BorderSide(color: ClientColors.border)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 8,
                          offset: const Offset(0, -3),
                        )
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Total Selected:', style: TextStyle(fontSize: 14, color: ClientColors.textMuted)),
                            Text(
                              '$totalSelected bottles',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: ClientColors.primary),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton.icon(
                            onPressed: canConfirm
                                ? () async {
                                    Navigator.pop(sheetContext);
                                    final allocatedEntries = draftAllocations.entries.where((e) => e.value > 0).toList();
                                    if (allocatedEntries.isNotEmpty) {
                                      final first = allocatedEntries.first;
                                      final sm = supervisedSalesmen.firstWhere(
                                        (s) => s['id'].toString() == first.key,
                                        orElse: () => {'name': 'Salesman'},
                                      );
                                      await _initiateSalesmanTransfer(
                                        context: context,
                                        fsmId: fsmId,
                                        fsmName: fsmName,
                                        bottleUnitPrice: bottleUnitPrice,
                                        salesmanId: first.key,
                                        salesmanName: sm['name'] ?? 'Salesman',
                                        quantity: first.value,
                                        onStockUpdated: onStockUpdated,
                                      );
                                    }
                                  }
                                : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: ClientColors.primary,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: Colors.grey.shade300,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            icon: const Icon(Icons.qr_code_2, size: 20),
                            label: Text(
                              'Authorize & Generate Handoff QR ($totalSelected btls)',
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  static Future<void> _initiateSalesmanTransfer({
    required BuildContext context,
    required String fsmId,
    required String fsmName,
    required double? bottleUnitPrice,
    required String salesmanId,
    required String salesmanName,
    required int quantity,
    required VoidCallback onStockUpdated,
  }) async {
    const productId = '6602541b-1e4d-4162-bc86-e44f05cda0b3';
    const productName = 'Water Bottle';
    String transferId = 'tr_${DateTime.now().millisecondsSinceEpoch}';

    try {
      final result = await OfflineSyncService.executeWithOfflineFallback(
        apiBaseUrl: AppState.apiBaseUrl,
        endpoint: '/stock/transfer',
        method: 'POST',
        role: 'field_sales_manager',
        type: 'stock_transfer',
        title: 'Transfer to $salesmanName ($quantity units)',
        userId: fsmId,
        payload: {
          'from_id': fsmId,
          'to_id': salesmanId,
          'product_id': productId,
          'quantity': quantity,
          'status': 'pending',
        },
      );

      if (result['success'] == true) {
        final body = result['data'];
        if (body != null && body['transfer'] != null && body['transfer']['id'] != null) {
          transferId = body['transfer']['id'].toString();
        } else if (result['action_id'] != null) {
          transferId = result['action_id'].toString();
        }
      }
    } catch (_) {}

    final securityPin = (transferId.hashCode.abs() % 900000 + 100000).toString();
    final qrPayload = jsonEncode({
      'type': 'FSM_TO_SALESMAN_TRANSFER',
      'transfer_id': transferId,
      'from_fsm_id': fsmId,
      'from_fsm_name': fsmName,
      'to_salesman_id': salesmanId,
      'salesman_name': salesmanName,
      'product_id': productId,
      'product_name': productName,
      'quantity': quantity,
      'security_pin': securityPin,
      'created_at': DateTime.now().toIso8601String(),
    });

    if (!context.mounted) return;
    showSalesmanHandoffQrModal(
      context: context,
      fsmId: fsmId,
      transferId: transferId,
      salesmanId: salesmanId,
      salesmanName: salesmanName,
      productName: productName,
      quantity: quantity,
      securityPin: securityPin,
      qrPayload: qrPayload,
      bottleUnitPrice: bottleUnitPrice,
      onStockUpdated: onStockUpdated,
    );
  }

  static void showSalesmanHandoffQrModal({
    required BuildContext context,
    required String fsmId,
    required String transferId,
    required String salesmanId,
    required String salesmanName,
    required String productName,
    required int quantity,
    required String securityPin,
    required String qrPayload,
    required double? bottleUnitPrice,
    required VoidCallback onStockUpdated,
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
                  Uri.parse('${AppState.apiBaseUrl}/stock/transfers?from_id=$fsmId'),
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
                    onStockUpdated();
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
                                  color: isTransferAccepted
                                      ? ClientColors.success.withValues(alpha: 0.15)
                                      : ClientColors.primary.withValues(alpha: 0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  isTransferAccepted ? Icons.check_circle : Icons.qr_code_2,
                                  color: isTransferAccepted ? ClientColors.success : ClientColors.primary,
                                  size: 26,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    isTransferAccepted ? 'Stock Transfer Verified' : 'Salesman Stock Handoff',
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: ClientColors.textDark),
                                  ),
                                  Text(
                                    isTransferAccepted ? 'Stock handed over to agent' : 'Show QR to Salesman to scan',
                                    style: const TextStyle(fontSize: 11, color: ClientColors.textMuted),
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
                              onStockUpdated();
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Salesman Info Card
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: ClientColors.alertBg,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: ClientColors.alertBorder),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: ClientColors.primary.withValues(alpha: 0.2),
                              child: Text(
                                salesmanName.isNotEmpty ? salesmanName[0] : 'S',
                                style: const TextStyle(color: ClientColors.primary, fontWeight: FontWeight.bold),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    salesmanName,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: ClientColors.textDark),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Field Salesman • $productName',
                                    style: const TextStyle(fontSize: 11, color: ClientColors.textMuted),
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '$quantity btls',
                                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: ClientColors.primary),
                                ),
                                bottleUnitPrice != null
                                    ? Text(
                                        '₹${(quantity * bottleUnitPrice).toInt()}',
                                        style: const TextStyle(fontSize: 11, color: ClientColors.textMuted, fontWeight: FontWeight.w600),
                                      )
                                    : const SizedBox(
                                        width: 12,
                                        height: 12,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: ClientColors.primary),
                                      ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),

                      if (isTransferAccepted) ...[
                        // Accepted State
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0FDF4),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFF86EFAC), width: 1.5),
                          ),
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: const BoxDecoration(
                                  color: ClientColors.success,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.check, color: Colors.white, size: 40),
                              ),
                              const SizedBox(height: 14),
                              const Text(
                                'HANDOFF VERIFIED & COMPLETED!',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF166534)),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '$quantity bottles of $productName successfully accepted by $salesmanName into field inventory.',
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 12, color: Color(0xFF15803D)),
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
                              onStockUpdated();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: ClientColors.success,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text('Done / Close', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
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
                            eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: ClientColors.textDark),
                            dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: ClientColors.primary),
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
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: ClientColors.textMuted, letterSpacing: 1.1),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                securityPin.split('').join('  '),
                                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 3, color: ClientColors.textDark, fontFamily: 'monospace'),
                              ),
                              const SizedBox(height: 2),
                              const Text(
                                'Salesman can manually enter this 6-digit PIN in scanner',
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
                                const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFB45309)))
                              else
                                Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFFD97706), shape: BoxShape.circle)),
                              const SizedBox(width: 8),
                              const Text(
                                'WAITING FOR SALESMAN TO SCAN & CONFIRM',
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF92400E)),
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
}
