import 'package:flutter/material.dart';
import '../../../core/constants/colors.dart';
import '../../../core/state/app_state.dart';

class ManagerDashboardTab extends StatelessWidget {
  final Map<String, dynamic> dashboardData;
  final String fsmName;
  final Future<void> Function() onRefresh;
  final VoidCallback onViewAllTeam;
  final VoidCallback onScanWarehouseQR;

  const ManagerDashboardTab({
    super.key,
    required this.dashboardData,
    required this.fsmName,
    required this.onRefresh,
    required this.onViewAllTeam,
    required this.onScanWarehouseQR,
  });

  @override
  Widget build(BuildContext context) {
    final earnings = (dashboardData['earnings'] as Map<String, dynamic>?) ?? {};
    final teamSales = (dashboardData['team_sales'] as Map<String, dynamic>?) ?? {};
    final stockAcc = (dashboardData['stock_accountability'] as Map<String, dynamic>?) ?? {};
    final topPerformers = (dashboardData['top_performers'] as List?) ?? [];
    final whName = AppState.currentUser?['warehouse_name'] ?? AppState.currentUser?['warehouse']?['name'];

    return RefreshIndicator(
      color: ClientColors.primary,
      onRefresh: onRefresh,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Welcome Header Card
            Container(
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
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF3C7),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'FIELD MANAGER',
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF92400E)),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Good Morning, $fsmName 👋',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: ClientColors.textDark,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          whName != null
                              ? 'Assigned to $whName'
                              : 'Field Sales Operations',
                          style: const TextStyle(fontSize: 12, color: ClientColors.textMuted),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE6F4EA),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFCEEAD6)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.circle, color: Color(0xFF137333), size: 8),
                        SizedBox(width: 5),
                        Text(
                          'ACTIVE',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF137333)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Today's Earnings & Team Sales Cards
            Row(
              children: [
                // Earnings Card (Terracotta Gradient)
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFB8501E), Color(0xFF8B3A0D)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: ClientColors.primary.withValues(alpha: 0.25),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        )
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Today's Earnings",
                          style: TextStyle(fontSize: 12, color: Colors.white70, fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '₹${earnings['today_earned'] ?? 0}',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${earnings['units_allocated'] ?? earnings['bottles_sold'] ?? 0} units allocated to team',
                          style: const TextStyle(fontSize: 10, color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Team Sales Card
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: ClientColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Team Sales',
                          style: TextStyle(fontSize: 12, color: ClientColors.textMuted, fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${teamSales['bottles'] ?? 0} btls',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: ClientColors.textDark,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${teamSales['bottles'] ?? 0} bottles sold',
                          style: const TextStyle(fontSize: 10, color: ClientColors.success, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Team Stock Accountability Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: ClientColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Team Stock Accountability',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: ClientColors.textDark),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _buildMiniStatBox('Received', '${stockAcc['received'] ?? 0}', Colors.blue.shade50, Colors.blue.shade800),
                      const SizedBox(width: 8),
                      _buildMiniStatBox('Allocated', '${stockAcc['allocated'] ?? 0}', Colors.purple.shade50, Colors.purple.shade800),
                      const SizedBox(width: 8),
                      _buildMiniStatBox('Sold', '${stockAcc['sold'] ?? 0}', Colors.green.shade50, Colors.green.shade800),
                      const SizedBox(width: 8),
                      _buildMiniStatBox('Remaining', '${stockAcc['remaining'] ?? 0}', ClientColors.alertBg, ClientColors.primary),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Top Performers Leaderboard
            Container(
              padding: const EdgeInsets.all(16),
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
                        'Top Performers',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: ClientColors.textDark),
                      ),
                      TextButton(
                        onPressed: onViewAllTeam,
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text('View All', style: TextStyle(fontSize: 12, color: ClientColors.primary, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (topPerformers.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        'No team sales recorded today yet.',
                        style: TextStyle(fontSize: 12, color: ClientColors.textMuted),
                      ),
                    )
                  else
                    ...topPerformers.map((p) {
                      final rank = p['rank'] ?? 1;
                      final name = p['name'] ?? '';
                      final bottles = p['bottles'] ?? 0;
                      final hasTrophy = p['has_trophy'] == true;

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: rank == 1 ? const Color(0xFFFEF3C7) : Colors.grey.shade100,
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              '$rank',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: rank == 1 ? const Color(0xFF92400E) : ClientColors.textMuted,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              name,
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: ClientColors.textDark),
                            ),
                          ),
                          Text(
                            '$bottles btls',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: ClientColors.textDark),
                          ),
                          if (hasTrophy) ...[
                            const SizedBox(width: 4),
                            const Text('🏆', style: TextStyle(fontSize: 14)),
                          ],
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),

            const SizedBox(height: 18),

            // Bottom Full-width Action: Scan Warehouse QR
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: onScanWarehouseQR,
                icon: const Icon(Icons.qr_code_scanner, size: 20),
                label: const Text('Scan Warehouse QR', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: ClientColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniStatBox(String label, String value, Color bg, Color textColor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textColor),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(fontSize: 10, color: textColor.withValues(alpha: 0.8), fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}
