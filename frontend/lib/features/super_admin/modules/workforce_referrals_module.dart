import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../../core/constants/colors.dart';
import '../../../core/state/app_state.dart';

class WorkforceReferralsModule extends StatefulWidget {
  final List<Map<String, dynamic>> referrals;
  final Map<String, dynamic> referralTreeData;
  final VoidCallback onRefresh;
  final VoidCallback onBack;
  final VoidCallback? onPayoutProcessed;

  const WorkforceReferralsModule({
    super.key,
    required this.referrals,
    required this.referralTreeData,
    required this.onRefresh,
    required this.onBack,
    this.onPayoutProcessed,
  });

  @override
  State<WorkforceReferralsModule> createState() => _WorkforceReferralsModuleState();
}

class _WorkforceReferralsModuleState extends State<WorkforceReferralsModule> {
  int _referralSubTab = 0; // 0: Workforce Tree, 1: Commission Ledger

  Future<void> _processReferralPayout(String id) async {
    try {
      final res = await http.post(
        Uri.parse('${AppState.apiBaseUrl}/referrals/$id/payout'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'admin_id': AppState.currentUser?['id'],
          'admin_name': AppState.currentUser?['name'],
        }),
      );
      if (res.statusCode == 429 && mounted) {
        String msg = 'Security Rate Limit: Too many payout operations. Please wait.';
        try {
          final b = jsonDecode(res.body);
          if (b['error'] != null) msg = b['error'].toString();
        } catch (_) {}
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Colors.amber.shade900),
        );
        return;
      }
      widget.onRefresh();
      widget.onPayoutProcessed?.call();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Referral payout processed!')),
        );
      }
    } catch (_) {
      setState(() {
        final r = widget.referrals.firstWhere(
          (x) => x['id'] == id,
          orElse: () => <String, dynamic>{},
        );
        if (r.isNotEmpty) r['status'] = 'paid';
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payout recorded locally!')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final treeList =
        (widget.referralTreeData['tree'] as List?)?.cast<Map<String, dynamic>>() ??
        [];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Workforce Referrals'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: widget.onBack,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: widget.onRefresh,
          ),
        ],
      ),
      body: Column(
        children: [
          // Sub-tab Navigation
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _referralSubTab == 0
                          ? AppColors.primary
                          : Colors.grey.shade100,
                      foregroundColor: _referralSubTab == 0
                          ? Colors.white
                          : Colors.black87,
                      elevation: _referralSubTab == 0 ? 2 : 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () => setState(() => _referralSubTab = 0),
                    icon: const Icon(Icons.account_tree_outlined, size: 18),
                    label: const Text('Workforce Tree'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _referralSubTab == 1
                          ? AppColors.primary
                          : Colors.grey.shade100,
                      foregroundColor: _referralSubTab == 1
                          ? Colors.white
                          : Colors.black87,
                      elevation: _referralSubTab == 1 ? 2 : 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () => setState(() => _referralSubTab = 1),
                    icon: const Icon(Icons.receipt_long_outlined, size: 18),
                    label: Text('Ledger (${widget.referrals.length})'),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // SUBTAB 0: WORKFORCE TREE VIEW
                  if (_referralSubTab == 0) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Workforce Tree Hierarchy',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 17,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          '${widget.referralTreeData['total_salesmen'] ?? treeList.length} Salesmen',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Tree displays direct downlines (A ➔ B, D; B ➔ C). Referrer receives commissions per bottle sold based on product catalog rates.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (treeList.isEmpty)
                      Card(
                        color: AppColors.cardBg,
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            children: [
                              Icon(
                                Icons.account_tree_outlined,
                                size: 48,
                                color: Colors.grey.shade400,
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'No workforce tree nodes found',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Salesmen referral relationships will appear here.',
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      ...treeList.map(
                        (rootNode) => _buildWorkforceTreeNode(rootNode, 0),
                      ),
                  ],

                  // SUBTAB 1: COMMISSION LEDGER & PAYOUTS
                  if (_referralSubTab == 1) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Commissions Ledger',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 17,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          '${widget.referrals.length} Transactions',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (widget.referrals.isEmpty)
                      Card(
                        color: AppColors.cardBg,
                        child: const Padding(
                          padding: EdgeInsets.all(24),
                          child: Center(
                            child: Text(
                              'No referral commissions recorded yet.',
                            ),
                          ),
                        ),
                      )
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: widget.referrals.length,
                        itemBuilder: (ctx, idx) {
                          final ref = widget.referrals[idx];
                          final status = (ref['status'] ?? 'pending')
                              .toString()
                              .toLowerCase();
                          final isPaid = status == 'paid';
                          final isUnlocked =
                              status == 'unlocked' || status == 'pending';
                          final isQuotaPending = status == 'quota_pending';

                          Color statusColor = Colors.orange;
                          String statusLabel = 'PENDING';
                          IconData statusIcon = Icons.lock_clock;

                          if (isPaid) {
                            statusColor = Colors.green;
                            statusLabel = 'PAID';
                            statusIcon = Icons.check_circle;
                          } else if (isUnlocked) {
                            statusColor = Colors.blue;
                            statusLabel = 'UNLOCKED';
                            statusIcon = Icons.lock_open;
                          }

                          return Card(
                            color: AppColors.cardBg,
                            margin: const EdgeInsets.only(bottom: 12),
                            elevation: 1,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 16,
                                        backgroundColor: statusColor.withValues(
                                          alpha: 0.15,
                                        ),
                                        child: Icon(
                                          statusIcon,
                                          color: statusColor,
                                          size: 18,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              '${ref['referrer_name'] ?? 'Referrer'} ➔ ${ref['referred_name'] ?? ref['seller_name'] ?? 'Seller'}',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                                color: AppColors.textPrimary,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              'Sold: ${ref['bottles_sold'] ?? 0} bottles${ref['rate_per_bottle'] != null ? ' @ ₹${ref['rate_per_bottle']}/bottle' : ''}',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey.shade600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            '₹${(ref['commission_amount'] ?? ref['bonus_amount'] ?? 0)}',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                              color: AppColors.primary,
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: statusColor.withValues(
                                                alpha: 0.1,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              statusLabel,
                                              style: TextStyle(
                                                fontSize: 9,
                                                fontWeight: FontWeight.bold,
                                                color: statusColor,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  if (isQuotaPending) ...[
                                    const SizedBox(height: 8),
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.amber.shade50,
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: Colors.amber.shade200,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.info_outline,
                                            size: 14,
                                            color: Colors.amber.shade900,
                                          ),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Text(
                                              'Held: Commission is pending verification.',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: Colors.amber.shade900,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                  if (isUnlocked) ...[
                                    const SizedBox(height: 10),
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppColors.primary,
                                          foregroundColor: Colors.white,
                                          visualDensity: VisualDensity.compact,
                                        ),
                                        onPressed: () => _processReferralPayout(
                                          ref['id'].toString(),
                                        ),
                                        icon: const Icon(
                                          Icons.payments_outlined,
                                          size: 14,
                                        ),
                                        label: const Text('Disburse Payout'),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkforceTreeNode(Map<String, dynamic> node, int depth) {
    final name = node['name']?.toString() ?? 'Salesman';
    final bottlesSold = node['bottles_sold_today'] ?? 0;
    final unlockedComm =
        (node['unlocked_commission'] as num?)?.toDouble() ?? 0.0;
    final pendingComm = (node['pending_commission'] as num?)?.toDouble() ?? 0.0;
    final children =
        (node['children'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    return Container(
      margin: EdgeInsets.only(left: depth * 16.0, bottom: 10),
      decoration: BoxDecoration(
        color: depth == 0 ? Colors.white : AppColors.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: depth == 0
              ? AppColors.primary.withValues(alpha: 0.35)
              : Colors.grey.shade300,
          width: depth == 0 ? 1.5 : 1,
        ),
        boxShadow: depth == 0
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 17,
                  backgroundColor: depth == 0
                      ? AppColors.primary
                      : AppColors.accent,
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : 'S',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: AppColors.textPrimary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (depth == 0) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 1.5,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(
                                  alpha: 0.12,
                                ),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'ROOT',
                                style: TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Sales: $bottlesSold btls sold today',
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: Colors.green.shade300,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.verified,
                        size: 12,
                        color: Colors.green.shade700,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Active',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                _treeStatChip(
                  Icons.people_outline,
                  '${node['downline_count'] ?? 0} Downlines',
                  Colors.blueGrey,
                ),
                _treeStatChip(
                  Icons.payments_outlined,
                  '₹${unlockedComm.toStringAsFixed(0)} Earned',
                  Colors.green,
                ),
                if (pendingComm > 0)
                  _treeStatChip(
                    Icons.lock_clock,
                    '₹${pendingComm.toStringAsFixed(0)} Pending',
                    Colors.orange,
                  ),
              ],
            ),
            if (children.isNotEmpty) ...[
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Row(
                  children: [
                    const Icon(
                      Icons.subdirectory_arrow_right,
                      size: 15,
                      color: Colors.grey,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Referred Downlines (${children.length}):',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              ...children.map(
                (child) => _buildWorkforceTreeNode(child, depth + 1),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _treeStatChip(IconData icon, String label, MaterialColor color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(
        color: color.shade50,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color.shade700),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: color.shade900,
            ),
          ),
        ],
      ),
    );
  }
}
