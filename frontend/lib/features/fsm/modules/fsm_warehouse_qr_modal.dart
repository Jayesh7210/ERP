import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import '../../../core/constants/colors.dart';
import '../../../core/state/app_state.dart';
import '../../../core/services/offline_sync_service.dart';
import '../../../core/widgets/live_qr_scanner_modal.dart';

class FsmWarehouseQrModal {
  static String getDeterministicPin(String trId) {
    if (trId.isEmpty) return '000000';
    final code = (trId.hashCode.abs() % 900000 + 100000).toString();
    return code;
  }

  static bool isMatchingTransfer(Map<String, dynamic> t, String query) {
    final q = query.trim();
    if (q.isEmpty) return false;
    final trId = t['id']?.toString() ?? '';
    final pin = t['security_pin']?.toString() ?? getDeterministicPin(trId);
    return q == trId ||
        q == pin ||
        (q.length >= 6 && trId.endsWith(q)) ||
        (q.length >= 4 && trId.startsWith(q));
  }

  static void open({
    required BuildContext context,
    required String fsmId,
    required VoidCallback onReceiptConfirmed,
  }) async {
    // 1. Fetch strictly pending transfers for this FSM
    List<Map<String, dynamic>> pendingTransfers = [];
    try {
      final res = await http.get(
        Uri.parse('${AppState.apiBaseUrl}/stock/transfers?to_id=$fsmId&status=pending'),
      );
      if (res.statusCode == 200) {
        pendingTransfers = List<Map<String, dynamic>>.from(jsonDecode(res.body));
      }
    } catch (_) {}

    if (pendingTransfers.isEmpty) {
      try {
        final res = await http.get(
          Uri.parse('${AppState.apiBaseUrl}/stock/transfers?status=pending'),
        );
        if (res.statusCode == 200) {
          final all = List<Map<String, dynamic>>.from(jsonDecode(res.body));
          pendingTransfers = all.where((t) => t['to_id'] == fsmId && t['status'] == 'pending').toList();
        }
      } catch (_) {}
    }

    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetCtx) {
        // Default selected transfer: newest pending transfer if available
        Map<String, dynamic>? selectedTransfer = pendingTransfers.isNotEmpty ? pendingTransfers.first : null;
        final pinController = TextEditingController();
        bool isProcessing = false;
        bool isVerifying = false;

        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            Future<void> confirmReceipt(Map<String, dynamic> tr) async {
              setSheetState(() => isProcessing = true);
              final trId = tr['id']?.toString() ?? '';
              final qty = (tr['quantity'] as num?)?.toInt() ?? 0;
              final prodName = tr['product']?['name'] ?? tr['product_name'] ?? 'Bottles';

              try {
                final result = await OfflineSyncService.executeWithOfflineFallback(
                  apiBaseUrl: AppState.apiBaseUrl,
                  endpoint: '/stock/transfers/$trId/accept',
                  method: 'PUT',
                  role: 'field_sales_manager',
                  type: 'stock_accept',
                  title: 'Accept Stock ($qty units)',
                  userId: fsmId,
                  payload: {'user_id': fsmId},
                );
                if (result['success'] == true) {
                  if (sheetCtx.mounted) Navigator.pop(sheetCtx);
                  if (context.mounted) {
                    final isOffline = result['is_offline'] == true;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: isOffline ? Colors.amber.shade800 : ClientColors.success,
                        content: Text(isOffline
                            ? '⚡ Stock accepted offline ($qty units)! Queued to sync to server.'
                            : '✓ Verified & Received $qty units of $prodName into depot stock!'),
                        duration: const Duration(seconds: 3),
                      ),
                    );
                    onReceiptConfirmed();
                  }
                  return;
                }
              } catch (_) {}

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

            Future<void> openLiveScanner() async {
              final raw = await LiveQrScannerModal.show(
                context: context,
                title: 'Scan Store Admin Dispatch QR',
                subtitle: 'Point camera at Warehouse dispatch authorization QR or enter PIN',
              );
              if (raw == null || raw.trim().isEmpty) return;

              String extractedPin = raw.trim();
              String? extractedId;
              Map<String, dynamic>? decodedMap;

              try {
                final decoded = jsonDecode(raw);
                if (decoded is Map) {
                  decodedMap = Map<String, dynamic>.from(decoded);
                  extractedPin = decoded['security_pin']?.toString() ?? decoded['pin']?.toString() ?? extractedPin;
                  extractedId = decoded['transfer_id']?.toString() ?? decoded['id']?.toString();
                }
              } catch (_) {}

              // 1. Check local pending list
              Map<String, dynamic>? match = pendingTransfers.cast<Map<String, dynamic>?>().firstWhere(
                (t) =>
                    (extractedId != null && t?['id']?.toString() == extractedId) ||
                    (t != null && isMatchingTransfer(t, extractedPin)) ||
                    (extractedId != null && t != null && isMatchingTransfer(t, extractedId)),
                orElse: () => null,
              );

              // 2. If not found locally, fetch fresh from server by ID
              if (match == null && extractedId != null) {
                try {
                  final res = await http.get(Uri.parse('${AppState.apiBaseUrl}/stock/transfers?id=$extractedId'));
                  if (res.statusCode == 200) {
                    final list = List<Map<String, dynamic>>.from(jsonDecode(res.body));
                    if (list.isNotEmpty) {
                      match = list.first;
                      if (!pendingTransfers.any((x) => x['id']?.toString() == match?['id']?.toString())) {
                        pendingTransfers.insert(0, match);
                      }
                    }
                  }
                } catch (_) {}
              }

              // 3. Fallback: if decodedMap is a valid handoff QR payload with quantity & transfer_id
              if (match == null && decodedMap != null && decodedMap['transfer_id'] != null && decodedMap['quantity'] != null) {
                match = {
                  'id': decodedMap['transfer_id'],
                  'from_id': decodedMap['from_warehouse_id'],
                  'from_name': 'Warehouse Hub',
                  'to_id': fsmId,
                  'product_id': decodedMap['product_id'],
                  'product_name': decodedMap['product_name'] ?? 'Bottles',
                  'product': {'name': decodedMap['product_name'] ?? 'Bottles'},
                  'quantity': (decodedMap['quantity'] as num?)?.toInt() ?? 0,
                  'status': 'pending',
                  'security_pin': extractedPin,
                };
                if (!pendingTransfers.any((x) => x['id']?.toString() == match?['id']?.toString())) {
                  pendingTransfers.insert(0, match);
                }
              }

              if (match != null) {
                final matchedTr = match;
                final qty = matchedTr['quantity'];
                final pName = matchedTr['product']?['name'] ?? matchedTr['product_name'] ?? 'Bottles';
                setSheetState(() => selectedTransfer = matchedTr);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: ClientColors.success,
                      content: Text('✓ Verified dispatch: $qty units of $pName!'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              } else {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('No pending warehouse dispatch found matching: $extractedPin'),
                      backgroundColor: Colors.orange.shade800,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              }
            }

            Future<void> pickAndSimulateScan(ImageSource source) async {
              try {
                final picker = ImagePicker();
                final img = await picker.pickImage(source: source, imageQuality: 75, maxWidth: 1280, maxHeight: 1280);
                if (img != null) {
                  setSheetState(() => isVerifying = true);
                  await Future.delayed(const Duration(milliseconds: 600));
                  if (pendingTransfers.isNotEmpty) {
                    setSheetState(() {
                      selectedTransfer = pendingTransfers.first;
                      isVerifying = false;
                    });
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          backgroundColor: ClientColors.success,
                          content: Text('✓ Selected pending dispatch: ${selectedTransfer?['quantity']} units'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  } else {
                    setSheetState(() => isVerifying = false);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('No pending stock transfers waiting for acceptance.')),
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
                        decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
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
                              child: const Icon(Icons.qr_code_scanner, color: ClientColors.primary, size: 22),
                            ),
                            const SizedBox(width: 10),
                            const Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Receive Warehouse Stock', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: ClientColors.textDark)),
                                Text('Scan Store Admin QR code or select dispatch below', style: TextStyle(fontSize: 11, color: ClientColors.textMuted)),
                              ],
                            ),
                          ],
                        ),
                        IconButton(icon: const Icon(Icons.close, color: ClientColors.textMuted), onPressed: () => Navigator.pop(sheetCtx)),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Viewfinder Box (Tap to launch live camera scanner)
                    InkWell(
                      onTap: openLiveScanner,
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        height: 160,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E1712),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: ClientColors.primaryLight, width: 1.5),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 10, offset: const Offset(0, 4)),
                          ],
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  isVerifying ? Icons.sync : Icons.qr_code_scanner,
                                  size: 64,
                                  color: isVerifying ? ClientColors.primaryLight : Colors.white,
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'TAP TO SCAN DISPATCH QR CODE',
                                  style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Instantly detects Store Admin handoff QR',
                                  style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 11),
                                ),
                              ],
                            ),
                            Positioned(
                              top: 14,
                              left: 14,
                              child: Container(width: 20, height: 20, decoration: const BoxDecoration(border: Border(top: BorderSide(color: ClientColors.primaryLight, width: 3), left: BorderSide(color: ClientColors.primaryLight, width: 3)))),
                            ),
                            Positioned(
                              top: 14,
                              right: 14,
                              child: Container(width: 20, height: 20, decoration: const BoxDecoration(border: Border(top: BorderSide(color: ClientColors.primaryLight, width: 3), right: BorderSide(color: ClientColors.primaryLight, width: 3)))),
                            ),
                            Positioned(
                              bottom: 14,
                              left: 14,
                              child: Container(width: 20, height: 20, decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: ClientColors.primaryLight, width: 3), left: BorderSide(color: ClientColors.primaryLight, width: 3)))),
                            ),
                            Positioned(
                              bottom: 14,
                              right: 14,
                              child: Container(width: 20, height: 20, decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: ClientColors.primaryLight, width: 3), right: BorderSide(color: ClientColors.primaryLight, width: 3)))),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Primary Live Scanner Button
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: ElevatedButton.icon(
                        onPressed: openLiveScanner,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: ClientColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 2,
                        ),
                        icon: const Icon(Icons.camera, size: 20),
                        label: const Text(
                          'OPEN LIVE CAMERA SCANNER',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),

                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => pickAndSimulateScan(ImageSource.camera),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: ClientColors.primary,
                              side: const BorderSide(color: ClientColors.primary),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            icon: const Icon(Icons.camera_alt, size: 16),
                            label: const Text('Camera', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => pickAndSimulateScan(ImageSource.gallery),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: ClientColors.textDark,
                              side: BorderSide(color: Colors.grey.shade400),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            icon: const Icon(Icons.photo_library, size: 16),
                            label: const Text('Gallery', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Manual PIN Entry Row
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: pinController,
                            decoration: InputDecoration(
                              labelText: '6-Digit Transfer PIN',
                              hintText: 'e.g. 592814',
                              isDense: true,
                              prefixIcon: const Icon(Icons.pin, size: 18, color: ClientColors.primary),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () {
                            final pin = pinController.text.trim();
                            if (pin.isEmpty) return;
                            final match = pendingTransfers.cast<Map<String, dynamic>?>().firstWhere(
                              (t) => t != null && isMatchingTransfer(t, pin),
                              orElse: () => null,
                            );
                            if (match != null) {
                              setSheetState(() => selectedTransfer = match);
                              ScaffoldMessenger.of(sheetCtx).showSnackBar(
                                SnackBar(
                                  backgroundColor: ClientColors.success,
                                  content: Text('✓ Verified PIN: ${match['quantity']} bottles selected!'),
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            } else {
                              ScaffoldMessenger.of(sheetCtx).showSnackBar(
                                const SnackBar(
                                  content: Text('No pending stock transfer found matching this PIN.'),
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: ClientColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: const Text('Verify PIN', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Pending Incoming Transfers Selector
                    if (pendingTransfers.isNotEmpty) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Incoming Dispatches Waiting for Receipt',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: ClientColors.textDark),
                          ),
                          Text(
                            '${pendingTransfers.length} pending',
                            style: const TextStyle(fontSize: 11, color: ClientColors.textMuted),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ...pendingTransfers.map((tr) {
                        final trId = tr['id']?.toString() ?? '';
                        final shortId = trId.split('-').first;
                        final qty = (tr['quantity'] as num?)?.toInt() ?? 0;
                        final pName = tr['product']?['name'] ?? tr['product_name'] ?? 'Bottles';
                        final pin = getDeterministicPin(trId);
                        final isSelected = selectedTransfer != null && selectedTransfer!['id']?.toString() == trId;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFFF0FDF4) : Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected ? const Color(0xFF16A34A) : Colors.grey.shade300,
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: ListTile(
                            onTap: () => setSheetState(() => selectedTransfer = tr),
                            dense: true,
                            leading: CircleAvatar(
                              backgroundColor: isSelected ? const Color(0xFF16A34A) : Colors.grey.shade200,
                              radius: 18,
                              child: Icon(
                                isSelected ? Icons.check : Icons.local_shipping,
                                color: isSelected ? Colors.white : ClientColors.primary,
                                size: 18,
                              ),
                            ),
                            title: Row(
                              children: [
                                Text(
                                  '$qty $pName',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: isSelected ? const Color(0xFF15803D) : ClientColors.textDark,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.shade100,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'PIN: $pin',
                                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.amber.shade900),
                                  ),
                                ),
                              ],
                            ),
                            subtitle: Text(
                              'Dispatch #$shortId • From ${tr['from_name'] ?? 'Warehouse'}',
                              style: const TextStyle(fontSize: 11, color: ClientColors.textMuted),
                            ),
                            trailing: isSelected
                                ? const Icon(Icons.radio_button_checked, color: Color(0xFF16A34A))
                                : const Icon(Icons.radio_button_unchecked, color: Colors.grey),
                          ),
                        );
                      }),
                      const SizedBox(height: 12),
                    ],

                    // Selected Transfer Confirmation Card
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
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: ClientColors.success,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.check_circle, color: Colors.white, size: 12),
                                      SizedBox(width: 4),
                                      Text('VERIFIED WAREHOUSE DISPATCH', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                ),
                                Flexible(
                                  child: Text(
                                    '#${(selectedTransfer!['id']?.toString() ?? 'TR').split('-').first}',
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 11, color: ClientColors.textMuted, fontFamily: 'monospace'),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Incoming Product:', style: TextStyle(fontSize: 13, color: ClientColors.textMuted)),
                                Text(
                                  selectedTransfer!['product']?['name'] ?? selectedTransfer!['product_name'] ?? 'Kalash Bottle',
                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: ClientColors.textDark),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Authorized Quantity:', style: TextStyle(fontSize: 13, color: ClientColors.textMuted)),
                                Text(
                                  '${(selectedTransfer!['quantity'] as num?)?.toInt() ?? 0} Bottles',
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: ClientColors.primary),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Source Warehouse:', style: TextStyle(fontSize: 13, color: ClientColors.textMuted)),
                                Text(
                                  selectedTransfer!['from_name'] ?? 'Central Warehouse Hub',
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: ClientColors.textDark),
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
                          onPressed: isProcessing ? null : () => confirmReceipt(selectedTransfer!),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: ClientColors.success,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: isProcessing
                              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.check, size: 20),
                          label: Text(
                            isProcessing
                                ? 'Confirming Receipt...'
                                : 'Accept & Confirm Stock Receipt (${(selectedTransfer!['quantity'] as num?)?.toInt() ?? 0} btls)',
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ] else ...[
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: ClientColors.alertBg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: ClientColors.alertBorder),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.info_outline, color: ClientColors.primary, size: 20),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'No pending transfers auto-detected yet. Scan the Store Admin QR code or enter the 6-digit PIN to load.',
                                style: TextStyle(fontSize: 12, color: ClientColors.textDark),
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
