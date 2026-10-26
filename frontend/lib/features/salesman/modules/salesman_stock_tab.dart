import 'dart:typed_data';
import 'package:flutter/material.dart';
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
  final bool isOpeningScanner;
  final Function(String? name, String? base64, Uint8List? bytes)? onProofPhotoChanged;
  final VoidCallback? onAcceptStock;
  final Future<void> Function()? onRefresh;

  const SalesmanStockTab({
    super.key,
    required this.currentStock,
    required this.soldToday,
    this.totalDispatchedBottles = 0,
    required this.bottleUnitPrice,
    required this.unitPrice,
    this.isStockAccepted = false,
    this.parentName = '',
    this.proofPhotoName,
    this.proofPhotoBytes,
    this.proofPhotoBase64,
    required this.stockHistory,
    required this.onOpenReceiveStockScanner,
    this.isOpeningScanner = false,
    this.onProofPhotoChanged,
    this.onAcceptStock,
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
            onPressed: isOpeningScanner ? null : onOpenReceiveStockScanner,
            icon: isOpeningScanner
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.qr_code_scanner, size: 20),
            label: Text(
              isOpeningScanner ? 'Opening Scanner...' : 'Scan QR to Accept Stock',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: ClientColors.primary,
              foregroundColor: Colors.white,
              disabledBackgroundColor: ClientColors.primary.withValues(alpha: 0.75),
              disabledForegroundColor: Colors.white,
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
