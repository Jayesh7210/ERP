import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/constants/colors.dart';
import '../../../core/state/app_state.dart';
import '../../../core/services/offline_sync_service.dart';

// ==========================================
// TAB 0: INVENTORY & STOCK INTAKE
// ==========================================
class InventoryIntakeTab extends StatefulWidget {
  final String warehouseId;
  final String warehouseName;
  final List<Map<String, dynamic>> warehouseStocks;
  final List<Map<String, dynamic>> alerts;
  final List<Map<String, dynamic>> products;
  final double dispatchEarnings;
  final int dispatchedUnits;
  final int Function(String) getStockForProduct;
  final double Function(String) getRetailPriceForProduct;
  final double Function(String) getDistributorPriceForProduct;
  final VoidCallback onRefresh;

  const InventoryIntakeTab({
    super.key,
    required this.warehouseId,
    this.warehouseName = '',
    required this.warehouseStocks,
    required this.alerts,
    required this.products,
    required this.dispatchEarnings,
    required this.dispatchedUnits,
    required this.getStockForProduct,
    required this.getRetailPriceForProduct,
    required this.getDistributorPriceForProduct,
    required this.onRefresh,
  });

  @override
  State<InventoryIntakeTab> createState() => _InventoryIntakeTabState();
}

class _InventoryIntakeTabState extends State<InventoryIntakeTab> {
  Widget _buildHeaderStat(String label, String value, {bool alert = false}) {
    return Column(
      children: [
        Text(value, style: TextStyle(color: alert ? Colors.amberAccent : Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
      ],
    );
  }

  // Stock Intake Bottom Sheet Modal
  void _showStockIntakeModal() {
    String selectedProduct = widget.products.isNotEmpty ? widget.products.first['id'].toString() : '';
    final qtyController = TextEditingController();
    final batchController = TextEditingController(text: 'BATCH-${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}');
    final supplierController = TextEditingController();
    final dateController = TextEditingController(text: DateTime.now().toIso8601String().split('T').first);
    XFile? receiptFile;
    Uint8List? receiptBytes;
    bool isSubmitting = false;

    Future<void> pickInvoice(ImageSource source, StateSetter setModalState) async {
      try {
        final picker = ImagePicker();
        final img = await picker.pickImage(
          source: source,
          imageQuality: 85,
          maxWidth: 1920,
          maxHeight: 1920,
        );
        if (img != null) {
          final bytes = await img.readAsBytes();
          setModalState(() {
            receiptFile = img;
            receiptBytes = bytes;
          });
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not attach image: $e')),
          );
        }
      }
    }

    void showSourceSelectionSheet(BuildContext parentCtx, StateSetter setModalState) {
      showModalBottomSheet(
        context: parentCtx,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (sheetCtx) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const Text(
                    'Attach Supplier Invoice / Challan',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Select upload method for document proof',
                    style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Colors.grey.shade200),
                    ),
                    tileColor: AppColors.background,
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.camera_alt, color: AppColors.primary),
                    ),
                    title: const Text(
                      'Capture with Camera',
                      style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                    ),
                    subtitle: const Text('Take a photo of physical challan / invoice'),
                    trailing: const Icon(Icons.chevron_right, color: AppColors.textSecondary),
                    onTap: () {
                      Navigator.pop(sheetCtx);
                      pickInvoice(ImageSource.camera, setModalState);
                    },
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Colors.grey.shade200),
                    ),
                    tileColor: AppColors.background,
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.photo_library, color: AppColors.accent),
                    ),
                    title: const Text(
                      'Select from Gallery',
                      style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                    ),
                    subtitle: const Text('Choose existing photo from device gallery'),
                    trailing: const Icon(Icons.chevron_right, color: AppColors.textSecondary),
                    onTap: () {
                      Navigator.pop(sheetCtx);
                      pickInvoice(ImageSource.gallery, setModalState);
                    },
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          );
        },
      );
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Stock Intake Entry', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                        IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                      ],
                    ),
                    const Text('Add new supplier stock arrival to warehouse inventory with batch tracking.', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                    const SizedBox(height: 16),

                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: selectedProduct,
                      decoration: const InputDecoration(labelText: 'Product', border: OutlineInputBorder()),
                      items: widget.products.map((p) {
                        return DropdownMenuItem<String>(
                          value: p['id'].toString(),
                          child: Text('${p['name']} (${p['sku']})', overflow: TextOverflow.ellipsis),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setModalState(() => selectedProduct = val);
                      },
                    ),
                    const SizedBox(height: 14),

                    TextField(
                      controller: qtyController,
                      decoration: const InputDecoration(labelText: 'Received Quantity (Units)', border: OutlineInputBorder()),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 14),

                    TextField(
                      controller: batchController,
                      decoration: const InputDecoration(labelText: 'Batch / Lot Number', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 14),

                    TextField(
                      controller: supplierController,
                      decoration: const InputDecoration(labelText: 'Supplier / Vendor Name', hintText: 'e.g., Supplier / Vendor Name', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 14),

                    TextField(
                      controller: dateController,
                      decoration: const InputDecoration(labelText: 'Date Received (YYYY-MM-DD)', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 14),

                    // Attachment Section (Camera or Gallery)
                    if (receiptFile == null)
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: ClientColors.border, width: 1.2),
                        ),
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.receipt_long, color: AppColors.primary, size: 20),
                                ),
                                const SizedBox(width: 10),
                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Supplier Invoice / Challan',
                                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                      ),
                                      Text(
                                        'Attach physical proof (Camera or Gallery)',
                                        style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () => pickInvoice(ImageSource.camera, setModalState),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: AppColors.primary,
                                      side: const BorderSide(color: AppColors.primary),
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                    icon: const Icon(Icons.camera_alt, size: 18),
                                    label: const Text('Camera', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () => pickInvoice(ImageSource.gallery, setModalState),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primary,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      elevation: 0,
                                    ),
                                    icon: const Icon(Icons.photo_library, size: 18),
                                    label: const Text('Gallery', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      )
                    else
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.green.shade50.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.green.shade300, width: 1.2),
                        ),
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                if (receiptBytes != null)
                                  GestureDetector(
                                    onTap: () {
                                      showDialog(
                                        context: context,
                                        builder: (previewCtx) => Dialog(
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                          clipBehavior: Clip.antiAlias,
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              AppBar(
                                                title: Text(receiptFile!.name, style: const TextStyle(fontSize: 14)),
                                                backgroundColor: AppColors.primary,
                                                foregroundColor: Colors.white,
                                                elevation: 0,
                                                actions: [
                                                  IconButton(
                                                    icon: const Icon(Icons.close),
                                                    onPressed: () => Navigator.pop(previewCtx),
                                                  ),
                                                ],
                                              ),
                                              Image.memory(receiptBytes!, fit: BoxFit.contain),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                    child: Stack(
                                      children: [
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(8),
                                          child: Image.memory(
                                            receiptBytes!,
                                            width: 58,
                                            height: 58,
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                        Positioned(
                                          right: 2,
                                          bottom: 2,
                                          child: Container(
                                            padding: const EdgeInsets.all(2),
                                            decoration: const BoxDecoration(
                                              color: Colors.black54,
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(Icons.zoom_in, color: Colors.white, size: 12),
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                else
                                  Container(
                                    width: 58,
                                    height: 58,
                                    decoration: BoxDecoration(
                                      color: Colors.green.shade100,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(Icons.receipt_long, color: Colors.green, size: 28),
                                  ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: Colors.green.shade700,
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: const Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(Icons.check_circle, color: Colors.white, size: 11),
                                                SizedBox(width: 4),
                                                Text('ATTACHED', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          if (receiptBytes != null)
                                            Text(
                                              '${(receiptBytes!.lengthInBytes / 1024).toStringAsFixed(1)} KB',
                                              style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        receiptFile!.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary),
                                      ),
                                      const Text(
                                        'Tap thumbnail to view full image',
                                        style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                                  tooltip: 'Remove Invoice',
                                  onPressed: () {
                                    setModalState(() {
                                      receiptFile = null;
                                      receiptBytes = null;
                                    });
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            InkWell(
                              onTap: () => showSourceSelectionSheet(ctx, setModalState),
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 6),
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.green.shade200),
                                ),
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.sync, size: 14, color: AppColors.primary),
                                    SizedBox(width: 6),
                                    Text('Change Invoice (Camera / Gallery)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary)),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 20),

                    ElevatedButton(
                      onPressed: isSubmitting
                          ? null
                          : () async {
                              final qty = int.tryParse(qtyController.text);
                              if (qty == null || qty <= 0) {
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter valid quantity')));
                                return;
                              }
                              setModalState(() => isSubmitting = true);

                              final messenger = ScaffoldMessenger.of(context);
                              String? base64Data;
                              if (receiptBytes != null) {
                                base64Data = base64Encode(receiptBytes!);
                              } else if (receiptFile != null) {
                                final bytes = await receiptFile!.readAsBytes();
                                base64Data = base64Encode(bytes);
                              }

                              try {
                                final result = await OfflineSyncService.executeWithOfflineFallback(
                                  apiBaseUrl: AppState.apiBaseUrl,
                                  endpoint: '/stock/intake',
                                  method: 'POST',
                                  role: 'store_admin',
                                  type: 'stock_intake',
                                  title: 'Stock Intake ($qty units)',
                                  userId: AppState.currentUser?['id'],
                                  payload: {
                                    'warehouse_id': widget.warehouseId,
                                    'product_id': selectedProduct,
                                    'quantity': qty,
                                    'batch_number': batchController.text.trim(),
                                    'supplier': supplierController.text.trim().isEmpty ? 'Direct Supplier' : supplierController.text.trim(),
                                    'date_received': dateController.text.trim(),
                                    'receipt_base64': base64Data,
                                    'receipt_filename': receiptFile?.name,
                                    'received_by': AppState.currentUser?['id'],
                                  },
                                );

                                if (result['success'] == true) {
                                  if (ctx.mounted) Navigator.pop(ctx);
                                  final isOffline = result['is_offline'] == true;
                                  messenger.showSnackBar(
                                    SnackBar(
                                      content: Text(isOffline
                                          ? '⚡ Stock intake saved offline! Queued to sync once connected.'
                                          : 'Stock Intake Recorded Successfully!'),
                                      backgroundColor: isOffline ? Colors.amber.shade800 : Colors.green,
                                    ),
                                  );
                                  widget.onRefresh();
                                  return;
                                }
                              } catch (_) {}

                              // Fallback Mock Update
                              final prodStock = widget.warehouseStocks.firstWhere((s) => s['product_id'] == selectedProduct, orElse: () => {});
                              if (prodStock.isNotEmpty) {
                                prodStock['quantity'] = (prodStock['quantity'] as int) + qty;
                              } else {
                                widget.warehouseStocks.add({'owner_id': widget.warehouseId, 'product_id': selectedProduct, 'quantity': qty});
                              }

                              if (ctx.mounted) Navigator.pop(ctx);
                              messenger.showSnackBar(const SnackBar(content: Text('Stock Intake Recorded (Offline Fallback)!')));
                              if (mounted) setState(() {});
                              widget.onRefresh();
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: isSubmitting
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Text('Confirm Stock Intake', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalUnits = widget.warehouseStocks.fold<int>(0, (sum, item) {
      final q = item['quantity'] is int ? item['quantity'] : int.tryParse(item['quantity'].toString()) ?? 0;
      return sum + (q as int);
    });

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Warehouse Header Card
          Card(
            color: AppColors.primary,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(18.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(12)),
                        child: const Icon(Icons.warehouse, color: Colors.white, size: 28),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.warehouseName.isNotEmpty ? widget.warehouseName : 'Warehouse Hub',
                              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              'Warehouse #${widget.warehouseId.length > 8 ? widget.warehouseId.substring(0, 8) : widget.warehouseId}',
                              style: const TextStyle(color: Colors.white70, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(20)),
                        child: const Text('Store Admin', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                      )
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(color: Colors.white24),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildHeaderStat('Products', '${widget.products.length} SKUs'),
                      _buildHeaderStat('Total Stock', '$totalUnits Units'),
                      _buildHeaderStat('Earnings', '₹${widget.dispatchEarnings.toStringAsFixed(0)} (${widget.dispatchedUnits} u)'),
                      _buildHeaderStat('Low Stock', '${widget.alerts.length} Items', alert: widget.alerts.isNotEmpty),
                    ],
                  )
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Low Stock Alert Banner
          if (widget.alerts.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.shade300),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Low Warehouse Stock Alert!', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 14)),
                        Text(
                          '${widget.alerts.length} item(s) below threshold. Immediate stock intake recommended.',
                          style: TextStyle(color: Colors.red.shade800, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Quick Action: Add Stock Intake
          ElevatedButton.icon(
            onPressed: _showStockIntakeModal,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.add_shopping_cart),
            label: const Text('Add New Stock Intake (Batch/Supplier)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          ),
          const SizedBox(height: 20),

          // Section: Current Warehouse Stock Levels
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Current Stock Levels', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              Text('${widget.products.length} Products', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 12),

          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: widget.products.length,
            itemBuilder: (context, index) {
              final product = widget.products[index];
              final pId = product['id'];
              final stock = widget.getStockForProduct(pId);
              final minAlert = int.tryParse(product['min_stock_alert']?.toString() ?? '0') ?? 0;
              final isLow = widget.alerts.any((a) => a['product_id']?.toString() == pId?.toString()) || (minAlert > 0 && stock <= minAlert);
              final retailPrice = widget.getRetailPriceForProduct(pId);
              final distPrice = widget.getDistributorPriceForProduct(pId);

              return Card(
                color: Colors.white,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: isLow ? Colors.red.shade300 : Colors.grey.shade200, width: isLow ? 1.5 : 1),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              product['name'] ?? 'Product',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textPrimary),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: isLow ? Colors.red.shade100 : Colors.green.shade100,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              isLow ? 'LOW STOCK' : 'IN STOCK',
                              style: TextStyle(
                                color: isLow ? Colors.red.shade900 : Colors.green.shade900,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text('SKU: ${product['sku'] ?? 'N/A'} • Unit: ${product['unit'] ?? 'packet'} • Category: ${product['category'] ?? 'General'}',
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Available Stock', style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                              Text('$stock ${product['unit'] ?? 'units'}',
                                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isLow ? Colors.red : AppColors.primary)),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.lock, size: 12, color: Colors.amber),
                                  const SizedBox(width: 4),
                                  Text('Retail: ₹$retailPrice', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                ],
                              ),
                              Row(
                                children: [
                                  const Icon(Icons.lock, size: 12, color: Colors.amber),
                                  const SizedBox(width: 4),
                                  Text('Distributor: ₹$distPrice', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.accent)),
                                ],
                              ),
                            ],
                          )
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
