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
  XFile? _image;
  var _isSaving = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final image = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 1600,
    );
    if (image == null) return;
    setState(() => _image = image);
  }

  Future<void> _submit() async {
    if (_isSaving || !(_formKey.currentState?.validate() ?? false)) return;
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
        centerTitle: true,
        leading: IconButton(
          tooltip: 'Quay lại',
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: Text(
          'Báo cáo lỗi',
          style: AppTextStyles.headlineLargeMobile.copyWith(
            color: AppColors.primary,
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                _ReportFormCard(
                  formKey: _formKey,
                  titleController: _titleController,
                  descriptionController: _descriptionController,
                  severity: _severity,
                  screenName: _screenName,
                  image: _image,
                  isSaving: _isSaving,
                  onSeverityChanged: (value) {
                    if (value == null) return;
                    setState(() => _severity = value);
                  },
                  onScreenChanged: (value) {
                    if (value == null) return;
                    setState(() => _screenName = value);
                  },
                  onPickImage: _pickImage,
                  onRemoveImage: () => setState(() => _image = null),
                  onSubmit: _submit,
                ),
                const SizedBox(height: 20),
                Text('Báo cáo đã gửi', style: AppTextStyles.titleMedium),
                const SizedBox(height: 10),
                StreamBuilder<List<BugReport>>(
                  stream: _repository.watchMyBugReports(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
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
    );
  }
}

class _ReportFormCard extends StatelessWidget {
  const _ReportFormCard({
    required this.formKey,
    required this.titleController,
    required this.descriptionController,
    required this.severity,
    required this.screenName,
    required this.image,
    required this.isSaving,
    required this.onSeverityChanged,
    required this.onScreenChanged,
    required this.onPickImage,
    required this.onRemoveImage,
    required this.onSubmit,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController titleController;
  final TextEditingController descriptionController;
  final String severity;
  final String screenName;
  final XFile? image;
  final bool isSaving;
  final ValueChanged<String?> onSeverityChanged;
  final ValueChanged<String?> onScreenChanged;
  final VoidCallback onPickImage;
  final VoidCallback onRemoveImage;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.outlineVariant.withValues(alpha: 0.20),
        ),
      ),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Gửi lỗi cho admin', style: AppTextStyles.titleMedium),
            const SizedBox(height: 14),
            TextFormField(
              controller: titleController,
              decoration: const InputDecoration(
                labelText: 'Tiêu đề lỗi',
                prefixIcon: Icon(Icons.bug_report_outlined),
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if ((value ?? '').trim().length < 5) {
                  return 'Nhập tiêu đề ít nhất 5 ký tự';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: descriptionController,
              minLines: 4,
              maxLines: 6,
              decoration: const InputDecoration(
                labelText: 'Mô tả chi tiết',
                alignLabelWithHint: true,
                prefixIcon: Icon(Icons.notes_rounded),
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if ((value ?? '').trim().length < 10) {
                  return 'Mô tả lỗi rõ hơn một chút nhé';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: severity,
                    decoration: const InputDecoration(
                      labelText: 'Mức độ',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'low', child: Text('Thấp')),
                      DropdownMenuItem(
                        value: 'medium',
                        child: Text('Trung bình'),
                      ),
                      DropdownMenuItem(value: 'high', child: Text('Cao')),
                      DropdownMenuItem(
                        value: 'critical',
                        child: Text('Nghiêm trọng'),
                      ),
                    ],
                    onChanged: onSeverityChanged,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: screenName,
                    decoration: const InputDecoration(
                      labelText: 'Màn hình',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'Không rõ',
                        child: Text('Không rõ'),
                      ),
                      DropdownMenuItem(value: 'Home', child: Text('Home')),
                      DropdownMenuItem(
                        value: 'Transactions',
                        child: Text('Giao dịch'),
                      ),
                      DropdownMenuItem(
                        value: 'Statistics',
                        child: Text('Thống kê'),
                      ),
                      DropdownMenuItem(value: 'Profile', child: Text('Hồ sơ')),
                      DropdownMenuItem(
                        value: 'Currency',
                        child: Text('Đổi tiền'),
                      ),
                    ],
                    onChanged: onScreenChanged,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (image == null)
              OutlinedButton.icon(
                onPressed: onPickImage,
                icon: const Icon(Icons.image_outlined),
                label: const Text('Đính kèm ảnh lỗi'),
              )
            else
              _SelectedImagePreview(image: image!, onRemove: onRemoveImage),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton.icon(
                onPressed: isSaving ? null : onSubmit,
                icon: isSaving
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send_rounded),
                label: Text(isSaving ? 'Đang gửi...' : 'Gửi báo cáo'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SelectedImagePreview extends StatelessWidget {
  const _SelectedImagePreview({required this.image, required this.onRemove});

  final XFile image;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: FutureBuilder<Uint8List>(
              future: image.readAsBytes(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const SizedBox.square(
                    dimension: 56,
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                return Image.memory(
                  snapshot.data!,
                  width: 56,
                  height: 56,
                  fit: BoxFit.cover,
                );
              },
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              image.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.bodyMedium,
            ),
          ),
          IconButton(
            tooltip: 'Xóa ảnh',
            onPressed: onRemove,
            icon: const Icon(Icons.close_rounded),
          ),
        ],
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
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.outlineVariant.withValues(alpha: 0.20),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(report.title, style: AppTextStyles.titleMedium),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
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
          const SizedBox(height: 8),
          Text(
            '${_severityLabel(report.severity)} • ${report.screenName ?? 'Không rõ'} • ${formatDateTime(report.createdAt)}',
            style: AppTextStyles.labelMedium,
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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        'Bạn chưa gửi báo cáo lỗi nào.',
        textAlign: TextAlign.center,
        style: AppTextStyles.bodyMedium.copyWith(
          color: AppColors.onSurfaceVariant,
        ),
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
    'resolved' => _StatusInfo('Đã xử lý', AppColors.secondary),
    'rejected' => _StatusInfo('Từ chối', AppColors.error),
    _ => _StatusInfo('Chờ xử lý', AppColors.tertiary),
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
