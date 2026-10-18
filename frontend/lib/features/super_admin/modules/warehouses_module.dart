import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../../core/constants/colors.dart';
import '../../../core/state/app_state.dart';

class WarehousesModule extends StatefulWidget {
  final List<Map<String, dynamic>> warehouses;
  final List<Map<String, dynamic>> globalStocks;
  final List<Map<String, dynamic>> workforce;
  final VoidCallback onRefresh;
  final VoidCallback onBack;
  final VoidCallback? onNavigateToStock;

  const WarehousesModule({
    super.key,
    required this.warehouses,
    required this.globalStocks,
    required this.workforce,
    required this.onRefresh,
    required this.onBack,
    this.onNavigateToStock,
  });

  @override
  State<WarehousesModule> createState() => _WarehousesModuleState();
}

class _WarehousesModuleState extends State<WarehousesModule> {
  String _warehouseSearchQuery = '';
  final TextEditingController _warehouseSearchCtrl = TextEditingController();

  @override
  void dispose() {
    _warehouseSearchCtrl.dispose();
    super.dispose();
  }

  void _showAddWarehouseDialog([Map<String, dynamic>? editWarehouse]) {
    final nameCtrl = TextEditingController(
      text: editWarehouse?['name']?.toString() ?? '',
    );
    final locCtrl = TextEditingController(
      text: editWarehouse?['location']?.toString() ?? '',
    );
    final isEdit = editWarehouse != null;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              isEdit ? Icons.edit_outlined : Icons.warehouse_outlined,
              color: AppColors.primary,
            ),
            const SizedBox(width: 8),
            Text(
              isEdit ? 'Edit Warehouse' : 'Register Warehouse',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: InputDecoration(
                labelText: 'Warehouse Name',
                hintText: 'e.g. South Central Hub',
                prefixIcon: const Icon(Icons.business_outlined),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: locCtrl,
              decoration: InputDecoration(
                labelText: 'Location / City',
                hintText: 'e.g. Pune, Maharashtra',
                prefixIcon: const Icon(Icons.location_on_outlined),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              final name = nameCtrl.text.trim();
              final location = locCtrl.text.trim();
              if (name.isEmpty) return;

              try {
                if (isEdit) {
                  final whId = editWarehouse['id'];
                  await http.put(
                    Uri.parse('${AppState.apiBaseUrl}/warehouses/$whId'),
                    headers: {'Content-Type': 'application/json'},
                    body: jsonEncode({'name': name, 'location': location}),
                  );
                } else {
                  await http.post(
                    Uri.parse('${AppState.apiBaseUrl}/warehouses'),
                    headers: {'Content-Type': 'application/json'},
                    body: jsonEncode({'name': name, 'location': location}),
                  );
                }
                widget.onRefresh();
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        isEdit
                            ? 'Warehouse updated successfully!'
                            : 'Warehouse registered successfully!',
                      ),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (_) {
                if (isEdit) {
                  setState(() {
                    final idx = widget.warehouses.indexWhere(
                      (w) => w['id'] == editWarehouse['id'],
                    );
                    if (idx != -1) {
                      widget.warehouses[idx]['name'] = name;
                      widget.warehouses[idx]['location'] = location;
                    }
                  });
                } else {
                  setState(
                    () => widget.warehouses.add({
                      'id': 'w_${DateTime.now().millisecondsSinceEpoch}',
                      'name': name,
                      'location': location,
                    }),
                  );
                }
                if (ctx.mounted) Navigator.pop(ctx);
              }
            },
            child: Text(isEdit ? 'Save Changes' : 'Register'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteWarehouse(Map<String, dynamic> w) {
    final whId = w['id']?.toString() ?? '';
    final whName = w['name']?.toString() ?? 'Warehouse';
    final whLoc = w['location']?.toString() ?? '';

    final stockCount = widget.globalStocks
        .where((s) => s['warehouse_id']?.toString() == whId)
        .fold<int>(
          0,
          (sum, item) =>
              sum + (int.tryParse(item['quantity']?.toString() ?? '0') ?? 0),
        );
    final staffCount = widget.workforce
        .where((u) => u['warehouse_id']?.toString() == whId)
        .length;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.delete_forever, color: Colors.red.shade700, size: 26),
            const SizedBox(width: 8),
            const Text(
              'Delete Warehouse',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to permanently delete "$whName"?',
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Location: $whLoc',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.red.shade900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Current Inventory: $stockCount units',
                    style: TextStyle(fontSize: 12, color: Colors.red.shade800),
                  ),
                  Text(
                    'Assigned Personnel: $staffCount staff members',
                    style: TextStyle(fontSize: 12, color: Colors.red.shade800),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Deleting will unlink staff and purge stock associated with this hub.',
                    style: TextStyle(
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                      color: Colors.red,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              final prevList = List<Map<String, dynamic>>.from(widget.warehouses);
              setState(
                () => widget.warehouses.removeWhere(
                  (item) => item['id']?.toString() == whId,
                ),
              );
              try {
                final res = await http.delete(
                  Uri.parse('${AppState.apiBaseUrl}/warehouses/$whId'),
                );
                if (res.statusCode == 200) {
                  widget.onRefresh();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Warehouse "$whName" deleted successfully!',
                        ),
                        backgroundColor: Colors.red.shade700,
                      ),
                    );
                  }
                } else {
                  setState(() {
                    widget.warehouses.clear();
                    widget.warehouses.addAll(prevList);
                  });
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Failed to delete warehouse on server.'),
                      ),
                    );
                  }
                }
              } catch (_) {
                widget.onRefresh();
              }
            },
            child: const Text('Delete Permanently'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final query = _warehouseSearchQuery.trim().toLowerCase();
    final filteredWarehouses = widget.warehouses.where((w) {
      if (query.isEmpty) return true;
      final name = (w['name'] ?? '').toString().toLowerCase();
      final loc = (w['location'] ?? '').toString().toLowerCase();
      return name.contains(query) || loc.contains(query);
    }).toList();

    final totalSystemUnits = widget.globalStocks.fold<int>(
      0,
      (sum, item) =>
          sum + (int.tryParse(item['quantity']?.toString() ?? '0') ?? 0),
    );
    final totalAssignedStaff = widget.workforce
        .where((u) => u['warehouse_id'] != null)
        .length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Warehouses & Hubs'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: widget.onBack,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: widget.onRefresh,
            tooltip: 'Refresh Warehouses',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddWarehouseDialog(),
        icon: const Icon(Icons.add_business_outlined),
        label: const Text(
          'Register Warehouse',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Search & Summary Area
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            color: AppColors.background,
            child: Column(
              children: [
                TextField(
                  controller: _warehouseSearchCtrl,
                  decoration: InputDecoration(
                    hintText: 'Search warehouses by name or location...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: _warehouseSearchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _warehouseSearchCtrl.clear();
                              setState(() => _warehouseSearchQuery = '');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                  ),
                  onChanged: (val) =>
                      setState(() => _warehouseSearchQuery = val),
                ),
                const SizedBox(height: 12),
                // Network Metrics summary row
                Row(
                  children: [
                    _whStatCard(
                      'Active Hubs',
                      '${widget.warehouses.length}',
                      Icons.warehouse,
                      Colors.teal,
                    ),
                    const SizedBox(width: 8),
                    _whStatCard(
                      'Total Units',
                      '$totalSystemUnits',
                      Icons.inventory_2,
                      Colors.blue.shade700,
                    ),
                    const SizedBox(width: 8),
                    _whStatCard(
                      'Assigned Staff',
                      '$totalAssignedStaff',
                      Icons.badge,
                      Colors.purple.shade700,
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Warehouse Cards List
          Expanded(
            child: filteredWarehouses.isEmpty
                ? Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.warehouse_outlined,
                            size: 64,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            widget.warehouses.isEmpty
                                ? 'No Warehouses Registered'
                                : 'No Warehouses Found',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            widget.warehouses.isEmpty
                                ? 'Add regional hubs and central warehouses to manage storage and distribution.'
                                : 'Try searching with a different name or location.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 20),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                            ),
                            onPressed: () => _showAddWarehouseDialog(),
                            icon: const Icon(Icons.add),
                            label: const Text('Register Warehouse Now'),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
                    itemCount: filteredWarehouses.length,
                    itemBuilder: (ctx, index) {
                      final w = filteredWarehouses[index];
                      final whId = w['id']?.toString() ?? '';
                      final whName =
                          w['name']?.toString() ?? 'Unnamed Warehouse';
                      final whLocation = w['location']?.toString() ?? 'Unknown';

                      // Find stocks in this warehouse
                      final whStocks = widget.globalStocks
                          .where((s) => s['warehouse_id']?.toString() == whId)
                          .toList();
                      final whUnits = whStocks.fold<int>(
                        0,
                        (sum, s) =>
                            sum +
                            (int.tryParse(s['quantity']?.toString() ?? '0') ??
                                0),
                      );
                      final distinctSkus = whStocks
                          .map((s) => s['product_id'])
                          .toSet()
                          .length;

                      // Find staff assigned
                      final whStaff = widget.workforce
                          .where((u) => u['warehouse_id']?.toString() == whId)
                          .toList();
                      final storeAdmins = whStaff
                          .where((u) => u['role'] == 'store_admin')
                          .toList();

                      return Card(
                        margin: const EdgeInsets.only(bottom: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(color: Colors.grey.shade200),
                        ),
                        elevation: 1.5,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Top Header: Icon, Name, City & Active Badge
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withValues(
                                        alpha: 0.1,
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(
                                      Icons.warehouse,
                                      color: AppColors.primary,
                                      size: 26,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          whName,
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            const Icon(
                                              Icons.location_on,
                                              size: 14,
                                              color: AppColors.textSecondary,
                                            ),
                                            const SizedBox(width: 3),
                                            Text(
                                              whLocation.isNotEmpty
                                                  ? whLocation
                                                  : 'City unassigned',
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: AppColors.textSecondary,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
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
                                      color: Colors.green.shade50,
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: Colors.green.shade300,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.check_circle,
                                          size: 12,
                                          color: Colors.green.shade700,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          'ACTIVE HUB',
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
                              const Divider(height: 24),

                              // Quick Metrics Grid for this Warehouse
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: Colors.grey.shade200,
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceAround,
                                  children: [
                                    _whMiniMetric(
                                      'Stocked Units',
                                      '$whUnits',
                                      Icons.inventory_2_outlined,
                                      Colors.blue.shade700,
                                    ),
                                    Container(
                                      height: 28,
                                      width: 1,
                                      color: Colors.grey.shade300,
                                    ),
                                    _whMiniMetric(
                                      'SKU Types',
                                      '$distinctSkus',
                                      Icons.category_outlined,
                                      Colors.indigo.shade700,
                                    ),
                                    Container(
                                      height: 28,
                                      width: 1,
                                      color: Colors.grey.shade300,
                                    ),
                                    _whMiniMetric(
                                      'Staff',
                                      '${whStaff.length}',
                                      Icons.people_outline,
                                      Colors.teal.shade700,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),

                              // In-charge staff banner
                              Row(
                                children: [
                                  const Icon(
                                    Icons.person_pin_outlined,
                                    size: 15,
                                    color: AppColors.textSecondary,
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      storeAdmins.isNotEmpty
                                          ? 'Admin: ${storeAdmins.map((a) => a['name']).join(", ")}'
                                          : whStaff.isNotEmpty
                                          ? 'Assigned: ${whStaff.map((a) => a['name']).join(", ")}'
                                          : 'No Store Admin assigned yet',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: storeAdmins.isNotEmpty
                                            ? AppColors.textPrimary
                                            : Colors.orange.shade800,
                                        fontWeight: storeAdmins.isNotEmpty
                                            ? FontWeight.w500
                                            : FontWeight.normal,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              const Divider(height: 20),

                              // Actions Row: View Stock, Edit, Delete
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: AppColors.primary,
                                        side: const BorderSide(
                                          color: AppColors.primary,
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 8,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                      ),
                                      icon: const Icon(
                                        Icons.swap_horiz,
                                        size: 16,
                                      ),
                                      label: const Text(
                                        'View Stock',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      onPressed: widget.onNavigateToStock,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.edit_outlined,
                                      size: 20,
                                      color: AppColors.primary,
                                    ),
                                    tooltip: 'Edit Warehouse',
                                    onPressed: () => _showAddWarehouseDialog(w),
                                  ),
                                  IconButton(
                                    icon: Icon(
                                      Icons.delete_outline,
                                      size: 20,
                                      color: Colors.red.shade700,
                                    ),
                                    tooltip: 'Delete Warehouse',
                                    onPressed: () => _confirmDeleteWarehouse(w),
                                  ),
                                ],
                              ),
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

  Widget _whStatCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(height: 4),
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
              style: const TextStyle(
                fontSize: 10,
                color: AppColors.textSecondary,
              ),
              maxLines: 1,
            ),
          ],
        ),
      ),
    );
  }

  Widget _whMiniMetric(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}
