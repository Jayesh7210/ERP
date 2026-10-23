import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../constants/colors.dart';

/// Production-Grade Live Camera Barcode & QR Scanner Modal
/// Features real-time camera scanning, torch/flashlight toggle, camera switcher,
/// animated scanning laser line, and manual PIN entry fallback.
class LiveQrScannerModal extends StatefulWidget {
  final String title;
  final String subtitle;
  final ValueChanged<String> onScanned;
  final VoidCallback? onCancel;

  const LiveQrScannerModal({
    super.key,
    this.title = 'Scan QR Code',
    this.subtitle = 'Align QR code inside the viewfinder to scan automatically',
    required this.onScanned,
    this.onCancel,
  });

  static Future<String?> show({
    required BuildContext context,
    String title = 'Scan QR Code',
    String subtitle = 'Align QR code inside the viewfinder to scan automatically',
  }) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => LiveQrScannerModal(
        title: title,
        subtitle: subtitle,
        onScanned: (val) {
          Navigator.pop(ctx, val);
        },
        onCancel: () => Navigator.pop(ctx),
      ),
    );
  }

  @override
  State<LiveQrScannerModal> createState() => _LiveQrScannerModalState();
}

class _LiveQrScannerModalState extends State<LiveQrScannerModal>
    with SingleTickerProviderStateMixin {
  late final MobileScannerController _scannerController;
  late final AnimationController _animController;
  late final Animation<double> _animation;
  final TextEditingController _pinController = TextEditingController();

  bool _hasDetected = false;
  bool _isTorchOn = false;
  bool _showPinInput = false;

  @override
  void initState() {
    super.initState();
    _scannerController = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      facing: CameraFacing.back,
      torchEnabled: false,
    );

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    _scannerController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_hasDetected) return;
    final List<Barcode> barcodes = capture.barcodes;
    for (final barcode in barcodes) {
      final raw = barcode.rawValue;
      if (raw != null && raw.trim().isNotEmpty) {
        _hasDetected = true;
        HapticFeedback.mediumImpact();
        widget.onScanned(raw.trim());
        break;
      }
    }
  }

  void _toggleTorch() async {
    await _scannerController.toggleTorch();
    setState(() {
      _isTorchOn = !_isTorchOn;
    });
  }

  void _switchCamera() async {
    await _scannerController.switchCamera();
  }

  void _submitManualPin() {
    final pin = _pinController.text.trim();
    if (pin.isNotEmpty) {
      HapticFeedback.selectionClick();
      widget.onScanned(pin);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final double boxSize = (size.width * 0.7).clamp(220.0, 300.0);

    return Container(
      height: size.height * 0.85,
      decoration: const BoxDecoration(
        color: Color(0xFF141312),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.subtitle,
                        style: const TextStyle(color: Colors.white60, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white70),
                  onPressed: () {
                    if (widget.onCancel != null) {
                      widget.onCancel!();
                    } else {
                      Navigator.pop(context);
                    }
                  },
                ),
              ],
            ),
          ),

          const Divider(color: Colors.white12, height: 1),

          // Main View: Camera or Manual PIN
          Expanded(
            child: _showPinInput
                ? _buildManualPinView()
                : Stack(
                    alignment: Alignment.center,
                    children: [
                      // Camera Stream
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: MobileScanner(
                          controller: _scannerController,
                          onDetect: _onDetect,
                          errorBuilder: (context, error) {
                            return Center(
                              child: Padding(
                                padding: const EdgeInsets.all(24.0),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.videocam_off, color: Colors.amber, size: 48),
                                    const SizedBox(height: 12),
                                    Text(
                                      'Camera unavailable: ${error.errorCode.name}',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(color: Colors.white70, fontSize: 13),
                                    ),
                                    const SizedBox(height: 16),
                                    ElevatedButton.icon(
                                      onPressed: () {
                                        setState(() => _showPinInput = true);
                                      },
                                      icon: const Icon(Icons.pin, size: 16),
                                      label: const Text('Enter PIN Manually'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: ClientColors.primary,
                                        foregroundColor: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),

                      // Dark Vignette Mask with Transparent Cutout for QR
                      ColorFiltered(
                        colorFilter: ColorFilter.mode(
                          Colors.black.withValues(alpha: 0.55),
                          BlendMode.srcOut,
                        ),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Container(
                              decoration: const BoxDecoration(
                                color: Colors.black,
                                backgroundBlendMode: BlendMode.dstOut,
                              ),
                            ),
                            Align(
                              alignment: Alignment.center,
                              child: Container(
                                width: boxSize,
                                height: boxSize,
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  borderRadius: BorderRadius.circular(18),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Targeted Reticles Box
                      Container(
                        width: boxSize,
                        height: boxSize,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: ClientColors.primary.withValues(alpha: 0.6), width: 1.5),
                        ),
                        child: Stack(
                          children: [
                            // 4 Corner brackets
                            _reticleCorner(top: 0, left: 0, isTop: true, isLeft: true),
                            _reticleCorner(top: 0, right: 0, isTop: true, isLeft: false),
                            _reticleCorner(bottom: 0, left: 0, isTop: false, isLeft: true),
                            _reticleCorner(bottom: 0, right: 0, isTop: false, isLeft: false),

                            // Animated Laser Line
                            AnimatedBuilder(
                              animation: _animation,
                              builder: (context, child) {
                                return Positioned(
                                  top: _animation.value * (boxSize - 8),
                                  left: 12,
                                  right: 12,
                                  child: Container(
                                    height: 3,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          ClientColors.primary.withValues(alpha: 0.1),
                                          ClientColors.primary,
                                          ClientColors.primary.withValues(alpha: 0.1),
                                        ],
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: ClientColors.primary.withValues(alpha: 0.8),
                                          blurRadius: 8,
                                          spreadRadius: 1,
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),

                      // Top action controls (Torch, Switch Camera)
                      Positioned(
                        top: 20,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: Colors.white12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: Icon(
                                  _isTorchOn ? Icons.flash_on : Icons.flash_off,
                                  color: _isTorchOn ? Colors.amber : Colors.white70,
                                  size: 22,
                                ),
                                onPressed: _toggleTorch,
                                tooltip: 'Toggle Torch',
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.flip_camera_ios, color: Colors.white70, size: 22),
                                onPressed: _switchCamera,
                                tooltip: 'Switch Camera',
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Bottom helper badge
                      Positioned(
                        bottom: 24,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.black87,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white12),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.qr_code_scanner, color: ClientColors.primary, size: 16),
                              SizedBox(width: 8),
                              Text(
                                'Scanning live barcode / QR feed...',
                                style: TextStyle(color: Colors.white70, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
          ),

          // Bottom Toggle Switch: Scanner vs Manual PIN
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            color: const Color(0xFF1B1917),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      setState(() => _showPinInput = !_showPinInput);
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white24),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: Icon(_showPinInput ? Icons.qr_code_scanner : Icons.pin, size: 18),
                    label: Text(
                      _showPinInput ? 'Switch to Camera Scanner' : 'Enter 6-Digit PIN Manually',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildManualPinView() {
    return Padding(
      padding: const EdgeInsets.all(28.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: ClientColors.primary.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.dialpad, color: ClientColors.primary, size: 36),
          ),
          const SizedBox(height: 16),
          const Text(
            'Manual Verification PIN',
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          const Text(
            'Enter the 6-digit security PIN displayed on the other device',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white60, fontSize: 12),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _pinController,
            autofocus: true,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
              letterSpacing: 8,
              fontFamily: 'monospace',
            ),
            maxLength: 6,
            decoration: InputDecoration(
              counterText: '',
              hintText: '••••••',
              hintStyle: const TextStyle(color: Colors.white24, letterSpacing: 8),
              filled: true,
              fillColor: const Color(0xFF262320),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Colors.white12),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: ClientColors.primary, width: 2),
              ),
            ),
            onSubmitted: (_) => _submitManualPin(),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _submitManualPin,
              style: ElevatedButton.styleFrom(
                backgroundColor: ClientColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Verify PIN & Proceed', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _reticleCorner({
    double? top,
    double? bottom,
    double? left,
    double? right,
    required bool isTop,
    required bool isLeft,
  }) {
    const double length = 22.0;
    const double thickness = 3.5;
    const color = ClientColors.primary;

    return Positioned(
      top: top,
      bottom: bottom,
      left: left,
      right: right,
      child: Container(
        width: length,
        height: length,
        decoration: BoxDecoration(
          border: Border(
            top: isTop ? const BorderSide(color: color, width: thickness) : BorderSide.none,
            bottom: !isTop ? const BorderSide(color: color, width: thickness) : BorderSide.none,
            left: isLeft ? const BorderSide(color: color, width: thickness) : BorderSide.none,
            right: !isLeft ? const BorderSide(color: color, width: thickness) : BorderSide.none,
          ),
        ),
      ),
    );
  }
}
