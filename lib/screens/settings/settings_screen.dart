import 'package:flutter/material.dart';

import '../../app/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

enum _DisplayMode { light, dark, system }

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  var _displayMode = _DisplayMode.light;
  var _allowNotifications = true;
  var _dailyReminder = true;

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
          color: AppColors.onSurfaceVariant,
        ),
        title: Text(
          'Cài đặt',
          style: AppTextStyles.headlineLargeMobile.copyWith(
            color: AppColors.primary,
          ),
        ),
        actions: const [SizedBox(width: 48)],
      ),
      bottomNavigationBar: const _SettingsBottomNavBar(),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 672),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                const _ProfileBanner(),
                const SizedBox(height: 24),
                _AppearanceSection(
                  selectedMode: _displayMode,
                  onChanged: (mode) {
                    setState(() {
                      _displayMode = mode;
                    });
                  },
                ),
                const SizedBox(height: 24),
                _NotificationsSection(
                  allowNotifications: _allowNotifications,
                  dailyReminder: _dailyReminder,
                  onAllowChanged: (value) {
                    setState(() {
                      _allowNotifications = value;
                    });
                  },
                  onReminderChanged: (value) {
                    setState(() {
                      _dailyReminder = value;
                    });
                  },
                ),
                const SizedBox(height: 24),
                const _RegionalSection(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileBanner extends StatelessWidget {
  const _ProfileBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            clipBehavior: Clip.antiAlias,
            decoration: const BoxDecoration(
              color: AppColors.surfaceVariant,
              shape: BoxShape.circle,
            ),
            child: Image.network(
              'https://lh3.googleusercontent.com/aida-public/AB6AXuAtmcKaNDghQj4GCK7CtWfgKUoJcyr2LWHKmBUVIt7PTDmZkY7wcfilp_oLPMq4v5X8Uc0Vz_5M52Cgm80oJ4Hc158FUzmzfQafgNZ1BCtF2YFuVLWXJ4gqkb5p750tw7EkW4C4x3YLKKN6a_v0uu23s_6baMzznIJvJzoYEVbUuumGYZRnv5C5uBRwuuEl0HghQg6hdEX9RAY7yva950tQ5lp4mH_1nRciHufRt46d2r-IML9wog',
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return const Icon(
                  Icons.person_rounded,
                  color: AppColors.onSurfaceVariant,
                  size: 36,
                );
              },
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Nguyễn Văn A',
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.titleMedium.copyWith(
                    color: AppColors.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Thành viên cơ bản',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AppearanceSection extends StatelessWidget {
  const _AppearanceSection({
    required this.selectedMode,
    required this.onChanged,
  });

  final _DisplayMode selectedMode;
  final ValueChanged<_DisplayMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return _SettingsSectionShell(
      title: 'Giao diện',
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(
                  Icons.palette_outlined,
                  color: AppColors.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Text(
                  'Chế độ hiển thị',
                  style: AppTextStyles.bodyLarge.copyWith(
                    color: AppColors.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _DisplayModeButton(
                    label: 'Sáng',
                    icon: Icons.light_mode_outlined,
                    selected: selectedMode == _DisplayMode.light,
                    onTap: () => onChanged(_DisplayMode.light),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _DisplayModeButton(
                    label: 'Tối',
                    icon: Icons.dark_mode_outlined,
                    selected: selectedMode == _DisplayMode.dark,
                    onTap: () => onChanged(_DisplayMode.dark),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _DisplayModeButton(
                    label: 'Hệ thống',
                    icon: Icons.settings_suggest_outlined,
                    selected: selectedMode == _DisplayMode.system,
                    onTap: () => onChanged(_DisplayMode.system),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DisplayModeButton extends StatelessWidget {
  const _DisplayModeButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? AppColors.primaryContainer : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.outlineVariant,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: selected
                  ? AppColors.onPrimaryContainer
                  : AppColors.onSurfaceVariant,
            ),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                style: AppTextStyles.labelMedium.copyWith(
                  color: selected
                      ? AppColors.onPrimaryContainer
                      : AppColors.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationsSection extends StatelessWidget {
  const _NotificationsSection({
    required this.allowNotifications,
    required this.dailyReminder,
    required this.onAllowChanged,
    required this.onReminderChanged,
  });

  final bool allowNotifications;
  final bool dailyReminder;
  final ValueChanged<bool> onAllowChanged;
  final ValueChanged<bool> onReminderChanged;

  @override
  Widget build(BuildContext context) {
    return _SettingsSectionShell(
      title: 'Thông báo & Nhắc nhở',
      child: Column(
        children: [
          _SwitchTile(
            icon: Icons.notifications_active_outlined,
            title: 'Cho phép thông báo',
            subtitle: 'Nhận thông báo về chi tiêu',
            value: allowNotifications,
            onChanged: onAllowChanged,
          ),
          const Divider(height: 1, color: AppColors.surfaceVariant),
          _SwitchTile(
            icon: Icons.edit_calendar_outlined,
            title: 'Nhắc ghi giao dịch hằng ngày',
            subtitle: 'Lúc 20:00 mỗi tối',
            value: dailyReminder,
            onChanged: onReminderChanged,
          ),
        ],
      ),
    );
  }
}

class _SwitchTile extends StatelessWidget {
  const _SwitchTile({
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
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Icon(icon, color: AppColors.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.bodyLarge.copyWith(
                    color: AppColors.onSurface,
                  ),
                ),
                Text(
                  subtitle,
                  style: AppTextStyles.labelMedium.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            activeThumbColor: AppColors.onPrimary,
            activeTrackColor: AppColors.primary,
            inactiveTrackColor: AppColors.surfaceVariant,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _RegionalSection extends StatelessWidget {
  const _RegionalSection();

  @override
  Widget build(BuildContext context) {
    return const _SettingsSectionShell(
      title: 'Khu vực & Ngôn ngữ',
      child: Column(
        children: [
          _ActionTile(
            icon: Icons.language_rounded,
            title: 'Ngôn ngữ',
            trailingText: 'Tiếng Việt',
          ),
          Divider(height: 1, color: AppColors.surfaceVariant),
          _ActionTile(
            icon: Icons.payments_outlined,
            title: 'Đơn vị tiền tệ',
            trailingText: 'VNĐ (₫)',
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.trailingText,
  });

  final IconData icon;
  final String title;
  final String trailingText;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$title sẽ được thêm sau.')));
      },
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, color: AppColors.onSurfaceVariant),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: AppTextStyles.bodyLarge.copyWith(
                  color: AppColors.onSurface,
                ),
              ),
            ),
            Text(
              trailingText,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 4),
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

class _SettingsSectionShell extends StatelessWidget {
  const _SettingsSectionShell({required this.title, required this.child});

  final String title;
  final Widget child;

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
              color: AppColors.surfaceContainerLowest,
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
          child,
        ],
      ),
    );
  }
}

class _SettingsBottomNavBar extends StatelessWidget {
  const _SettingsBottomNavBar();

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
            _NavItem(
              label: 'Profile',
              icon: Icons.person_rounded,
              selected: true,
              onTap: () {
                Navigator.of(context).pushReplacementNamed(AppRoutes.profile);
              },
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
        onTap: onTap,
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
