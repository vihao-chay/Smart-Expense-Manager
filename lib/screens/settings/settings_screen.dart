import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../data/models/user_settings.dart';
import '../../data/repositories/firebase_auth_error_mapper.dart';
import '../../data/repositories/firestore_repository.dart';
import '../../data/services/notification_service.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  static const _currencies = [
    _CurrencyOption(
      code: 'VND',
      name: 'Đồng Việt Nam',
      symbol: 'đ',
    ),
    _CurrencyOption(
      code: 'USD',
      name: 'Đô la Mỹ',
      symbol: '\$',
    ),
    _CurrencyOption(
      code: 'EUR',
      name: 'Euro',
      symbol: '€',
    ),
    _CurrencyOption(
      code: 'JPY',
      name: 'Yên Nhật',
      symbol: '¥',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final repository = FirestoreRepository();

    Future<void> save(
      UserSettings settings, {
      bool checkDailyReminder = false,
    }) async {
      try {
        await repository.saveSettings(settings);
        if (checkDailyReminder) {
          await NotificationService.instance.refreshDeviceToken();
          await repository.createDailyReminderIfNeeded(settings);
        }
      } catch (error) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(firebaseAuthErrorMessage(error))),
        );
      }
    }

    Future<void> saveCurrency(UserSettings settings, String currency) async {
      try {
        await repository.saveSettings(settings.copyWith(currency: currency));
        await repository.updateDefaultCurrency(currency);
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Đã đặt tiền tệ mặc định: $currency')),
        );
      } catch (error) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(firebaseAuthErrorMessage(error))),
        );
      }
    }

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
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
            color: AppColors.onSurface,
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: StreamBuilder<UserSettings>(
              stream: repository.watchSettings(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final settings = snapshot.data ?? const UserSettings();
                final notificationsOn = settings.notificationEnabled;

                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                  children: [
                    _IntroBanner(),
                    const SizedBox(height: 18),
                    _SectionLabel('Thông báo'),
                    const SizedBox(height: 8),
                    _SettingsGroup(
                      children: [
                        _ToggleTile(
                          icon: Icons.notifications_active_outlined,
                          iconColor: AppColors.primary,
                          iconBackground: AppColors.primaryFixed.withValues(
                            alpha: 0.45,
                          ),
                          title: 'Cho phép thông báo',
                          subtitle: 'Cập nhật giao dịch, ngân sách và nhắc nhở',
                          value: settings.notificationEnabled,
                          onChanged: (value) {
                            save(
                              settings.copyWith(
                                notificationEnabled: value,
                                dailyReminderEnabled: value
                                    ? settings.dailyReminderEnabled
                                    : false,
                              ),
                              checkDailyReminder: value,
                            );
                          },
                          showDivider: true,
                        ),
                        _ToggleTile(
                          icon: Icons.alarm_rounded,
                          iconColor: const Color(0xFFD97706),
                          iconBackground: const Color(0xFFFFF7ED),
                          title: 'Nhắc nhở hằng ngày',
                          subtitle: notificationsOn
                              ? 'Gợi ý ghi lại khoản chi trong ngày'
                              : 'Bật thông báo để dùng nhắc nhở',
                          value: settings.dailyReminderEnabled &&
                              notificationsOn,
                          enabled: notificationsOn,
                          onChanged: notificationsOn
                              ? (value) {
                                  save(
                                    settings.copyWith(
                                      dailyReminderEnabled: value,
                                    ),
                                    checkDailyReminder: value,
                                  );
                                }
                              : null,
                          showDivider: false,
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _SectionLabel('Tiền tệ'),
                    const SizedBox(height: 8),
                    _SettingsGroup(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
                          child: Text(
                            'Tiền tệ mặc định dùng khi hiển thị và đổi tiền.',
                            style: AppTextStyles.labelMedium.copyWith(
                              color: AppColors.onSurfaceVariant,
                            ),
                          ),
                        ),
                        for (var i = 0; i < _currencies.length; i++)
                          _CurrencyTile(
                            option: _currencies[i],
                            selected: settings.currency == _currencies[i].code,
                            showDivider: i != _currencies.length - 1,
                            onTap: () {
                              if (settings.currency == _currencies[i].code) {
                                return;
                              }
                              saveCurrency(settings, _currencies[i].code);
                            },
                          ),
                      ],
                    ),
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

class _CurrencyOption {
  const _CurrencyOption({
    required this.code,
    required this.name,
    required this.symbol,
  });

  final String code;
  final String name;
  final String symbol;
}

class _IntroBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primaryContainer,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryContainer.withValues(alpha: 0.25),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              Icons.tune_rounded,
              color: AppColors.onPrimaryContainer,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tuỳ chỉnh trải nghiệm',
                  style: AppTextStyles.titleMedium.copyWith(
                    color: AppColors.onPrimaryContainer,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Thông báo và tiền tệ áp dụng cho tài khoản của bạn.',
                  style: AppTextStyles.labelMedium.copyWith(
                    color: AppColors.onPrimaryContainer.withValues(alpha: 0.85),
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

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        text,
        style: AppTextStyles.labelMedium.copyWith(
          fontWeight: FontWeight.w700,
          color: AppColors.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.outlineVariant.withValues(alpha: 0.14),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }
}

class _ToggleTile extends StatelessWidget {
  const _ToggleTile({
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    required this.showDivider,
    this.enabled = true,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final bool showDivider;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.55,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
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
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: iconBackground,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: AppTextStyles.labelMedium.copyWith(
                      color: AppColors.onSurfaceVariant,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            Switch.adaptive(
              value: value,
              onChanged: onChanged,
              activeThumbColor: Colors.white,
              activeTrackColor: AppColors.primaryContainer,
            ),
          ],
        ),
      ),
    );
  }
}

class _CurrencyTile extends StatelessWidget {
  const _CurrencyTile({
    required this.option,
    required this.selected,
    required this.showDivider,
    required this.onTap,
  });

  final _CurrencyOption option;
  final bool selected;
  final bool showDivider;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? AppColors.primaryFixed.withValues(alpha: 0.22)
          : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected
                      ? AppColors.primaryContainer
                      : AppColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  option.symbol,
                  style: AppTextStyles.titleMedium.copyWith(
                    color: selected
                        ? AppColors.onPrimaryContainer
                        : AppColors.onSurfaceVariant,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      option.code,
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontWeight: FontWeight.w700,
                        color: selected
                            ? AppColors.primary
                            : AppColors.onSurface,
                      ),
                    ),
                    Text(
                      option.name,
                      style: AppTextStyles.labelMedium.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (selected)
                Icon(
                  Icons.check_circle_rounded,
                  color: AppColors.primary,
                  size: 22,
                )
              else
                Icon(
                  Icons.circle_outlined,
                  color: AppColors.outlineVariant,
                  size: 22,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
