import 'package:flutter/material.dart';
import '../constants/colors.dart';

/// A global, reusable refresh button widget that provides immediate visual
/// feedback (a smooth spinner and disabled state) while data is loading.
///
/// Can be used as a standalone icon button (ideal for AppBars and Card headers)
/// or as a labeled button (`AppRefreshButton.labeled`) for in-page actions.
class AppRefreshButton extends StatefulWidget {
  /// The async function to execute when the user taps refresh.
  /// The spinner will remain active until this Future completes.
  final Future<void> Function()? onRefresh;

  /// Optional external loading flag. If provided, the button will show
  /// a spinner whenever this is true.
  final bool? isLoading;

  /// Tooltip displayed on hover/long-press. Defaults to 'Refresh data'.
  final String tooltip;

  /// Icon to display when idle. Defaults to [Icons.refresh_rounded].
  final IconData icon;

  /// Color of the icon and spinner. Defaults to [ClientColors.textMuted].
  final Color? color;

  /// Size of the icon. Defaults to 22.0.
  final double size;

  /// Padding around the icon button. Defaults to [EdgeInsets.all(8.0)].
  final EdgeInsetsGeometry padding;

  /// Whether to display a brief floating confirmation SnackBar on completion.
  /// Defaults to false so it remains subtle, but can be enabled anywhere.
  final bool showFeedback;

  /// The feedback message displayed if [showFeedback] is true.
  final String feedbackMessage;

  /// Optional text label if used in labeled mode.
  final String? label;

  /// Whether this is a labeled button rather than an icon-only button.
  final bool isLabeled;

  const AppRefreshButton({
    super.key,
    required this.onRefresh,
    this.isLoading,
    this.tooltip = 'Refresh data',
    this.icon = Icons.refresh_rounded,
    this.color,
    this.size = 22.0,
    this.padding = const EdgeInsets.all(8.0),
    this.showFeedback = false,
    this.feedbackMessage = 'Data refreshed successfully',
  })  : isLabeled = false,
        label = null;

  /// Labeled constructor for full-width or inline buttons with text and icon.
  const AppRefreshButton.labeled({
    super.key,
    required this.onRefresh,
    this.isLoading,
    required this.label,
    this.tooltip = 'Refresh data',
    this.icon = Icons.refresh_rounded,
    this.color,
    this.size = 18.0,
    this.padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
    this.showFeedback = false,
    this.feedbackMessage = 'Data refreshed successfully',
  }) : isLabeled = true;

  @override
  State<AppRefreshButton> createState() => _AppRefreshButtonState();
}

class _AppRefreshButtonState extends State<AppRefreshButton>
    with SingleTickerProviderStateMixin {
  bool _isLocalBusy = false;
  late AnimationController _rotationCtrl;

  bool get _isBusy => (widget.isLoading ?? false) || _isLocalBusy;

  @override
  void initState() {
    super.initState();
    _rotationCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
  }

  @override
  void didUpdateWidget(covariant AppRefreshButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_isBusy && !_rotationCtrl.isAnimating) {
      _rotationCtrl.repeat();
    } else if (!_isBusy && _rotationCtrl.isAnimating) {
      _rotationCtrl.stop();
      _rotationCtrl.reset();
    }
  }

  @override
  void dispose() {
    _rotationCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleRefresh() async {
    if (_isBusy || widget.onRefresh == null) return;

    setState(() => _isLocalBusy = true);
    _rotationCtrl.repeat();

    try {
      await widget.onRefresh!();

      if (mounted && widget.showFeedback) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_outline, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text(widget.feedbackMessage, style: const TextStyle(fontSize: 12))),
              ],
            ),
            backgroundColor: const Color(0xFF0F766E),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } catch (_) {
    } finally {
      if (mounted) {
        setState(() => _isLocalBusy = false);
        _rotationCtrl.stop();
        _rotationCtrl.reset();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final effectiveColor = widget.color ?? ClientColors.textMuted;
    final spinnerSize = (widget.size * 0.85).clamp(14.0, 24.0);

    final Widget spinnerWidget = SizedBox(
      width: spinnerSize,
      height: spinnerSize,
      child: CircularProgressIndicator(
        strokeWidth: 2.2,
        valueColor: AlwaysStoppedAnimation<Color>(effectiveColor),
      ),
    );

    if (widget.isLabeled) {
      return OutlinedButton.icon(
        onPressed: _isBusy ? null : _handleRefresh,
        style: OutlinedButton.styleFrom(
          padding: widget.padding,
          side: BorderSide(color: effectiveColor.withValues(alpha: 0.3)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        icon: _isBusy ? spinnerWidget : Icon(widget.icon, size: widget.size, color: effectiveColor),
        label: Text(
          _isBusy ? 'Loading...' : (widget.label ?? 'Refresh'),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: effectiveColor,
          ),
        ),
      );
    }

    return Tooltip(
      message: _isBusy ? 'Refreshing...' : widget.tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: _isBusy ? null : _handleRefresh,
        child: Padding(
          padding: widget.padding,
          child: _isBusy
              ? spinnerWidget
              : Icon(
                  widget.icon,
                  size: widget.size,
                  color: effectiveColor,
                ),
        ),
      ),
    );
  }
}
