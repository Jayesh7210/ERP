import 'package:flutter/material.dart';
import '../../../core/constants/colors.dart';

class SettlementHubTab extends StatelessWidget {
  final Map<String, dynamic> settlementHub;
  final VoidCallback onScanSalesmanSettlement;
  final void Function(Map<String, dynamic> settlement) onReviewSettlement;
  final VoidCallback onWarehouseReturnQR;
  final void Function(String salesmanId, String name) onSendReminder;
  final Future<void> Function()? onRefresh;

  const SettlementHubTab({
    super.key,
    required this.settlementHub,
    required this.onScanSalesmanSettlement,
    required this.onReviewSettlement,
    required this.onWarehouseReturnQR,
    required this.onSendReminder,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final wh = (settlementHub['warehouse'] as Map<String, dynamic>?) ?? {};
    final teamSettlements = (settlementHub['team_settlement'] as List?) ?? [];
    final pendingSettlements = (settlementHub['pending_settlements'] as List?) ?? [];
    final int settledCount = teamSettlements.where((ts) => ts['status'] == 'settled').length;
    final int totalTeam = teamSettlements.length;
    final String settlementRatioText = totalTeam > 0 ? '$settledCount/$totalTeam Settled' : 'All Settled';

    final content = SingleChildScrollView(
      physics: onRefresh != null ? const AlwaysScrollableScrollPhysics() : null,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. SALESMAN FIELD SETTLEMENT & SCANNER CARD
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1B365D), Color(0xFF2E5B88)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF1B365D).withValues(alpha: 0.25),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.handshake_rounded, color: Colors.white, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Salesman Settlement',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ],
                    ),
                    if (pendingSettlements.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF59E0B),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${pendingSettlements.length} Pending Review',
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'Reconciliation Ready',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Scan the Salesman\'s settlement QR code to verify bottles sold, accept unsold returns into depot stock, confirm cash/online payments, and inspect damaged bottles.',
                  style: TextStyle(fontSize: 12, color: Colors.white70, height: 1.4),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: onScanSalesmanSettlement,
                    icon: const Icon(Icons.qr_code_scanner, size: 22),
                    label: const Text(
                      'SCAN SALESMAN SETTLEMENT QR',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF1B365D),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 2,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 2. PENDING SETTLEMENT CARDS (IF ANY)
          if (pendingSettlements.isNotEmpty) ...[
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Pending Approvals',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: ClientColors.textDark),
                ),
                Text(
                  '${pendingSettlements.length} Awaiting Scan',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFD97706)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ...pendingSettlements.map((st) {
              final smName = st['salesman_name'] ?? 'Salesman';
              final sold = st['bottles_sold'] ?? 0;
              final ret = st['remaining_qty'] ?? 0;
              final dmg = (st['damaged_qty'] as num?)?.toInt() ?? 0;
              final cash = (st['cash_received'] ?? st['cash_collected'] ?? 0);
              final online = (st['online_payment'] ?? 0);
              final total = cash + online;

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.amber.withValues(alpha: 0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
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
                              radius: 14,
                              backgroundColor: Color(0xFF1B365D),
                              child: Icon(Icons.person, color: Colors.white, size: 14),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              smName,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: ClientColors.textDark),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: const Color(0xFFFEF3C7), borderRadius: BorderRadius.circular(4)),
                          child: const Text('QR Generated', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF92400E))),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Sold: $sold btls • Unsold Return: $ret btls • Paid: ₹$total (Cash ₹$cash, Online ₹$online)',
                      style: const TextStyle(fontSize: 11, color: ClientColors.textMuted),
                    ),
                    if (dmg > 0) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.warning_amber_rounded, size: 14, color: Color(0xFFD97706)),
                          const SizedBox(width: 4),
                          Text(
                            '$dmg Damaged Bottles Reported',
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF92400E)),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      height: 36,
                      child: ElevatedButton.icon(
                        onPressed: () => onReviewSettlement(st),
                        icon: const Icon(Icons.verified_rounded, size: 16),
                        label: const Text('Review & Reconcile', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF15803D),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],

          const SizedBox(height: 20),

          // Warehouse Settlement Main Card
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Warehouse Settlement',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: ClientColors.textDark),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'Pending Return',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF92400E)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // 4-box metrics grid
                Row(
                  children: [
                    _buildSettlementStat('Received', '${wh['received'] ?? 0} btls'),
                    const SizedBox(width: 10),
                    _buildSettlementStat('Sold', '${wh['sold'] ?? 0} btls'),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _buildSettlementStat('Returned', '${wh['returned'] ?? 0} btls'),
                    const SizedBox(width: 10),
                    _buildSettlementStat('Difference', '₹${wh['difference'] ?? 0}'),
                  ],
                ),

                const SizedBox(height: 14),
                const Divider(height: 1, color: ClientColors.border),
                const SizedBox(height: 12),

                // Inventory & Sold Values
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Inventory Value', style: TextStyle(fontSize: 11, color: ClientColors.textMuted)),
                        const SizedBox(height: 2),
                        Text(
                          '₹${wh['inv_value'] ?? 0}',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: ClientColors.textDark),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text('Sold Value', style: TextStyle(fontSize: 11, color: ClientColors.textMuted)),
                        const SizedBox(height: 2),
                        Text(
                          '₹${wh['sold_value'] ?? 0}',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: ClientColors.primary),
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Generate Warehouse Return QR Button
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton.icon(
                    onPressed: onWarehouseReturnQR,
                    icon: const Icon(Icons.qr_code_2, size: 20),
                    label: const Text('Generate Warehouse Return QR', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ClientColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Team Settlement Section
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Team Settlement',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: ClientColors.textDark),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFE6F4EA),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  settlementRatioText,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF137333)),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Team Settlement List
          if (teamSettlements.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              alignment: Alignment.center,
              child: const Text(
                'No team settlement records for today.',
                style: TextStyle(fontSize: 13, color: ClientColors.textMuted),
              ),
            )
          else
            ...teamSettlements.map((ts) {
              final String name = ts['name'] ?? 'Agent';
            final String status = ts['status'] ?? 'settled';
            final bool isSettled = status == 'settled';
            final int pendingAmount = (ts['pending_amount'] as num?)?.toInt() ?? 0;
            final String smId = ts['salesman_id'] ?? ts['id'] ?? '';

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: ClientColors.border),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: isSettled ? Colors.green.shade50 : ClientColors.alertBg,
                    child: Text(
                      name.isNotEmpty ? name[0] : 'S',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isSettled ? Colors.green.shade700 : ClientColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: ClientColors.textDark)),
                        const SizedBox(height: 2),
                        Text(
                          isSettled ? 'Settled on schedule' : 'Cash handover pending',
                          style: TextStyle(fontSize: 11, color: isSettled ? ClientColors.textMuted : Colors.red.shade700),
                        ),
                      ],
                    ),
                  ),
                  if (isSettled)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE6F4EA),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.check_circle, size: 14, color: Color(0xFF137333)),
                          SizedBox(width: 4),
                          Text('Settled', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF137333))),
                        ],
                      ),
                    )
                  else ...[
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '₹$pendingAmount',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.red.shade700),
                        ),
                        const SizedBox(height: 4),
                        InkWell(
                          onTap: () => onSendReminder(smId, name),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: ClientColors.alertBg,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: ClientColors.alertBorder),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                Icon(Icons.notifications_active_outlined, size: 12, color: ClientColors.primary),
                                SizedBox(width: 4),
                                Text('Remind', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: ClientColors.primary)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            );
          }),
        ],
      ),
    );

    if (onRefresh != null) {
      return RefreshIndicator(
        color: ClientColors.primary,
        onRefresh: onRefresh!,
        child: content,
      );
    }
    return content;
  }

  Widget _buildSettlementStat(String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: ClientColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 11, color: ClientColors.textMuted)),
            const SizedBox(height: 3),
            Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: ClientColors.textDark)),
          ],
        ),
      ),
    );
  }
}
