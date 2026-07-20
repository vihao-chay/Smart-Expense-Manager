import 'package:flutter/material.dart';

import '../../app/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../data/models/app_user_profile.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/firebase_auth_error_mapper.dart';
import '../../data/repositories/firestore_repository.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final repository = FirestoreRepository();

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'Hồ sơ',
          style: AppTextStyles.headlineLargeMobile.copyWith(
            color: AppColors.primary,
          ),
        ),
      ),
      bottomNavigationBar: const _ProfileBottomNavBar(),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: StreamBuilder<AppUserProfile?>(
              stream: repository.watchProfile(),
              builder: (context, snapshot) {
                final profile = snapshot.data;
                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                  children: [
                    _ProfileHeader(profile: profile),
                    const SizedBox(height: 16),
                    _MenuTile(
                      icon: Icons.settings_outlined,
                      title: 'Cài đặt',
                      subtitle: 'Thông báo, ngôn ngữ và tiền tệ',
                      onTap: () {
                        Navigator.of(context).pushNamed(AppRoutes.settings);
                      },
                    ),
                    _MenuTile(
                      icon: Icons.receipt_long_outlined,
                      title: 'Lịch sử giao dịch',
                      subtitle: 'Xem, tìm kiếm và lọc giao dịch',
                      onTap: () {
                        Navigator.of(context).pushNamed(AppRoutes.transactions);
                      },
                    ),
                    _MenuTile(
                      icon: Icons.leaderboard_outlined,
                      title: 'Thống kê',
                      subtitle: 'Biểu đồ thu chi và danh mục',
                      onTap: () {
                        Navigator.of(context).pushNamed(AppRoutes.statistics);
                      },
                    ),
                    const SizedBox(height: 12),
                    const _LogoutButton(),
                  ],
                );
              },
            ),
          ),
        ),
      ),
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
            radius: 42,
            backgroundColor: AppColors.secondaryContainer,
            backgroundImage: profile?.avatarUrl == null
                ? null
                : NetworkImage(profile!.avatarUrl!),
            child: profile?.avatarUrl == null
                ? const Icon(Icons.person_rounded, size: 42)
                : null,
          ),
          const SizedBox(height: 14),
          Text(
            name,
            textAlign: TextAlign.center,
            style: AppTextStyles.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            email,
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
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
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Ink(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppColors.outlineVariant.withValues(alpha: 0.20),
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppColors.surfaceContainer,
                  child: Icon(icon, color: AppColors.primary),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: AppTextStyles.titleMedium),
                      Text(subtitle, style: AppTextStyles.labelMedium),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded),
              ],
            ),
          ),
        ),
      ),
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
      height: 48,
      child: OutlinedButton.icon(
        onPressed: _isLoading ? null : _logout,
        icon: _isLoading
            ? const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.logout_rounded),
        label: const Text('Đăng xuất'),
        style: OutlinedButton.styleFrom(foregroundColor: AppColors.error),
      ),
    );
  }
}

class _ProfileBottomNavBar extends StatelessWidget {
  const _ProfileBottomNavBar();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        color: AppColors.surface,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _NavItem(
              label: 'Home',
              icon: Icons.home_outlined,
              onTap: () {
                Navigator.of(context).pushReplacementNamed(AppRoutes.home);
              },
            ),
            _NavItem(
              label: 'Transactions',
              icon: Icons.receipt_long_outlined,
              onTap: () {
                Navigator.of(
                  context,
                ).pushReplacementNamed(AppRoutes.transactions);
              },
            ),
            _NavItem(
              label: 'Statistics',
              icon: Icons.leaderboard_outlined,
              onTap: () {
                Navigator.of(
                  context,
                ).pushReplacementNamed(AppRoutes.statistics);
              },
            ),
            const _NavItem(
              label: 'Profile',
              icon: Icons.person_rounded,
              selected: true,
            ),
          ],
        ),
      ),
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
