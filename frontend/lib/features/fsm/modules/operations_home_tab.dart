import 'package:flutter/material.dart';
import '../../../core/constants/colors.dart';

class OperationsHomeTab extends StatelessWidget {
  final int availableDepotStock;
  final int pendingRequestsCount;
  final VoidCallback onAllocateStock;
  final void Function(int index) onNavigateTab;
  final VoidCallback onScanWarehouseQR;

  const OperationsHomeTab({
    super.key,
    required this.availableDepotStock,
    required this.pendingRequestsCount,
    required this.onAllocateStock,
    required this.onNavigateTab,
    required this.onScanWarehouseQR,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Greeting / Title Banner
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: ClientColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Operations Hub',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: ClientColors.textDark),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: ClientColors.alertBg,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Depot: $availableDepotStock btls',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: ClientColors.primary),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  'Manage inventory allocations, warehouse returns, and agent supervision.',
                  style: TextStyle(fontSize: 12, color: ClientColors.textMuted),
                ),
              ],
            ),
          ),

          const SizedBox(height: 18),

          // Primary Quick Action Cards (Allocate Stock & Settlement)
          InkWell(
            onTap: onAllocateStock,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFB8501E), Color(0xFFD66835)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: ClientColors.primary.withValues(alpha: 0.28),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  )
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.inventory_2_outlined, color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Allocate Stock',
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        SizedBox(height: 3),
                        Text(
                          'Distribute depot bottles to field salesmen with live stock calculations.',
                          style: TextStyle(fontSize: 12, color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios, color: Colors.white70, size: 16),
                ],
              ),
            ),
          ),

          const SizedBox(height: 14),

          InkWell(
            onTap: () => onNavigateTab(4),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: ClientColors.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  )
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: const BoxDecoration(
                      color: Color(0xFFFEF3C7),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.account_balance_wallet_outlined, color: Color(0xFF92400E), size: 26),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Settlement Hub',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: ClientColors.textDark),
                        ),
                        SizedBox(height: 3),
                        Text(
                          'Central warehouse return QR & field team cash reconciliation.',
                          style: TextStyle(fontSize: 12, color: ClientColors.textMuted),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios, color: ClientColors.textMuted, size: 16),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Secondary Quick Actions (2 Columns)
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: onScanWarehouseQR,
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: ClientColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Icon(Icons.qr_code_scanner, color: ClientColors.primary, size: 24),
                        SizedBox(height: 8),
                        Text(
                          'Scan Warehouse',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: ClientColors.textDark),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Verify incoming batch',
                          style: TextStyle(fontSize: 10, color: ClientColors.textMuted),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: InkWell(
                  onTap: () => onNavigateTab(0),
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: ClientColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Icon(Icons.insights_outlined, color: Colors.indigo, size: 24),
                        SizedBox(height: 8),
                        Text(
                          'Team Insights',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: ClientColors.textDark),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Leaderboard & metrics',
                          style: TextStyle(fontSize: 10, color: ClientColors.textMuted),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Pending Referral Banner Shortcut
          InkWell(
            onTap: () => onNavigateTab(3),
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: ClientColors.alertBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: ClientColors.alertBorder),
              ),
              child: Row(
                children: [
                  const Icon(Icons.person_add_alt_1_outlined, color: ClientColors.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Referral Applications',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: ClientColors.primary),
                        ),
                        Text(
                          '$pendingRequestsCount candidates awaiting verification',
                          style: const TextStyle(fontSize: 11, color: ClientColors.textMuted),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: ClientColors.primary),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
