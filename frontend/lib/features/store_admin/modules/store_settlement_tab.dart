import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../../core/constants/colors.dart';
import '../../../core/state/app_state.dart';
import 'store_fsm_settlement_modal.dart';

// -----------------------------------------------------------------------------
// STORE ADMIN SETTLEMENT HUB (FSM STOCK RETURN RECONCILIATION & SCANNER)
// -----------------------------------------------------------------------------
class StoreSettlementTab extends StatefulWidget {
  final String warehouseId;
  final String warehouseName;
  final VoidCallback onSettlementCompleted;

  const StoreSettlementTab({
    super.key,
    required this.warehouseId,
    this.warehouseName = '',
    required this.onSettlementCompleted,
  });

  @override
  State<StoreSettlementTab> createState() => _StoreSettlementTabState();
}

class _StoreSettlementTabState extends State<StoreSettlementTab> {
  bool _isLoading = false;
  Map<String, dynamic> _summary = {
    'total_fsm': 0,
    'dispatched_bottles': 0,
    'sold_bottles': 0,
    'pending_return_bottles': 0,
    'settled_return_bottles': 0,
    'total_collected_amount': 0,
    'pending_returns_count': 0,
  };

  List<Map<String, dynamic>> _pendingReturns = [];
  List<Map<String, dynamic>> _fsmStatusList = [];
  List<Map<String, dynamic>> _history = [];

  @override
  void initState() {
    super.initState();
    _loadSettlementData();
  }

  Future<void> _loadSettlementData() async {
    if (widget.warehouseId.isEmpty) return;
    setState(() => _isLoading = true);

    try {
      final res = await http.get(
        Uri.parse('${AppState.apiBaseUrl}/settlements/warehouse/${widget.warehouseId}'),
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (mounted) {
          setState(() {
            _summary = Map<String, dynamic>.from(data['summary'] ?? {});
            _pendingReturns = List<Map<String, dynamic>>.from(data['pending_returns'] ?? []);
            _fsmStatusList = List<Map<String, dynamic>>.from(data['fsm_status'] ?? []);
            _history = List<Map<String, dynamic>>.from(data['history'] ?? []);
          });
        }
      }
    } catch (_) {}

    if (mounted) setState(() => _isLoading = false);
  }

  void _openFsmSettlementModal([Map<String, dynamic>? initialReturn]) {
    StoreFsmSettlementModal.open(
      context: context,
      warehouseId: widget.warehouseId,
      warehouseName: widget.warehouseName,
      pendingReturns: _pendingReturns,
      fsmStatusList: _fsmStatusList,
      initialReturn: initialReturn,
      onSettlementApproved: () {
        _loadSettlementData();
        widget.onSettlementCompleted();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: _loadSettlementData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Warehouse Overview Header Card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 10, offset: const Offset(0, 4)),
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
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(10)),
                            child: const Icon(Icons.warehouse, color: Colors.white, size: 22),
                          ),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.warehouseName.isNotEmpty ? widget.warehouseName : 'Central Warehouse Hub',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              const Text('FSM Daily Settlement & Return Hub', style: TextStyle(color: Colors.white70, fontSize: 11)),
                            ],
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: Colors.tealAccent.shade700, borderRadius: BorderRadius.circular(10)),
                        child: const Text('Store Admin', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(color: Colors.white24, height: 1),
                  const SizedBox(height: 14),

                  // 4-box metrics grid
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildHeaderStat('Dispatched', '${_summary['dispatched_bottles']} btls'),
                      _buildHeaderStat('Field Sold', '${_summary['sold_bottles']} btls'),
                      _buildHeaderStat('Pending Return', '${_summary['pending_return_bottles']} btls', alert: (_summary['pending_return_bottles'] as int? ?? 0) > 0),
                      _buildHeaderStat('Settled Back', '${_summary['settled_return_bottles']} btls'),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 2. SCAN FSM RETURN QR ACTION HERO CARD (Matching FSM Settlement Hub Style)
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
                  BoxShadow(color: const Color(0xFF1B365D).withValues(alpha: 0.25), blurRadius: 10, offset: const Offset(0, 4)),
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
                            'FSM Stock Settlement',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        ],
                      ),
                      if (_pendingReturns.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF59E0B),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${_pendingReturns.length} Pending Review',
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
                    'Scan the FSM\'s settlement QR code to verify bottles sold in the field, accept unsold returns back into warehouse stock, and inspect damaged bottles.',
                    style: TextStyle(fontSize: 12, color: Colors.white70, height: 1.4),
                  ),
                  const SizedBox(height: 16),

                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: () => _openFsmSettlementModal(),
                      icon: const Icon(Icons.qr_code_scanner, size: 22),
                      label: const Text(
                        'SCAN FSM SETTLEMENT QR',
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
            const SizedBox(height: 20),

            // 3. PENDING FSM RETURNS QUEUE
            if (_pendingReturns.isNotEmpty) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Pending FSM Returns', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                  Text('${_pendingReturns.length} requests', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                ],
              ),
              const SizedBox(height: 10),

              ..._pendingReturns.map((ret) {
                final fsmName = ret['fsm_name'] ?? 'Field Sales Manager';
                final qty = ret['quantity'] ?? 0;
                final code = ret['return_code'] ?? 'WR-RET';
                final pin = ret['security_pin'] ?? '';

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                    boxShadow: [
                      BoxShadow(color: Colors.amber.withValues(alpha: 0.08), blurRadius: 8, offset: const Offset(0, 2)),
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
                              CircleAvatar(
                                radius: 14,
                                backgroundColor: const Color(0xFF1B365D),
                                child: Text(
                                  fsmName.isNotEmpty ? fsmName[0].toUpperCase() : 'F',
                                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(fsmName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: ClientColors.textDark)),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: const Color(0xFFFEF3C7), borderRadius: BorderRadius.circular(4)),
                            child: Text(code, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF92400E))),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Returning $qty bottles to warehouse depot • PIN: $pin',
                        style: const TextStyle(fontSize: 11, color: ClientColors.textMuted),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        height: 36,
                        child: ElevatedButton.icon(
                          onPressed: () => _openFsmSettlementModal(ret),
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
              const SizedBox(height: 14),
            ],

            // 4. FSM TEAM FIELD STATUS ROSTER
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('FSM Distribution Status', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                Text('${_fsmStatusList.length} FSMs', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
            const SizedBox(height: 10),

            if (_fsmStatusList.isEmpty)
              Container(
                padding: const EdgeInsets.all(24),
                alignment: Alignment.center,
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                child: const Text('No Field Sales Managers assigned to this warehouse yet.', style: TextStyle(color: AppColors.textSecondary)),
              )
            else
              ..._fsmStatusList.map((fsm) {
                final name = fsm['name'] ?? 'FSM';
                final dispatched = fsm['dispatched_bottles'] ?? 0;
                final sold = fsm['team_sold_bottles'] ?? 0;
                final depot = fsm['depot_stock'] ?? 0;
                final status = (fsm['status'] ?? 'in_field').toString();
                final isPendingReturn = status == 'pending_warehouse';
                final isSettled = status == 'settled';

                return Card(
                  color: Colors.white,
                  margin: const EdgeInsets.only(bottom: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(color: isPendingReturn ? Colors.amber.shade300 : Colors.grey.shade200),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(14.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary)),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: isSettled
                                    ? Colors.green.shade100
                                    : isPendingReturn
                                        ? Colors.amber.shade100
                                        : Colors.blue.shade100,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                isSettled
                                    ? 'SETTLED'
                                    : isPendingReturn
                                        ? 'RETURN PENDING'
                                        : 'IN FIELD',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: isSettled
                                      ? Colors.green.shade900
                                      : isPendingReturn
                                          ? Colors.amber.shade900
                                          : Colors.blue.shade900,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            _buildMiniMetric('Dispatched', '$dispatched btls'),
                            const SizedBox(width: 12),
                            _buildMiniMetric('Team Sold', '$sold btls'),
                            const SizedBox(width: 12),
                            _buildMiniMetric('Depot Stock', '$depot btls', isHighlight: depot > 0),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }),

            const SizedBox(height: 20),

            // 5. COMPLETED SETTLEMENT HISTORY
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Settled Returns History', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                Text('${_history.length} settled', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
            const SizedBox(height: 10),

            if (_history.isEmpty)
              Container(
                padding: const EdgeInsets.all(20),
                alignment: Alignment.center,
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                child: const Text('No returns settled yet for this cycle.', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              )
            else
              ..._history.map((h) {
                final fsmName = h['fsm_name'] ?? 'FSM';
                final qty = h['quantity'] ?? 0;
                final code = h['return_code'] ?? 'WR-RET';
                final settledAt = (h['settled_at'] ?? h['created_at'] ?? '').toString().split('T').first;

                return Card(
                  color: Colors.white,
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFFE8F5E9),
                      child: Icon(Icons.check, color: Colors.green),
                    ),
                    title: Text('$qty bottles returned • $fsmName', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    subtitle: Text('Code: $code • Date: $settledAt', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: Colors.green.shade100, borderRadius: BorderRadius.circular(6)),
                      child: const Text('SETTLED', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.green)),
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderStat(String label, String value, {bool alert = false}) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: alert ? Colors.amberAccent : Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10)),
      ],
    );
  }

  Widget _buildMiniMetric(String label, String value, {bool isHighlight = false}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
        decoration: BoxDecoration(
          color: isHighlight ? const Color(0xFFF0FDF4) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isHighlight ? Colors.green.shade200 : const Color(0xFFE2E8F0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 9, color: AppColors.textSecondary)),
            const SizedBox(height: 2),
            Text(
              value,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isHighlight ? Colors.green.shade800 : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
