import 'package:flutter/material.dart';

import '../../app/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

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
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              Navigator.of(context).pushReplacementNamed(AppRoutes.home);
            }
          },
          icon: const Icon(Icons.arrow_back_rounded),
          color: AppColors.onSurfaceVariant,
        ),
        title: Text(
          'Hồ sơ',
          style: AppTextStyles.headlineLargeMobile.copyWith(
            color: AppColors.primary,
          ),
        ),
        actions: const [SizedBox(width: 48)],
      ),
      bottomNavigationBar: const _ProfileBottomNavBar(),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: const [
                _ProfileCard(),
                SizedBox(height: 24),
                _SettingsSection(
                  title: 'Cài đặt tài khoản',
                  items: [
                    _SettingsItemData(
                      icon: Icons.person_outline_rounded,
                      title: 'Thông tin cá nhân',
                    ),
                    _SettingsItemData(
                      icon: Icons.settings_outlined,
                      title: 'Cài đặt',
                      routeName: AppRoutes.settings,
                    ),
                  ],
                ),
                SizedBox(height: 16),
                _SettingsSection(
                  title: 'Khác',
                  items: [
                    _SettingsItemData(
                      icon: Icons.notifications_none_rounded,
                      title: 'Thông báo',
                      routeName: AppRoutes.notifications,
                    ),
                    _SettingsItemData(
                      icon: Icons.security_rounded,
                      title: 'Bảo mật',
                    ),
                    _SettingsItemData(
                      icon: Icons.logout_rounded,
                      title: 'Đăng xuất',
                      destructive: true,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 96,
                height: 96,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLow,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.surfaceContainerLow,
                    width: 4,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0F172A).withValues(alpha: 0.08),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Image.network(
                  'https://lh3.googleusercontent.com/aida-public/AB6AXuA2fHJpRdBCLlyefGIzzLazCq7mMvdgHIglk7huInHnQSXxBQfgoneT4OuUUwYznCfi4oGeIPjHy9zCBw_hZgPjksH25ZPfAS6AfxgHLbmdeNg-ZfEEXj7gjs6RLyi0kyNLgTwVkDNYY5uPYeO40cUMGtA-bvLpJKm_2FiodI6I4Ylzaroq7Zi94wuLc_4q-eJwh0-TFxUg-GiHJFuz-m6THkSZ9hJPp5FRPEKF8GC8pSuznGI-VA',
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return const Icon(
                      Icons.person_rounded,
                      color: AppColors.onSurfaceVariant,
                      size: 48,
                    );
                  },
                ),
              ),
              Positioned(
                right: -2,
                bottom: -2,
                child: IconButton.filled(
                  tooltip: 'Đổi ảnh đại diện',
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Chức năng đổi ảnh sẽ được thêm sau.'),
                      ),
                    );
                  },
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.primaryContainer,
                    foregroundColor: AppColors.onPrimary,
                    minimumSize: const Size(32, 32),
                    fixedSize: const Size(32, 32),
                  ),
                  icon: const Icon(Icons.edit_rounded, size: 16),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Nguyễn Minh Khang',
            textAlign: TextAlign.center,
            style: AppTextStyles.titleMedium.copyWith(
              color: AppColors.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'khang.nguyen@example.com',
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Màn chỉnh sửa hồ sơ sẽ được thêm sau.'),
                ),
              );
            },
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primaryContainer,
              foregroundColor: AppColors.onPrimary,
              minimumSize: const Size(0, 40),
              padding: const EdgeInsets.symmetric(horizontal: 32),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              textStyle: AppTextStyles.labelMedium.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            child: const Text('Chỉnh sửa hồ sơ'),
          ),
        ],
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({required this.title, required this.items});

  final String title;
  final List<_SettingsItemData> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: const BoxDecoration(
              color: AppColors.surfaceContainerLow,
              border: Border(
                bottom: BorderSide(color: AppColors.surfaceVariant),
              ),
            ),
            child: Text(
              title.toUpperCase(),
              style: AppTextStyles.labelMedium.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          for (var index = 0; index < items.length; index++) ...[
            _SettingsTile(item: items[index]),
            if (index != items.length - 1)
              const Divider(height: 1, color: AppColors.surfaceVariant),
          ],
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({required this.item});

  final _SettingsItemData item;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        if (item.destructive) {
          Navigator.of(
            context,
          ).pushNamedAndRemoveUntil(AppRoutes.login, (route) => false);
          return;
        }

        if (item.routeName != null) {
          Navigator.of(context).pushNamed(item.routeName!);
          return;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${item.title} sẽ được thêm sau.')),
        );
      },
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: item.destructive
                    ? AppColors.error.withValues(alpha: 0.12)
                    : AppColors.secondaryContainer.withValues(alpha: 0.20),
                shape: BoxShape.circle,
              ),
              child: Icon(
                item.icon,
                color: item.destructive ? AppColors.error : AppColors.primary,
                size: 22,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                item.title,
                style: AppTextStyles.bodyLarge.copyWith(
                  color: item.destructive
                      ? AppColors.error
                      : AppColors.onSurface,
                  fontWeight: item.destructive
                      ? FontWeight.w500
                      : FontWeight.w400,
                ),
              ),
            ),
            if (!item.destructive)
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.onSurfaceVariant,
              ),
          ],
        ),
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
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F172A).withValues(alpha: 0.05),
              blurRadius: 12,
              offset: const Offset(0, -4),
            ),
          ],
        ),
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
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? AppColors.secondaryContainer : Colors.transparent,
            borderRadius: selected
                ? BorderRadius.circular(999)
                : BorderRadius.circular(12),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  color: selected
                      ? AppColors.onSecondaryContainer
                      : AppColors.onSurfaceVariant,
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: AppTextStyles.labelMedium.copyWith(
                    color: selected
                        ? AppColors.onSecondaryContainer
                        : AppColors.onSurfaceVariant,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SettingsItemData {
  const _SettingsItemData({
    required this.icon,
    required this.title,
    this.routeName,
    this.destructive = false,
  });

  final IconData icon;
  final String title;
  final String? routeName;
  final bool destructive;
}
