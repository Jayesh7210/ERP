import 'package:flutter/material.dart';
import '../../../core/constants/colors.dart';

class SalesmanHomeTab extends StatelessWidget {
  final Widget offlineSyncBanner;
  final int soldToday;
  final double? bottleUnitPrice;
  final ValueChanged<int> onNavigateTab;
  final VoidCallback onRecordSale;

  const SalesmanHomeTab({
    super.key,
    required this.offlineSyncBanner,
    required this.soldToday,
    required this.bottleUnitPrice,
    required this.onNavigateTab,
    required this.onRecordSale,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Agent Welcome
          const Text(
            'Welcome Back, Agent',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: ClientColors.textDark,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            "Ready for today's field operations?",
            style: TextStyle(fontSize: 13, color: ClientColors.textMuted),
          ),
          const SizedBox(height: 16),

          // Offline Sync Banner (if any unsynced offline sales)
          offlineSyncBanner,
          const SizedBox(height: 4),

          // 2x2 Action Tiles
          Row(
            children: [
              Expanded(
                child: _homeActionCard(
                  icon: Icons.qr_code_scanner,
                  iconBg: const Color(0xFFFFECE5),
                  iconColor: ClientColors.primary,
                  title: 'Scan Stock',
                  subtitle: 'Accept from Manager',
                  onTap: () => onNavigateTab(1),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _homeActionCard(
                  icon: Icons.point_of_sale,
                  iconBg: const Color(0xFFFFEBEE),
                  iconColor: const Color(0xFFE53935),
                  title: 'Record Sale',
                  subtitle: 'Log bottles sold',
                  onTap: onRecordSale,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _homeActionCard(
                  icon: Icons.inventory_2_outlined,
                  iconBg: const Color(0xFFEFEBE9),
                  iconColor: const Color(0xFF5D4037),
                  title: 'My Inventory',
                  subtitle: 'Current stock',
                  onTap: () => onNavigateTab(1),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _homeActionCard(
                  icon: Icons.account_balance_wallet_outlined,
                  iconBg: const Color(0xFFFFF8E1),
                  iconColor: const Color(0xFFFFA000),
                  title: 'Settlement',
                  subtitle: "Today's tally",
                  onTap: () => onNavigateTab(4),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Referral Promo Card
          InkWell(
            onTap: () => onNavigateTab(3),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: ClientColors.border),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: ClientColors.alertBg,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.person_add_alt_1,
                      color: ClientColors.primary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Refer Salesman',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: ClientColors.textDark,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Grow your network, earn rewards >',
                          style: TextStyle(
                            fontSize: 11,
                            color: ClientColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: ClientColors.textMuted),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Today's Sales Metrics Strip
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: ClientColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Today's Sales",
                        style: TextStyle(
                          fontSize: 11,
                          color: ClientColors.textMuted,
                        ),
                      ),
                      const SizedBox(height: 6),
                      bottleUnitPrice != null
                          ? Text(
                              '₹${(soldToday * bottleUnitPrice!).toInt()}',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: ClientColors.primary,
                              ),
                            )
                          : const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: ClientColors.primary,
                              ),
                            ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: ClientColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Bottles Sold',
                        style: TextStyle(
                          fontSize: 11,
                          color: ClientColors.textMuted,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '$soldToday',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: ClientColors.textDark,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _homeActionCard({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: ClientColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: ClientColors.textDark,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 11,
                color: ClientColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
