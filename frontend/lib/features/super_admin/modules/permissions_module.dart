import 'package:flutter/material.dart';
import '../../../core/constants/colors.dart';

class PermissionsModule extends StatelessWidget {
  final List<Map<String, dynamic>> permissions;
  final Future<void> Function(String role, String permissionKey, bool currentAllowed) onTogglePermission;
  final VoidCallback onBack;

  const PermissionsModule({
    super.key,
    required this.permissions,
    required this.onTogglePermission,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final roles = ['store_admin', 'field_sales_manager', 'salesman'];
    final capabilities = [
      {'key': 'add_stock', 'title': 'Intake & Add Stock'},
      {'key': 'transfer_fsm', 'title': 'Transfer Stock to FSM'},
      {'key': 'transfer_salesman', 'title': 'Transfer Stock to Salesman'},
      {'key': 'direct_sale', 'title': 'Direct Sale to Customer'},
      {
        'key': 'bulk_sale_distributor',
        'title': 'Bulk Wholesale to Distributor',
      },
      {'key': 'onboard_customer', 'title': 'Onboard New Customer'},
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Role & Permission Matrix'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: onBack,
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Dynamic Access Control (RBAC)',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Toggle capabilities per role in real-time. Changes are logged to the audit trail immediately.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 20),
          for (final r in roles) ...[
            Card(
              color: AppColors.cardBg,
              margin: const EdgeInsets.only(bottom: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: ExpansionTile(
                initiallyExpanded: true,
                title: Text(
                  r.replaceAll('_', ' ').toUpperCase(),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
                subtitle: const Text('Tap to configure capabilities'),
                children: [
                  const Divider(height: 1),
                  for (final cap in capabilities) ...[
                    SwitchListTile(
                      title: Text(cap['title']!),
                      value: permissions.any(
                        (p) =>
                            p['role'] == r &&
                            p['permission_key'] == cap['key'] &&
                            p['is_allowed'] == true,
                      ),
                      activeThumbColor: AppColors.accent,
                      onChanged: (_) {
                        final curr = permissions.any(
                          (p) =>
                              p['role'] == r &&
                              p['permission_key'] == cap['key'] &&
                              p['is_allowed'] == true,
                        );
                        onTogglePermission(r, cap['key']!, curr);
                      },
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
