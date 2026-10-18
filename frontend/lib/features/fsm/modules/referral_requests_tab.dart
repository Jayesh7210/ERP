import 'package:flutter/material.dart';
import '../../../core/constants/colors.dart';

class ReferralRequestsTab extends StatelessWidget {
  final Map<String, dynamic> requestsSummary;
  final List<Map<String, dynamic>> referralRequests;
  final String selectedFilter;
  final ValueChanged<String> onFilterSelected;
  final void Function(String reqId, String action) onReferralAction;

  const ReferralRequestsTab({
    super.key,
    required this.requestsSummary,
    required this.referralRequests,
    required this.selectedFilter,
    required this.onFilterSelected,
    required this.onReferralAction,
  });

  @override
  Widget build(BuildContext context) {
    final pendingCount = requestsSummary['pending'] ?? 12;
    final reviewCount = requestsSummary['in_review'] ?? 4;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Metric Summary Pills
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  decoration: BoxDecoration(
                    color: ClientColors.alertBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: ClientColors.alertBorder),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.pending_actions, color: ClientColors.primary, size: 20),
                      const SizedBox(width: 10),
                      Text(
                        '$pendingCount PENDING',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: ClientColors.primary),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.visibility_outlined, color: Colors.blue.shade700, size: 20),
                      const SizedBox(width: 10),
                      Text(
                        '$reviewCount IN REVIEW',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.blue.shade800),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: ['All New', 'High Priority', 'Recent'].map((filter) {
                final isSel = selectedFilter == filter;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(filter),
                    selected: isSel,
                    selectedColor: ClientColors.primary,
                    labelStyle: TextStyle(
                      fontSize: 12,
                      fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                      color: isSel ? Colors.white : ClientColors.textDark,
                    ),
                    backgroundColor: Colors.white,
                    side: BorderSide(color: isSel ? ClientColors.primary : ClientColors.border),
                    onSelected: (_) => onFilterSelected(filter),
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 14),

          // Candidates Roster
          ...referralRequests.map((req) {
            final String reqId = req['id'] ?? '';
            final String candidateName = req['candidate_name'] ?? 'Candidate';
            final String referredBy = req['referred_by'] ?? 'Salesman';
            final String timestamp = req['timestamp'] ?? '';
            final String phone = req['phone'] ?? '';
            final String location = req['location'] ?? '';
            final List docs = (req['documents'] as List?) ?? [];
            final String status = req['status'] ?? 'pending';
            final bool isApproved = status == 'approved';
            final bool isRejected = status == 'rejected';

            return Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(16),
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
                  // Candidate Name & Referred By Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            candidateName,
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: ClientColors.textDark),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Referred by $referredBy • $timestamp',
                            style: const TextStyle(fontSize: 11, color: ClientColors.textMuted),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: isApproved
                              ? const Color(0xFFE6F4EA)
                              : isRejected
                                  ? Colors.red.shade50
                                  : const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          status.toUpperCase(),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: isApproved
                                ? const Color(0xFF137333)
                                : isRejected
                                    ? Colors.red.shade800
                                    : const Color(0xFF92400E),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Phone & Location
                  Row(
                    children: [
                      const Icon(Icons.phone_outlined, size: 14, color: ClientColors.textMuted),
                      const SizedBox(width: 6),
                      Text(phone, style: const TextStyle(fontSize: 12, color: ClientColors.textDark)),
                      const SizedBox(width: 16),
                      const Icon(Icons.location_on_outlined, size: 14, color: ClientColors.textMuted),
                      const SizedBox(width: 6),
                      Text(location, style: const TextStyle(fontSize: 12, color: ClientColors.textDark)),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Attached Documents
                  const Text('Attached Documents', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: ClientColors.textMuted)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: docs.map((d) {
                      return InkWell(
                        onTap: () {
                          showDialog(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: Text('$d Preview'),
                              content: Text('Viewing verified document record for $candidateName ($d).'),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
                              ],
                            ),
                          );
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: ClientColors.border),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.description_outlined, size: 14, color: ClientColors.primary),
                              const SizedBox(width: 6),
                              Text(d.toString(), style: const TextStyle(fontSize: 11, color: ClientColors.textDark, fontWeight: FontWeight.w500)),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                  if (status == 'pending' || status == 'in_review') ...[
                    const SizedBox(height: 14),
                    const Divider(height: 1, color: ClientColors.border),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => onReferralAction(reqId, 'reject'),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: Colors.red.shade300),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                            child: Text(
                              '✕ Reject',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.red.shade700),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => onReferralAction(reqId, 'approve'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: ClientColors.primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                            child: const Text(
                              '✔ Approve',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
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
  }
}
