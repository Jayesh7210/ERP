import 'package:flutter/material.dart';
import '../../../core/constants/colors.dart';

class MyTeamTab extends StatelessWidget {
  final Map<String, dynamic> teamSummary;
  final List<Map<String, dynamic>> supervisedSalesmen;
  final VoidCallback onAllocateStock;

  const MyTeamTab({
    super.key,
    required this.teamSummary,
    required this.supervisedSalesmen,
    required this.onAllocateStock,
  });

  @override
  Widget build(BuildContext context) {
    final activeCount = teamSummary['active'] ?? 0;
    final offlineCount = teamSummary['offline'] ?? 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status Cards (Active / Offline)
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE6F4EA),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFCEEAD6)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.circle, color: Color(0xFF137333), size: 10),
                      const SizedBox(width: 8),
                      Text(
                        'ACTIVE • $activeCount',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF137333)),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.circle, color: Colors.grey.shade600, size: 10),
                      const SizedBox(width: 8),
                      Text(
                        'OFFLINE • $offlineCount',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey.shade700),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Header + Filter
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Salesmen',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: ClientColors.textDark),
              ),
              OutlinedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Showing all zones'), duration: Duration(seconds: 1)),
                  );
                },
                icon: const Icon(Icons.filter_list, size: 16, color: ClientColors.textDark),
                label: const Text('Filter', style: TextStyle(fontSize: 12, color: ClientColors.textDark)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: ClientColors.border),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Salesmen Roster Cards
          ...supervisedSalesmen.map((sm) {
            final String name = sm['name'] ?? 'Salesman';
            final String zone = sm['zone'] ?? 'Zone A';
            final String code = sm['code'] ?? 'SP-00';
            final bool isActive = sm['is_active'] == true;
            final int soldToday = (sm['sold_today'] as num?)?.toInt() ?? 0;
            final int stock = (sm['current_stock'] as num?)?.toInt() ?? 0;
            final bool isLowStock = stock <= 10;

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: ClientColors.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  )
                ],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Stack(
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: ClientColors.primary.withValues(alpha: 0.12),
                            child: Text(
                              name.isNotEmpty ? name[0] : 'S',
                              style: const TextStyle(color: ClientColors.primary, fontWeight: FontWeight.bold),
                            ),
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: isActive ? ClientColors.success : Colors.grey.shade400,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 1.5),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: ClientColors.textDark),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '$zone • ID: $code',
                              style: const TextStyle(fontSize: 11, color: ClientColors.textMuted),
                            ),
                          ],
                        ),
                      ),
                      OutlinedButton(
                        onPressed: onAllocateStock,
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: ClientColors.primary),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Text('Allocate', style: TextStyle(fontSize: 11, color: ClientColors.primary, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Divider(height: 1, color: ClientColors.border),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Text('Sold Today: ', style: TextStyle(fontSize: 12, color: ClientColors.textMuted)),
                          Text('$soldToday btls', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: ClientColors.textDark)),
                        ],
                      ),
                      Row(
                        children: [
                          const Text('Current Stock: ', style: TextStyle(fontSize: 12, color: ClientColors.textMuted)),
                          Text(
                            isLowStock ? '$stock btls ⚠️' : '$stock btls',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isLowStock ? Colors.red.shade700 : ClientColors.textDark,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
