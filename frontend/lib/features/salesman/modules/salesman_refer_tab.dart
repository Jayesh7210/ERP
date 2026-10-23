import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/constants/colors.dart';

class SalesmanReferTab extends StatelessWidget {
  final String salesmanName;
  final Map<String, dynamic> earningsData;
  final int soldToday;
  final List<Map<String, dynamic>> referralsList;
  final TextEditingController refNameCtrl;
  final TextEditingController refPhoneCtrl;
  final String selectedKycFile;
  final String? selectedKycBase64;
  final Uint8List? selectedKycBytes;
  final bool isSubmittingReferral;
  final Function(String name, String? base64, Uint8List? bytes) onKycChanged;
  final Future<void> Function() onSubmitReferral;
  final VoidCallback onRefreshReferrals;
  final Future<void> Function()? onRefresh;

  const SalesmanReferTab({
    super.key,
    required this.salesmanName,
    required this.earningsData,
    required this.soldToday,
    required this.referralsList,
    required this.refNameCtrl,
    required this.refPhoneCtrl,
    required this.selectedKycFile,
    required this.selectedKycBase64,
    required this.selectedKycBytes,
    required this.isSubmittingReferral,
    required this.onKycChanged,
    required this.onSubmitReferral,
    required this.onRefreshReferrals,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final soldTodayCount = (earningsData['sold_bottles_today'] as num?)?.toInt() ?? soldToday;
    final minQuota = (earningsData['min_sales_quota'] as num?)?.toInt() ?? 0;
    final isQuotaActive = earningsData['is_quota_condition_active'] == true;
    final isQualified = earningsData['is_qualified'] == true || !isQuotaActive;
    final bottlesNeeded = (earningsData['bottles_needed_to_qualify'] as num?)?.toInt() ??
        (isQualified ? 0 : (minQuota - soldTodayCount).clamp(0, minQuota));
    final unlockedEarned =
        ((earningsData['unlocked_referral_earned'] ?? earningsData['referral_earned']) as num?)
                ?.toDouble() ??
            0.0;
    final quotaPendingEarned =
        (earningsData['quota_pending_referral_earned'] as num?)?.toDouble() ?? 0.0;
    final downlineBottles =
        ((earningsData['downline_bottles_sold'] ?? earningsData['referral_bottles']) as num?)
                ?.toInt() ??
            0;
    final myReferralCode =
        'REF-SALES-${salesmanName.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toUpperCase()}';
    final double quotaProgress =
        minQuota > 0 ? (soldTodayCount / minQuota).clamp(0.0, 1.0) : 1.0;

    final scrollContent = SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Hero Refer & Earn Banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFFC85A17), Color(0xFF8B3A0D)]),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF8B3A0D).withValues(alpha: 0.25),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.hub_outlined, color: Colors.white, size: 22),
                    SizedBox(width: 8),
                    Text(
                      'Workforce Referral Program',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Earn Referral Bonus on Every Sale',
                  style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  'Earn per-product referral bonuses for each unit sold by salesmen in your direct downline.',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Super Admin Qualification Condition Gate Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isQualified ? const Color(0xFFF0FDF4) : const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isQualified ? const Color(0xFF86EFAC) : const Color(0xFFFDE68A),
                width: 1.5,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          isQualified ? Icons.verified : Icons.lock_clock,
                          color: isQualified ? const Color(0xFF15803D) : const Color(0xFFB45309),
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isQualified ? 'QUALIFICATION GATE MET' : 'QUALIFICATION GATE PENDING',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: isQualified ? const Color(0xFF15803D) : const Color(0xFFB45309),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isQualified ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '$soldTodayCount / $minQuota btls',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isQualified ? const Color(0xFF166534) : const Color(0xFF92400E),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: quotaProgress,
                    minHeight: 7,
                    backgroundColor:
                        isQualified ? const Color(0xFFDCFCE7) : const Color(0xFFFED7AA),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isQualified ? const Color(0xFF22C55E) : const Color(0xFFF59E0B),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  isQualified
                      ? '✅ Great job! You have sold $soldTodayCount bottles today (quota: $minQuota). Downline commissions are fully unlocked for payout.'
                      : '⏳ Super Admin Rule: Sell $bottlesNeeded more bottle(s) today to meet your $minQuota-bottle quota and unlock ₹${quotaPendingEarned.toStringAsFixed(0)} pending referral commission.',
                  style: TextStyle(
                    fontSize: 12,
                    color: isQualified ? const Color(0xFF166534) : const Color(0xFF92400E),
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Workforce Referral Metrics Row (3 Cards)
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: ClientColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.check_circle_outline, color: Colors.green, size: 18),
                      const SizedBox(height: 6),
                      const Text(
                        'Unlocked',
                        style: TextStyle(fontSize: 10, color: ClientColors.textMuted),
                      ),
                      Text(
                        '₹${unlockedEarned.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: ClientColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.lock_clock, color: Colors.orange, size: 18),
                      const SizedBox(height: 6),
                      const Text(
                        'Quota-Held',
                        style: TextStyle(fontSize: 10, color: ClientColors.textMuted),
                      ),
                      Text(
                        '₹${quotaPendingEarned.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: ClientColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.water_drop_outlined, color: ClientColors.primary, size: 18),
                      const SizedBox(height: 6),
                      const Text(
                        'Team Bottles',
                        style: TextStyle(fontSize: 10, color: ClientColors.textMuted),
                      ),
                      Text(
                        '$downlineBottles',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: ClientColors.textDark,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // My Referral Code Box
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: ClientColors.creamBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: ClientColors.border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'YOUR REFERRAL CODE',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: ClientColors.textMuted,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        myReferralCode,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: ClientColors.primary,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ClientColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: myReferralCode));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Referral code "$myReferralCode" copied to clipboard!'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  },
                  icon: const Icon(Icons.copy, size: 14),
                  label: const Text('Copy'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Refer a Salesman Form Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: ClientColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.person_add, color: ClientColors.primary, size: 18),
                    SizedBox(width: 8),
                    Text(
                      'Refer a New Salesman',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: ClientColors.textDark,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: refNameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Full Name',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: refPhoneCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Phone Number',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 12),

                // KYC Upload Box
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: selectedKycFile != 'Tap to select file'
                        ? Colors.blue.withValues(alpha: 0.05)
                        : ClientColors.creamBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: selectedKycFile != 'Tap to select file'
                          ? Colors.blue.shade300
                          : ClientColors.border,
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(
                                selectedKycFile != 'Tap to select file'
                                    ? Icons.check_circle
                                    : Icons.cloud_upload_outlined,
                                color: selectedKycFile != 'Tap to select file'
                                    ? Colors.green
                                    : ClientColors.primary,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'Upload KYC (Aadhaar / Govt ID)',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: ClientColors.textDark,
                                ),
                              ),
                            ],
                          ),
                          if (selectedKycFile != 'Tap to select file')
                            GestureDetector(
                              onTap: () => onKycChanged('Tap to select file', null, null),
                              child: const Text(
                                'Remove',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.red,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
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
                        onTap: () {
                          showModalBottomSheet(
                            context: context,
                            shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                            ),
                            builder: (sheetCtx) => SafeArea(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Padding(
                                      padding: EdgeInsets.only(bottom: 8),
                                      child: Text(
                                        'Attach KYC Document (Aadhaar/PAN)',
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                      ),
                                    ),
                                    ListTile(
                                      leading: const CircleAvatar(
                                        backgroundColor: Colors.blue,
                                        child: Icon(Icons.camera_alt, color: Colors.white),
                                      ),
                                      title: const Text('Take Photo with Camera'),
                                      subtitle: const Text('Capture clear photo of physical ID proof'),
                                      onTap: () async {
                                        Navigator.pop(sheetCtx);
                                        try {
                                          final picker = ImagePicker();
                                          final picked = await picker.pickImage(
                                            source: ImageSource.camera,
                                            imageQuality: 85,
                                            maxWidth: 1600,
                                          );
                                          if (picked != null) {
                                            final bytes = await picked.readAsBytes();
                                            final base64Str =
                                                'data:image/jpeg;base64,${base64Encode(bytes)}';
                                            onKycChanged(picked.name, base64Str, bytes);
                                            if (context.mounted) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(
                                                  content: Text('Attached: ${picked.name}'),
                                                  backgroundColor: Colors.green,
                                                ),
                                              );
                                            }
                                          }
                                        } catch (_) {}
                                      },
                                    ),
                                    ListTile(
                                      leading: const CircleAvatar(
                                        backgroundColor: Colors.orange,
                                        child: Icon(Icons.photo_library, color: Colors.white),
                                      ),
                                      title: const Text('Choose from Gallery / Photos'),
                                      subtitle: const Text('Select image or document scan'),
                                      onTap: () async {
                                        Navigator.pop(sheetCtx);
                                        try {
                                          final picker = ImagePicker();
                                          final picked = await picker.pickImage(
                                            source: ImageSource.gallery,
                                            imageQuality: 85,
                                            maxWidth: 1600,
                                          );
                                          if (picked != null) {
                                            final bytes = await picked.readAsBytes();
                                            final base64Str =
                                                'data:image/jpeg;base64,${base64Encode(bytes)}';
                                            onKycChanged(picked.name, base64Str, bytes);
                                            if (context.mounted) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(
                                                  content: Text('Attached: ${picked.name}'),
                                                  backgroundColor: Colors.green,
                                                ),
                                              );
                                            }
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
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: ClientColors.border),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                selectedKycFile != 'Tap to select file'
                                    ? Icons.check_circle
                                    : Icons.upload_file,
                                size: 16,
                                color: selectedKycFile != 'Tap to select file'
                                    ? Colors.green
                                    : ClientColors.primary,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  selectedKycFile,
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: selectedKycFile != 'Tap to select file'
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    color: selectedKycFile != 'Tap to select file'
                                        ? Colors.black87
                                        : ClientColors.textMuted,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text(
                                selectedKycFile != 'Tap to select file' ? 'Change' : 'Attach',
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  color: ClientColors.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                ElevatedButton(
                  onPressed: isSubmittingReferral ? null : onSubmitReferral,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ClientColors.primary,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(46),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: isSubmittingReferral
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Text(
                          'Submit Referral ->',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // My Referral Team Section
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'My Referral Team (${referralsList.length})',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: ClientColors.textDark,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh, size: 18, color: ClientColors.primary),
                tooltip: 'Refresh',
                onPressed: onRefreshReferrals,
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (referralsList.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: ClientColors.border),
              ),
              child: const Center(
                child: Text('No salesmen referred yet. Refer your first colleague above!'),
              ),
            )
          else
            ...referralsList.map((ref) {
              final bottles = ref['bottles_sold'] ?? 0;
              final earned = (ref['earned'] as num?)?.toDouble() ?? 0.0;
              final pending = (ref['pending_earned'] as num?)?.toDouble() ?? 0.0;
              final name = ref['full_name'] ?? 'Agent';

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: ClientColors.border),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: ClientColors.creamBg,
                          child: Text(
                            name.isNotEmpty ? name[0].toUpperCase() : 'S',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: ClientColors.primary,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: ClientColors.textDark,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '$bottles bottles sold • ${ref['status'] ?? 'Active'}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: ClientColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text(
                          'Earned',
                          style: TextStyle(fontSize: 10, color: ClientColors.textMuted),
                        ),
                        Text(
                          '₹${earned.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: Colors.green,
                          ),
                        ),
                        if (pending > 0)
                          Text(
                            '₹${pending.toStringAsFixed(0)} held',
                            style: const TextStyle(
                              fontSize: 9,
                              color: Colors.orange,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );

    return RefreshIndicator(
      color: ClientColors.primary,
      onRefresh: onRefresh ?? () async => onRefreshReferrals(),
      child: scrollContent,
    );
  }
}
