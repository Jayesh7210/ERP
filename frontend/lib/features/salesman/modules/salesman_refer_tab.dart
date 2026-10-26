import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/colors.dart';
import '../../../core/widgets/app_refresh_button.dart';
import 'salesman_referral_modal.dart';

class SalesmanReferTab extends StatelessWidget {
  final String salesmanName;
  final Map<String, dynamic> earningsData;
  final int soldToday;
  final List<Map<String, dynamic>> referralsList;
  final TextEditingController? refNameCtrl;
  final TextEditingController? refPhoneCtrl;
  final String? selectedKycFile;
  final String? selectedKycBase64;
  final Uint8List? selectedKycBytes;
  final bool? isSubmittingReferral;
  final Function(String name, String? base64, Uint8List? bytes)? onKycChanged;
  final Future<void> Function()? onSubmitReferral;
  final Future<bool> Function({
    required String name,
    required String phone,
    String? email,
    String? docType,
    String? kycDoc,
  })? onDirectReferralSubmit;
  final VoidCallback onRefreshReferrals;
  final Future<void> Function()? onRefresh;

  const SalesmanReferTab({
    super.key,
    required this.salesmanName,
    required this.earningsData,
    required this.soldToday,
    required this.referralsList,
    this.refNameCtrl,
    this.refPhoneCtrl,
    this.selectedKycFile,
    this.selectedKycBase64,
    this.selectedKycBytes,
    this.isSubmittingReferral,
    this.onKycChanged,
    this.onSubmitReferral,
    this.onDirectReferralSubmit,
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

          // Refer a New Salesman CTA Button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: () => _openReferralModal(context),
              icon: const Icon(Icons.person_add_alt_1, size: 20),
              label: const Text(
                'Refer a New Salesman',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  letterSpacing: 0.3,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: ClientColors.primary,
                foregroundColor: Colors.white,
                elevation: 2,
                shadowColor: ClientColors.primary.withValues(alpha: 0.3),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
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
              AppRefreshButton(
                icon: Icons.refresh,
                size: 18,
                color: ClientColors.primary,
                tooltip: 'Refresh Referrals',
                showFeedback: true,
                feedbackMessage: 'Referral team updated',
                onRefresh: () async {
                  if (onRefresh != null) {
                    await onRefresh!();
                  } else {
                    onRefreshReferrals();
                  }
                },
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

  void _openReferralModal(BuildContext context) {
    SalesmanReferralModal.show(
      context: context,
      onSubmit: ({
        required String name,
        required String phone,
        String? email,
        String? docType,
        String? kycDoc,
      }) async {
        if (onDirectReferralSubmit != null) {
          return await onDirectReferralSubmit!(
            name: name,
            phone: phone,
            email: email,
            docType: docType,
            kycDoc: kycDoc,
          );
        } else {
          refNameCtrl?.text = name;
          refPhoneCtrl?.text = phone;
          if (kycDoc != null && onKycChanged != null) {
            onKycChanged!('Attached Document', kycDoc, null);
          }
          if (onSubmitReferral != null) {
            await onSubmitReferral!();
            return true;
          }
          return false;
        }
      },
    );
  }
}
