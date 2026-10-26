import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/constants/colors.dart';

class SalesmanReferralModal {
  static Future<void> show({
    required BuildContext context,
    required Future<bool> Function({
      required String name,
      required String phone,
      String? email,
      String? docType,
      String? kycDoc,
    }) onSubmit,
  }) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _SalesmanReferralSheet(onSubmit: onSubmit),
    );
  }
}

class _SalesmanReferralSheet extends StatefulWidget {
  final Future<bool> Function({
    required String name,
    required String phone,
    String? email,
    String? docType,
    String? kycDoc,
  }) onSubmit;

  const _SalesmanReferralSheet({required this.onSubmit});

  @override
  State<_SalesmanReferralSheet> createState() => _SalesmanReferralSheetState();
}

class _SalesmanReferralSheetState extends State<_SalesmanReferralSheet> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _phoneCtrl = TextEditingController();
  final TextEditingController _emailCtrl = TextEditingController();

  String _selectedDocType = 'Aadhaar Card';
  String _selectedFileName = 'Tap to select document';
  String? _selectedKycBase64;
  Uint8List? _selectedKycBytes;
  bool _isSubmitting = false;

  final List<String> _docTypes = [
    'Aadhaar Card',
    'PAN Card',
    'Driving License',
    'Voter ID',
  ];

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDocument(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1600,
      );
      if (picked != null) {
        final bytes = await picked.readAsBytes();
        final base64Str = 'data:image/jpeg;base64,${base64Encode(bytes)}';
        setState(() {
          _selectedFileName = picked.name;
          _selectedKycBase64 = base64Str;
          _selectedKycBytes = bytes;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to select file: $e')),
        );
      }
    }
  }

  void _showDocumentPickerOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: Row(
                  children: [
                    Icon(Icons.file_present_outlined, color: ClientColors.primary, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Attach ID Proof Document',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ],
                ),
              ),
              const Divider(height: 16),
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: ClientColors.primary.withValues(alpha: 0.12),
                  child: const Icon(Icons.camera_alt, color: ClientColors.primary),
                ),
                title: const Text('Take Photo with Camera', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Capture clear photo of physical ID proof', style: TextStyle(fontSize: 12)),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickDocument(ImageSource.camera);
                },
              ),
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.blue.withValues(alpha: 0.12),
                  child: const Icon(Icons.photo_library, color: Colors.blue),
                ),
                title: const Text('Choose from Gallery / Photos', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Select existing photo or scan', style: TextStyle(fontSize: 12)),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickDocument(ImageSource.gallery);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleSubmit() async {
    final name = _nameCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();
    final email = _emailCtrl.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter candidate\'s full name'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    if (phone.isEmpty || phone.length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid 10-digit mobile number'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final success = await widget.onSubmit(
        name: name,
        phone: phone,
        email: email.isNotEmpty ? email : null,
        docType: _selectedDocType,
        kycDoc: _selectedKycBase64 ?? (_selectedFileName != 'Tap to select document' ? _selectedFileName : null),
      );

      if (success && mounted) {
        Navigator.of(context).pop();
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final maxSheetHeight = MediaQuery.of(context).size.height * 0.88;

    return Container(
      constraints: BoxConstraints(maxHeight: maxSheetHeight),
      margin: EdgeInsets.only(bottom: bottomInset),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag Handle
          const SizedBox(height: 10),
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: ClientColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.person_add_alt_1,
                    color: ClientColors.primary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Refer a New Salesman',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: ClientColors.textDark,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Add candidate details & document proof',
                        style: TextStyle(
                          fontSize: 12,
                          color: ClientColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, color: Colors.grey),
                  splashRadius: 20,
                  tooltip: 'Close',
                ),
              ],
            ),
          ),
          const Divider(height: 18),

          // Form Body
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Candidate Name
                    const Text(
                      'Full Name *',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: ClientColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _nameCtrl,
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(
                        hintText: 'e.g. Rahul Sharma',
                        prefixIcon: const Icon(Icons.person_outline, size: 20),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Phone Number
                    const Text(
                      'Mobile Number *',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: ClientColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _phoneCtrl,
                      keyboardType: TextInputType.phone,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(10),
                      ],
                      decoration: InputDecoration(
                        hintText: '10-digit mobile number',
                        prefixIcon: const Icon(Icons.phone_outlined, size: 20),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Email Address
                    const Text(
                      'Email Address',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: ClientColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        hintText: 'e.g. rahul@example.com (optional)',
                        prefixIcon: const Icon(Icons.email_outlined, size: 20),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Document Type Selector
                    const Text(
                      'Document / ID Proof Type',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: ClientColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedDocType,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.badge_outlined, size: 20),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      ),
                      items: _docTypes.map((type) {
                        return DropdownMenuItem<String>(
                          value: type,
                          child: Text(type, style: const TextStyle(fontSize: 13.5)),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedDocType = val);
                      },
                    ),
                    const SizedBox(height: 14),

                    // Document / KYC Attachment
                    const Text(
                      'KYC Document / Proof',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: ClientColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _selectedKycBytes != null
                            ? Colors.green.withValues(alpha: 0.04)
                            : ClientColors.creamBg,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: _selectedKycBytes != null ? Colors.green.shade300 : ClientColors.border,
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
                                    _selectedKycBytes != null
                                        ? Icons.verified
                                        : Icons.cloud_upload_outlined,
                                    color: _selectedKycBytes != null ? Colors.green : ClientColors.primary,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _selectedKycBytes != null
                                        ? 'Document Attached'
                                        : 'Attach ID Proof Image',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: _selectedKycBytes != null ? Colors.green.shade800 : ClientColors.textDark,
                                    ),
                                  ),
                                ],
                              ),
                              if (_selectedKycBytes != null)
                                GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _selectedFileName = 'Tap to select document';
                                      _selectedKycBase64 = null;
                                      _selectedKycBytes = null;
                                    });
                                  },
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
                          if (_selectedKycBytes != null) ...[
                            const SizedBox(height: 10),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.memory(
                                _selectedKycBytes!,
                                height: 110,
                                width: double.infinity,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ],
                          const SizedBox(height: 10),
                          InkWell(
                            onTap: _showDocumentPickerOptions,
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: ClientColors.border),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    _selectedKycBytes != null ? Icons.check_circle : Icons.upload_file,
                                    size: 16,
                                    color: _selectedKycBytes != null ? Colors.green : ClientColors.primary,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _selectedFileName,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: _selectedKycBytes != null ? FontWeight.bold : FontWeight.normal,
                                        color: _selectedKycBytes != null ? Colors.black87 : ClientColors.textMuted,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Text(
                                    _selectedKycBytes != null ? 'Change' : 'Attach',
                                    style: const TextStyle(
                                      fontSize: 12,
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
                    const SizedBox(height: 22),

                    // Action Buttons
                    Row(
                      children: [
                        Expanded(
                          flex: 1,
                          child: OutlinedButton(
                            onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: ClientColors.textDark,
                              side: const BorderSide(color: ClientColors.border),
                              minimumSize: const Size.fromHeight(46),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w600)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            onPressed: _isSubmitting ? null : _handleSubmit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: ClientColors.primary,
                              foregroundColor: Colors.white,
                              minimumSize: const Size.fromHeight(46),
                              elevation: 1,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            child: _isSubmitting
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.check_circle_outline, size: 18),
                                      SizedBox(width: 6),
                                      Text(
                                        'Submit Referral',
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
