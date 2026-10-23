import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/constants/colors.dart';

class SalesmanStockTab extends StatelessWidget {
  final int currentStock;
  final int soldToday;
  final int totalDispatchedBottles;
  final double? bottleUnitPrice;
  final double unitPrice;
  final bool isStockAccepted;
  final String parentName;
  final String? proofPhotoName;
  final Uint8List? proofPhotoBytes;
  final String? proofPhotoBase64;
  final List<Map<String, dynamic>> stockHistory;
  final VoidCallback onOpenReceiveStockScanner;
  final Function(String? name, String? base64, Uint8List? bytes) onProofPhotoChanged;
  final VoidCallback onAcceptStock;
  final Future<void> Function()? onRefresh;

  const SalesmanStockTab({
    super.key,
    required this.currentStock,
    required this.soldToday,
    required this.totalDispatchedBottles,
    required this.bottleUnitPrice,
    required this.unitPrice,
    required this.isStockAccepted,
    required this.parentName,
    required this.proofPhotoName,
    required this.proofPhotoBytes,
    required this.proofPhotoBase64,
    required this.stockHistory,
    required this.onOpenReceiveStockScanner,
    required this.onProofPhotoChanged,
    required this.onAcceptStock,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final scrollContent = SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Current Stock Header Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: ClientColors.border),
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
                          'CURRENT STOCK',
                          style: TextStyle(
                            fontSize: 10,
                            color: ClientColors.textMuted,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$currentStock Bottles',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: ClientColors.textDark,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text(
                          'VALUE',
                          style: TextStyle(
                            fontSize: 10,
                            color: ClientColors.textMuted,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        bottleUnitPrice != null
                            ? Text(
                                '₹${(currentStock * bottleUnitPrice!).toInt()}',
                                style: const TextStyle(
                                  fontSize: 18,
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
                const SizedBox(height: 12),
                const Divider(),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Sold Today: $soldToday',
                      style: const TextStyle(fontSize: 12, color: ClientColors.textMuted),
                    ),
                    Text(
                      'Remaining: $currentStock',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: ClientColors.textDark,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Scan QR to Accept Stock Button
          ElevatedButton.icon(
            onPressed: onOpenReceiveStockScanner,
            icon: const Icon(Icons.qr_code_scanner, size: 20),
            label: const Text(
              'Scan QR to Accept Stock',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: ClientColors.primary,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
          const SizedBox(height: 16),

          // Stock Verification Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: ClientColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.verified_user_outlined, color: ClientColors.primary, size: 18),
                    SizedBox(width: 8),
                    Text(
                      'Stock Verification',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: ClientColors.textDark,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _verificationRow('Assigned By', parentName),
                _verificationRow('Quantity', '$totalDispatchedBottles Bottles'),
                _verificationRow(
                  'Value',
                  bottleUnitPrice != null
                      ? '₹${(totalDispatchedBottles * bottleUnitPrice!).toInt()}'
                      : 'Loading...',
                ),
                const SizedBox(height: 14),

                // Capture Proof Photo with Camera / Gallery
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: proofPhotoName != null
                        ? Colors.blue.withValues(alpha: 0.05)
                        : ClientColors.cardBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: proofPhotoName != null ? Colors.blue.shade300 : ClientColors.border,
                      width: proofPhotoName != null ? 1.5 : 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            proofPhotoName != null ? Icons.verified : Icons.camera_alt_outlined,
                            size: 18,
                            color: proofPhotoName != null ? Colors.blue : ClientColors.textDark,
                          ),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Handover Proof Photo (Optional)',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (proofPhotoName != null) ...[
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () => onProofPhotoChanged(null, null, null),
                              child: const Text(
                                'Remove',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.red,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (proofPhotoBytes != null) ...[
                        const SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.memory(
                            proofPhotoBytes!,
                            height: 110,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: () {
                          showModalBottomSheet(
                            context: context,
                            shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                            ),
                            builder: (sheetCtx) => SafeArea(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Padding(
                                      padding: EdgeInsets.only(bottom: 8),
                                      child: Text(
                                        'Attach Stock Handover Proof',
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                      ),
                                    ),
                                    ListTile(
                                      leading: const CircleAvatar(
                                        backgroundColor: Colors.blue,
                                        child: Icon(Icons.camera_alt, color: Colors.white),
                                      ),
                                      title: const Text('Take Photo with Camera'),
                                      subtitle: const Text('Capture photo of received stock crates'),
                                      onTap: () async {
                                        Navigator.pop(sheetCtx);
                                        try {
                                          final picker = ImagePicker();
                                          final picked = await picker.pickImage(
                                            source: ImageSource.camera,
                                            imageQuality: 85,
                                            maxWidth: 1600,
                                          );
                                          if (picked != null) {
                                            final bytes = await picked.readAsBytes();
                                            final base64Str =
                                                'data:image/jpeg;base64,${base64Encode(bytes)}';
                                            onProofPhotoChanged(picked.name, base64Str, bytes);
                                            if (context.mounted) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(
                                                  content: Text('Attached: ${picked.name}'),
                                                  backgroundColor: Colors.green,
                                                ),
                                              );
                                            }
                                          }
                                        } catch (_) {}
                                      },
                                    ),
                                    ListTile(
                                      leading: const CircleAvatar(
                                        backgroundColor: Colors.orange,
                                        child: Icon(Icons.photo_library, color: Colors.white),
                                      ),
                                      title: const Text('Choose from Gallery / Photos'),
                                      subtitle: const Text('Select existing proof picture'),
                                      onTap: () async {
                                        Navigator.pop(sheetCtx);
                                        try {
                                          final picker = ImagePicker();
                                          final picked = await picker.pickImage(
                                            source: ImageSource.gallery,
                                            imageQuality: 85,
                                            maxWidth: 1600,
                                          );
                                          if (picked != null) {
                                            final bytes = await picked.readAsBytes();
                                            final base64Str =
                                                'data:image/jpeg;base64,${base64Encode(bytes)}';
                                            onProofPhotoChanged(picked.name, base64Str, bytes);
                                            if (context.mounted) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(
                                                  content: Text('Attached: ${picked.name}'),
                                                  backgroundColor: Colors.green,
                                                ),
                                              );
                                            }
                                          }
                                        } catch (_) {}
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: ClientColors.border),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                proofPhotoName != null ? Icons.check_circle : Icons.upload_file,
                                size: 16,
                                color: proofPhotoName != null ? Colors.green : ClientColors.primary,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  proofPhotoName ?? 'Tap to take photo or choose file',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: proofPhotoName != null
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    color: proofPhotoName != null
                                        ? Colors.black87
                                        : ClientColors.textMuted,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text(
                                proofPhotoName != null ? 'Change' : 'Attach',
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  color: ClientColors.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                const Text(
                  'By accepting this stock, you confirm responsibility for the listed quantity and value.',
                  style: TextStyle(
                    fontSize: 11,
                    color: ClientColors.textMuted,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(height: 14),

                ElevatedButton(
                  onPressed: isStockAccepted ? null : onAcceptStock,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFC76950),
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(46),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text(
                    isStockAccepted ? '✓ Stock Accepted & Verified' : 'Accept Stock & Confirm',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Recent History Section
          const Text(
            'Recent History',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: ClientColors.textDark,
            ),
          ),
          const SizedBox(height: 10),
          if (stockHistory.isNotEmpty)
            ...stockHistory.map(
              (item) => _historyItem(
                item['date']?.toString() ?? 'Today',
                '${(item['bottles'] as num?)?.toInt() ?? 0} Bottles',
                '₹${item['amount'] ?? (((item['bottles'] as num?)?.toInt() ?? 0) * unitPrice).toInt()}',
                item['status']?.toString() ?? 'SETTLED',
              ),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: ClientColors.border),
              ),
              child: const Column(
                children: [
                  Icon(Icons.inventory_2_outlined, color: ClientColors.textMuted, size: 36),
                  SizedBox(height: 8),
                  Text(
                    'No stock transfers recorded yet',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: ClientColors.textMuted,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Accepted dispatches will appear here',
                    style: TextStyle(fontSize: 11, color: ClientColors.textMuted),
                  ),
                ],
              ),
            ),
        ],
      ),
    );

    if (onRefresh != null) {
      return RefreshIndicator(
        color: ClientColors.primary,
        onRefresh: onRefresh!,
        child: scrollContent,
      );
    }
    return scrollContent;
  }

  Widget _verificationRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
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

  Widget _historyItem(String date, String bottles, String amount, String status) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: ClientColors.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                date,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: ClientColors.textDark,
                ),
              ),
              Text(bottles, style: const TextStyle(fontSize: 11, color: ClientColors.textMuted)),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                amount,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: ClientColors.textDark,
                ),
              ),
              Container(
                margin: const EdgeInsets.only(top: 2),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  status,
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: ClientColors.textMuted,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
