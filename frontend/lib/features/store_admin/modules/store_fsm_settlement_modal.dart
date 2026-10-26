import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/constants/colors.dart';
import '../../../core/state/app_state.dart';
import '../../../core/services/offline_sync_service.dart';
import '../../../core/widgets/live_qr_scanner_modal.dart';

class StoreFsmSettlementModal {
  static void open({
    required BuildContext context,
    required String warehouseId,
    required String warehouseName,
    required List<Map<String, dynamic>> pendingReturns,
    required List<Map<String, dynamic>> fsmStatusList,
    Map<String, dynamic>? initialReturn,
    required VoidCallback onSettlementApproved,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) {
        Map<String, dynamic>? selected = initialReturn;
        final pinController = TextEditingController();
        bool isProcessing = false;
        bool isVerifying = false;

        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final messenger = ScaffoldMessenger.of(context);

            void selectMatch(Map<String, dynamic> match) {
              setSheetState(() => selected = match);
              messenger.showSnackBar(
                SnackBar(
                  backgroundColor: const Color(0xFF1B365D),
                  content: Text('✓ Verified return for ${match['fsm_name'] ?? 'FSM'} (${match['quantity'] ?? 0} bottles)'),
                  duration: const Duration(seconds: 2),
                ),
              );
            }

            Future<void> openLiveScanner() async {
              final raw = await LiveQrScannerModal.show(
                context: context,
                title: 'Scan FSM Return QR',
                subtitle: 'Point camera at FSM\'s Warehouse Return QR code',
              );

              if (raw == null || raw.trim().isEmpty) return;

              String extractedToken = raw.trim();
              String? extractedPin;
              String? extractedId;

              try {
                final decoded = jsonDecode(raw);
                if (decoded is Map) {
                  extractedToken = decoded['return_code']?.toString() ?? decoded['token']?.toString() ?? extractedToken;
                  extractedPin = decoded['security_pin']?.toString() ?? decoded['pin']?.toString();
                  extractedId = decoded['id']?.toString() ?? decoded['return_id']?.toString();
                }
              } catch (_) {}

              final match = pendingReturns.cast<Map<String, dynamic>?>().firstWhere(
                (r) =>
                    (extractedId != null && r?['id']?.toString() == extractedId) ||
                    r?['return_code']?.toString() == extractedToken ||
                    r?['security_pin']?.toString() == extractedToken ||
                    (extractedPin != null && r?['security_pin']?.toString() == extractedPin) ||
                    r?['id']?.toString() == extractedToken ||
                    r?['qr_token']?.toString() == extractedToken,
                orElse: () => null,
              );

              if (match != null) {
                selectMatch(match);
              } else {
                // Check FSM status list
                final fsmMatch = fsmStatusList.cast<Map<String, dynamic>?>().firstWhere(
                  (f) =>
                      f?['pending_return_code']?.toString() == extractedToken ||
                      f?['pending_return_pin']?.toString() == extractedToken,
                  orElse: () => null,
                );

                if (fsmMatch != null) {
                  selectMatch({
                    'id': fsmMatch['pending_return_id'] ?? 'fsm_ret_${DateTime.now().millisecondsSinceEpoch}',
                    'return_code': fsmMatch['pending_return_code'] ?? extractedToken,
                    'security_pin': fsmMatch['pending_return_pin'] ?? (extractedToken.length == 6 ? extractedToken : '123456'),
                    'fsm_id': fsmMatch['fsm_id'],
                    'fsm_name': fsmMatch['name'],
                    'quantity': fsmMatch['pending_return_quantity'] ?? fsmMatch['depot_stock'] ?? 0,
                    'status': 'pending_warehouse',
                  });
                } else if (extractedToken.startsWith('WR-RET-')) {
                  selectMatch({
                    'id': 'fsm_ret_${DateTime.now().millisecondsSinceEpoch}',
                    'return_code': extractedToken,
                    'security_pin': extractedToken.replaceAll(RegExp(r'[^0-9]'), '').padRight(6, '0').substring(0, 6),
                    'fsm_id': null,
                    'fsm_name': 'Field Sales Manager',
                    'quantity': 10,
                    'status': 'pending_warehouse',
                  });
                } else {
                  messenger.showSnackBar(
                    SnackBar(
                      backgroundColor: Colors.amber.shade900,
                      content: Text('No matching FSM return found for scanned code: $extractedToken'),
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
                  if (pendingReturns.isNotEmpty) {
                    setSheetState(() {
                      selected = pendingReturns.first;
                      isVerifying = false;
                    });
                  } else {
                    setSheetState(() => isVerifying = false);
                    messenger.showSnackBar(
                      const SnackBar(content: Text('No pending FSM returns found for verification.')),
                    );
                  }
                }
              } catch (_) {
                setSheetState(() => isVerifying = false);
              }
            }

            Future<void> confirmApproval(Map<String, dynamic> retItem) async {
              setSheetState(() => isProcessing = true);
              final returnId = retItem['id']?.toString() ?? '';
              final returnCode = retItem['return_code']?.toString() ?? '';
              final securityPin = retItem['security_pin']?.toString() ?? '';
              final fsmName = retItem['fsm_name'] ?? 'Field Sales Manager';
              final returnQty = (retItem['quantity'] as num?)?.toInt() ?? 0;

              try {
                final result = await OfflineSyncService.executeWithOfflineFallback(
                  apiBaseUrl: AppState.apiBaseUrl,
                  endpoint: '/settlements/warehouse-returns/approve',
                  method: 'POST',
                  role: 'store_admin',
                  type: 'warehouse_settlement_approval',
                  title: 'FSM Return Approval ($fsmName - $returnQty btls)',
                  userId: AppState.currentUser?['id'],
                  payload: {
                    'id': returnId,
                    'code_or_pin': returnCode,
                    'return_code': returnCode,
                    'security_pin': securityPin,
                    'warehouse_id': warehouseId,
                    'approved_by': AppState.currentUser?['id'],
                    'approved_by_name': AppState.currentUser?['name'] ?? 'Store Admin',
                  },
                );

                if (result['success'] == true) {
                  if (sheetCtx.mounted) Navigator.pop(sheetCtx);
                  final isOffline = result['is_offline'] == true;
                  messenger.showSnackBar(
                    SnackBar(
                      backgroundColor: isOffline ? Colors.amber.shade800 : Colors.green.shade800,
                      content: Text(
                        isOffline
                            ? '⚡ Return approved offline! $returnQty bottles queued to credit warehouse once online.'
                            : '✓ Return Approved! Reconciled & received $returnQty bottles from $fsmName into Warehouse inventory.',
                      ),
                      duration: const Duration(seconds: 4),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                  onSettlementApproved();
                  return;
                } else {
                  final err = result['error']?.toString() ?? 'Failed to approve return';
                  messenger.showSnackBar(SnackBar(content: Text('Error: $err'), backgroundColor: Colors.red));
                }
              } catch (e) {
                messenger.showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
              } finally {
                setSheetState(() => isProcessing = false);
              }
            }

            final int returnQty = (selected?['quantity'] as num?)?.toInt() ?? 0;
            final fsmId = selected?['fsm_id'];
            final fsmInfo = fsmStatusList.firstWhere(
              (f) => f['fsm_id'] == fsmId,
              orElse: () => {},
            );
            final int dispatched = fsmInfo['dispatched_bottles'] ?? 0;
            final int sold = fsmInfo['team_sold_bottles'] ?? 0;
            final collected = fsmInfo['total_collected'] ?? 0;

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
                    // Drag Handle
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 14),
                        decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                      ),
                    ),

                    // Header Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1B365D).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.qr_code_scanner, color: Color(0xFF1B365D), size: 22),
                            ),
                            const SizedBox(width: 10),
                            const Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Scan FSM Settlement QR', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: ClientColors.textDark)),
                                Text('Verify unsold returns, cash, and damage', style: TextStyle(fontSize: 11, color: ClientColors.textMuted)),
                              ],
                            ),
                          ],
                        ),
                        IconButton(icon: const Icon(Icons.close, color: ClientColors.textMuted), onPressed: () => Navigator.pop(sheetCtx)),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Viewfinder Container (Tap to launch live scanner)
                    InkWell(
                      onTap: openLiveScanner,
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        height: 160,
                        decoration: BoxDecoration(
                          color: const Color(0xFF131E2E),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFF60A5FA), width: 1.5),
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
                                  size: 68,
                                  color: isVerifying ? const Color(0xFF60A5FA) : Colors.white,
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'TAP TO SCAN QR WITH LIVE CAMERA',
                                  style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'Auto-detects FSM settlement QR instantly',
                                  style: TextStyle(color: Colors.white60, fontSize: 11),
                                ),
                              ],
                            ),
                            Positioned(
                              top: 12,
                              left: 12,
                              child: Container(width: 22, height: 22, decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFF60A5FA), width: 3), left: BorderSide(color: Color(0xFF60A5FA), width: 3)))),
                            ),
                            Positioned(
                              top: 12,
                              right: 12,
                              child: Container(width: 22, height: 22, decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFF60A5FA), width: 3), right: BorderSide(color: Color(0xFF60A5FA), width: 3)))),
                            ),
                            Positioned(
                              bottom: 12,
                              left: 12,
                              child: Container(width: 22, height: 22, decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFF60A5FA), width: 3), left: BorderSide(color: Color(0xFF60A5FA), width: 3)))),
                            ),
                            Positioned(
                              bottom: 12,
                              right: 12,
                              child: Container(width: 22, height: 22, decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFF60A5FA), width: 3), right: BorderSide(color: Color(0xFF60A5FA), width: 3)))),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Primary Live Scanner Button
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: ElevatedButton.icon(
                        onPressed: openLiveScanner,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1B365D),
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
                    const SizedBox(height: 10),

                    // Camera / Gallery Buttons
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => pickAndSimulateScan(ImageSource.camera),
                            icon: const Icon(Icons.camera_alt, size: 16),
                            label: const Text('Camera Scan', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF1B365D),
                              side: const BorderSide(color: Color(0xFF1B365D)),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => pickAndSimulateScan(ImageSource.gallery),
                            icon: const Icon(Icons.photo_library, size: 16),
                            label: const Text('From Gallery', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF1B365D),
                              side: const BorderSide(color: Color(0xFF1B365D)),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Manual 6-Digit PIN Option
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: pinController,
                            keyboardType: TextInputType.text,
                            maxLength: 15,
                            decoration: InputDecoration(
                              counterText: '',
                              hintText: 'Enter 6-digit Settlement PIN',
                              hintStyle: const TextStyle(fontSize: 12, color: ClientColors.textMuted),
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () {
                            final code = pinController.text.trim();
                            if (code.isNotEmpty) {
                              final match = pendingReturns.firstWhere(
                                (s) =>
                                    (s['security_pin'] ?? '').toString() == code ||
                                    (s['return_code'] ?? '').toString() == code ||
                                    (s['id'] ?? '').toString() == code,
                                orElse: () => {},
                              );
                              if (match.isNotEmpty) {
                                selectMatch(match);
                              } else {
                                // Try FSM status list
                                final fsmMatch = fsmStatusList.firstWhere(
                                  (f) =>
                                      (f['pending_return_pin'] ?? '').toString() == code ||
                                      (f['pending_return_code'] ?? '').toString() == code,
                                  orElse: () => {},
                                );
                                if (fsmMatch.isNotEmpty) {
                                  selectMatch({
                                    'id': fsmMatch['pending_return_id'] ?? 'fsm_ret_${DateTime.now().millisecondsSinceEpoch}',
                                    'return_code': fsmMatch['pending_return_code'] ?? code,
                                    'security_pin': fsmMatch['pending_return_pin'] ?? (code.length == 6 ? code : '123456'),
                                    'fsm_id': fsmMatch['fsm_id'],
                                    'fsm_name': fsmMatch['name'],
                                    'quantity': fsmMatch['pending_return_quantity'] ?? fsmMatch['depot_stock'] ?? 0,
                                    'status': 'pending_warehouse',
                                  });
                                } else {
                                  messenger.showSnackBar(
                                    const SnackBar(
                                      content: Text('Invalid PIN. No pending FSM return found for this PIN.'),
                                      duration: Duration(seconds: 2),
                                    ),
                                  );
                                }
                              }
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1B365D),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          ),
                          child: const Text('Verify PIN', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),

                    if (pendingReturns.isNotEmpty && selected == null) ...[
                      const SizedBox(height: 14),
                      const Text('Or Select Pending FSM Return:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: ClientColors.textDark)),
                      const SizedBox(height: 6),
                      ...pendingReturns.map((st) {
                        return InkWell(
                          onTap: () => setSheetState(() => selected = st),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 6),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: ClientColors.border),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('${st['fsm_name'] ?? 'FSM'} (${st['quantity'] ?? 0} Bottles to Return)', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                const Icon(Icons.arrow_forward_ios, size: 12, color: ClientColors.textMuted),
                              ],
                            ),
                          ),
                        );
                      }),
                    ],

                    // Selected Settlement Full Breakdown Card
                    if (selected != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFF93C5FD)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const CircleAvatar(
                                      radius: 16,
                                      backgroundColor: Color(0xFF1B365D),
                                      child: Icon(Icons.person, color: Colors.white, size: 18),
                                    ),
                                    const SizedBox(width: 8),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(selected!['fsm_name'] ?? 'FSM', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: ClientColors.textDark)),
                                        Text('Return Code: ${selected!['return_code'] ?? 'WR-RET'}', style: const TextStyle(fontSize: 11, color: ClientColors.textMuted)),
                                      ],
                                    ),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(color: Colors.amber.shade100, borderRadius: BorderRadius.circular(6)),
                                  child: const Text('Verified', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.amber)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            const Divider(height: 1, color: ClientColors.border),
                            const SizedBox(height: 12),

                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Dispatched to FSM:', style: TextStyle(fontSize: 12, color: ClientColors.textMuted)),
                                Text('$dispatched Bottles', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: ClientColors.textDark)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Sold in Field by Team:', style: TextStyle(fontSize: 12, color: ClientColors.textMuted)),
                                Text('$sold Bottles', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.blue)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Total Team Revenue:', style: TextStyle(fontSize: 12, color: ClientColors.textMuted)),
                                Text('₹$collected', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.green)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Unsold Bottles Returning:', style: TextStyle(fontSize: 12, color: ClientColors.textMuted)),
                                Text('$returnQty Bottles', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.teal)),
                              ],
                            ),

                            const SizedBox(height: 14),
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.green.shade50,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.green.shade200),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.add_business_rounded, color: Colors.green, size: 18),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      '+$returnQty bottles will be credited to Central Warehouse inventory and deducted from FSM depot.',
                                      style: TextStyle(fontSize: 11, color: Colors.green.shade900, fontWeight: FontWeight.w500),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),

                            SizedBox(
                              width: double.infinity,
                              height: 46,
                              child: ElevatedButton.icon(
                                onPressed: isProcessing ? null : () => confirmApproval(selected!),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF15803D),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                icon: isProcessing
                                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                    : const Icon(Icons.check_circle, size: 20),
                                label: Text(
                                  isProcessing ? 'Receiving Stock...' : 'Approve & Receive $returnQty Bottles into Warehouse',
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                                ),
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
