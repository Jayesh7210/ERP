import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import '../../core/constants/colors.dart';
import '../../core/state/app_state.dart';

// 5. WORKFORCE MANAGEMENT PAGE (Comprehensive Directory & Onboarding Approval Queue)
class WorkforceRequestsPage extends StatefulWidget {
  final bool showBackButton;
  final VoidCallback? onBack;

  const WorkforceRequestsPage({super.key, this.showBackButton = false, this.onBack});

  @override
  State<WorkforceRequestsPage> createState() => _WorkforceRequestsPageState();
}

class _WorkforceRequestsPageState extends State<WorkforceRequestsPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<Map<String, dynamic>> _users = [];
  final List<Map<String, dynamic>> _warehouses = [];
  final List<Map<String, dynamic>> _requests = [];
  bool _isLoading = false;

  String _searchQuery = '';
  String _selectedRoleFilter = 'all';
  final TextEditingController _searchController = TextEditingController();

  // For non-admin request submission
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordReqController = TextEditingController();
  final TextEditingController _aadhaarReqController = TextEditingController();
  String _selectedReqKycFile = '';
  String? _selectedReqKycBase64;
  Uint8List? _selectedReqKycBytes;
  String _selectedReqRole = 'salesman';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadAllData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordReqController.dispose();
    _aadhaarReqController.dispose();
    super.dispose();
  }

  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);
    await Future.wait([
      _loadUsers(),
      _loadWarehouses(),
      _loadRequests(),
    ]);
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _loadUsers() async {
    try {
      final res = await http.get(Uri.parse('${AppState.apiBaseUrl}/users'));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as List;
        setState(() {
          _users.clear();
          _users.addAll(data.cast<Map<String, dynamic>>());
        });
      }
    } catch (_) {}
  }

  Future<void> _loadWarehouses() async {
    try {
      final res = await http.get(Uri.parse('${AppState.apiBaseUrl}/warehouses'));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as List;
        setState(() {
          _warehouses.clear();
          _warehouses.addAll(data.cast<Map<String, dynamic>>());
        });
      }
    } catch (_) {}
  }

  Future<void> _loadRequests() async {
    try {
      final res = await http.get(Uri.parse('${AppState.apiBaseUrl}/workforce/requests'));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as List;
        setState(() {
          _requests.clear();
          _requests.addAll(data.cast<Map<String, dynamic>>());
        });
      }
    } catch (_) {}
  }

  List<Map<String, dynamic>> get _filteredUsers {
    return _users.where((u) {
      final role = (u['role'] ?? '').toString();
      final matchRole = _selectedRoleFilter == 'all' || role == _selectedRoleFilter;
      if (!matchRole) return false;

      if (_searchQuery.trim().isEmpty) return true;
      final query = _searchQuery.toLowerCase();
      final name = (u['name'] ?? '').toString().toLowerCase();
      final email = (u['email'] ?? '').toString().toLowerCase();
      final phone = (u['phone'] ?? '').toString().toLowerCase();
      return name.contains(query) || email.contains(query) || phone.contains(query);
    }).toList();
  }

  Color _roleColor(String role) {
    switch (role) {
      case 'super_admin':
        return Colors.purple.shade700;
      case 'store_admin':
        return Colors.teal.shade700;
      case 'field_sales_manager':
        return Colors.indigo.shade700;
      case 'salesman':
        return Colors.blue.shade700;
      case 'distributor':
        return Colors.amber.shade800;
      case 'customer':
        return Colors.green.shade700;
      default:
        return Colors.blueGrey;
    }
  }

  String _roleDisplayName(String role) {
    switch (role) {
      case 'super_admin':
        return 'Super Admin';
      case 'store_admin':
        return 'Store Admin';
      case 'field_sales_manager':
        return 'Field Sales Manager (FSM)';
      case 'salesman':
        return 'Salesman';
      case 'distributor':
        return 'Bulk Distributor';
      case 'customer':
        return 'Retail Customer';
      default:
        return role.replaceAll('_', ' ').toUpperCase();
    }
  }

  String? _getWarehouseName(Map<String, dynamic> u) {
    final wh = u['warehouse'];
    if (wh is Map) return wh['name']?.toString();
    if (wh is List && wh.isNotEmpty && wh[0] is Map) return wh[0]['name']?.toString();
    final whId = u['warehouse_id'];
    if (whId != null) {
      final found = _warehouses.firstWhere((w) => w['id']?.toString() == whId.toString(), orElse: () => {});
      return found['name']?.toString();
    }
    return null;
  }

  String? _getParentName(Map<String, dynamic> u) {
    final parent = u['parent'];
    if (parent is Map) return parent['name']?.toString();
    if (parent is List && parent.isNotEmpty && parent[0] is Map) return parent[0]['name']?.toString();
    final pId = u['parent_id'];
    if (pId != null) {
      final found = _users.firstWhere((p) => p['id']?.toString() == pId.toString(), orElse: () => {});
      return found['name']?.toString();
    }
    return null;
  }

  // ==========================================
  // VIEW WORKER DETAILS MODAL (POPUP WINDOW)
  // Shows: Basic Details, Password, Aadhaar Card
  // ==========================================
  void _showWorkerDetailsDialog(Map<String, dynamic> u) {
    bool obscurePassword = false;
    final role = (u['role'] ?? '').toString();
    final color = _roleColor(role);
    final whName = _getWarehouseName(u) ?? 'Unassigned Hub';
    final parentName = _getParentName(u) ?? 'Direct to Super Admin';
    final password = (u['password'] ?? '').toString();
    final phone = (u['phone'] ?? '').toString();
    final email = (u['email'] ?? '').toString();
    final name = (u['name'] ?? 'Worker').toString();
    final aadhaarNumber = (u['aadhaar_number'] ?? '').toString();
    final rawAadhaarDoc = (u['aadhaar_doc'] ?? u['kyc_doc'] ?? '').toString();
    final aadhaarDoc = (rawAadhaarDoc == 'Aadhaar_Document.pdf') ? '' : rawAadhaarDoc;
    final kycStatus = (u['kyc_status'] ?? (aadhaarDoc.isNotEmpty ? 'Verified' : 'Pending')).toString();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.90,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  // Drag Handle
                  Container(
                    width: 44,
                    height: 5,
                    margin: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),

                  // Header with Worker Title & Close
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 24,
                              backgroundColor: color.withValues(alpha: 0.15),
                              child: Text(
                                name.isNotEmpty ? name[0].toUpperCase() : 'W',
                                style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 18),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                                const SizedBox(height: 2),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: color.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    _roleDisplayName(role).toUpperCase(),
                                    style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 10),
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
                  ),

                  const Divider(height: 20),

                  // Scrollable Content
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 1. PASSWORD CARD (Visible to Super Admin)
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Colors.amber.shade50, Colors.orange.shade50],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.orange.shade200),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(Icons.vpn_key_rounded, color: Colors.orange.shade900, size: 20),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Account Password (Super Admin View)',
                                          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange.shade900, fontSize: 13),
                                        ),
                                      ],
                                    ),
                                    IconButton(
                                      icon: Icon(obscurePassword ? Icons.visibility_off : Icons.visibility, size: 20, color: Colors.orange.shade800),
                                      onPressed: () => setSheetState(() => obscurePassword = !obscurePassword),
                                      tooltip: obscurePassword ? 'Show Password' : 'Hide Password',
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                if (u['requires_password_setup'] == true) ...[
                                  Container(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.amber.shade100,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: Colors.amber.shade400),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.hourglass_top_rounded, size: 14, color: Colors.amber.shade900),
                                        const SizedBox(width: 6),
                                        Text(
                                          'Awaiting Worker First-Time Setup',
                                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.amber.shade900),
                                        ),
                                      ],
                                    ),
                                  ),
                                ] else ...[
                                  Container(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.green.shade50,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: Colors.green.shade300),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.check_circle_outline, size: 14, color: Colors.green.shade800),
                                        const SizedBox(width: 6),
                                        Text(
                                          'Password Set & Active by Worker',
                                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green.shade800),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: Colors.orange.shade200),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        obscurePassword ? '••••••••••••' : password,
                                        style: TextStyle(
                                          fontFamily: 'monospace',
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.grey.shade900,
                                          letterSpacing: obscurePassword ? 3 : 1.5,
                                        ),
                                      ),
                                      Row(
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.copy, size: 18, color: Colors.orange),
                                            tooltip: 'Copy Password',
                                            onPressed: () {
                                              Clipboard.setData(ClipboardData(text: password));
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(
                                                  content: Text('Password for $name copied: $password'),
                                                  backgroundColor: Colors.orange.shade800,
                                                  duration: const Duration(seconds: 2),
                                                ),
                                              );
                                            },
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.edit_note, size: 22, color: Colors.blue),
                                            tooltip: 'Reset/Change Password',
                                            onPressed: () => _promptResetPassword(u),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Super Admin Note: Since there is no self-serve forgot password, provide this password when the worker requests it.',
                                  style: TextStyle(fontSize: 11, color: Colors.orange.shade900, height: 1.3),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 18),

                          // 2. AADHAAR CARD / GOVT ID ("OTHER CARD")
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.grey.shade300),
                              boxShadow: [
                                BoxShadow(color: Colors.grey.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, 3)),
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
                                        Icon(Icons.credit_card, color: Colors.blueAccent, size: 20),
                                        SizedBox(width: 8),
                                        Text(
                                          'Aadhaar Card (Govt ID Proof)',
                                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                        ),
                                      ],
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: Colors.green.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.verified, size: 13, color: Colors.green),
                                          const SizedBox(width: 4),
                                          Text(
                                            kycStatus.toUpperCase(),
                                            style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 10),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 14),

                                // Graphical Aadhaar Card Representation
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [Colors.orange.shade50, Colors.white, Colors.green.shade50],
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.grey.shade300),
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
                                                width: 14,
                                                height: 14,
                                                decoration: const BoxDecoration(
                                                  color: Colors.deepOrange,
                                                  shape: BoxShape.circle,
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              const Text(
                                                'GOVERNMENT OF INDIA',
                                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 0.5),
                                              ),
                                            ],
                                          ),
                                          const Text('आधार / AADHAAR', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.red)),
                                        ],
                                      ),
                                      const Divider(height: 14),
                                      Row(
                                        children: [
                                          Container(
                                            width: 52,
                                            height: 60,
                                            decoration: BoxDecoration(
                                              color: Colors.grey.shade200,
                                              borderRadius: BorderRadius.circular(6),
                                              border: Border.all(color: Colors.grey.shade400),
                                            ),
                                            child: const Icon(Icons.person, size: 36, color: Colors.grey),
                                          ),
                                          const SizedBox(width: 14),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                                const SizedBox(height: 2),
                                                Text('Role: ${_roleDisplayName(role)}', style: const TextStyle(fontSize: 11, color: Colors.blueGrey)),
                                                const SizedBox(height: 2),
                                                Text(
                                                  'Doc: ${aadhaarDoc.isNotEmpty ? (aadhaarDoc.startsWith('data:image') ? 'KYC Photo Attached' : aadhaarDoc) : 'Not Uploaded'}',
                                                  style: const TextStyle(fontSize: 11, color: Colors.blueGrey),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ],
                                            ),
                                          ),
                                          const Icon(Icons.qr_code_2, size: 48, color: Colors.black87),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      Center(
                                        child: Text(
                                          aadhaarNumber.isEmpty
                                              ? 'No Aadhaar Number Provided'
                                              : (aadhaarNumber.length >= 12
                                                  ? '${aadhaarNumber.substring(0, 4)}  ${aadhaarNumber.substring(4, 8)}  ${aadhaarNumber.substring(8)}'
                                                  : aadhaarNumber),
                                          style: TextStyle(
                                            fontFamily: aadhaarNumber.isNotEmpty ? 'monospace' : null,
                                            fontWeight: FontWeight.bold,
                                            fontSize: aadhaarNumber.isNotEmpty ? 16 : 13,
                                            letterSpacing: aadhaarNumber.isNotEmpty ? 2 : 0.5,
                                            color: aadhaarNumber.isNotEmpty ? Colors.black87 : Colors.grey.shade600,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      const Center(
                                        child: Text(
                                          'मेरा आधार, मेरी पहचान',
                                          style: TextStyle(fontSize: 9.5, color: Colors.red, fontWeight: FontWeight.w600),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        'File: ${aadhaarDoc.isNotEmpty ? (aadhaarDoc.startsWith('data:image') ? 'Attached KYC Photo' : aadhaarDoc) : 'Not Uploaded'}',
                                        style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (aadhaarDoc.isNotEmpty || aadhaarNumber.isNotEmpty)
                                      TextButton.icon(
                                        onPressed: () => _previewAadhaarDocument(name, aadhaarNumber, aadhaarDoc),
                                        icon: const Icon(Icons.open_in_new, size: 14),
                                        label: Text(aadhaarDoc.isNotEmpty ? 'View Document' : 'View ID Card', style: const TextStyle(fontSize: 12)),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 18),

                          // 3. BASIC WORKER DETAILS
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.cardBg,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.grey.withValues(alpha: 0.15)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Row(
                                  children: [
                                    Icon(Icons.badge_outlined, color: AppColors.primary, size: 18),
                                    SizedBox(width: 8),
                                    Text('Basic Information', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                _detailRow(Icons.email_outlined, 'Email Address', email, canCopy: true),
                                const Divider(height: 16),
                                _detailRow(Icons.phone_outlined, 'Mobile Number', phone.isNotEmpty ? phone : 'Not Provided', canCopy: phone.isNotEmpty),
                                const Divider(height: 16),
                                _detailRow(Icons.warehouse_outlined, 'Assigned Warehouse', whName),
                                const Divider(height: 16),
                                _detailRow(Icons.supervisor_account_outlined, 'Reports To', parentName),
                                const Divider(height: 16),
                                _detailRow(Icons.fingerprint, 'System ID', u['id']?.toString() ?? 'N/A', canCopy: true),
                              ],
                            ),
                          ),

                          const SizedBox(height: 20),

                          // Action Buttons: Edit / Delete
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () {
                                    Navigator.pop(ctx);
                                    _showAddOrEditUserDialog(editUser: u);
                                  },
                                  icon: const Icon(Icons.edit_outlined, size: 18),
                                  label: const Text('Edit Details'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppColors.primary,
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    Navigator.pop(ctx);
                                    _confirmDeleteUser(u);
                                  },
                                  icon: const Icon(Icons.delete_outline, size: 18),
                                  label: const Text('Remove'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _promptResetPassword(Map<String, dynamic> u) {
    final newPassCtrl = TextEditingController(text: u['password'] ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.lock_reset, color: AppColors.primary),
            const SizedBox(width: 8),
            Expanded(child: Text('Change Password: ${u['name']}', style: const TextStyle(fontSize: 16))),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Enter a new password for this worker. They will be able to log in with this password immediately.',
                style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
            const SizedBox(height: 14),
            TextField(
              controller: newPassCtrl,
              decoration: InputDecoration(
                labelText: 'New Password *',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                prefixIcon: const Icon(Icons.key),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
            onPressed: () async {
              final newPass = newPassCtrl.text.trim();
              if (newPass.length < 4) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password must be at least 4 characters')));
                return;
              }
              try {
                final res = await http.post(
                  Uri.parse('${AppState.apiBaseUrl}/users/${u['id']}/reset-password'),
                  headers: {'Content-Type': 'application/json'},
                  body: jsonEncode({
                    'password': newPass,
                    'admin_id': AppState.currentUser?['id'],
                    'admin_name': AppState.currentUser?['name'],
                  }),
                );
                if (res.statusCode == 200) {
                  setState(() {
                    u['password'] = newPass;
                  });
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('✅ Password updated to "$newPass" for ${u['name']}'), backgroundColor: Colors.green),
                    );
                  }
                  _loadAllData();
                }
              } catch (_) {
                if (ctx.mounted) Navigator.pop(ctx);
              }
            },
            child: const Text('Update Password'),
          ),
        ],
      ),
    );
  }

  void _previewAadhaarDocument(String name, String aadhaarNo, String docName) {
    if (docName.isEmpty && aadhaarNo.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No Aadhaar card or document uploaded for this user.')),
      );
      return;
    }

    Uint8List? imageBytes;
    if (docName.startsWith('data:image/')) {
      try {
        imageBytes = base64Decode(docName.split(',').last);
      } catch (_) {}
    }

    final isNetworkUrl = docName.startsWith('http://') || docName.startsWith('https://');

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Govt ID Document Proof', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
                const SizedBox(height: 10),

                // If real image bytes exist, show the actual photo!
                if (imageBytes != null) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      constraints: const BoxConstraints(maxHeight: 280),
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.black12,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: InteractiveViewer(
                        child: Image.memory(
                          imageBytes,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ] else if (isNetworkUrl) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      constraints: const BoxConstraints(maxHeight: 280),
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.black12,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: InteractiveViewer(
                        child: Image.network(
                          docName,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) => const Padding(
                            padding: EdgeInsets.all(20),
                            child: Icon(Icons.broken_image, size: 48, color: Colors.grey),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // Aadhaar Profile Details Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.orange.shade100, Colors.white, Colors.green.shade100],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Column(
                    children: [
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.verified_user, color: Colors.blue, size: 20),
                          SizedBox(width: 8),
                          Text('AADHAAR IDENTIFICATION CARD', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 0.5)),
                        ],
                      ),
                      const Divider(height: 20),
                      Row(
                        children: [
                          CircleAvatar(radius: 28, backgroundColor: Colors.grey.shade300, child: const Icon(Icons.person, size: 36, color: Colors.white)),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                const SizedBox(height: 2),
                                const Text('Government Verified Profile', style: TextStyle(fontSize: 11, color: Colors.green, fontWeight: FontWeight.w600)),
                                const SizedBox(height: 2),
                                Text(
                                  docName.isNotEmpty
                                      ? (docName.startsWith('data:image') ? 'Attached KYC Photo (Verified)' : 'File: $docName')
                                      : 'No document file uploaded',
                                  style: const TextStyle(fontSize: 11, color: Colors.blueGrey),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
                        child: Text(
                          aadhaarNo.isNotEmpty ? aadhaarNo : 'Aadhaar No. Not Provided',
                          style: TextStyle(
                            fontFamily: aadhaarNo.isNotEmpty ? 'monospace' : null,
                            fontWeight: FontWeight.bold,
                            fontSize: aadhaarNo.isNotEmpty ? 18 : 13,
                            letterSpacing: aadhaarNo.isNotEmpty ? 2.5 : 0.5,
                            color: aadhaarNo.isNotEmpty ? Colors.black87 : Colors.grey.shade600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(42),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Close Preview'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value, {bool canCopy = false}) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.textSecondary),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              const SizedBox(height: 1),
              Text(value, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
            ],
          ),
        ),
        if (canCopy)
          IconButton(
            icon: const Icon(Icons.copy, size: 16, color: AppColors.primary),
            tooltip: 'Copy',
            onPressed: () {
              Clipboard.setData(ClipboardData(text: value));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('$label copied to clipboard'), duration: const Duration(seconds: 1)),
              );
            },
          ),
      ],
    );
  }

  // ==========================================
  // ADD OR EDIT WORKER (SUPER ADMIN)
  // Takes: Password, Phone, Aadhaar Card
  // ==========================================
  void _showAddOrEditUserDialog({Map<String, dynamic>? editUser}) {
    final nameCtrl = TextEditingController(text: editUser?['name'] ?? '');
    final emailCtrl = TextEditingController(text: editUser?['email'] ?? '');
    final phoneCtrl = TextEditingController(text: editUser?['phone'] ?? '');
    final passwordCtrl = TextEditingController(text: editUser?['password'] ?? '');
    final aadhaarCtrl = TextEditingController(text: editUser?['aadhaar_number'] ?? '');
    
    final rawKycDoc = (editUser?['aadhaar_doc'] ?? editUser?['kyc_doc'] ?? '').toString();
    String selectedKycDoc = (rawKycDoc == 'Aadhaar_Document.pdf') ? '' : rawKycDoc;
    String? selectedKycBase64;
    Uint8List? selectedKycBytes;

    if (selectedKycDoc.startsWith('data:image/')) {
      try {
        selectedKycBytes = base64Decode(selectedKycDoc.split(',').last);
      } catch (_) {}
    }

    String selectedRole = editUser?['role'] ?? 'salesman';
    String? selectedWarehouseId = editUser?['warehouse_id']?.toString();
    String? selectedParentId = editUser?['parent_id']?.toString();
    bool isSaving = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            Future<void> pickStaffDoc(ImageSource source) async {
              try {
                final picker = ImagePicker();
                final picked = await picker.pickImage(source: source, imageQuality: 85, maxWidth: 1600);
                if (picked != null) {
                  final bytes = await picked.readAsBytes();
                  final base64Str = 'data:image/jpeg;base64,${base64Encode(bytes)}';
                  setDialogState(() {
                    selectedKycDoc = picked.name;
                    selectedKycBase64 = base64Str;
                    selectedKycBytes = bytes;
                  });
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Attached Aadhaar Document: ${picked.name}'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Could not attach document: $e'), backgroundColor: Colors.red),
                  );
                }
              }
            }

            void showStaffDocSourceSheet() {
              showModalBottomSheet(
                context: ctx,
                useRootNavigator: true,
                shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
                builder: (sheetCtx) => SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(bottom: 8),
                          child: Text('Attach Aadhaar Document / KYC', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        ),
                        ListTile(
                          leading: const CircleAvatar(backgroundColor: Colors.blue, child: Icon(Icons.camera_alt, color: Colors.white)),
                          title: const Text('Take Photo with Camera'),
                          subtitle: const Text('Capture clear photo of physical Aadhaar card'),
                          onTap: () {
                            Navigator.pop(sheetCtx);
                            pickStaffDoc(ImageSource.camera);
                          },
                        ),
                        ListTile(
                          leading: const CircleAvatar(backgroundColor: Colors.orange, child: Icon(Icons.photo_library, color: Colors.white)),
                          title: const Text('Choose from Gallery / Device'),
                          subtitle: const Text('Select Aadhaar card image or scan'),
                          onTap: () {
                            Navigator.pop(sheetCtx);
                            pickStaffDoc(ImageSource.gallery);
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                    child: Icon(editUser != null ? Icons.manage_accounts : Icons.person_add, color: AppColors.primary),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      editUser != null ? 'Edit Staff Account' : 'Add Staff Account',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameCtrl,
                      decoration: InputDecoration(
                        labelText: 'Full Name *',
                        prefixIcon: const Icon(Icons.person_outline),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: 'Email Address *',
                        prefixIcon: const Icon(Icons.email_outlined),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: phoneCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: 'Phone Number (Mobile) *',
                        prefixIcon: const Icon(Icons.phone_outlined),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Password input field
                    TextField(
                      controller: passwordCtrl,
                      decoration: InputDecoration(
                        labelText: 'Login Password *',
                        hintText: 'Enter login password for staff',
                        prefixIcon: const Icon(Icons.lock_outline),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Aadhaar Card Number
                    TextField(
                      controller: aadhaarCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Aadhaar Card Number (Govt ID) *',
                        hintText: '12-digit Aadhaar number',
                        prefixIcon: const Icon(Icons.credit_card),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Aadhaar Document Attachment
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: selectedKycDoc.isNotEmpty ? Colors.blue.withValues(alpha: 0.05) : Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: selectedKycDoc.isNotEmpty ? Colors.blue.shade300 : Colors.grey.shade300,
                          width: selectedKycDoc.isNotEmpty ? 1.5 : 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                selectedKycDoc.isNotEmpty ? Icons.verified : Icons.credit_card,
                                color: selectedKycDoc.isNotEmpty ? Colors.blue : Colors.grey.shade600,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Text(
                                  'Aadhaar Document (KYC)',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (selectedKycDoc.isNotEmpty) ...[
                                const SizedBox(width: 8),
                                GestureDetector(
                                  onTap: () {
                                    setDialogState(() {
                                      selectedKycDoc = '';
                                      selectedKycBase64 = null;
                                      selectedKycBytes = null;
                                    });
                                  },
                                  child: const Text('Remove', style: TextStyle(fontSize: 11, color: Colors.red, fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ],
                          ),
                          if (selectedKycBytes != null) ...[
                            const SizedBox(height: 10),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.memory(
                                selectedKycBytes!,
                                height: 110,
                                width: double.infinity,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ],
                          const SizedBox(height: 8),
                          InkWell(
                            onTap: showStaffDocSourceSheet,
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    selectedKycDoc.isNotEmpty ? Icons.check_circle : Icons.upload_file,
                                    size: 16,
                                    color: selectedKycDoc.isNotEmpty ? Colors.green : Colors.blue,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      selectedKycDoc.isNotEmpty
                                          ? (selectedKycDoc.startsWith('data:image') ? 'KYC Photo Attached' : selectedKycDoc)
                                          : 'Tap to take photo or choose file',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: selectedKycDoc.isNotEmpty ? FontWeight.bold : FontWeight.normal,
                                        color: selectedKycDoc.isNotEmpty ? Colors.black87 : Colors.grey.shade600,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Text(
                                    selectedKycDoc.isNotEmpty ? 'Change' : 'Attach',
                                    style: const TextStyle(fontSize: 11.5, color: Colors.blue, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: selectedRole,
                      decoration: InputDecoration(
                        labelText: 'Role *',
                        prefixIcon: const Icon(Icons.badge_outlined),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'store_admin', child: Text('Warehouse Admin (Store Admin)', overflow: TextOverflow.ellipsis)),
                        DropdownMenuItem(value: 'field_sales_manager', child: Text('Field Sales Manager (FSM)', overflow: TextOverflow.ellipsis)),
                        DropdownMenuItem(value: 'salesman', child: Text('Field Salesman', overflow: TextOverflow.ellipsis)),
                        DropdownMenuItem(value: 'distributor', child: Text('Bulk Distributor', overflow: TextOverflow.ellipsis)),
                        DropdownMenuItem(value: 'customer', child: Text('Retail Customer', overflow: TextOverflow.ellipsis)),
                      ],
                      onChanged: (v) {
                        if (v != null) setDialogState(() => selectedRole = v);
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String?>(
                      isExpanded: true,
                      initialValue: selectedWarehouseId,
                      decoration: InputDecoration(
                        labelText: 'Assigned Warehouse',
                        prefixIcon: const Icon(Icons.warehouse_outlined),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('None (Unassigned)', overflow: TextOverflow.ellipsis)),
                        ..._warehouses.map((w) => DropdownMenuItem(
                              value: w['id']?.toString(),
                              child: Text(w['name'] ?? 'Hub', maxLines: 1, overflow: TextOverflow.ellipsis),
                            )),
                      ],
                      onChanged: (v) => setDialogState(() => selectedWarehouseId = v),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String?>(
                      isExpanded: true,
                      initialValue: selectedParentId,
                      decoration: InputDecoration(
                        labelText: 'Reports To (Supervisor)',
                        prefixIcon: const Icon(Icons.supervisor_account_outlined),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('None (Direct to Super Admin)', overflow: TextOverflow.ellipsis)),
                        ..._users.where((u) => u['id'] != editUser?['id']).map((u) => DropdownMenuItem(
                              value: u['id']?.toString(),
                              child: Text('${u['name']} (${_roleDisplayName(u['role'] ?? '')})', maxLines: 1, overflow: TextOverflow.ellipsis),
                            )),
                      ],
                      onChanged: (v) => setDialogState(() => selectedParentId = v),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: isSaving
                      ? null
                      : () async {
                          if (nameCtrl.text.trim().isEmpty || emailCtrl.text.trim().isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Please enter name and email')),
                            );
                            return;
                          }

                          setDialogState(() => isSaving = true);
                          final body = {
                            'name': nameCtrl.text.trim(),
                            'email': emailCtrl.text.trim(),
                            'phone': phoneCtrl.text.trim(),
                            'password': passwordCtrl.text.trim(),
                            'aadhaar_number': aadhaarCtrl.text.trim(),
                            'aadhaar_doc': selectedKycBase64 ?? selectedKycDoc,
                            'role': selectedRole,
                            'warehouse_id': selectedWarehouseId,
                            'parent_id': selectedParentId,
                            'admin_id': AppState.currentUser?['id'],
                            'admin_name': AppState.currentUser?['name'],
                          };

                          try {
                            if (editUser != null) {
                              await http.put(
                                Uri.parse('${AppState.apiBaseUrl}/users/${editUser['id']}'),
                                headers: {'Content-Type': 'application/json'},
                                body: jsonEncode(body),
                              );
                            } else {
                              await http.post(
                                Uri.parse('${AppState.apiBaseUrl}/users'),
                                headers: {'Content-Type': 'application/json'},
                                body: jsonEncode(body),
                              );
                            }
                            if (ctx.mounted) Navigator.pop(ctx);
                            _loadAllData();
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(editUser != null ? '✅ Staff member updated!' : '✅ New staff member created!'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            }
                          } catch (_) {
                            if (ctx.mounted) Navigator.pop(ctx);
                            _loadAllData();
                          }
                        },
                  child: isSaving
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text(editUser != null ? 'Save Changes' : 'Create Account'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _confirmDeleteUser(Map<String, dynamic> user) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red),
            SizedBox(width: 8),
            Text('Delete Account'),
          ],
        ),
        content: Text('Are you sure you want to remove "${user['name']}" (${user['email']})? This user will no longer be able to log in.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              try {
                await http.delete(
                  Uri.parse('${AppState.apiBaseUrl}/users/${user['id']}?admin_id=${AppState.currentUser?['id']}&admin_name=${AppState.currentUser?['name']}'),
                );
                if (ctx.mounted) Navigator.pop(ctx);
                _loadAllData();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Account removed successfully'), backgroundColor: Colors.red),
                  );
                }
              } catch (_) {
                if (ctx.mounted) Navigator.pop(ctx);
                _loadAllData();
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleApproval(String id, bool approve) async {
    try {
      final res = await http.post(
        Uri.parse('${AppState.apiBaseUrl}/workforce/approve'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'request_id': id,
          'approve': approve,
        }),
      );
      if (res.statusCode == 200) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(approve ? '✅ Request approved! Staff account created.' : 'Request rejected.'),
            backgroundColor: approve ? Colors.green : Colors.red,
          ),
        );
        _loadAllData();
      }
    } catch (_) {
      setState(() => _requests.removeWhere((r) => r['id'] == id));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(approve ? 'Request approved' : 'Request rejected')),
      );
    }
  }

  Future<void> _submitAddRequest() async {
    if (_nameController.text.trim().isEmpty || _emailController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill name and email')));
      return;
    }

    try {
      await http.post(
        Uri.parse('${AppState.apiBaseUrl}/workforce/request'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'name': _nameController.text.trim(),
          'email': _emailController.text.trim(),
          'phone': _phoneController.text.trim(),
          'password': _passwordReqController.text.trim(),
          'aadhaar_number': _aadhaarReqController.text.trim(),
          'kyc_doc': _selectedReqKycBase64 ?? _selectedReqKycFile,
          'role': _selectedReqRole,
          'requested_by': AppState.currentUser?['id'],
          'warehouse_id': AppState.currentUser?['warehouse_id'],
          'parent_id': AppState.currentUser?['id'],
        }),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Onboarding request sent to Super Admin!'), backgroundColor: Colors.green),
      );
      _nameController.clear();
      _emailController.clear();
      _phoneController.clear();
      _passwordReqController.clear();
      _aadhaarReqController.clear();
      setState(() {
        _selectedReqKycFile = '';
        _selectedReqKycBase64 = null;
        _selectedReqKycBytes = null;
      });
      _loadRequests();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Request submitted for approval!'), backgroundColor: Colors.green),
      );
      _nameController.clear();
      _emailController.clear();
      _phoneController.clear();
      _passwordReqController.clear();
      _aadhaarReqController.clear();
      setState(() {
        _selectedReqKycFile = '';
        _selectedReqKycBase64 = null;
        _selectedReqKycBytes = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!AppState.isSuperAdmin) {
      return _buildNonAdminSubmitView();
    }

    final pendingCount = _requests.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Workforce & Team Management'),
        leading: widget.showBackButton
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: widget.onBack ?? () => Navigator.maybePop(context),
              )
            : null,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAllData,
            tooltip: 'Refresh All',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: [
            Tab(
              icon: const Icon(Icons.people_alt_outlined, size: 20),
              text: 'Staff Directory (${_users.length})',
            ),
            Tab(
              icon: Badge(
                isLabelVisible: pendingCount > 0,
                label: Text('$pendingCount'),
                backgroundColor: Colors.red,
                child: const Icon(Icons.how_to_reg_outlined, size: 20),
              ),
              text: 'Approval Queue${pendingCount > 0 ? " ($pendingCount)" : ""}',
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildStaffDirectoryTab(),
                _buildApprovalQueueTab(),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddOrEditUserDialog(),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.person_add, color: Colors.white),
        label: const Text('Add Staff', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildStaffDirectoryTab() {
    final filtered = _filteredUsers;
    final storeAdmins = _users.where((u) => u['role'] == 'store_admin').length;
    final fsms = _users.where((u) => u['role'] == 'field_sales_manager').length;
    final salesmen = _users.where((u) => u['role'] == 'salesman').length;

    return RefreshIndicator(
      onRefresh: _loadAllData,
      child: Column(
        children: [
          // 1. KPI Metric Strip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.cardBg,
              border: Border(bottom: BorderSide(color: Colors.grey.withValues(alpha: 0.15))),
            ),
            child: Row(
              children: [
                _metricMiniCard('Total Staff', '${_users.length}', Colors.purple.shade700, Icons.group),
                const SizedBox(width: 8),
                _metricMiniCard('Store Admins', '$storeAdmins', Colors.teal.shade700, Icons.warehouse),
                const SizedBox(width: 8),
                _metricMiniCard('FSMs', '$fsms', Colors.indigo.shade700, Icons.badge),
                const SizedBox(width: 8),
                _metricMiniCard('Salesmen', '$salesmen', Colors.blue.shade700, Icons.directions_walk),
              ],
            ),
          ),

          // 2. Search Field
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search staff by name, email, phone...',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                filled: true,
                fillColor: AppColors.cardBg,
              ),
              onChanged: (v) => setState(() => _searchQuery = v),
            ),
          ),

          // 3. Role Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            child: Row(
              children: [
                _roleFilterChip('all', 'All (${_users.length})'),
                _roleFilterChip('store_admin', 'Store Admins ($storeAdmins)'),
                _roleFilterChip('field_sales_manager', 'FSMs ($fsms)'),
                _roleFilterChip('salesman', 'Salesmen ($salesmen)'),
                _roleFilterChip('distributor', 'Distributors (${_users.where((u) => u['role'] == 'distributor').length})'),
                _roleFilterChip('customer', 'Customers (${_users.where((u) => u['role'] == 'customer').length})'),
              ],
            ),
          ),
          const SizedBox(height: 6),

          // 4. Staff List
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.person_search_outlined, size: 54, color: AppColors.textSecondary.withValues(alpha: 0.4)),
                          const SizedBox(height: 12),
                          const Text('No Staff Members Found', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                          const SizedBox(height: 6),
                          Text(
                            _searchQuery.isNotEmpty ? 'Try changing your search term or filter' : 'Tap the "+ Add Staff" button to register team members',
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(14, 6, 14, 80),
                    itemCount: filtered.length,
                    itemBuilder: (ctx, idx) {
                      final u = filtered[idx];
                      final role = (u['role'] ?? '').toString();
                      final color = _roleColor(role);
                      final whName = _getWarehouseName(u);
                      final parentName = _getParentName(u);
                      final phone = u['phone']?.toString();

                      return Card(
                        color: AppColors.cardBg,
                        elevation: 1.5,
                        margin: const EdgeInsets.only(bottom: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: BorderSide(color: Colors.grey.withValues(alpha: 0.12)),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 20,
                                    backgroundColor: color.withValues(alpha: 0.12),
                                    child: Text(
                                      (u['name'] ?? 'U').toString().substring(0, 1).toUpperCase(),
                                      style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(u['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                        const SizedBox(height: 2),
                                        Text(u['email'] ?? '', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: color.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      _roleDisplayName(role).split('(')[0].trim().toUpperCase(),
                                      style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 10.5),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 12,
                                runSpacing: 6,
                                children: [
                                  if (phone != null && phone.trim().isNotEmpty)
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.phone_outlined, size: 14, color: AppColors.textSecondary),
                                        const SizedBox(width: 4),
                                        Text(phone, style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
                                      ],
                                    ),
                                  if (whName != null && whName.trim().isNotEmpty)
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.warehouse_outlined, size: 14, color: AppColors.textSecondary),
                                        const SizedBox(width: 4),
                                        Text(whName, style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
                                      ],
                                    ),
                                  if (parentName != null && parentName.trim().isNotEmpty)
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.supervisor_account_outlined, size: 14, color: AppColors.textSecondary),
                                        const SizedBox(width: 4),
                                        Text('Reports to: $parentName', style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
                                      ],
                                    ),
                                ],
                              ),
                              const Divider(height: 18),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  ElevatedButton.icon(
                                    onPressed: () => _showWorkerDetailsDialog(u),
                                    icon: const Icon(Icons.visibility_outlined, size: 16),
                                    label: const Text('View Details'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                                      foregroundColor: AppColors.primary,
                                      elevation: 0,
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  TextButton.icon(
                                    onPressed: () => _showAddOrEditUserDialog(editUser: u),
                                    icon: const Icon(Icons.edit_outlined, size: 16),
                                    label: const Text('Edit'),
                                    style: TextButton.styleFrom(
                                      foregroundColor: AppColors.textSecondary,
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  TextButton.icon(
                                    onPressed: () => _confirmDeleteUser(u),
                                    icon: const Icon(Icons.delete_outline, size: 16),
                                    label: const Text('Delete'),
                                    style: TextButton.styleFrom(
                                      foregroundColor: Colors.red,
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    ),
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

  Widget _buildApprovalQueueTab() {
    if (_requests.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle_outline, size: 48, color: Colors.green),
              ),
              const SizedBox(height: 16),
              const Text('All Caught Up!', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              const SizedBox(height: 8),
              const Text(
                'No pending workforce onboarding requests.\nWhen Store Admins or Field Sales Managers request new staff or salesmen, they will appear here for your review and approval.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary, height: 1.4),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadAllData,
      child: ListView.builder(
        padding: const EdgeInsets.all(14),
        itemCount: _requests.length,
        itemBuilder: (ctx, idx) {
          final req = _requests[idx];
          final role = (req['role'] ?? 'salesman').toString();
          final color = _roleColor(role);
          final aadhaarNo = (req['aadhaar_number'] ?? '').toString();
          final rawKycDoc = (req['kyc_doc'] ?? req['aadhaar_doc'] ?? '').toString();
          final kycDoc = (rawKycDoc == 'Aadhaar_Document.pdf') ? '' : rawKycDoc;
          final password = (req['password'] ?? '').toString();

          return Card(
            color: AppColors.cardBg,
            elevation: 2,
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(req['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
                        child: Text(
                          _roleDisplayName(role).split('(')[0].trim().toUpperCase(),
                          style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text('Email: ${req['email'] ?? 'N/A'}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                  if (req['phone'] != null && req['phone'].toString().isNotEmpty)
                    Text('Phone: ${req['phone']}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                  const SizedBox(height: 6),

                  // Display Proposed Password & Aadhaar info for Super Admin Review
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.withValues(alpha: 0.2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.vpn_key_rounded, size: 14, color: Colors.orange),
                            const SizedBox(width: 6),
                            Text('Initial Password: ${password.isNotEmpty ? password : 'None set'}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.orange)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.credit_card, size: 14, color: Colors.blue),
                                const SizedBox(width: 6),
                                Text('Aadhaar: ${aadhaarNo.isNotEmpty ? aadhaarNo : 'Not provided'}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                              ],
                            ),
                            if (kycDoc.isNotEmpty || aadhaarNo.isNotEmpty)
                              TextButton.icon(
                                onPressed: () => _previewAadhaarDocument(req['name'] ?? 'Worker', aadhaarNo, kycDoc),
                                icon: const Icon(Icons.open_in_new, size: 12),
                                label: Text(kycDoc.isNotEmpty ? 'View Aadhaar' : 'View ID', style: const TextStyle(fontSize: 11)),
                                style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(50, 24)),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  if (req['requested_by'] != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text('Requested by: ${req['requested_by']?['name'] ?? 'Supervisor'}',
                          style: const TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w600)),
                    ),
                  const Divider(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => _handleApproval(req['id']?.toString() ?? '', false),
                        icon: const Icon(Icons.close, size: 16),
                        label: const Text('Reject'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton.icon(
                        onPressed: () => _handleApproval(req['id']?.toString() ?? '', true),
                        icon: const Icon(Icons.check, size: 16),
                        label: const Text('Approve & Onboard'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildNonAdminSubmitView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Request Team Member Onboarding', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          const SizedBox(height: 6),
          const Text('Submit candidate details to add workforce under you. The request will be sent to the Super Admin for sign-off.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          const SizedBox(height: 20),
          Card(
            color: AppColors.cardBg,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  TextField(controller: _nameController, decoration: const InputDecoration(labelText: 'Full Name *')),
                  const SizedBox(height: 12),
                  TextField(controller: _emailController, decoration: const InputDecoration(labelText: 'Email Address *')),
                  const SizedBox(height: 12),
                  TextField(controller: _phoneController, decoration: const InputDecoration(labelText: 'Phone Number (Mobile) *')),
                  const SizedBox(height: 12),
                  TextField(controller: _passwordReqController, decoration: const InputDecoration(labelText: 'Initial Password *')),
                  const SizedBox(height: 12),
                  TextField(controller: _aadhaarReqController, decoration: const InputDecoration(labelText: 'Aadhaar Card Number *', hintText: '12-digit number')),
                  const SizedBox(height: 12),

                  // Aadhaar Document Upload
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _selectedReqKycFile.isNotEmpty ? Colors.blue.withValues(alpha: 0.05) : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _selectedReqKycFile.isNotEmpty ? Colors.blue.shade300 : Colors.grey.shade300,
                        width: _selectedReqKycFile.isNotEmpty ? 1.5 : 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              _selectedReqKycFile.isNotEmpty ? Icons.verified : Icons.credit_card,
                              color: _selectedReqKycFile.isNotEmpty ? Colors.blue : Colors.grey.shade600,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                'Upload Aadhaar Card (KYC)',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (_selectedReqKycFile.isNotEmpty) ...[
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _selectedReqKycFile = '';
                                    _selectedReqKycBase64 = null;
                                    _selectedReqKycBytes = null;
                                  });
                                },
                                child: const Text('Remove', style: TextStyle(fontSize: 11, color: Colors.red, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ],
                        ),
                        if (_selectedReqKycBytes != null) ...[
                          const SizedBox(height: 10),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.memory(
                              _selectedReqKycBytes!,
                              height: 110,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ],
                        const SizedBox(height: 8),
                        InkWell(
                          onTap: () {
                            showModalBottomSheet(
                              context: context,
                              shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
                              builder: (sheetCtx) => SafeArea(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Padding(
                                        padding: EdgeInsets.only(bottom: 8),
                                        child: Text('Attach Aadhaar Document / KYC', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                      ),
                                      ListTile(
                                        leading: const CircleAvatar(backgroundColor: Colors.blue, child: Icon(Icons.camera_alt, color: Colors.white)),
                                        title: const Text('Take Photo with Camera'),
                                        subtitle: const Text('Capture clear photo of physical Aadhaar card'),
                                        onTap: () async {
                                          Navigator.pop(sheetCtx);
                                          try {
                                            final picker = ImagePicker();
                                            final picked = await picker.pickImage(source: ImageSource.camera, imageQuality: 85, maxWidth: 1600);
                                            if (picked != null) {
                                              final bytes = await picked.readAsBytes();
                                              final base64Str = 'data:image/jpeg;base64,${base64Encode(bytes)}';
                                              setState(() {
                                                _selectedReqKycFile = picked.name;
                                                _selectedReqKycBase64 = base64Str;
                                                _selectedReqKycBytes = bytes;
                                              });
                                            }
                                          } catch (_) {}
                                        },
                                      ),
                                      ListTile(
                                        leading: const CircleAvatar(backgroundColor: Colors.orange, child: Icon(Icons.photo_library, color: Colors.white)),
                                        title: const Text('Choose from Gallery / Device'),
                                        subtitle: const Text('Select Aadhaar card image or scan'),
                                        onTap: () async {
                                          Navigator.pop(sheetCtx);
                                          try {
                                            final picker = ImagePicker();
                                            final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85, maxWidth: 1600);
                                            if (picked != null) {
                                              final bytes = await picked.readAsBytes();
                                              final base64Str = 'data:image/jpeg;base64,${base64Encode(bytes)}';
                                              setState(() {
                                                _selectedReqKycFile = picked.name;
                                                _selectedReqKycBase64 = base64Str;
                                                _selectedReqKycBytes = bytes;
                                              });
                                            }
                                          } catch (_) {}
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  _selectedReqKycFile.isNotEmpty ? Icons.check_circle : Icons.upload_file,
                                  size: 16,
                                  color: _selectedReqKycFile.isNotEmpty ? Colors.green : Colors.blue,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _selectedReqKycFile.isNotEmpty
                                        ? (_selectedReqKycFile.startsWith('data:image') ? 'KYC Photo Attached' : _selectedReqKycFile)
                                        : 'Tap to take photo or choose file',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: _selectedReqKycFile.isNotEmpty ? FontWeight.bold : FontWeight.normal,
                                      color: _selectedReqKycFile.isNotEmpty ? Colors.black87 : Colors.grey.shade600,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Text(
                                  _selectedReqKycFile.isNotEmpty ? 'Change' : 'Attach',
                                  style: const TextStyle(fontSize: 11.5, color: Colors.blue, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  DropdownButtonFormField<String>(
                    initialValue: _selectedReqRole,
                    decoration: const InputDecoration(labelText: 'Role *'),
                    items: [
                      if (AppState.isStoreAdmin) const DropdownMenuItem(value: 'field_sales_manager', child: Text('Field Sales Manager (FSM)')),
                      const DropdownMenuItem(value: 'salesman', child: Text('Salesman')),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedReqRole = val);
                    },
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _submitAddRequest,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Send Onboarding Request to Super Admin'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _metricMiniCard(String label, String value, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 4),
            Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: color)),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(fontSize: 9.5, color: AppColors.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }

  Widget _roleFilterChip(String role, String label) {
    final isSelected = _selectedRoleFilter == role;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
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
          if (selected) setState(() => _selectedRoleFilter = role);
        },
      ),
    );
  }
}
