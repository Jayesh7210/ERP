import 'package:flutter/material.dart';
import '../../../core/constants/colors.dart';

class PaymentsHistoryModule extends StatefulWidget {
  final List<Map<String, dynamic>> payments;
  final Map<String, dynamic> paymentsSummary;
  final VoidCallback onRefresh;
  final VoidCallback onBack;

  const PaymentsHistoryModule({
    super.key,
    required this.payments,
    required this.paymentsSummary,
    required this.onRefresh,
    required this.onBack,
  });

  @override
  State<PaymentsHistoryModule> createState() => _PaymentsHistoryModuleState();
}

class _PaymentsHistoryModuleState extends State<PaymentsHistoryModule> {
  String _paymentTypeFilter = 'all';
  String _paymentMethodFilter = 'all';
  String _paymentSearchQuery = '';

  @override
  Widget build(BuildContext context) {
    final filtered = widget.payments.where((p) {
      if (_paymentTypeFilter != 'all') {
        if (p['type'] != _paymentTypeFilter) return false;
      }
      if (_paymentMethodFilter != 'all') {
        if (p['payment_method'] != _paymentMethodFilter) return false;
      }
      if (_paymentSearchQuery.isNotEmpty) {
        final q = _paymentSearchQuery.toLowerCase();
        final payer = (p['payer_name'] ?? '').toString().toLowerCase();
        final no = (p['payment_no'] ?? '').toString().toLowerCase();
        final collector = (p['collector_name'] ?? '').toString().toLowerCase();
        final item = (p['item_description'] ?? '').toString().toLowerCase();
        final notes = (p['notes'] ?? '').toString().toLowerCase();
        if (!payer.contains(q) &&
            !no.contains(q) &&
            !collector.contains(q) &&
            !item.contains(q) &&
            !notes.contains(q)) {
          return false;
        }
      }
      return true;
    }).toList();

    final totalCollected =
        double.tryParse(
          widget.paymentsSummary['total_collected']?.toString() ?? '0',
        ) ??
        widget.payments
            .where((p) => p['type'] != 'referral_payout')
            .fold<double>(
              0.0,
              (sum, p) =>
                  sum +
                  (double.tryParse(p['amount']?.toString() ?? '0') ?? 0.0),
            );
    final onlineTotal =
        double.tryParse(widget.paymentsSummary['online_total']?.toString() ?? '0') ??
        widget.payments
            .where(
              (p) =>
                  p['payment_method'] == 'online' ||
                  p['payment_method'] == 'upi',
            )
            .fold<double>(
              0.0,
              (sum, p) =>
                  sum +
                  (double.tryParse(p['amount']?.toString() ?? '0') ?? 0.0),
            );
    final cashTotal =
        double.tryParse(widget.paymentsSummary['cash_total']?.toString() ?? '0') ??
        widget.payments
            .where((p) => p['payment_method'] == 'cash')
            .fold<double>(
              0.0,
              (sum, p) =>
                  sum +
                  (double.tryParse(p['amount']?.toString() ?? '0') ?? 0.0),
            );
    final payoutsTotal =
        double.tryParse(widget.paymentsSummary['payouts_total']?.toString() ?? '0') ??
        widget.payments
            .where((p) => p['type'] == 'referral_payout')
            .fold<double>(
              0.0,
              (sum, p) =>
                  sum +
                  (double.tryParse(p['amount']?.toString() ?? '0') ?? 0.0),
            );

    return Scaffold(
      backgroundColor: const Color(0xFFF9F7F5),
      appBar: AppBar(
        title: const Text('Payments History'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: widget.onBack,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: widget.onRefresh,
            tooltip: 'Refresh Ledger',
          ),
        ],
      ),
      body: Column(
        children: [
          // 1. KPI Financial Header
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _payKpiCard(
                    'Total Inflow',
                    '₹${totalCollected.toStringAsFixed(0)}',
                    Icons.arrow_downward,
                    Colors.green,
                  ),
                  const SizedBox(width: 10),
                  _payKpiCard(
                    'Online / UPI',
                    '₹${onlineTotal.toStringAsFixed(0)}',
                    Icons.qr_code_2,
                    Colors.blue,
                  ),
                  const SizedBox(width: 10),
                  _payKpiCard(
                    'Cash Handover',
                    '₹${cashTotal.toStringAsFixed(0)}',
                    Icons.payments_outlined,
                    Colors.amber.shade800,
                  ),
                  const SizedBox(width: 10),
                  _payKpiCard(
                    'Payouts Outflow',
                    '₹${payoutsTotal.toStringAsFixed(0)}',
                    Icons.arrow_upward,
                    Colors.purple,
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 1),

          // 2. Search Field
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search payer, receipt no, salesman...',
                prefixIcon: const Icon(Icons.search, size: 20),
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
              onChanged: (v) => setState(() => _paymentSearchQuery = v.trim()),
            ),
          ),

          // 3. Filter Chips
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            child: Column(
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _payTypeChip('all', 'All Types'),
                      const SizedBox(width: 8),
                      _payTypeChip('sale', 'Sales Inflow'),
                      const SizedBox(width: 8),
                      _payTypeChip('settlement', 'Settlements'),
                      const SizedBox(width: 8),
                      _payTypeChip('referral_payout', 'Referral Payouts'),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _payModePill('all', 'All Modes'),
                      const SizedBox(width: 6),
                      _payModePill('cash', 'Cash'),
                      const SizedBox(width: 6),
                      _payModePill('online', 'Online/UPI'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // 4. Payments List
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.receipt_long_outlined,
                          size: 48,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No payment transactions found',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: filtered.length,
                    itemBuilder: (ctx, idx) {
                      final item = filtered[idx];
                      return _buildPaymentCard(item);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _payKpiCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: color.withValues(alpha: 0.15),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10.5,
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _payTypeChip(String key, String label) {
    final isSelected = _paymentTypeFilter == key;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? Colors.white : AppColors.textPrimary,
        ),
      ),
      selected: isSelected,
      selectedColor: AppColors.primary,
      backgroundColor: Colors.white,
      side: BorderSide(
        color: isSelected ? AppColors.primary : Colors.grey.shade300,
      ),
      onSelected: (_) => setState(() => _paymentTypeFilter = key),
    );
  }

  Widget _payModePill(String key, String label) {
    final isSelected = _paymentMethodFilter == key;
    return InkWell(
      onTap: () => setState(() => _paymentMethodFilter = key),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.accent.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.accent : Colors.grey.shade300,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? AppColors.accent : Colors.grey.shade700,
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentCard(Map<String, dynamic> item) {
    final isPayout = item['type'] == 'referral_payout';
    final isSettlement = item['type'] == 'settlement';
    final isOnline =
        item['payment_method'] == 'online' || item['payment_method'] == 'upi';

    IconData icon;
    Color iconColor;
    Color iconBg;
    String prefix;
    Color amountColor;

    if (isPayout) {
      icon = Icons.card_giftcard;
      iconColor = Colors.purple;
      iconBg = Colors.purple.shade50;
      prefix = '- ';
      amountColor = Colors.purple.shade700;
    } else if (isSettlement) {
      icon = Icons.account_balance_wallet_outlined;
      iconColor = Colors.blue.shade700;
      iconBg = Colors.blue.shade50;
      prefix = '+ ';
      amountColor = Colors.teal.shade800;
    } else {
      icon = isOnline ? Icons.qr_code_2 : Icons.payments_outlined;
      iconColor = isOnline ? Colors.green.shade700 : Colors.amber.shade800;
      iconBg = isOnline ? Colors.green.shade50 : Colors.amber.shade50;
      prefix = '+ ';
      amountColor = Colors.green.shade800;
    }

    final double amount =
        double.tryParse(item['amount']?.toString() ?? '0') ?? 0.0;
    final isCompleted = item['status'] == 'completed';

    return Card(
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      elevation: 1,
      child: InkWell(
        onTap: () => _showPaymentReceiptModal(item),
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Row: Avatar, Payer Name, Receipt Pill
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: iconBg,
                    child: Icon(icon, color: iconColor, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item['payer_name'] ?? 'Direct Customer',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: AppColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item['item_description'] ?? 'Product Sale',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '$prefix₹${amount.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: amountColor,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: isCompleted
                              ? Colors.green.shade50
                              : Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: isCompleted
                                ? Colors.green.shade200
                                : Colors.orange.shade200,
                          ),
                        ),
                        child: Text(
                          isCompleted ? 'COMPLETED' : 'PENDING',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: isCompleted
                                ? Colors.green.shade800
                                : Colors.orange.shade800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const Divider(height: 20),

              // Bottom Details Row: Mode Pill, Collector, Date & View Receipt Link
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: isOnline
                          ? Colors.blue.shade50
                          : Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      (item['payment_method'] ?? 'cash')
                          .toString()
                          .toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: isOnline
                            ? Colors.blue.shade800
                            : Colors.amber.shade900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'By: ${item['collector_name'] ?? 'Staff'} • ${_formatPayDate(item['created_at'])}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Text(
                    'Receipt',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right,
                    size: 14,
                    color: AppColors.primary,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPaymentReceiptModal(Map<String, dynamic> item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Drag Handle
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Receipt Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.receipt_long,
                          color: AppColors.primary,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Official Payment Receipt',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            item['payment_no'] ?? 'PAY-00000',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const Divider(height: 24),

              // Receipt Fields
              _receiptRow('Transaction Type', (item['type'] ?? 'sale').toString().toUpperCase()),
              _receiptRow('Payment Mode', (item['payment_method'] ?? 'cash').toString().toUpperCase()),
              _receiptRow('Amount Paid', '₹${item['amount']}'),
              _receiptRow('Payer / Customer', item['payer_name'] ?? 'Direct Customer'),
              _receiptRow(
                'Collector / Staff',
                '${item['collector_name']} (${(item['collector_role'] ?? 'Staff').toString().replaceAll('_', ' ').toUpperCase()})',
              ),
              _receiptRow(
                'Item / Purpose',
                item['item_description'] ?? 'Supply Chain Transaction',
              ),
              _receiptRow('Date & Time', _formatPayDate(item['created_at'])),
              if (item['reference_id'] != null)
                _receiptRow('Reference ID', item['reference_id']),
              if ((item['notes'] ?? '').toString().isNotEmpty)
                _receiptRow('Audit Notes', item['notes']),

              const SizedBox(height: 20),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.check, size: 18),
                label: const Text(
                  'Done',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                onPressed: () => Navigator.pop(ctx),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _receiptRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 125,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }

  String _formatPayDate(dynamic raw) {
    if (raw == null) return 'Recent';
    try {
      final dt = DateTime.parse(raw.toString()).toLocal();
      final now = DateTime.now();
      final hour = dt.hour.toString().padLeft(2, '0');
      final minute = dt.minute.toString().padLeft(2, '0');
      if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
        return 'Today, $hour:$minute';
      }
      return '${dt.day}/${dt.month}/${dt.year} $hour:$minute';
    } catch (_) {
      return raw.toString().split('T').first;
    }
  }
}
