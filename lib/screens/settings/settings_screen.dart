import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../data/models/user_settings.dart';
import '../../data/repositories/firebase_auth_error_mapper.dart';
import '../../data/repositories/firestore_repository.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

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
        centerTitle: true,
        leading: IconButton(
          tooltip: 'Quay lại',
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: Text(
          'Cài đặt',
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
            child: StreamBuilder<UserSettings>(
              stream: repository.watchSettings(),
              builder: (context, snapshot) {
                final settings = snapshot.data ?? const UserSettings();

                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                  children: [
                    _SectionCard(
                      title: 'Thông báo',
                      children: [
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          value: settings.notificationEnabled,
                          title: const Text('Cho phép thông báo'),
                          subtitle: const Text(
                            'Nhận cập nhật ngân sách và giao dịch',
                          ),
                          onChanged: (value) {
                            save(
                              settings.copyWith(notificationEnabled: value),
                              checkDailyReminder: value,
                            );
                          },
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          value: settings.dailyReminderEnabled,
                          title: const Text('Nhắc nhở hằng ngày'),
                          subtitle: const Text(
                            'Gợi ý ghi lại khoản chi trong ngày',
                          ),
                          onChanged: settings.notificationEnabled
                              ? (value) {
                                  save(
                                    settings.copyWith(
                                      dailyReminderEnabled: value,
                                    ),
                                    checkDailyReminder: value,
                                  );
                                }
                              : null,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _SectionCard(
                      title: 'Tiền tệ',
                      children: [
                        DropdownButtonFormField<String>(
                          initialValue: settings.currency,
                          decoration: const InputDecoration(
                            labelText: 'Tiền tệ mặc định',
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'VND', child: Text('VND')),
                            DropdownMenuItem(value: 'USD', child: Text('USD')),
                            DropdownMenuItem(value: 'EUR', child: Text('EUR')),
                            DropdownMenuItem(value: 'JPY', child: Text('JPY')),
                          ],
                          onChanged: (value) {
                            if (value == null) return;
                            saveCurrency(settings, value);
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

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.outlineVariant.withValues(alpha: 0.20),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTextStyles.titleMedium),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}
