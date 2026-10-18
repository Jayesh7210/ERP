import 'package:flutter/material.dart';
import '../../../core/constants/colors.dart';

class SalesOversightModule extends StatefulWidget {
  final List<Map<String, dynamic>> sales;
  final VoidCallback onBack;

  const SalesOversightModule({
    super.key,
    required this.sales,
    required this.onBack,
  });

  @override
  State<SalesOversightModule> createState() => _SalesOversightModuleState();
}

class _SalesOversightModuleState extends State<SalesOversightModule> {
  String _paymentFilter = 'all';
  String _customerFilter = 'all';

  List<Map<String, dynamic>> get _filteredSales {
    return widget.sales.where((s) {
      final matchPayment =
          _paymentFilter == 'all' || s['payment_method'] == _paymentFilter;
      final matchCust =
          _customerFilter == 'all' ||
          (s['customer_type'] ?? 'retail') == _customerFilter;
      return matchPayment && matchCust;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredSales;

    return Scaffold(
      appBar: AppBar(
        title: const Text('System Sales Oversight'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: widget.onBack,
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _paymentFilter,
                    decoration: const InputDecoration(
                      labelText: 'Payment Mode',
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'all',
                        child: Text('All Payments'),
                      ),
                      DropdownMenuItem(
                        value: 'online',
                        child: Text('Online Only'),
                      ),
                      DropdownMenuItem(
                        value: 'cash',
                        child: Text('Cash Only'),
                      ),
                    ],
                    onChanged: (v) =>
                        setState(() => _paymentFilter = v ?? 'all'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _customerFilter,
                    decoration: const InputDecoration(
                      labelText: 'Customer Tier',
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'all',
                        child: Text('All Customers'),
                      ),
                      DropdownMenuItem(
                        value: 'retail',
                        child: Text('Retail'),
                      ),
                      DropdownMenuItem(
                        value: 'distributor',
                        child: Text('Distributor'),
                      ),
                    ],
                    onChanged: (v) =>
                        setState(() => _customerFilter = v ?? 'all'),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: filtered.isEmpty
                ? const Center(child: Text('No sales found matching criteria'))
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: filtered.length,
                    itemBuilder: (ctx, idx) {
                      final s = filtered[idx];
                      final isOnline = s['payment_method'] == 'online';
                      return Card(
                        color: AppColors.cardBg,
                        margin: const EdgeInsets.only(bottom: 10),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: isOnline
                                ? Colors.green.shade100
                                : Colors.amber.shade100,
                            child: Icon(
                              isOnline ? Icons.payment : Icons.money,
                              color: isOnline
                                  ? Colors.green
                                  : Colors.amber.shade800,
                            ),
                          ),
                          title: Text(s['product']?['name'] ?? 'Product'),
                          subtitle: Text(
                            'Sold by: ${s['salesman']?['name'] ?? 'Salesman'} • Qty: ${s['quantity']} • ${s['customer_type'] ?? 'retail'}',
                          ),
                          trailing: Text(
                            '₹${s['amount']}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
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
}
