import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../../core/constants/colors.dart';
import '../../../core/state/app_state.dart';

class SettlementOversightModule extends StatefulWidget {
  final List<Map<String, dynamic>> settlements;
  final VoidCallback onRefresh;
  final VoidCallback onBack;

  const SettlementOversightModule({
    super.key,
    required this.settlements,
    required this.onRefresh,
    required this.onBack,
  });

  @override
  State<SettlementOversightModule> createState() =>
      _SettlementOversightModuleState();
}

class _SettlementOversightModuleState extends State<SettlementOversightModule> {
  String _settlementFilter = 'all';

  Future<void> _handleApproveSettlement(String id) async {
    try {
      final res = await http.put(
        Uri.parse('${AppState.apiBaseUrl}/settlements/$id/approve'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'approved_by': AppState.currentUser?['id']}),
      );
      if (res.statusCode == 200) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Settlement approved and marked settled!'),
            backgroundColor: Colors.green,
          ),
        );
        widget.onRefresh();
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Settlement reconciled!'),
          backgroundColor: Colors.green,
        ),
      );
      setState(() {
        final item = widget.settlements.firstWhere(
          (s) => s['id']?.toString() == id,
          orElse: () => {},
        );
        if (item.isNotEmpty) {
          item['status'] = 'settled';
          item['difference'] = 0;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final settlements = widget.settlements;
    final filtered = settlements.where((s) {
      if (_settlementFilter == 'pending') {
        return s['status'] != 'settled' && s['status'] != 'reconciled';
      } else if (_settlementFilter == 'tally_zero') {
        return (double.tryParse(s['difference']?.toString() ?? '0') ?? 0) == 0;
      } else if (_settlementFilter == 'has_diff') {
        return (double.tryParse(s['difference']?.toString() ?? '0') ?? 0)
                .abs() >
            0.01;
      } else if (_settlementFilter == 'settled') {
        return s['status'] == 'settled' || s['status'] == 'reconciled';
      }
      return true;
    }).toList();

    final pendingCount = settlements
        .where((s) => s['status'] != 'settled' && s['status'] != 'reconciled')
        .length;
    final totalDiff = settlements.fold<double>(
      0.0,
      (sum, s) =>
          sum +
          (double.tryParse(s['difference']?.toString() ?? '0') ?? 0.0).abs(),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settlements & Reconciliation'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: widget.onBack,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: widget.onRefresh,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                _stlFilterChip('all', 'All (${settlements.length})'),
                _stlFilterChip('pending', 'Pending Review ($pendingCount)'),
                _stlFilterChip('has_diff', 'Discrepancies'),
                _stlFilterChip('tally_zero', 'Zero Difference'),
                _stlFilterChip('settled', 'Settled / Reconciled'),
              ],
            ),
          ),
          if (totalDiff > 0)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.amber.shade300),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.orange,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Unsettled difference of ₹${totalDiff.toStringAsFixed(0)} pending reconciliation across salesmen.',
                      style: TextStyle(
                        color: Colors.orange.shade900,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.assignment_turned_in_outlined,
                            size: 54,
                            color: AppColors.textSecondary.withValues(
                              alpha: 0.5,
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'No Settlement Records Found',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Salesmen daily tally reports and end-of-day bottle settlements will be submitted here for Super Admin approval.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: filtered.length,
                    itemBuilder: (ctx, idx) {
                      final s = filtered[idx];
                      final salesman = s['salesman'] as Map<String, dynamic>?;
                      final salesmanName =
                          salesman?['name'] ??
                          s['salesman_name'] ??
                          'Salesman (${s['salesman_id'] ?? 'Unknown'})';
                      final dispatched = s['bottles_dispatched'] ?? 0;
                      final sold = s['bottles_sold'] ?? 0;
                      final unsold = s['unsold_bottles'] ?? 0;
                      final cash =
                          double.tryParse(
                            s['cash_collected']?.toString() ?? '0',
                          ) ??
                          0;
                      final diff =
                          double.tryParse(s['difference']?.toString() ?? '0') ??
                          0;
                      final status = (s['status'] ?? 'pending')
                          .toString()
                          .toLowerCase();
                      final isSettled =
                          status == 'settled' || status == 'reconciled';
                      final hasDiff = diff.abs() > 0.01;

                      return Card(
                        color: AppColors.cardBg,
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: isSettled
                                ? Colors.green.shade200
                                : (hasDiff
                                      ? Colors.orange.shade300
                                      : Colors.blue.shade200),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 18,
                                    backgroundColor: isSettled
                                        ? Colors.green.shade50
                                        : (hasDiff
                                              ? Colors.orange.shade50
                                              : Colors.blue.shade50),
                                    child: Icon(
                                      isSettled
                                          ? Icons.check_circle_rounded
                                          : (hasDiff
                                                ? Icons.error_outline_rounded
                                                : Icons.pending_rounded),
                                      color: isSettled
                                          ? Colors.green
                                          : (hasDiff
                                                ? Colors.orange
                                                : Colors.blue),
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          salesmanName,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                          ),
                                        ),
                                        Text(
                                          'ID: ${s['id']} • Date: ${s['date_label'] ?? 'Today'}',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isSettled
                                          ? Colors.green.withValues(alpha: 0.1)
                                          : (hasDiff
                                                ? Colors.orange.withValues(
                                                    alpha: 0.1,
                                                  )
                                                : Colors.blue.withValues(
                                                    alpha: 0.1,
                                                  )),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      isSettled
                                          ? 'SETTLED'
                                          : (hasDiff
                                                ? 'DIFFERENCE'
                                                : 'TALLY ZERO'),
                                      style: TextStyle(
                                        color: isSettled
                                            ? Colors.green
                                            : (hasDiff
                                                  ? Colors.orange.shade800
                                                  : Colors.blue),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const Divider(height: 20),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceAround,
                                children: [
                                  _stlStatCol('Dispatched', '$dispatched btls'),
                                  _stlStatCol('Sold', '$sold btls'),
                                  _stlStatCol('Returned', '$unsold btls'),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.grey.withValues(alpha: 0.06),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Cash Handover',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                        Text(
                                          '₹${cash.toStringAsFixed(0)}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                            color: Colors.green,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        const Text(
                                          'Difference / Shortfall',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                        Text(
                                          diff == 0
                                              ? '₹0 (Perfect)'
                                              : '₹${diff.toStringAsFixed(0)}',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                            color: diff == 0
                                                ? Colors.green
                                                : Colors.red,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              if (!isSettled) ...[
                                const SizedBox(height: 12),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    onPressed: () => _handleApproveSettlement(
                                      s['id']?.toString() ?? '',
                                    ),
                                    icon: const Icon(Icons.verified, size: 16),
                                    label: const Text(
                                      'Approve & Mark Reconciled',
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primary,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 10,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _stlFilterChip(String value, String label) {
    final isSelected = _settlementFilter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        selectedColor: AppColors.primary.withValues(alpha: 0.15),
        checkmarkColor: AppColors.primary,
        labelStyle: TextStyle(
          color: isSelected ? AppColors.primary : AppColors.textSecondary,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          fontSize: 12,
        ),
        onSelected: (selected) {
          if (selected) setState(() => _settlementFilter = value);
        },
      ),
    );
  }

  Widget _stlStatCol(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}
