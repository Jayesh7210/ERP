import 'package:flutter/material.dart';
import '../../../core/constants/colors.dart';

class InventoryModule extends StatefulWidget {
  final List<Map<String, dynamic>> globalStocks;
  final List<Map<String, dynamic>> transfers;
  final List<Map<String, dynamic>> alerts;
  final VoidCallback onBack;
  final int initialSubTab;

  const InventoryModule({
    super.key,
    required this.globalStocks,
    required this.transfers,
    required this.alerts,
    required this.onBack,
    this.initialSubTab = 0,
  });

  @override
  State<InventoryModule> createState() => _InventoryModuleState();
}

class _InventoryModuleState extends State<InventoryModule> {
  late int _inventorySubTab;

  @override
  void initState() {
    super.initState();
    _inventorySubTab = widget.initialSubTab;
  }

  @override
  void didUpdateWidget(covariant InventoryModule oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialSubTab != widget.initialSubTab) {
      _inventorySubTab = widget.initialSubTab;
    }
  }

  Widget _subTabButton(int idx, String title) {
    final isSelected = _inventorySubTab == idx;
    return TextButton(
      onPressed: () => setState(() => _inventorySubTab = idx),
      child: Text(
        title,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? AppColors.accent : AppColors.textSecondary,
          decoration: isSelected
              ? TextDecoration.underline
              : TextDecoration.none,
        ),
      ),
    );
  }

  Widget _buildGlobalStockList() {
    return widget.globalStocks.isEmpty
        ? const Center(child: Text('No stock recorded'))
        : ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: widget.globalStocks.length,
            itemBuilder: (ctx, idx) {
              final s = widget.globalStocks[idx];
              return Card(
                color: AppColors.cardBg,
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  title: Text(s['product']?['name'] ?? 'Product'),
                  subtitle: Text('Held by: ${s['owner_name']}'),
                  trailing: Chip(
                    label: Text(
                      '${s['quantity']} units',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                  ),
                ),
              );
            },
          );
  }

  Widget _buildTransferLedgerList() {
    return widget.transfers.isEmpty
        ? const Center(child: Text('No transfer movements recorded'))
        : ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: widget.transfers.length,
            itemBuilder: (ctx, idx) {
              final t = widget.transfers[idx];
              return Card(
                color: AppColors.cardBg,
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Colors.blueGrey,
                    child: Icon(Icons.swap_horiz, color: Colors.white),
                  ),
                  title: Text('${t['from_name']} ➔ ${t['to_name']}'),
                  subtitle: Text(
                    'Item: ${t['product']?['name'] ?? 'Product'} • Qty: ${t['quantity']}',
                  ),
                  trailing: const Chip(
                    label: Text(
                      'Completed',
                      style: TextStyle(fontSize: 10, color: Colors.green),
                    ),
                  ),
                ),
              );
            },
          );
  }

  Widget _buildAlertsList() {
    return widget.alerts.isEmpty
        ? const Center(
            child: Text('All stock levels are above safety thresholds!'),
          )
        : ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: widget.alerts.length,
            itemBuilder: (ctx, idx) {
              final a = widget.alerts[idx];
              return Card(
                color: Colors.red.shade50,
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  leading: const Icon(Icons.warning, color: Colors.red),
                  title: Text(
                    a['product']?['name'] ?? 'Product',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    'Total Available: ${a['total_quantity']} • Threshold: ${a['threshold']}',
                  ),
                  trailing: Chip(
                    label: Text(
                      'Deficit: -${a['deficit']}',
                      style: const TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              );
            },
          );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventory & Stock Movement'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: widget.onBack,
        ),
      ),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            width: double.infinity,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _subTabButton(0, 'Global Balances'),
                  _subTabButton(1, 'Transfer Ledger'),
                  _subTabButton(2, 'Low Stock (${widget.alerts.length})'),
                ],
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _inventorySubTab == 0
                ? _buildGlobalStockList()
                : _inventorySubTab == 1
                ? _buildTransferLedgerList()
                : _buildAlertsList(),
          ),
        ],
      ),
    );
  }
}
