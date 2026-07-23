import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/app_formatters.dart';
import '../../data/models/bug_report.dart';
import '../../data/repositories/firebase_auth_error_mapper.dart';
import '../../data/repositories/firestore_repository.dart';
import '../../data/repositories/storage_repository.dart';

class BugReportScreen extends StatefulWidget {
  const BugReportScreen({super.key});

  @override
  State<BugReportScreen> createState() => _BugReportScreenState();
}

class _BugReportScreenState extends State<BugReportScreen> {
  final _formKey = GlobalKey<FormState>();
  final _repository = FirestoreRepository();
  final _storageRepository = StorageRepository();
  final _imagePicker = ImagePicker();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  var _severity = 'medium';
  var _screenName = 'Không rõ';
  var _filtersExpanded = false;
  XFile? _image;
  Uint8List? _imageBytes;
  var _isSaving = false;

  static const _screens = [
    'Không rõ',
    'Trang chủ',
    'Giao dịch',
    'Thống kê',
    'Cá nhân',
    'Đổi tiền',
    'Ngân sách',
    'Khác',
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    if (_isSaving) return;
    try {
      final image = await _imagePicker.pickImage(
        source: source,
        imageQuality: 80,
        maxWidth: 1600,
      );
      if (image == null) return;
      final bytes = await image.readAsBytes();
      if (!mounted) return;
      setState(() {
        _image = image;
        _imageBytes = bytes;
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(firebaseAuthErrorMessage(error))));
    }
  }

  Future<void> _showImageOptions() async {
    if (_isSaving) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surfaceContainerLowest,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.outlineVariant,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 16),
                Text('Đính kèm ảnh lỗi', style: AppTextStyles.titleMedium),
                const SizedBox(height: 8),
                ListTile(
                  leading: Icon(
                    Icons.photo_library_outlined,
                    color: AppColors.primary,
                  ),
                  title: const Text('Chọn từ thư viện'),
                  onTap: () {
                    Navigator.pop(context);
                    _pickImage(ImageSource.gallery);
                  },
                ),
                ListTile(
                  leading: Icon(
                    Icons.photo_camera_outlined,
                    color: AppColors.primary,
                  ),
                  title: const Text('Chụp ảnh màn hình'),
                  onTap: () {
                    Navigator.pop(context);
                    _pickImage(ImageSource.camera);
                  },
                ),
                if (_image != null)
                  ListTile(
                    leading: Icon(
                      Icons.delete_outline_rounded,
                      color: AppColors.expense,
                    ),
                    title: Text(
                      'Xóa ảnh đã chọn',
                      style: TextStyle(color: AppColors.expense),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      setState(() {
                        _image = null;
                        _imageBytes = null;
                      });
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _submit() async {
    if (_isSaving || !(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    setState(() => _isSaving = true);

    try {
      BugImageUploadResult? uploadResult;
      if (_image != null) {
        uploadResult = await _storageRepository.uploadBugImage(image: _image!);
      }

      await _repository.createBugReport(
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        severity: _severity,
        screenName: _screenName,
        imageUrl: uploadResult?.downloadUrl,
        imageStoragePath: uploadResult?.storagePath,
      );

      _titleController.clear();
      _descriptionController.clear();
      setState(() {
        _image = null;
        _imageBytes = null;
        _severity = 'medium';
        _screenName = 'Không rõ';
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã gửi báo cáo lỗi cho admin.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(firebaseAuthErrorMessage(error))));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        leading: IconButton(
          tooltip: 'Quay lại',
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close_rounded),
        ),
        title: Text(
          'Báo cáo lỗi',
          style: AppTextStyles.headlineLargeMobile.copyWith(
            color: AppColors.onSurface,
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: SizedBox(
            height: 52,
            child: FilledButton(
              onPressed: _isSaving ? null : _submit,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primaryContainer,
                foregroundColor: AppColors.onPrimaryContainer,
                disabledBackgroundColor: AppColors.primaryContainer.withValues(
                  alpha: 0.55,
                ),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: _isSaving
                  ? SizedBox.square(
                      dimension: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: AppColors.onPrimaryContainer,
                      ),
                    )
                  : Text(
                      'Gửi báo cáo',
                      style: AppTextStyles.titleMedium.copyWith(
                        color: AppColors.onPrimaryContainer,
                        fontSize: 16,
                      ),
                    ),
            ),
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Form(
              key: _formKey,
              child: ListView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.fromLTRB(
                  16,
                  8,
                  16,
                  24 + MediaQuery.viewInsetsOf(context).bottom,
                ),
                children: [
                  const _IntroBanner(),
                  const SizedBox(height: 16),
                  _FormCard(
                    children: [
                      Text(
                        'Thông tin lỗi',
                        style: AppTextStyles.titleMedium.copyWith(fontSize: 16),
                      ),
                      const SizedBox(height: 14),
                      _SoftTextField(
                        controller: _titleController,
                        label: 'Tiêu đề',
                        hint: 'Ví dụ: App bị crash khi mở Thống kê',
                        icon: Icons.title_rounded,
                        textInputAction: TextInputAction.next,
                        validator: (value) {
                          if ((value ?? '').trim().length < 5) {
                            return 'Nhập tiêu đề ít nhất 5 ký tự';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      _SoftTextField(
                        controller: _descriptionController,
                        label: 'Mô tả chi tiết',
                        hint:
                            'Bạn đang làm gì khi lỗi xảy ra? Kết quả mong muốn là gì?',
                        icon: Icons.notes_rounded,
                        minLines: 4,
                        maxLines: 6,
                        alignLabelWithHint: true,
                        validator: (value) {
                          if ((value ?? '').trim().length < 10) {
                            return 'Mô tả lỗi rõ hơn một chút nhé';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      _FilterToggleRow(
                        severityLabel: _severityLabel(_severity),
                        screenName: _screenName,
                        expanded: _filtersExpanded,
                        onToggle: () {
                          setState(() => _filtersExpanded = !_filtersExpanded);
                        },
                      ),
                      AnimatedSize(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOutCubic,
                        alignment: Alignment.topCenter,
                        child: _filtersExpanded
                            ? Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  const SizedBox(height: 14),
                                  Text(
                                    'Mức độ',
                                    style: AppTextStyles.labelMedium.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      for (final item in const [
                                        ('low', 'Thấp'),
                                        ('medium', 'Trung bình'),
                                        ('high', 'Cao'),
                                        ('critical', 'Nghiêm trọng'),
                                      ])
                                        _SeverityChip(
                                          label: item.$2,
                                          selected: _severity == item.$1,
                                          color: _severityColor(item.$1),
                                          onTap: () => setState(
                                            () => _severity = item.$1,
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 14),
                                  Text(
                                    'Màn hình gặp lỗi',
                                    style: AppTextStyles.labelMedium.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  DropdownButtonFormField<String>(
                                    initialValue: _screenName,
                                    decoration: _softDecoration(
                                      icon: Icons.phone_android_rounded,
                                    ),
                                    items: [
                                      for (final screen in _screens)
                                        DropdownMenuItem(
                                          value: screen,
                                          child: Text(screen),
                                        ),
                                    ],
                                    onChanged: (value) {
                                      if (value == null) return;
                                      setState(() => _screenName = value);
                                    },
                                  ),
                                ],
                              )
                            : const SizedBox.shrink(),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Ảnh minh họa (tuỳ chọn)',
                        style: AppTextStyles.labelMedium.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _ImageAttachArea(
                        imageBytes: _imageBytes,
                        enabled: !_isSaving,
                        onTap: _showImageOptions,
                        onRemove: () {
                          setState(() {
                            _image = null;
                            _imageBytes = null;
                          });
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Báo cáo đã gửi',
                    style: AppTextStyles.titleMedium.copyWith(fontSize: 16),
                  ),
                  const SizedBox(height: 10),
                  StreamBuilder<List<BugReport>>(
                    stream: _repository.watchMyBugReports(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      if (snapshot.hasError) {
                        return Text(firebaseAuthErrorMessage(snapshot.error!));
                      }

                      final reports = snapshot.data ?? [];
                      if (reports.isEmpty) return const _EmptyReports();

                      return Column(
                        children: [
                          for (final report in reports) ...[
                            _BugReportTile(report: report),
                            const SizedBox(height: 10),
                          ],
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _IntroBanner extends StatelessWidget {
  const _IntroBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            AppColors.primary.withValues(alpha: 0.10),
            AppColors.secondaryContainer.withValues(alpha: 0.35),
          ],
        ),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.14)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primaryContainer,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              Icons.bug_report_rounded,
              color: AppColors.onPrimaryContainer,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Giúp chúng tôi cải thiện app',
                  style: AppTextStyles.titleMedium.copyWith(fontSize: 16),
                ),
                const SizedBox(height: 2),
                Text(
                  'Mô tả rõ lỗi và đính kèm ảnh nếu có để xử lý nhanh hơn.',
                  style: AppTextStyles.labelMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterToggleRow extends StatelessWidget {
  const _FilterToggleRow({
    required this.severityLabel,
    required this.screenName,
    required this.expanded,
    required this.onToggle,
  });

  final String severityLabel;
  final String screenName;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onToggle,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: expanded
                ? AppColors.primaryFixed.withValues(alpha: 0.45)
                : AppColors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: expanded
                  ? AppColors.primary.withValues(alpha: 0.28)
                  : AppColors.outlineVariant.withValues(alpha: 0.2),
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.tune_rounded,
                color: AppColors.primary,
                size: 22,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bộ lọc',
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$severityLabel • $screenName',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.labelMedium,
                    ),
                  ],
                ),
              ),
              Icon(
                expanded
                    ? Icons.keyboard_arrow_up_rounded
                    : Icons.keyboard_arrow_down_rounded,
                color: AppColors.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FormCard extends StatelessWidget {
  const _FormCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.outlineVariant.withValues(alpha: 0.14),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}

InputDecoration _softDecoration({required IconData icon, String? hint}) {
  return InputDecoration(
    hintText: hint,
    prefixIcon: Icon(icon),
    filled: true,
    fillColor: AppColors.surfaceContainerLow,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide.none,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: AppColors.primary, width: 1.5),
    ),
  );
}

class _SoftTextField extends StatelessWidget {
  const _SoftTextField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.minLines = 1,
    this.maxLines = 1,
    this.alignLabelWithHint = false,
    this.textInputAction,
    this.validator,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final int minLines;
  final int maxLines;
  final bool alignLabelWithHint;
  final TextInputAction? textInputAction;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTextStyles.labelMedium.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          minLines: minLines,
          maxLines: maxLines,
          textInputAction: textInputAction,
          validator: validator,
          style: AppTextStyles.bodyMedium,
          decoration: _softDecoration(icon: icon, hint: hint).copyWith(
            alignLabelWithHint: alignLabelWithHint,
          ),
        ),
      ],
    );
  }
}

class _SeverityChip extends StatelessWidget {
  const _SeverityChip({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: selected
                ? color.withValues(alpha: 0.14)
                : AppColors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected
                  ? color.withValues(alpha: 0.45)
                  : AppColors.outlineVariant.withValues(alpha: 0.22),
            ),
          ),
          child: Text(
            label,
            style: AppTextStyles.labelMedium.copyWith(
              color: selected ? color : AppColors.onSurface,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

class _ImageAttachArea extends StatelessWidget {
  const _ImageAttachArea({
    required this.imageBytes,
    required this.enabled,
    required this.onTap,
    required this.onRemove,
  });

  final Uint8List? imageBytes;
  final bool enabled;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    if (imageBytes != null) {
      return Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: Image.memory(imageBytes!, fit: BoxFit.cover),
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: Material(
              color: Colors.black.withValues(alpha: 0.45),
              shape: const CircleBorder(),
              child: IconButton(
                tooltip: 'Xóa ảnh',
                onPressed: enabled ? onRemove : null,
                icon: const Icon(Icons.close_rounded, color: Colors.white),
              ),
            ),
          ),
          Positioned(
            left: 8,
            bottom: 8,
            child: FilledButton.tonal(
              onPressed: enabled ? onTap : null,
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white.withValues(alpha: 0.92),
                foregroundColor: AppColors.primary,
              ),
              child: const Text('Đổi ảnh'),
            ),
          ),
        ],
      );
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.22),
              style: BorderStyle.solid,
            ),
          ),
          child: Column(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.add_photo_alternate_outlined,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Thêm ảnh chụp màn hình',
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Thư viện hoặc camera',
                style: AppTextStyles.labelMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BugReportTile extends StatelessWidget {
  const _BugReportTile({required this.report});

  final BugReport report;

  @override
  Widget build(BuildContext context) {
    final status = _statusInfo(report.status);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.outlineVariant.withValues(alpha: 0.14),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.035),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  report.title,
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: status.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  status.label,
                  style: AppTextStyles.labelMedium.copyWith(
                    color: status.color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            report.description,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _MetaChip(
                icon: Icons.flag_outlined,
                label: _severityLabel(report.severity),
                color: _severityColor(report.severity),
              ),
              _MetaChip(
                icon: Icons.phone_android_rounded,
                label: report.screenName ?? 'Không rõ',
              ),
              _MetaChip(
                icon: Icons.schedule_rounded,
                label: formatDateTime(report.createdAt),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({
    required this.icon,
    required this.label,
    this.color,
  });

  final IconData icon;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tone = color ?? AppColors.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: tone),
          const SizedBox(width: 4),
          Text(
            label,
            style: AppTextStyles.labelMedium.copyWith(color: tone),
          ),
        ],
      ),
    );
  }
}

class _EmptyReports extends StatelessWidget {
  const _EmptyReports();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.outlineVariant.withValues(alpha: 0.14),
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(
              Icons.inbox_outlined,
              color: AppColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Chưa có báo cáo nào',
            style: AppTextStyles.titleMedium.copyWith(fontSize: 16),
          ),
          const SizedBox(height: 4),
          Text(
            'Các báo cáo bạn gửi sẽ hiện tại đây.',
            textAlign: TextAlign.center,
            style: AppTextStyles.labelMedium,
          ),
        ],
      ),
    );
  }
}

class _StatusInfo {
  const _StatusInfo(this.label, this.color);

  final String label;
  final Color color;
}

_StatusInfo _statusInfo(String status) {
  return switch (status) {
    'in_progress' => _StatusInfo('Đang xử lý', AppColors.primary),
    'resolved' => _StatusInfo('Đã xử lý', AppColors.primary),
    'rejected' => _StatusInfo('Từ chối', AppColors.expense),
    _ => _StatusInfo('Chờ xử lý', AppColors.onSurfaceVariant),
  };
}

String _severityLabel(String severity) {
  return switch (severity) {
    'low' => 'Thấp',
    'high' => 'Cao',
    'critical' => 'Nghiêm trọng',
    _ => 'Trung bình',
  };
}

Color _severityColor(String severity) {
  return switch (severity) {
    'low' => AppColors.primary,
    'high' => const Color(0xFFD97706),
    'critical' => AppColors.expense,
    _ => AppColors.primary,
  };
}
