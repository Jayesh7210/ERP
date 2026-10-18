import 'package:flutter/material.dart';
import '../../../core/constants/colors.dart';

class SalesmanDashboardTab extends StatelessWidget {
  final String salesmanName;
  final bool isOnDuty;
  final Map<String, dynamic> earningsData;
  final int soldToday;
  final int currentStock;
  final int totalDispatchedBottles;
  final int settlementSoldBottles;
  final double? bottleUnitPrice;
  final double unitPrice;
  final bool isStockAccepted;
  final Widget offlineSyncBanner;
  final ValueChanged<bool> onDutyToggle;
  final ValueChanged<int> onNavigateTab;
  final VoidCallback onRecordSale;

  const SalesmanDashboardTab({
    super.key,
    required this.salesmanName,
    required this.isOnDuty,
    required this.earningsData,
    required this.soldToday,
    required this.currentStock,
    required this.totalDispatchedBottles,
    required this.settlementSoldBottles,
    required this.bottleUnitPrice,
    required this.unitPrice,
    required this.isStockAccepted,
    required this.offlineSyncBanner,
    required this.onDutyToggle,
    required this.onNavigateTab,
    required this.onRecordSale,
  });

  @override
  Widget build(BuildContext context) {
    final totalEarned = (earningsData['total_earned'] as num?)?.toDouble() ?? 245.0;
    final commission = (earningsData['commission_earned'] as num?)?.toDouble() ?? 210.0;
    final referralEarned = (earningsData['referral_earned'] as num?)?.toDouble() ?? 35.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Greeting & Duty Toggle
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Good Morning, $salesmanName 👋', style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: ClientColors.textDark)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: isOnDuty ? Colors.green.shade50 : Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Container(width: 6, height: 6, decoration: BoxDecoration(color: isOnDuty ? Colors.green : Colors.grey, shape: BoxShape.circle)),
                            const SizedBox(width: 5),
                            Text(isOnDuty ? 'LIVE • ON DUTY' : 'OFF DUTY', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isOnDuty ? Colors.green.shade800 : Colors.grey.shade700)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Switch(
                value: isOnDuty,
                activeThumbColor: ClientColors.primary,
                onChanged: onDutyToggle,
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Offline Sync Banner (if any unsynced offline sales)
          offlineSyncBanner,

          // 4 Quick Action Buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => onNavigateTab(1), // Go to Stock
                  icon: const Icon(Icons.qr_code_scanner, size: 16),
                  label: const Text('Scan QR', style: TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(backgroundColor: ClientColors.primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onRecordSale,
                  icon: const Icon(Icons.shopping_bag_outlined, size: 16, color: ClientColors.textDark),
                  label: const Text('Start Sale', style: TextStyle(fontSize: 12, color: ClientColors.textDark)),
                  style: OutlinedButton.styleFrom(backgroundColor: Colors.white, side: const BorderSide(color: ClientColors.border), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => onNavigateTab(4), // Go to Settlement
                  icon: const Icon(Icons.account_balance_wallet_outlined, size: 16, color: ClientColors.textDark),
                  label: const Text('Settle', style: TextStyle(fontSize: 12, color: ClientColors.textDark)),
                  style: OutlinedButton.styleFrom(backgroundColor: Colors.white, side: const BorderSide(color: ClientColors.border), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => onNavigateTab(3), // Go to Refer
                  icon: const Icon(Icons.person_add_alt, size: 16, color: ClientColors.textDark),
                  label: const Text('Refer', style: TextStyle(fontSize: 12, color: ClientColors.textDark)),
                  style: OutlinedButton.styleFrom(backgroundColor: Colors.white, side: const BorderSide(color: ClientColors.border), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Today's Earnings Card (Gradient)
          Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFC85A17), Color(0xFF8B3A0D)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(color: const Color(0xFF8B3A0D).withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 6)),
              ],
            ),
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Today's Earnings", style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                    Icon(Icons.chevron_right, color: Colors.white.withValues(alpha: 0.8), size: 18),
                  ],
                ),
                const SizedBox(height: 10),
                const Text('TOTAL EARNED', style: TextStyle(color: Colors.white70, fontSize: 10, letterSpacing: 0.5)),
                Text('₹${totalEarned.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.sell_outlined, color: Colors.white70, size: 13),
                                SizedBox(width: 4),
                                Text('Commission', style: TextStyle(color: Colors.white70, fontSize: 11)),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text('₹${commission.toStringAsFixed(0)}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                            Text('${earningsData['sold_bottles_today'] ?? soldToday} bottles sold today', style: const TextStyle(color: Colors.white60, fontSize: 10)),
                          ],
                        ),
                      ),
                      Container(width: 1, height: 35, color: Colors.white24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.people_outline, color: Colors.white70, size: 13),
                                SizedBox(width: 4),
                                Text('Referrals', style: TextStyle(color: Colors.white70, fontSize: 11)),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text('₹${referralEarned.toStringAsFixed(0)}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                            Text('${earningsData['downline_bottles_sold'] ?? earningsData['referral_bottles'] ?? 0} bottles sold by referrals', style: const TextStyle(color: Colors.white60, fontSize: 10)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Current Inventory Section
          const Text('Current Inventory', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: ClientColors.textDark)),
          const SizedBox(height: 10),

          // Settlement Pending Alert
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: ClientColors.alertBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: ClientColors.alertBorder),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: ClientColors.alertText, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Settlement Pending', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: ClientColors.alertText)),
                      Text('${currentStock > 0 ? currentStock : 3} bottles remaining to be settled.', style: const TextStyle(fontSize: 11, color: ClientColors.textMuted)),
                      const SizedBox(height: 2),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          bottleUnitPrice != null
                              ? Text('Amount: ₹${((currentStock > 0 ? currentStock : 3) * bottleUnitPrice!).toInt()}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: ClientColors.textDark))
                              : const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: ClientColors.primary)),
                          InkWell(
                            onTap: () => onNavigateTab(4),
                            child: const Text('Settle Now ->', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: ClientColors.alertText)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Total Value Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: ClientColors.border),
            ),
            child: Builder(
              builder: (context) {
                final int totalBtls = totalDispatchedBottles;
                final int soldBtls = settlementSoldBottles;
                final int unsoldBtls = totalBtls > soldBtls ? totalBtls - soldBtls : 0;
                final double totalVal = totalBtls * unitPrice;
                final double progress = totalBtls > 0 ? (soldBtls / totalBtls).clamp(0.0, 1.0) : 0.0;
                final int pctSold = (progress * 100).toInt();

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('TOTAL VALUE', style: TextStyle(fontSize: 10, color: ClientColors.textMuted, fontWeight: FontWeight.bold)),
                            bottleUnitPrice != null
                                ? Text('₹${totalVal.toInt()}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: ClientColors.textDark))
                                : const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: ClientColors.primary)),
                            bottleUnitPrice != null
                                ? Text('$totalBtls btls × ₹${bottleUnitPrice!.toInt()}', style: const TextStyle(fontSize: 10, color: ClientColors.textMuted))
                                : const Text('Loading price...', style: TextStyle(fontSize: 10, color: ClientColors.textMuted)),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text('TOTAL BTLS', style: TextStyle(fontSize: 10, color: ClientColors.textMuted, fontWeight: FontWeight.bold)),
                            Text('$totalBtls', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: ClientColors.primary)),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('$pctSold% Sold', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: ClientColors.textDark)),
                        Text('$soldBtls / $totalBtls', style: const TextStyle(fontSize: 11, color: ClientColors.textMuted)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(value: progress, minHeight: 6, backgroundColor: const Color(0xFFF1EBE3), valueColor: const AlwaysStoppedAnimation<Color>(ClientColors.primary)),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.circle, color: ClientColors.primary, size: 8),
                            const SizedBox(width: 4),
                            Text('Sold: $soldBtls', style: const TextStyle(fontSize: 11, color: ClientColors.textMuted)),
                          ],
                        ),
                        Row(
                          children: [
                            const Icon(Icons.circle, color: Color(0xFFD4C9BC), size: 8),
                            const SizedBox(width: 4),
                            Text('Unsold: $unsoldBtls', style: const TextStyle(fontSize: 11, color: ClientColors.textMuted)),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Divider(),
                    if (totalBtls > 0)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: ClientColors.alertBg, borderRadius: BorderRadius.circular(8)),
                          child: const Icon(Icons.water_drop_outlined, color: ClientColors.primary, size: 18),
                        ),
                        title: Text('$totalBtls Btls Dispatched', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: ClientColors.textDark)),
                        subtitle: Text(isStockAccepted ? 'Accepted' : 'Pending Verification', style: TextStyle(fontSize: 11, color: isStockAccepted ? Colors.green : Colors.orange, fontWeight: FontWeight.w600)),
                        trailing: const Icon(Icons.chevron_right, size: 18, color: ClientColors.textMuted),
                        onTap: () => onNavigateTab(1),
                      )
                    else
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8.0),
                        child: Center(
                          child: Text('No active dispatches for today', style: TextStyle(fontSize: 12, color: ClientColors.textMuted)),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
