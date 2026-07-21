import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../data/models/app_user_profile.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/firebase_auth_error_mapper.dart';
import '../../data/repositories/firestore_repository.dart';
import '../../data/repositories/storage_repository.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _avatarUrlController = TextEditingController();
  final _firestoreRepository = FirestoreRepository();
  final _authRepository = AuthRepository();
  final _storageRepository = StorageRepository();
  final _imagePicker = ImagePicker();

  AppUserProfile? _profile;
  XFile? _selectedAvatar;
  Uint8List? _selectedAvatarBytes;
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController.addListener(_refreshPreview);
    _avatarUrlController.addListener(_refreshPreview);
    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.removeListener(_refreshPreview);
    _avatarUrlController.removeListener(_refreshPreview);
    _nameController.dispose();
    _emailController.dispose();
    _avatarUrlController.dispose();
    super.dispose();
  }

  void _refreshPreview() {
    if (mounted) setState(() {});
  }

  Future<void> _pickAvatar() async {
    if (_isSaving) return;

    try {
      final image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 900,
        maxHeight: 900,
        imageQuality: 88,
      );
      if (image == null) return;

      final bytes = await image.readAsBytes();
      if (!mounted) return;
      setState(() {
        _selectedAvatar = image;
        _selectedAvatarBytes = bytes;
        _avatarUrlController.clear();
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(firebaseAuthErrorMessage(error))));
    }
  }

  void _removeAvatar() {
    if (_isSaving) return;
    setState(() {
      _selectedAvatar = null;
      _selectedAvatarBytes = null;
      _avatarUrlController.clear();
    });
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await _firestoreRepository.fetchProfile();
      if (!mounted) return;
      _profile = profile;
      _nameController.text = profile?.fullName ?? '';
      _emailController.text = profile?.email ?? '';
      _avatarUrlController.text = profile?.avatarUrl ?? '';
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(firebaseAuthErrorMessage(error))));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveProfile() async {
    if (_isSaving || !(_formKey.currentState?.validate() ?? false)) return;

    final profile = _profile;
    if (profile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không tìm thấy hồ sơ để cập nhật.')),
      );
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _isSaving = true);

    final fullName = _nameController.text.trim();
    final avatarUrl = _avatarUrlController.text.trim();
    var normalizedAvatarUrl = avatarUrl.isEmpty ? null : avatarUrl;
    var nextAvatarStoragePath = profile.avatarStoragePath;

    try {
      if (_selectedAvatar == null && normalizedAvatarUrl != profile.avatarUrl) {
        nextAvatarStoragePath = null;
      }

      if (_selectedAvatar != null) {
        final uploadResult = await _storageRepository.uploadAvatar(
          image: _selectedAvatar!,
          fullName: fullName,
        );
        normalizedAvatarUrl = uploadResult.downloadUrl;
        nextAvatarStoragePath = uploadResult.storagePath;
      }

      await _authRepository.updateCurrentUserProfile(
        fullName: fullName,
        avatarUrl: normalizedAvatarUrl,
      );
      await _firestoreRepository.updateProfile(
        profile.copyWith(
          fullName: fullName,
          avatarUrl: normalizedAvatarUrl,
          clearAvatarUrl: normalizedAvatarUrl == null,
          avatarStoragePath: nextAvatarStoragePath,
          clearAvatarStoragePath: normalizedAvatarUrl == null,
        ),
      );

      if (profile.avatarStoragePath != null &&
          profile.avatarStoragePath != nextAvatarStoragePath) {
        await _storageRepository.deleteFileIfExists(profile.avatarStoragePath);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Đã cập nhật hồ sơ.')));
      Navigator.of(context).pop();
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
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: Text(
          'Chỉnh sửa hồ sơ',
          style: AppTextStyles.headlineLargeMobile.copyWith(
            color: AppColors.primary,
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _profile == null
                ? const _MissingProfileState()
                : Form(
                    key: _formKey,
                    child: ListView(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: EdgeInsets.fromLTRB(
                        16,
                        16,
                        16,
                        32 + MediaQuery.viewInsetsOf(context).bottom,
                      ),
                      children: [
                        _AvatarPreview(
                          name: _nameController.text,
                          avatarUrl: _previewAvatarUrl,
                          imageBytes: _selectedAvatarBytes,
                        ),
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: _isSaving ? null : _pickAvatar,
                                icon: const Icon(Icons.upload_rounded),
                                label: const Text('Chọn ảnh'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _isSaving || !_hasAvatar
                                    ? null
                                    : _removeAvatar,
                                icon: const Icon(Icons.delete_outline_rounded),
                                label: const Text('Xóa ảnh'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        _ProfileTextField(
                          controller: _nameController,
                          label: 'Họ tên',
                          hintText: 'Nhập họ tên',
                          icon: Icons.person_outline_rounded,
                          textInputAction: TextInputAction.next,
                          validator: (value) {
                            final name = value?.trim() ?? '';
                            if (name.isEmpty) {
                              return 'Vui lòng nhập họ tên.';
                            }
                            if (name.length < 2) {
                              return 'Họ tên cần ít nhất 2 ký tự.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),
                        _ProfileTextField(
                          controller: _emailController,
                          label: 'Email',
                          hintText: 'Email',
                          icon: Icons.mail_outline_rounded,
                          enabled: false,
                        ),
                        const SizedBox(height: 14),
                        _ProfileTextField(
                          controller: _avatarUrlController,
                          label: 'URL ảnh đại diện',
                          hintText: 'Tự điền sau khi upload hoặc nhập URL',
                          icon: Icons.image_outlined,
                          keyboardType: TextInputType.url,
                          textInputAction: TextInputAction.done,
                          suffix: _avatarUrlController.text.trim().isEmpty
                              ? null
                              : IconButton(
                                  tooltip: 'Xóa ảnh',
                                  onPressed: () => _avatarUrlController.clear(),
                                  icon: const Icon(Icons.close_rounded),
                                ),
                          validator: (value) {
                            final url = value?.trim() ?? '';
                            if (url.isEmpty) return null;
                            final uri = Uri.tryParse(url);
                            if (uri == null ||
                                uri.host.isEmpty ||
                                (uri.scheme != 'http' &&
                                    uri.scheme != 'https')) {
                              return 'URL ảnh phải bắt đầu bằng http hoặc https.';
                            }
                            return null;
                          },
                          onFieldSubmitted: (_) => _saveProfile(),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: _isSaving
                                    ? null
                                    : () => Navigator.of(context).pop(),
                                child: const Text('Hủy'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: _isSaving ? null : _saveProfile,
                                icon: _isSaving
                                    ? const SizedBox.square(
                                        dimension: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.save_outlined),
                                label: Text(
                                  _isSaving ? 'Đang lưu...' : 'Lưu thay đổi',
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
      ),
    );
  }

  String? get _normalizedAvatarUrl {
    final value = _avatarUrlController.text.trim();
    return value.isEmpty ? null : value;
  }

  String? get _previewAvatarUrl {
    if (_selectedAvatarBytes != null) return null;
    final value = _normalizedAvatarUrl;
    if (value == null) return null;
    final uri = Uri.tryParse(value);
    if (uri == null || uri.host.isEmpty) return null;
    if (uri.scheme != 'http' && uri.scheme != 'https') return null;
    return value;
  }

  bool get _hasAvatar {
    return _selectedAvatarBytes != null || _normalizedAvatarUrl != null;
  }
}

class _AvatarPreview extends StatelessWidget {
  const _AvatarPreview({
    required this.name,
    required this.avatarUrl,
    required this.imageBytes,
  });

  final String name;
  final String? avatarUrl;
  final Uint8List? imageBytes;

  @override
  Widget build(BuildContext context) {
    final trimmedName = name.trim();
    final initial = trimmedName.isEmpty ? '?' : trimmedName.characters.first;
    final avatarImage = imageBytes != null
        ? MemoryImage(imageBytes!)
        : avatarUrl == null
        ? null
        : NetworkImage(avatarUrl!) as ImageProvider;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.outlineVariant.withValues(alpha: 0.20),
        ),
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 46,
            backgroundColor: AppColors.secondaryContainer,
            backgroundImage: avatarImage,
            child: avatarImage == null
                ? Text(
                    initial.toUpperCase(),
                    style: AppTextStyles.headlineLarge.copyWith(
                      color: AppColors.onSecondaryContainer,
                    ),
                  )
                : null,
          ),
          const SizedBox(height: 14),
          Text(
            trimmedName.isEmpty ? 'Tên của bạn' : trimmedName,
            textAlign: TextAlign.center,
            style: AppTextStyles.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            'Ảnh và tên này sẽ hiển thị trong hồ sơ.',
            textAlign: TextAlign.center,
            style: AppTextStyles.labelMedium,
          ),
        ],
      ),
    );
  }
}

class _ProfileTextField extends StatelessWidget {
  const _ProfileTextField({
    required this.controller,
    required this.label,
    required this.hintText,
    required this.icon,
    this.enabled = true,
    this.keyboardType,
    this.textInputAction,
    this.suffix,
    this.validator,
    this.onFieldSubmitted,
  });

  final TextEditingController controller;
  final String label;
  final String hintText;
  final IconData icon;
  final bool enabled;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Widget? suffix;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onFieldSubmitted;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      validator: validator,
      onFieldSubmitted: onFieldSubmitted,
      style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onSurface),
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        prefixIcon: Icon(icon),
        suffixIcon: suffix,
        filled: true,
        fillColor: enabled
            ? AppColors.surfaceContainerLowest
            : AppColors.surfaceContainerLow,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.primary, width: 2),
        ),
      ),
    );
  }
}

class _MissingProfileState extends StatelessWidget {
  const _MissingProfileState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'Không tìm thấy hồ sơ người dùng.',
          textAlign: TextAlign.center,
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
