import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_avatar.dart';
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
  final _firestoreRepository = FirestoreRepository();
  final _authRepository = AuthRepository();
  final _storageRepository = StorageRepository();
  final _imagePicker = ImagePicker();

  AppUserProfile? _profile;
  XFile? _selectedAvatar;
  Uint8List? _selectedAvatarBytes;
  var _avatarRemoved = false;
  var _isLoading = true;
  var _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController.addListener(_refreshPreview);
    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.removeListener(_refreshPreview);
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  void _refreshPreview() {
    if (mounted) setState(() {});
  }

  Future<void> _pickAvatar(ImageSource source) async {
    if (_isSaving) return;

    try {
      final image = await _imagePicker.pickImage(
        source: source,
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
        _avatarRemoved = false;
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(firebaseAuthErrorMessage(error))));
    }
  }

  Future<void> _showAvatarOptions() async {
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
                Text('Ảnh đại diện', style: AppTextStyles.titleMedium),
                const SizedBox(height: 8),
                ListTile(
                  leading: Icon(
                    Icons.photo_library_outlined,
                    color: AppColors.primary,
                  ),
                  title: const Text('Chọn từ thư viện'),
                  onTap: () {
                    Navigator.pop(context);
                    _pickAvatar(ImageSource.gallery);
                  },
                ),
                ListTile(
                  leading: Icon(
                    Icons.photo_camera_outlined,
                    color: AppColors.primary,
                  ),
                  title: const Text('Chụp ảnh mới'),
                  onTap: () {
                    Navigator.pop(context);
                    _pickAvatar(ImageSource.camera);
                  },
                ),
                if (_hasAvatar)
                  ListTile(
                    leading: Icon(
                      Icons.delete_outline_rounded,
                      color: AppColors.expense,
                    ),
                    title: Text(
                      'Xóa ảnh hiện tại',
                      style: TextStyle(color: AppColors.expense),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      _removeAvatar();
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _removeAvatar() {
    if (_isSaving) return;
    setState(() {
      _selectedAvatar = null;
      _selectedAvatarBytes = null;
      _avatarRemoved = true;
    });
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await _firestoreRepository.fetchProfile();
      if (!mounted) return;
      _profile = profile;
      _nameController.text = profile?.fullName ?? '';
      _emailController.text = profile?.email ?? '';
      _avatarRemoved = false;
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
    String? normalizedAvatarUrl = profile.avatarUrl;
    String? nextAvatarStoragePath = profile.avatarStoragePath;

    try {
      if (_avatarRemoved && _selectedAvatar == null) {
        normalizedAvatarUrl = null;
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

  String? get _previewAvatarUrl {
    if (_selectedAvatarBytes != null || _avatarRemoved) return null;
    return _profile?.avatarUrl;
  }

  bool get _hasAvatar {
    if (_selectedAvatarBytes != null) return true;
    if (_avatarRemoved) return false;
    final url = _profile?.avatarUrl?.trim();
    return url != null && url.isNotEmpty;
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
          'Chỉnh sửa hồ sơ',
          style: AppTextStyles.headlineLargeMobile.copyWith(
            color: AppColors.onSurface,
          ),
        ),
      ),
      bottomNavigationBar: _isLoading || _profile == null
          ? null
          : SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: SizedBox(
                  height: 52,
                  child: FilledButton(
                    onPressed: _isSaving ? null : _saveProfile,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primaryContainer,
                      foregroundColor: AppColors.onPrimaryContainer,
                      disabledBackgroundColor: AppColors.primaryContainer
                          .withValues(alpha: 0.55),
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
                            'Lưu thay đổi',
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
                        8,
                        16,
                        24 + MediaQuery.viewInsetsOf(context).bottom,
                      ),
                      children: [
                        _AvatarEditor(
                          name: _nameController.text,
                          avatarUrl: _previewAvatarUrl,
                          imageBytes: _selectedAvatarBytes,
                          enabled: !_isSaving,
                          onTap: _showAvatarOptions,
                        ),
                        const SizedBox(height: 20),
                        _FormCard(
                          children: [
                            Text(
                              'Thông tin cá nhân',
                              style: AppTextStyles.titleMedium.copyWith(
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 14),
                            _ProfileTextField(
                              controller: _nameController,
                              label: 'Họ tên',
                              hintText: 'Nhập họ tên của bạn',
                              icon: Icons.person_outline_rounded,
                              textInputAction: TextInputAction.done,
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
                              onFieldSubmitted: (_) => _saveProfile(),
                            ),
                            const SizedBox(height: 14),
                            _ProfileTextField(
                              controller: _emailController,
                              label: 'Email',
                              hintText: 'Email',
                              icon: Icons.mail_outline_rounded,
                              enabled: false,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Email dùng để đăng nhập, không thể đổi tại đây.',
                              style: AppTextStyles.labelMedium,
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
}

class _AvatarEditor extends StatelessWidget {
  const _AvatarEditor({
    required this.name,
    required this.avatarUrl,
    required this.imageBytes,
    required this.enabled,
    required this.onTap,
  });

  final String name;
  final String? avatarUrl;
  final Uint8List? imageBytes;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final trimmedName = name.trim();

    return Column(
      children: [
        Stack(
          alignment: Alignment.bottomRight,
          children: [
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: enabled ? onTap : null,
                customBorder: const CircleBorder(),
                child: Ink(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.18),
                      width: 3,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(3),
                    child: AppAvatar(
                      name: trimmedName.isEmpty ? '?' : trimmedName,
                      avatarUrl: avatarUrl,
                      imageBytes: imageBytes,
                      radius: 52,
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              right: 2,
              bottom: 2,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: enabled ? onTap : null,
                  customBorder: const CircleBorder(),
                  child: Ink(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.primaryContainer,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.surface,
                        width: 3,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.25),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.photo_camera_rounded,
                      size: 18,
                      color: AppColors.onPrimaryContainer,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Text(
          trimmedName.isEmpty ? 'Tên của bạn' : trimmedName,
          textAlign: TextAlign.center,
          style: AppTextStyles.titleMedium,
        ),
        const SizedBox(height: 4),
        TextButton(
          onPressed: enabled ? onTap : null,
          style: TextButton.styleFrom(
            foregroundColor: AppColors.primary,
            padding: const EdgeInsets.symmetric(horizontal: 8),
          ),
          child: const Text('Đổi ảnh đại diện'),
        ),
      ],
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

class _ProfileTextField extends StatelessWidget {
  const _ProfileTextField({
    required this.controller,
    required this.label,
    required this.hintText,
    required this.icon,
    this.enabled = true,
    this.textInputAction,
    this.validator,
    this.onFieldSubmitted,
  });

  final TextEditingController controller;
  final String label;
  final String hintText;
  final IconData icon;
  final bool enabled;
  final TextInputAction? textInputAction;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onFieldSubmitted;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      textInputAction: textInputAction,
      validator: validator,
      onFieldSubmitted: onFieldSubmitted,
      style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onSurface),
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        prefixIcon: Icon(icon),
        filled: true,
        fillColor: enabled
            ? AppColors.surfaceContainerLow
            : AppColors.surfaceContainer.withValues(alpha: 0.55),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.primary, width: 1.5),
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
