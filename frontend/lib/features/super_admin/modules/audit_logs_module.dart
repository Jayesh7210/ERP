import 'package:flutter/material.dart';
import '../../../core/constants/colors.dart';

class AuditLogsModule extends StatelessWidget {
  final List<Map<String, dynamic>> auditLogs;
  final VoidCallback onBack;

  const AuditLogsModule({
    super.key,
    required this.auditLogs,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('System Audit Trail & Logs'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: onBack,
        ),
      ),
      body: auditLogs.isEmpty
          ? const Center(child: Text('No audit events logged yet'))
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: auditLogs.length,
              itemBuilder: (ctx, idx) {
                final log = auditLogs[idx];
                return Card(
                  color: AppColors.cardBg,
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Colors.indigo,
                      child: Icon(Icons.history, color: Colors.white),
                    ),
                    title: Text(
                      log['action'] ?? 'ACTION',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'By: ${log['user_name'] ?? 'Admin'} on ${log['entity_name']}',
                        ),
                        Text(
                          '${log['details'] ?? ''}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
