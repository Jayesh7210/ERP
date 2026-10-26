import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/constants/colors.dart';

class SalesmanSettlementTab extends StatefulWidget {
  final int currentStock;
  final int totalDispatchedBottles;
  final int settlementSoldBottles;
  final double? bottleUnitPrice;
  final double unitPrice;
  final int soldToday;
  final double recordedCashToday;
  final double recordedOnlineToday;
  final TextEditingController cashHandoverCtrl;
  final TextEditingController onlinePaymentCtrl;
  final TextEditingController soldBottlesInputCtrl;
  final TextEditingController damagedBottlesInputCtrl;
  final TextEditingController damageNotesCtrl;
  final bool hasDamagedBottles;
  final int damagedBottles;
  final XFile? damageImageFile;
  final Uint8List? damageImageBytes;
  final List<Map<String, dynamic>> settlementHistory;
  final Function(ImageSource source) onPickDamageImage;
  final VoidCallback onDeleteDamageImage;
  final Function({int? soldBottles, bool? hasDamaged, int? damagedCount}) onUpdateSettlementState;
  final VoidCallback onInitiateSettlement;
  final bool isGeneratingQr;
  final VoidCallback? onResetToRecorded;
  final VoidCallback? onUserModified;
  final Future<void> Function()? onRefresh;

  const SalesmanSettlementTab({
    super.key,
    required this.currentStock,
    required this.totalDispatchedBottles,
    required this.settlementSoldBottles,
    required this.bottleUnitPrice,
    required this.unitPrice,
    this.soldToday = 0,
    this.recordedCashToday = 0.0,
    this.recordedOnlineToday = 0.0,
    required this.cashHandoverCtrl,
    required this.onlinePaymentCtrl,
    required this.soldBottlesInputCtrl,
    required this.damagedBottlesInputCtrl,
    required this.damageNotesCtrl,
    required this.hasDamagedBottles,
    required this.damagedBottles,
    required this.damageImageFile,
    required this.damageImageBytes,
    required this.settlementHistory,
    required this.onPickDamageImage,
    required this.onDeleteDamageImage,
    required this.onUpdateSettlementState,
    required this.onInitiateSettlement,
    this.isGeneratingQr = false,
    this.onResetToRecorded,
    this.onUserModified,
    this.onRefresh,
  });

  @override
  State<SalesmanSettlementTab> createState() => _SalesmanSettlementTabState();
}

class _SalesmanSettlementTabState extends State<SalesmanSettlementTab> {
  bool _isLocalGenerating = false;

  @override
  void didUpdateWidget(covariant SalesmanSettlementTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isGeneratingQr && !widget.isGeneratingQr) {
      _isLocalGenerating = false;
    }
  }
  @override
  Widget build(BuildContext context) {
    final int heldStock =
        widget.currentStock > 0 ? widget.currentStock : widget.totalDispatchedBottles;
    final int damaged = widget.hasDamagedBottles ? widget.damagedBottles : 0;
    final int maxAllowed = (heldStock - damaged).clamp(0, heldStock);
    final int remaining =
        (heldStock - widget.settlementSoldBottles - damaged).clamp(0, heldStock);
    final int soldAmt = (widget.settlementSoldBottles * widget.unitPrice).toInt();
    final int remainingVal = (remaining * widget.unitPrice).toInt();
    final int cash = double.tryParse(widget.cashHandoverCtrl.text.trim())?.toInt() ?? 0;
    final int online = double.tryParse(widget.onlinePaymentCtrl.text.trim())?.toInt() ?? 0;
    final int totalCollected = cash + online;
    final int diff = soldAmt - totalCollected;

    final scrollContent = SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Smart Pre-fill Informational Banner
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFFEFF6FF),
                  const Color(0xFFDBEAFE).withValues(alpha: 0.6),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF93C5FD)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.bolt, color: Color(0xFF1D4ED8), size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            "Auto-Prefilled from Today's Sales",
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E3A8A),
                            ),
                          ),
                          const Spacer(),
                          if (widget.soldToday > 0 && widget.onResetToRecorded != null)
                            InkWell(
                              onTap: () {
                                widget.onResetToRecorded?.call();
                                setState(() {});
                              },
                              child: const Text(
                                'Reset to Recorded',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF2563EB),
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        widget.soldToday > 0
                            ? "Pre-loaded with ${widget.soldToday} bottle(s) sold today and ₹${widget.recordedCashToday.toInt()} cash / ₹${widget.recordedOnlineToday.toInt()} online split. All fields remain fully editable."
                            : (heldStock == 0 && widget.settlementHistory.isNotEmpty)
                                ? "All recorded sales and inventory have been settled! See Previous Settlements below."
                                : "No recorded sales today yet. All settlement fields are ready for manual entry.",
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF1E40AF),
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 2. STEP 1: TOTAL SALE (BOTTLES SOLD)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '1. Total Sale (Bottles Sold)',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: ClientColors.textDark,
                ),
              ),
              Text(
                'Max: $maxAllowed btls',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: ClientColors.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: ClientColors.border),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove_circle, color: ClientColors.primary, size: 38),
                      tooltip: 'Decrease 1 bottle',
                      onPressed: () {
                        if (widget.settlementSoldBottles > 0) {
                          widget.onUserModified?.call();
                          final newQty = widget.settlementSoldBottles - 1;
                          widget.soldBottlesInputCtrl.text = '$newQty';
                          final newAmt = (newQty * widget.unitPrice).toInt();
                          widget.cashHandoverCtrl.text = '$newAmt';
                          widget.onlinePaymentCtrl.text = '0';
                          widget.onUpdateSettlementState(soldBottles: newQty);
                          setState(() {});
                        }
                      },
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          Container(
                            width: 140,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: ClientColors.primary.withValues(alpha: 0.4),
                                width: 1.5,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: widget.soldBottlesInputCtrl,
                                    keyboardType: TextInputType.number,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontSize: 28,
                                      fontWeight: FontWeight.bold,
                                      color: ClientColors.textDark,
                                    ),
                                    decoration: const InputDecoration(
                                      border: InputBorder.none,
                                      isDense: true,
                                      contentPadding: EdgeInsets.symmetric(vertical: 4),
                                    ),
                                    onChanged: (val) {
                                      widget.onUserModified?.call();
                                      final parsed = int.tryParse(val.trim()) ?? 0;
                                      if (parsed > maxAllowed) {
                                        widget.soldBottlesInputCtrl.text = '$maxAllowed';
                                        widget.soldBottlesInputCtrl.selection =
                                            TextSelection.fromPosition(
                                          TextPosition(
                                              offset: widget.soldBottlesInputCtrl.text.length),
                                        );
                                        final newAmt = (maxAllowed * widget.unitPrice).toInt();
                                        widget.cashHandoverCtrl.text = '$newAmt';
                                        widget.onlinePaymentCtrl.text = '0';
                                        widget.onUpdateSettlementState(soldBottles: maxAllowed);
                                      } else {
                                        final clamped = parsed.clamp(0, maxAllowed);
                                        final newAmt = (clamped * widget.unitPrice).toInt();
                                        widget.cashHandoverCtrl.text = '$newAmt';
                                        widget.onlinePaymentCtrl.text = '0';
                                        widget.onUpdateSettlementState(soldBottles: clamped);
                                      }
                                      setState(() {});
                                    },
                                  ),
                                ),
                                const Icon(
                                  Icons.edit_note_rounded,
                                  size: 22,
                                  color: ClientColors.primary,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Bottles Sold • Tap box to type',
                            style: TextStyle(
                              fontSize: 11,
                              color: ClientColors.textMuted,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_circle, color: ClientColors.primary, size: 38),
                      tooltip: 'Increase 1 bottle',
                      onPressed: () {
                        if (widget.settlementSoldBottles < maxAllowed) {
                          widget.onUserModified?.call();
                          final newQty = widget.settlementSoldBottles + 1;
                          widget.soldBottlesInputCtrl.text = '$newQty';
                          final newAmt = (newQty * widget.unitPrice).toInt();
                          widget.cashHandoverCtrl.text = '$newAmt';
                          widget.onlinePaymentCtrl.text = '0';
                          widget.onUpdateSettlementState(soldBottles: newQty);
                          setState(() {});
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Quick Quantity Presets for Large Inventories
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      if (widget.soldToday > 0) ...[
                        ActionChip(
                          avatar: const Icon(Icons.history_toggle_off,
                              size: 14, color: Color(0xFF0D9488)),
                          label: Text(
                            'Recorded (${widget.soldToday})',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F766E),
                            ),
                          ),
                          backgroundColor: const Color(0xFFCCFBF1),
                          side: const BorderSide(color: Color(0xFF99F6E4)),
                          onPressed: () {
                            widget.onResetToRecorded?.call();
                            setState(() {});
                          },
                        ),
                        const SizedBox(width: 6),
                      ],
                      ActionChip(
                        avatar: const Icon(Icons.all_inclusive,
                            size: 14, color: ClientColors.primary),
                        label: Text(
                          'All ($maxAllowed)',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: ClientColors.primary,
                          ),
                        ),
                        backgroundColor: ClientColors.primary.withValues(alpha: 0.08),
                        side: BorderSide(color: ClientColors.primary.withValues(alpha: 0.2)),
                        onPressed: () {
                          widget.onUserModified?.call();
                          widget.soldBottlesInputCtrl.text = '$maxAllowed';
                          final newAmt = (maxAllowed * widget.unitPrice).toInt();
                          widget.cashHandoverCtrl.text = '$newAmt';
                          widget.onlinePaymentCtrl.text = '0';
                          widget.onUpdateSettlementState(soldBottles: maxAllowed);
                          setState(() {});
                        },
                      ),
                      if (maxAllowed >= 2) ...[
                        const SizedBox(width: 6),
                        ActionChip(
                          label: Text(
                            'Half (${maxAllowed ~/ 2})',
                            style:
                                const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                          backgroundColor: Colors.grey.shade100,
                          onPressed: () {
                            widget.onUserModified?.call();
                            final half = maxAllowed ~/ 2;
                            widget.soldBottlesInputCtrl.text = '$half';
                            final newAmt = (half * widget.unitPrice).toInt();
                            widget.cashHandoverCtrl.text = '$newAmt';
                            widget.onlinePaymentCtrl.text = '0';
                            widget.onUpdateSettlementState(soldBottles: half);
                            setState(() {});
                          },
                        ),
                      ],
                      if (maxAllowed >= 10) ...[
                        const SizedBox(width: 6),
                        ActionChip(
                          label: const Text('+10',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          backgroundColor: Colors.grey.shade100,
                          onPressed: () {
                            widget.onUserModified?.call();
                            final updated =
                                (widget.settlementSoldBottles + 10).clamp(0, maxAllowed);
                            widget.soldBottlesInputCtrl.text = '$updated';
                            final newAmt = (updated * widget.unitPrice).toInt();
                            widget.cashHandoverCtrl.text = '$newAmt';
                            widget.onlinePaymentCtrl.text = '0';
                            widget.onUpdateSettlementState(soldBottles: updated);
                            setState(() {});
                          },
                        ),
                      ],
                      if (maxAllowed >= 50) ...[
                        const SizedBox(width: 6),
                        ActionChip(
                          label: const Text('+50',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          backgroundColor: Colors.grey.shade100,
                          onPressed: () {
                            widget.onUserModified?.call();
                            final updated =
                                (widget.settlementSoldBottles + 50).clamp(0, maxAllowed);
                            widget.soldBottlesInputCtrl.text = '$updated';
                            final newAmt = (updated * widget.unitPrice).toInt();
                            widget.cashHandoverCtrl.text = '$newAmt';
                            widget.onlinePaymentCtrl.text = '0';
                            widget.onUpdateSettlementState(soldBottles: updated);
                            setState(() {});
                          },
                        ),
                      ],
                      const SizedBox(width: 6),
                      ActionChip(
                        avatar:
                            const Icon(Icons.clear, size: 14, color: Colors.redAccent),
                        label: const Text(
                          'Reset',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.redAccent,
                          ),
                        ),
                        backgroundColor: Colors.red.shade50,
                        side: BorderSide(color: Colors.red.shade200),
                        onPressed: () {
                          widget.onUserModified?.call();
                          widget.soldBottlesInputCtrl.text = '0';
                          widget.cashHandoverCtrl.text = '0';
                          widget.onlinePaymentCtrl.text = '0';
                          widget.onUpdateSettlementState(soldBottles: 0);
                          setState(() {});
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Sale Revenue:',
                        style: TextStyle(fontSize: 12, color: ClientColors.textMuted)),
                    Text(
                      '₹$soldAmt',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2E7D32),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // 3. STEP 2: REMAINING QUANTITY (RETURNING TO FSM)
          const Text(
            '2. Remaining Stock (Returning to FSM Depot)',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: ClientColors.textDark,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF86EFAC)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF22C55E).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.keyboard_return_rounded,
                    color: Color(0xFF15803D),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$remaining Bottles to Return',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF14532D),
                        ),
                      ),
                      Text(
                        remaining > 0
                            ? 'Will be added back to FSM depot stock • Value ₹$remainingVal'
                            : 'All stock has been reconciled and accounted for',
                        style: const TextStyle(fontSize: 11, color: Color(0xFF166534)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // 4. STEP 3: DAMAGED PRODUCT OPTION
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: widget.hasDamagedBottles
                    ? const Color(0xFFF59E0B)
                    : ClientColors.border,
                width: widget.hasDamagedBottles ? 1.5 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SwitchListTile(
                  title: const Row(
                    children: [
                      Icon(Icons.report_problem_outlined,
                          color: Color(0xFFD97706), size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Report Damaged Bottles?',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: ClientColors.textDark,
                        ),
                      ),
                    ],
                  ),
                  subtitle: const Text(
                    'Broken seal, leakage, transit defects',
                    style: TextStyle(fontSize: 11, color: ClientColors.textMuted),
                  ),
                  value: widget.hasDamagedBottles,
                  activeThumbColor: const Color(0xFFD97706),
                  onChanged: (val) {
                    int dmg = widget.damagedBottles;
                    int sold = widget.settlementSoldBottles;
                    if (val && dmg == 0) {
                      dmg = 1;
                      widget.damagedBottlesInputCtrl.text = '1';
                      if (sold + dmg > heldStock) {
                        sold = (heldStock - dmg).clamp(0, heldStock);
                        widget.soldBottlesInputCtrl.text = '$sold';
                      }
                    } else if (!val) {
                      dmg = 0;
                      widget.damagedBottlesInputCtrl.text = '0';
                    }
                    widget.onUpdateSettlementState(
                      hasDamaged: val,
                      damagedCount: dmg,
                      soldBottles: sold,
                    );
                    setState(() {});
                  },
                ),
                if (widget.hasDamagedBottles) ...[
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Damaged Quantity:',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: ClientColors.textDark,
                              ),
                            ),
                            Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.remove_circle_outline,
                                      color: Color(0xFFD97706)),
                                  onPressed: () {
                                    if (widget.damagedBottles > 1) {
                                      final newDmg = widget.damagedBottles - 1;
                                      widget.damagedBottlesInputCtrl.text = '$newDmg';
                                      widget.onUpdateSettlementState(damagedCount: newDmg);
                                      setState(() {});
                                    }
                                  },
                                ),
                                Container(
                                  width: 60,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 4, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: const Color(0xFFFDE68A),
                                      width: 1.5,
                                    ),
                                  ),
                                  child: TextField(
                                    controller: widget.damagedBottlesInputCtrl,
                                    keyboardType: TextInputType.number,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFFD97706),
                                    ),
                                    decoration: const InputDecoration(
                                      border: InputBorder.none,
                                      isDense: true,
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                    onChanged: (val) {
                                      final maxDmg =
                                          (heldStock - widget.settlementSoldBottles)
                                              .clamp(0, heldStock);
                                      final parsed = int.tryParse(val.trim()) ?? 0;
                                      if (parsed > maxDmg) {
                                        widget.damagedBottlesInputCtrl.text = '$maxDmg';
                                        widget.damagedBottlesInputCtrl.selection =
                                            TextSelection.fromPosition(
                                          TextPosition(
                                              offset: widget
                                                  .damagedBottlesInputCtrl.text.length),
                                        );
                                        widget.onUpdateSettlementState(damagedCount: maxDmg);
                                      } else {
                                        widget.onUpdateSettlementState(
                                            damagedCount: parsed.clamp(0, maxDmg));
                                      }
                                      setState(() {});
                                    },
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.add_circle_outline,
                                      color: Color(0xFFD97706)),
                                  onPressed: () {
                                    if (widget.damagedBottles <
                                        heldStock - widget.settlementSoldBottles) {
                                      final newDmg = widget.damagedBottles + 1;
                                      widget.damagedBottlesInputCtrl.text = '$newDmg';
                                      widget.onUpdateSettlementState(damagedCount: newDmg);
                                      setState(() {});
                                    }
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Damage Description / Notes:',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: ClientColors.textMuted,
                          ),
                        ),
                        const SizedBox(height: 4),
                        TextField(
                          controller: widget.damageNotesCtrl,
                          decoration: InputDecoration(
                            hintText: 'e.g. Broken seal, damaged cap during delivery...',
                            hintStyle:
                                const TextStyle(fontSize: 12, color: ClientColors.textMuted),
                            filled: true,
                            fillColor: const Color(0xFFFFFBEB),
                            isDense: true,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: Color(0xFFFDE68A)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: Color(0xFFFDE68A)),
                            ),
                          ),
                          style: const TextStyle(fontSize: 12),
                          maxLines: 2,
                        ),
                        const SizedBox(height: 12),

                        // Image Upload Buttons & Preview
                        const Text(
                          'Damage Proof Photo (Required):',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: ClientColors.textMuted,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () =>
                                    widget.onPickDamageImage(ImageSource.camera),
                                icon: const Icon(Icons.camera_alt,
                                    size: 16, color: ClientColors.primary),
                                label: const Text('Camera',
                                    style: TextStyle(
                                        fontSize: 12, color: ClientColors.primary)),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  side: const BorderSide(color: ClientColors.primary),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8)),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () =>
                                    widget.onPickDamageImage(ImageSource.gallery),
                                icon: const Icon(Icons.photo_library,
                                    size: 16, color: ClientColors.primary),
                                label: const Text('Gallery',
                                    style: TextStyle(
                                        fontSize: 12, color: ClientColors.primary)),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  side: const BorderSide(color: ClientColors.primary),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8)),
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (widget.damageImageBytes != null) ...[
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF3C7),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFFCD34D)),
                            ),
                            child: Row(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: Image.memory(
                                    widget.damageImageBytes!,
                                    width: 48,
                                    height: 48,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        widget.damageImageFile?.name ?? 'Damage Photo Attached',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF92400E),
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const Text(
                                        'Verified for FSM audit',
                                        style: TextStyle(
                                            fontSize: 10, color: Color(0xFFB45309)),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline,
                                      color: Colors.red, size: 20),
                                  onPressed: widget.onDeleteDamageImage,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 18),

          // 5. STEP 4: PAYMENT COLLECTION BREAKDOWN
          const Text(
            '4. Payment Collections Breakdown',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: ClientColors.textDark,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: ClientColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Quick Split Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Quick Fill:',
                        style: TextStyle(fontSize: 11, color: ClientColors.textMuted)),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          if (widget.recordedCashToday > 0 || widget.recordedOnlineToday > 0) ...[
                            InkWell(
                              onTap: () {
                                widget.onUserModified?.call();
                                widget.cashHandoverCtrl.text = '${widget.recordedCashToday.toInt()}';
                                widget.onlinePaymentCtrl.text = '${widget.recordedOnlineToday.toInt()}';
                                setState(() {});
                              },
                              child: Container(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFEF3C7),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: const Color(0xFFFDE68A)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.restore, size: 12, color: Color(0xFFB45309)),
                                    const SizedBox(width: 3),
                                    Text(
                                      'Recorded Split (₹${widget.recordedCashToday.toInt()} / ₹${widget.recordedOnlineToday.toInt()})',
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF92400E),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                          ],
                          InkWell(
                            onTap: () {
                              widget.onUserModified?.call();
                              widget.cashHandoverCtrl.text = '$soldAmt';
                              widget.onlinePaymentCtrl.text = '0';
                              setState(() {});
                            },
                            child: Container(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEFF6FF),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'All Cash',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1D4ED8),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          InkWell(
                            onTap: () {
                              widget.onUserModified?.call();
                              widget.cashHandoverCtrl.text = '0';
                              widget.onlinePaymentCtrl.text = '$soldAmt';
                              setState(() {});
                            },
                            child: Container(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF3E8FF),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'All Online',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF7E22CE),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          InkWell(
                            onTap: () {
                              widget.onUserModified?.call();
                              final half = soldAmt ~/ 2;
                              widget.cashHandoverCtrl.text = '$half';
                              widget.onlinePaymentCtrl.text = '${soldAmt - half}';
                              setState(() {});
                            },
                            child: Container(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFECFDF5),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                '50/50 Split',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF047857),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Cash Received Input
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.payments_outlined,
                          color: Color(0xFF2563EB), size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Cash Received (₹)',
                              style: TextStyle(
                                  fontSize: 11, color: ClientColors.textMuted)),
                          TextField(
                            controller: widget.cashHandoverCtrl,
                            keyboardType: TextInputType.number,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: ClientColors.textDark,
                            ),
                            decoration: const InputDecoration(
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(vertical: 4),
                              border: UnderlineInputBorder(),
                              hintText: '0',
                            ),
                            onChanged: (_) {
                              widget.onUserModified?.call();
                              setState(() {});
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Online Payment Input
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F3FF),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.qr_code_scanner,
                          color: Color(0xFF7C3AED), size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Online Payment / UPI (₹)',
                              style: TextStyle(
                                  fontSize: 11, color: ClientColors.textMuted)),
                          TextField(
                            controller: widget.onlinePaymentCtrl,
                            keyboardType: TextInputType.number,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: ClientColors.textDark,
                            ),
                            decoration: const InputDecoration(
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(vertical: 4),
                              border: UnderlineInputBorder(),
                              hintText: '0',
                            ),
                            onChanged: (_) {
                              widget.onUserModified?.call();
                              setState(() {});
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Tally Summary Strip
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: diff == 0 ? const Color(0xFFECFDF5) : const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: diff == 0 ? const Color(0xFFA7F3D0) : const Color(0xFFFDE68A),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            diff == 0 ? Icons.check_circle : Icons.info_outline,
                            color: diff == 0
                                ? const Color(0xFF059669)
                                : const Color(0xFFD97706),
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            diff == 0
                                ? 'Exact Match (₹$totalCollected)'
                                : 'Difference: ₹$diff',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: diff == 0
                                  ? const Color(0xFF065F46)
                                  : const Color(0xFF92400E),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        'Total Due: ₹$soldAmt',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: ClientColors.textDark,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),

          // 6. GENERATE SETTLEMENT QR CODE BUTTON
          Builder(
            builder: (context) {
              final bool isAllSettled =
                  (heldStock == 0 && widget.settlementSoldBottles == 0 && widget.settlementHistory.isNotEmpty);
              final bool isBusy = widget.isGeneratingQr || _isLocalGenerating;
              return SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: (isBusy || isAllSettled)
                      ? null
                      : () {
                          setState(() => _isLocalGenerating = true);
                          widget.onInitiateSettlement();
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1B365D),
                    disabledBackgroundColor: isAllSettled
                        ? const Color(0xFF0F766E)
                        : const Color(0xFF1B365D).withValues(alpha: 0.75),
                    foregroundColor: Colors.white,
                    disabledForegroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: isBusy ? 1 : 4,
                  ),
                  child: isBusy
                      ? const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            ),
                            SizedBox(width: 12),
                            Text(
                              'GENERATING SETTLEMENT QR...',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        )
                      : isAllSettled
                          ? const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.check_circle_outline, size: 22, color: Colors.white),
                                SizedBox(width: 10),
                                Text(
                                  'ALL SETTLED FOR TODAY',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            )
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.qr_code_2_rounded, size: 24),
                                SizedBox(width: 8),
                                Text(
                                  'GENERATE SETTLEMENT QR CODE',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                ),
              );
            },
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              (heldStock == 0 && widget.settlementSoldBottles == 0 && widget.settlementHistory.isNotEmpty)
                  ? 'All stock and collections have been fully reconciled with your Field Sales Manager'
                  : 'Show generated QR to FSM for scanning and instant stock reconciliation',
              style: const TextStyle(fontSize: 11, color: ClientColors.textMuted),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 24),

          // 7. ACTIVE PENDING SETTLEMENT (IF ANY)
          Builder(
            builder: (ctx) {
              final pendingList = widget.settlementHistory.where((s) {
                final st = (s['status'] ?? '').toString().toLowerCase();
                return st == 'pending_fsm' || st == 'pending';
              }).toList();

              if (pendingList.isEmpty) return const SizedBox.shrink();

              return Column(
                children: pendingList.map((p) {
                  final pSold = p['bottles_sold'] ?? 0;
                  final pReturn = p['remaining_qty'] ?? p['unsold_bottles'] ?? 0;
                  final pAmt = p['total_value'] ?? p['total_amount'] ?? 0;
                  final pPin = (p['security_pin'] ?? '').toString();

                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFCD34D)),
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
                                  padding: const EdgeInsets.all(6),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFFDE68A),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.qr_code_2, size: 20, color: Color(0xFFB45309)),
                                ),
                                const SizedBox(width: 8),
                                const Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Settlement QR Pending Scan',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                        color: Color(0xFF92400E),
                                      ),
                                    ),
                                    Text(
                                      'Waiting for Field Sales Manager to scan',
                                      style: TextStyle(fontSize: 11, color: Color(0xFFB45309)),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF3C7),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFFF59E0B)),
                              ),
                              child: const Text(
                                'AWAITING SCAN',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFB45309),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Sold: $pSold btls • Return: $pReturn btls • Total: ₹$pAmt${pPin.isNotEmpty ? ' • PIN: $pPin' : ''}',
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: Color(0xFF78350F),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          ),

          // 8. PREVIOUS SETTLEMENTS SECTION
          Builder(
            builder: (ctx) {
              final settledList = widget.settlementHistory.where((s) {
                final st = (s['status'] ?? '').toString().toLowerCase();
                return st == 'settled' || st == 'completed';
              }).toList();

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Previous Settlements',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: ClientColors.textDark,
                        ),
                      ),
                      Text(
                        '${settledList.length} Recorded',
                        style: const TextStyle(fontSize: 11, color: ClientColors.textMuted),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (settledList.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: ClientColors.border),
                      ),
                      child: const Center(
                        child: Text(
                          'No previous settlements recorded yet.',
                          style: TextStyle(fontSize: 12, color: ClientColors.textMuted),
                        ),
                      ),
                    )
                  else
                    ...settledList.map((s) {
                      final damagedCount = (s['damaged_qty'] as num?)?.toInt() ?? 0;
                      final cashAmt = (s['cash_collected'] ?? s['cash_received'] ?? 0);
                      final onlineAmt = (s['online_payment'] ?? 0);
                      final totalAmt = (s['total_value'] ?? s['total_amount'] ?? 0);
                      final status = (s['status'] ?? 'settled').toString().toLowerCase();
                      final isSettled = status == 'settled' || status == 'completed';

                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: ClientColors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: isSettled
                                        ? const Color(0xFFEFF6FF)
                                        : const Color(0xFFFFFBEB),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    isSettled
                                        ? Icons.check_circle_rounded
                                        : Icons.hourglass_top_rounded,
                                    color: isSettled
                                        ? const Color(0xFF2563EB)
                                        : const Color(0xFFD97706),
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        s['date_label'] ??
                                            'Settlement #${(s['id'] ?? '').toString().substring(0, (s['id'] ?? '').toString().length > 8 ? 8 : (s['id'] ?? '').toString().length)}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: ClientColors.textDark,
                                        ),
                                      ),
                                      Text(
                                        'Sold: ${s['bottles_sold'] ?? 0} btls • Returned: ${s['remaining_qty'] ?? 0} btls',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: ClientColors.textMuted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      '₹$totalAmt',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        color: ClientColors.textDark,
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: isSettled
                                            ? const Color(0xFFECFDF5)
                                            : const Color(0xFFFEF3C7),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        isSettled ? 'SETTLED' : 'PENDING FSM',
                                        style: TextStyle(
                                          fontSize: 9,
                                          color: isSettled
                                              ? const Color(0xFF047857)
                                              : const Color(0xFFB45309),
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                    if (damagedCount > 0) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFFBEB),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.warning_amber_rounded,
                                size: 13, color: Color(0xFFD97706)),
                            const SizedBox(width: 4),
                            Text(
                              '$damagedCount Damaged Bottles Reported',
                              style: const TextStyle(
                                fontSize: 10,
                                color: Color(0xFF92400E),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Cash: ₹$cashAmt',
                            style: const TextStyle(
                                fontSize: 11, color: ClientColors.textMuted)),
                        Text('Online: ₹$onlineAmt',
                            style: const TextStyle(
                                fontSize: 11, color: ClientColors.textMuted)),
                      ],
                    ),
                  ],
                ),
              );
            }),
          ],
        );
      },
    ),
  ],
),
);

    if (widget.onRefresh != null) {
      return RefreshIndicator(
        color: ClientColors.primary,
        onRefresh: widget.onRefresh!,
        child: scrollContent,
      );
    }
    return scrollContent;
  }
}
