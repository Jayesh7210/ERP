import 'package:flutter/material.dart';
import '../../../core/constants/colors.dart';

// ---------------------------------------------------------
// REPORTS & AUDITING VIEW (STORE ADMIN SCOPE ONLY)
// ---------------------------------------------------------
class StoreReportsView extends StatefulWidget {
  final String warehouseId;
  final String warehouseName;
  final List<Map<String, dynamic>> intakes;
  final List<Map<String, dynamic>> transfers;
  final List<Map<String, dynamic>> sales;
  final List<Map<String, dynamic>> alerts;
  final String Function(String) getProductName;
  final String Function(String) getProductUnit;

  const StoreReportsView({
    super.key,
    required this.warehouseId,
    this.warehouseName = '',
    required this.intakes,
    required this.transfers,
    required this.sales,
    required this.alerts,
    required this.getProductName,
    required this.getProductUnit,
  });

  @override
  State<StoreReportsView> createState() => _StoreReportsViewState();
}

class _StoreReportsViewState extends State<StoreReportsView> {
  int _selectedFilter = 0; // 0: All Ledgers, 1: Stock Intake, 2: FSM Transfers, 3: Retail Sales, 4: Distributor Sales, 5: Low Stock

  @override
  Widget build(BuildContext context) {
    final retailSales = widget.sales.where((s) => (s['customer_type'] ?? 'retail') == 'retail').toList();
    final distributorSales = widget.sales.where((s) => s['customer_type'] == 'distributor').toList();
    final totalRetailRev = retailSales.fold<double>(0.0, (sum, s) => sum + (double.tryParse(s['amount'].toString()) ?? 0.0));
    final totalDistRev = distributorSales.fold<double>(0.0, (sum, s) => sum + (double.tryParse(s['amount'].toString()) ?? 0.0));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Warehouse Scoping Header
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: const Color(0xFFF3EAE0), borderRadius: BorderRadius.circular(10)),
            child: Row(
              children: [
                const Icon(Icons.analytics_outlined, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Reports & audit records are strictly scoped to ${widget.warehouseName.isNotEmpty ? widget.warehouseName : 'Warehouse #${widget.warehouseId}'}.',
                    style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Summary Grid
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.6,
            children: [
              _buildReportMetric('Stock Intake', '${widget.intakes.length} Batches', Icons.add_business, Colors.teal),
              _buildReportMetric('FSM Transfers', '${widget.transfers.length} Outgoing', Icons.local_shipping, Colors.blue),
              _buildReportMetric('Retail Revenue', '₹${totalRetailRev.toStringAsFixed(0)}', Icons.point_of_sale, Colors.green),
              _buildReportMetric('Distributor Rev', '₹${totalDistRev.toStringAsFixed(0)}', Icons.storefront, Colors.purple),
            ],
          ),
          const SizedBox(height: 18),

          // Segmented Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('All Activity', 0),
                _buildFilterChip('Intakes (${widget.intakes.length})', 1),
                _buildFilterChip('FSM Transfers (${widget.transfers.length})', 2),
                _buildFilterChip('Retail Sales (${retailSales.length})', 3),
                _buildFilterChip('Distributor Sales (${distributorSales.length})', 4),
                _buildFilterChip('Low Stock Alerts (${widget.alerts.length})', 5),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Ledger Content
          _buildLedgerContent(retailSales, distributorSales),
        ],
      ),
    );
  }

  Widget _buildReportMetric(String title, String val, IconData icon, Color color) {
    return Card(
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 6),
                Expanded(child: Text(title, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary))),
              ],
            ),
            const SizedBox(height: 8),
            Text(val, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, int index) {
    final isSelected = _selectedFilter == index;
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        selectedColor: AppColors.primary,
        labelStyle: TextStyle(color: isSelected ? Colors.white : AppColors.textPrimary, fontSize: 12, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
        onSelected: (_) => setState(() => _selectedFilter = index),
      ),
    );
  }

  Widget _buildLedgerContent(List<Map<String, dynamic>> retailSales, List<Map<String, dynamic>> distSales) {
    if (_selectedFilter == 1) {
      return _buildIntakeLedger();
    } else if (_selectedFilter == 2) {
      return _buildTransfersLedger();
    } else if (_selectedFilter == 3) {
      return _buildSalesList(retailSales, 'Retail');
    } else if (_selectedFilter == 4) {
      return _buildSalesList(distSales, 'Distributor');
    } else if (_selectedFilter == 5) {
      return _buildAlertsLedger();
    }

    // Default: Combined overview
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Recent Stock Intakes', widget.intakes.length),
        _buildIntakeLedger(limit: 3),
        const SizedBox(height: 16),
        _buildSectionHeader('Recent Outgoing Transfers to FSMs', widget.transfers.length),
        _buildTransfersLedger(limit: 3),
        const SizedBox(height: 16),
        _buildSectionHeader('Recent Retail Direct Sales', retailSales.length),
        _buildSalesList(retailSales, 'Retail', limit: 3),
      ],
    );
  }

  Widget _buildSectionHeader(String title, int count) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary)),
          Text('$count total', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildIntakeLedger({int? limit}) {
    final list = limit != null ? widget.intakes.take(limit).toList() : widget.intakes;
    if (list.isEmpty) return const Text('No intakes recorded.', style: TextStyle(color: AppColors.textSecondary));
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: list.length,
      itemBuilder: (context, idx) {
        final item = list[idx];
        final pName = widget.getProductName(item['product_id'] ?? '');
        final qty = item['quantity'];
        final batch = item['batch_number'] ?? 'N/A';
        final supplier = item['supplier'] ?? 'Direct';
        final date = item['date_received'] ?? item['created_at']?.toString().split('T').first ?? 'N/A';

        return Card(
          color: Colors.white,
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: const CircleAvatar(backgroundColor: Color(0xFFE0F2F1), child: Icon(Icons.inventory, color: Colors.teal)),
            title: Text('$qty units • $pName', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            subtitle: Text('Batch: $batch • Supplier: $supplier • Date: $date', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: Colors.teal.shade50, borderRadius: BorderRadius.circular(6)),
              child: Text('INTAKE', style: TextStyle(color: Colors.teal.shade800, fontSize: 10, fontWeight: FontWeight.bold)),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTransfersLedger({int? limit}) {
    final list = limit != null ? widget.transfers.take(limit).toList() : widget.transfers;
    if (list.isEmpty) return const Text('No transfers recorded.', style: TextStyle(color: AppColors.textSecondary));
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: list.length,
      itemBuilder: (context, idx) {
        final t = list[idx];
        final pName = t['product']?['name'] ?? widget.getProductName(t['product_id'] ?? '');
        final qty = t['quantity'];
        final dest = t['to_name'] ?? 'FSM';
        final date = t['created_at']?.toString().split('T').first ?? 'N/A';

        final status = (t['status'] ?? 'COMPLETED').toString().toUpperCase();
        final isPending = status == 'PENDING';

        return Card(
          color: Colors.white,
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: const CircleAvatar(backgroundColor: Color(0xFFE3F2FD), child: Icon(Icons.local_shipping, color: Colors.blue)),
            title: Text('$qty units • $pName', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            subtitle: Text('To FSM: $dest • Date: $date', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isPending ? Colors.amber.shade50 : Colors.green.shade50,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                status,
                style: TextStyle(
                  color: isPending ? Colors.amber.shade800 : Colors.green.shade800,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSalesList(List<Map<String, dynamic>> sales, String type, {int? limit}) {
    final list = limit != null ? sales.take(limit).toList() : sales;
    if (list.isEmpty) return Text('No $type sales recorded.', style: const TextStyle(color: AppColors.textSecondary));
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: list.length,
      itemBuilder: (context, idx) {
        final s = list[idx];
        final custName = s['customer']?['name'] ?? (s['customer_name'] ?? 'Customer');
        final amt = s['amount'];
        final qty = s['quantity'];
        final pName = s['product']?['name'] ?? widget.getProductName(s['product_id'] ?? '');
        final pMethod = (s['payment_method'] ?? 'cash').toString().toUpperCase();

        return Card(
          color: Colors.white,
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: type == 'Retail' ? const Color(0xFFE8F5E9) : const Color(0xFFF3E5F5),
              child: Icon(type == 'Retail' ? Icons.person : Icons.business, color: type == 'Retail' ? Colors.green : Colors.purple),
            ),
            title: Text('$custName • ₹$amt', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            subtitle: Text('$qty units • $pName • $pMethod', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: type == 'Retail' ? Colors.green.shade50 : Colors.purple.shade50,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(type.toUpperCase(), style: TextStyle(color: type == 'Retail' ? Colors.green.shade800 : Colors.purple.shade800, fontSize: 10, fontWeight: FontWeight.bold)),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAlertsLedger() {
    if (widget.alerts.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        alignment: Alignment.center,
        child: const Text('All products are healthy above their minimum threshold.', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
      );
    }
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: widget.alerts.length,
      itemBuilder: (context, idx) {
        final a = widget.alerts[idx];
        final pName = a['product']?['name'] ?? 'Product';
        final stock = a['total_quantity'];
        final threshold = a['threshold'];
        final deficit = a['deficit'];

        return Card(
          color: Colors.red.shade50,
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: const CircleAvatar(backgroundColor: Colors.red, child: Icon(Icons.warning, color: Colors.white)),
            title: Text(pName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.red)),
            subtitle: Text('Current: $stock • Min Alert: $threshold (Deficit: -$deficit units)', style: TextStyle(fontSize: 12, color: Colors.red.shade900)),
          ),
        );
      },
    );
  }
}
