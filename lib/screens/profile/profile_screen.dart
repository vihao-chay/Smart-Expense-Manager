import 'package:flutter/material.dart';

import '../../app/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/theme_controller.dart';
import '../../core/widgets/app_avatar.dart';
import '../../core/widgets/app_top_bar.dart';
import '../../data/models/app_user_profile.dart';
import '../../data/models/user_settings.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/firebase_auth_error_mapper.dart';
import '../../data/repositories/firestore_repository.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final repository = FirestoreRepository();

    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeController.instance,
      builder: (context, _, _) {
        return Scaffold(
          backgroundColor: AppColors.surface,
          bottomNavigationBar: const _ProfileBottomNavBar(),
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: StreamBuilder<AppUserProfile?>(
                  stream: repository.watchProfile(),
                  builder: (context, snapshot) {
                    final profile = snapshot.data;
                    return Column(
                      children: [
                        AppTopBar(profile: profile),
                        Expanded(
                          child: ListView(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                            children: [
                              _ProfileHeader(profile: profile),
                              const SizedBox(height: 16),
                              _MenuSection(
                                children: [
                                  _MenuTile(
                                    icon: Icons.edit_outlined,
                                    title: 'Chỉnh sửa hồ sơ',
                                    subtitle: 'Cập nhật tên và ảnh đại diện',
                                    onTap: () {
                                      Navigator.of(
                                        context,
                                      ).pushNamed(AppRoutes.editProfile);
                                    },
                                  ),
                                  _ThemeModeTile(repository: repository),
                                  _MenuTile(
                                    icon: Icons.settings_outlined,
                                    title: 'Cài đặt',
                                    subtitle: 'Thông báo, ngôn ngữ và tiền tệ',
                                    onTap: () {
                                      Navigator.of(
                                        context,
                                      ).pushNamed(AppRoutes.settings);
                                    },
                                  ),
                                  _MenuTile(
                                    icon: Icons.picture_as_pdf_outlined,
                                    title: 'Tài liệu PDF',
                                    subtitle: 'Xem báo cáo PDF đã xuất',
                                    onTap: () {
                                      Navigator.of(
                                        context,
                                      ).pushNamed(AppRoutes.documents);
                                    },
                                  ),
                                  _MenuTile(
                                    icon: Icons.bug_report_outlined,
                                    title: 'Báo cáo lỗi',
                                    subtitle: 'Gửi lỗi app cho admin xử lý',
                                    onTap: () {
                                      Navigator.of(
                                        context,
                                      ).pushNamed(AppRoutes.bugReport);
                                    },
                                    showDivider: false,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              const _LogoutButton(),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.profile});

  final AppUserProfile? profile;

  @override
  Widget build(BuildContext context) {
    final name = profile?.fullName.trim().isNotEmpty == true
        ? profile!.fullName.trim()
        : 'Người dùng';
    final email = profile?.email.trim().isNotEmpty == true
        ? profile!.email.trim()
        : 'Chưa có email';

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primaryContainer,
            AppColors.primary,
            AppColors.tertiary,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.28),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            Positioned(
              right: -24,
              top: -30,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.08),
                ),
              ),
            ),
            Positioned(
              left: -20,
              bottom: -36,
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.06),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.7),
                        width: 2,
                      ),
                    ),
                    child: AppAvatar(
                      name: name,
                      avatarUrl: profile?.avatarUrl,
                      radius: 40,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    name,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.titleMedium.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    email,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: Colors.white.withValues(alpha: 0.82),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuSection extends StatelessWidget {
  const _MenuSection({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
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
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }
}

class _ThemeModeTile extends StatelessWidget {
  const _ThemeModeTile({required this.repository});

  final FirestoreRepository repository;

  Future<void> _saveTheme(
    BuildContext context,
    UserSettings settings,
    bool enabled,
  ) async {
    final previousValue = ThemeController.instance.firestoreValue;
    final nextValue = enabled ? 'dark' : 'light';
    ThemeController.instance.setDarkMode(enabled);

    try {
      await repository.saveSettings(settings.copyWith(themeMode: nextValue));
    } catch (error) {
      ThemeController.instance.applyFirestoreValue(previousValue);
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(firebaseAuthErrorMessage(error))));
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<UserSettings>(
      stream: repository.watchSettings(),
      builder: (context, snapshot) {
        final settings = snapshot.data ?? const UserSettings();

        return ValueListenableBuilder<ThemeMode>(
          valueListenable: ThemeController.instance,
          builder: (context, themeMode, _) {
            final isDark = themeMode == ThemeMode.dark;
            return _SwitchMenuTile(
              icon: isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
              title: 'Chế độ tối',
              subtitle: isDark
                  ? 'Đang dùng giao diện tối'
                  : 'Đang dùng giao diện sáng',
              value: isDark,
              onChanged: (value) => _saveTheme(context, settings, value),
            );
          },
        );
      },
    );
  }
}

class _SwitchMenuTile extends StatelessWidget {
  const _SwitchMenuTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: AppColors.outlineVariant.withValues(alpha: 0.16),
          ),
        ),
      ),
      child: Row(
        children: [
          _MenuIcon(icon: icon),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(subtitle, style: AppTextStyles.labelMedium),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppColors.onPrimaryContainer,
            activeTrackColor: AppColors.primaryContainer,
          ),
        ],
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.showDivider = true,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            border: showDivider
                ? Border(
                    bottom: BorderSide(
                      color: AppColors.outlineVariant.withValues(alpha: 0.16),
                    ),
                  )
                : null,
          ),
          child: Row(
            children: [
              _MenuIcon(icon: icon),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(subtitle, style: AppTextStyles.labelMedium),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: AppColors.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuIcon extends StatelessWidget {
  const _MenuIcon({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(icon, color: AppColors.primary, size: 22),
    );
  }
}

class _LogoutButton extends StatefulWidget {
  const _LogoutButton();

  @override
  State<_LogoutButton> createState() => _LogoutButtonState();
}

class _LogoutButtonState extends State<_LogoutButton> {
  final _authRepository = AuthRepository();
  var _isLoading = false;

  Future<void> _logout() async {
    setState(() => _isLoading = true);
    try {
      await _authRepository.signOut();
      if (!mounted) return;
      Navigator.of(
        context,
      ).pushNamedAndRemoveUntil(AppRoutes.login, (route) => false);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(firebaseAuthErrorMessage(error))));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: OutlinedButton.icon(
        onPressed: _isLoading ? null : _logout,
        icon: _isLoading
            ? SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: AppColors.expense,
                ),
              )
            : const Icon(Icons.logout_rounded),
        label: const Text('Đăng xuất'),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.expense,
          side: BorderSide(color: AppColors.expense.withValues(alpha: 0.45)),
          backgroundColor: AppColors.expense.withValues(alpha: 0.06),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}

class _ProfileBottomNavBar extends StatelessWidget {
  const _ProfileBottomNavBar();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeController.instance,
      builder: (context, _, _) {
        return SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            color: AppColors.surface,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _NavItem(
                  label: 'Trang chủ',
                  icon: Icons.home_outlined,
                  onTap: () {
                    Navigator.of(context).pushReplacementNamed(AppRoutes.home);
                  },
                ),
                _NavItem(
                  label: 'Giao dịch',
                  icon: Icons.receipt_long_outlined,
                  onTap: () {
                    Navigator.of(
                      context,
                    ).pushReplacementNamed(AppRoutes.transactions);
                  },
                ),
                _NavItem(
                  label: 'Thống kê',
                  icon: Icons.leaderboard_outlined,
                  onTap: () {
                    Navigator.of(
                      context,
                    ).pushReplacementNamed(AppRoutes.statistics);
                  },
                ),
                const _NavItem(
                  label: 'Cá nhân',
                  icon: Icons.person_rounded,
                  selected: true,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.label,
    required this.icon,
    this.selected = false,
    this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Flexible(
      child: InkWell(
        onTap: selected ? null : onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: selected
                    ? AppColors.primary
                    : AppColors.onSurfaceVariant,
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: AppTextStyles.labelMedium.copyWith(
                  color: selected
                      ? AppColors.primary
                      : AppColors.onSurfaceVariant,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
