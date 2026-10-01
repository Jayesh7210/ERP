import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../../core/constants/colors.dart';
import '../../core/services/session_service.dart';
import '../../core/state/app_state.dart';
import '../shell/dashboard_shell.dart';

// LOGIN PAGE (Traditional Mobile Number or Email + Password Authentication)
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _identifierController = TextEditingController(text: 'admin@erp.com');
  final TextEditingController _passwordController = TextEditingController(text: 'admin123');
  bool _obscurePassword = true;
  bool _isLoading = false;
  String _errorMessage = '';
  DateTime? _lastBackPressTime;

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleBackNavigation() {
    final now = DateTime.now();
    if (_lastBackPressTime == null || now.difference(_lastBackPressTime!) > const Duration(seconds: 2)) {
      _lastBackPressTime = now;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Press back again to exit'),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    SystemNavigator.pop();
  }

  Future<void> _handleLogin() async {
    final identifier = _identifierController.text.trim();
    final password = _passwordController.text.trim();

    if (identifier.isEmpty) {
      setState(() => _errorMessage = 'Please enter your mobile number or email address');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final response = await http.post(
        Uri.parse('${AppState.apiBaseUrl}/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'identifier': identifier,
          'password': password,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        if (data['requires_password_setup'] == true) {
          if (mounted) {
            _showFirstTimePasswordSetupSheet(data['user'] ?? {'phone': identifier, 'email': identifier});
          }
          return;
        }

        AppState.currentUser = data['user'];
        await SessionService.saveUser(AppState.currentUser!, token: data['token']);
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const DashboardShell()),
          );
        }
      } else {
        setState(() {
          _errorMessage = data['error'] ?? 'Login failed. Please verify your credentials.';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Unable to connect to server. Please check your internet connection or server settings.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showFirstTimeActivationModal() {
    final activeIdCtrl = TextEditingController(text: _identifierController.text.trim());
    bool isChecking = false;
    String statusError = '';
    Map<String, dynamic>? verifiedUser;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 5,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(3)),
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.verified_user_outlined, color: AppColors.primary, size: 24),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Account Activation', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            Text('First-time login setup for approved staff', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                          ],
                        ),
                      ),
                      IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                    ],
                  ),
                  const SizedBox(height: 18),
                  if (verifiedUser == null) ...[
                    const Text(
                      'Enter your registered Mobile Number (or Email) to verify your approved account and create your login password.',
                      style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: activeIdCtrl,
                      decoration: InputDecoration(
                        labelText: 'Registered Mobile Number or Email',
                        hintText: 'e.g. +91 98765 44444',
                        prefixIcon: const Icon(Icons.phone_android),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    if (statusError.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.amber.shade300),
                        ),
                        child: Text(statusError, style: TextStyle(color: Colors.brown.shade800, fontSize: 12)),
                      ),
                    ],
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: isChecking
                          ? null
                          : () async {
                              final idVal = activeIdCtrl.text.trim();
                              if (idVal.isEmpty) {
                                setSheetState(() => statusError = 'Please enter your mobile number or email');
                                return;
                              }
                              setSheetState(() {
                                isChecking = true;
                                statusError = '';
                              });
                              try {
                                final res = await http.post(
                                  Uri.parse('${AppState.apiBaseUrl}/auth/check-status'),
                                  headers: {'Content-Type': 'application/json'},
                                  body: jsonEncode({'identifier': idVal}),
                                );
                                final resData = jsonDecode(res.body);
                                if (res.statusCode == 200) {
                                  if (resData['status'] == 'pending_approval') {
                                    setSheetState(() {
                                      isChecking = false;
                                      statusError = '⏳ ${resData['message']}';
                                    });
                                  } else if (resData['status'] == 'already_setup') {
                                    setSheetState(() {
                                      isChecking = false;
                                      statusError = 'Password has already been set for this account. Please login using your password, or contact Super Admin if forgotten.';
                                    });
                                  } else {
                                    setSheetState(() {
                                      isChecking = false;
                                      verifiedUser = resData['user'];
                                    });
                                  }
                                } else {
                                  setSheetState(() {
                                    isChecking = false;
                                    statusError = resData['error'] ?? 'Staff account not found.';
                                  });
                                }
                              } catch (e) {
                                setSheetState(() {
                                  isChecking = false;
                                  statusError = 'Unable to connect to server. Check server connection.';
                                });
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: isChecking
                          ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Text('Verify Account & Proceed', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    ),
                  ] else ...[
                    FirstTimePasswordSetupForm(
                      user: verifiedUser!,
                      identifier: activeIdCtrl.text.trim(),
                      onSuccess: () {
                        if (ctx.mounted) Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('🎉 Welcome ${AppState.currentUser?['name'] ?? 'Worker'}! Account activated and logged in.'),
                            backgroundColor: Colors.green,
                          ),
                        );
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (context) => const DashboardShell()),
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showFirstTimePasswordSetupSheet(Map<String, dynamic> user) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(3)),
                  ),
                ),
                FirstTimePasswordSetupForm(
                  user: user,
                  identifier: (user['phone'] ?? user['email'] ?? _identifierController.text.trim()).toString(),
                  onSuccess: () {
                    if (ctx.mounted) Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('🎉 Welcome ${AppState.currentUser?['name'] ?? 'Worker'}! Account activated and logged in.'),
                        backgroundColor: Colors.green,
                      ),
                    );
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (context) => const DashboardShell()),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showServerConfigDialog() {
    final urlCtrl = TextEditingController(text: AppState.apiBaseUrl);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.dns_outlined, color: AppColors.primary),
            SizedBox(width: 8),
            Text('Server Configuration', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Specify your backend API endpoint. For physical devices on Wi-Fi, use your PC LAN IP (e.g. http://192.168.0.x:5000/api).',
              style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: urlCtrl,
              decoration: InputDecoration(
                labelText: 'Backend API URL',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                prefixIcon: const Icon(Icons.link),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              urlCtrl.text = 'http://localhost:5000/api';
            },
            child: const Text('Reset Default'),
          ),
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
            onPressed: () async {
              final newUrl = urlCtrl.text.trim();
              if (newUrl.isNotEmpty) {
                setState(() => AppState.apiBaseUrl = newUrl);
                await SessionService.saveApiBaseUrl(newUrl);
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Server endpoint saved: $newUrl'), backgroundColor: Colors.green),
                  );
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, dynamic result) {
        if (didPop) return;
        _handleBackNavigation();
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(Icons.settings_outlined, color: AppColors.textSecondary),
              tooltip: 'Configure Server URL',
              onPressed: _showServerConfigDialog,
            ),
          ],
        ),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(
                  Icons.pie_chart,
                  size: 72,
                  color: AppColors.primary,
                ),
                const SizedBox(height: 14),
                const Text(
                  'DISTRIBUTION ERP',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Supply chain & sales operations portal',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                ),
                const SizedBox(height: 36),

                // Identifier: Mobile Number or Email
                TextField(
                  controller: _identifierController,
                  decoration: InputDecoration(
                    labelText: 'Mobile Number or Email *',
                    hintText: 'e.g. admin@erp.com or +91 99999 00001',
                    prefixIcon: const Icon(Icons.person_outline),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 16),

                // Password Field
                TextField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'Password *',
                    hintText: 'Enter your password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 10),

                // Forgot Password notice
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, size: 16, color: Colors.blue),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Forgot password? Contact your Super Admin to view or reset your password.',
                          style: TextStyle(fontSize: 11.5, color: Colors.blueGrey),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                if (_errorMessage.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 14.0),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        _errorMessage,
                        style: const TextStyle(color: Colors.red, fontSize: 13, fontWeight: FontWeight.w500),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),

                ElevatedButton(
                  onPressed: _isLoading ? null : _handleLogin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Text('Login to Dashboard', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),

                const SizedBox(height: 12),

                OutlinedButton.icon(
                  onPressed: _showFirstTimeActivationModal,
                  icon: const Icon(Icons.stars_rounded, size: 18, color: AppColors.primary),
                  label: const Text(
                    'First Time Login? Activate & Set Password',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary, width: 1.2),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class FirstTimePasswordSetupForm extends StatefulWidget {
  final Map<String, dynamic> user;
  final String identifier;
  final VoidCallback onSuccess;

  const FirstTimePasswordSetupForm({
    super.key,
    required this.user,
    required this.identifier,
    required this.onSuccess,
  });

  @override
  State<FirstTimePasswordSetupForm> createState() => _FirstTimePasswordSetupFormState();
}

class _FirstTimePasswordSetupFormState extends State<FirstTimePasswordSetupForm> {
  late final TextEditingController _newPassCtrl;
  late final TextEditingController _confirmPassCtrl;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _isSubmitting = false;
  String _formError = '';

  @override
  void initState() {
    super.initState();
    _newPassCtrl = TextEditingController();
    _confirmPassCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _newPassCtrl.dispose();
    _confirmPassCtrl.dispose();
    super.dispose();
  }

  Future<void> _submitPassword() async {
    final p1 = _newPassCtrl.text.trim();
    final p2 = _confirmPassCtrl.text.trim();
    if (p1.length < 4) {
      setState(() => _formError = 'Password must be at least 4 characters long.');
      return;
    }
    if (p1 != p2) {
      setState(() => _formError = 'Passwords do not match. Please re-check.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _formError = '';
    });

    try {
      final setupRes = await http.post(
        Uri.parse('${AppState.apiBaseUrl}/auth/setup-password'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'identifier': widget.identifier,
          'password': p1,
        }),
      );

      if (setupRes.statusCode == 200) {
        final resData = jsonDecode(setupRes.body);
        AppState.currentUser = resData['user'];
        await SessionService.saveUser(AppState.currentUser!, token: resData['token']);
        if (!mounted) return;
        widget.onSuccess();
      } else {
        final errData = jsonDecode(setupRes.body);
        if (mounted) {
          setState(() {
            _isSubmitting = false;
            _formError = errData['error'] ?? 'Failed to set password.';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _formError = 'Failed to connect to server. Please check your network.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.green.shade200),
          ),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: Colors.green.shade600,
                foregroundColor: Colors.white,
                radius: 20,
                child: Text(
                  ((user['name'] ?? 'W') as String).isNotEmpty ? (user['name'] as String)[0].toUpperCase() : 'W',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user['name'] ?? 'Staff Member', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    Text('${user['role'] ?? 'Salesman'} • ${user['phone'] ?? widget.identifier}', style: TextStyle(fontSize: 12, color: Colors.green.shade900)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: Colors.green.shade200, borderRadius: BorderRadius.circular(6)),
                child: const Text('APPROVED', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.green)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Align(
          alignment: Alignment.centerLeft,
          child: Text('Create Your Account Password:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _newPassCtrl,
          obscureText: _obscureNew,
          decoration: InputDecoration(
            labelText: 'New Password *',
            hintText: 'At least 4 characters',
            prefixIcon: const Icon(Icons.lock_outline),
            suffixIcon: IconButton(
              icon: Icon(_obscureNew ? Icons.visibility_off : Icons.visibility),
              onPressed: () => setState(() => _obscureNew = !_obscureNew),
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _confirmPassCtrl,
          obscureText: _obscureConfirm,
          decoration: InputDecoration(
            labelText: 'Confirm Password *',
            hintText: 'Re-enter your password',
            prefixIcon: const Icon(Icons.lock_reset),
            suffixIcon: IconButton(
              icon: Icon(_obscureConfirm ? Icons.visibility_off : Icons.visibility),
              onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.blue.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
          ),
          child: const Row(
            children: [
              Icon(Icons.shield_outlined, size: 16, color: Colors.blue),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Company Policy: Your password is saved with Super Admin for support recovery. There is no automated password reset.',
                  style: TextStyle(fontSize: 11, color: Colors.blueGrey),
                ),
              ),
            ],
          ),
        ),
        if (_formError.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(_formError, style: const TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.w500), textAlign: TextAlign.center),
        ],
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: _isSubmitting ? null : _submitPassword,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: _isSubmitting
              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Text('Set Password & Enter Dashboard', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        ),
      ],
    );
  }
}

