import 'package:flutter/material.dart';

import '../../app/app_routes.dart';
import '../../data/models/app_notification.dart';
import '../../data/models/app_user_profile.dart';
import '../../data/repositories/firestore_repository.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'app_avatar.dart';

class AppTopBar extends StatelessWidget {
  AppTopBar({super.key, required this.profile});

  final AppUserProfile? profile;
  final _repository = FirestoreRepository();

  @override
  Widget build(BuildContext context) {
    final name = profile?.fullName.trim().isNotEmpty == true
        ? profile!.fullName.trim()
        : 'Bạn';

    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          AppAvatar(
            name: name,
            avatarUrl: profile?.avatarUrl,
            radius: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Xin chào,', style: AppTextStyles.labelMedium),
                Text(
                  name,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.titleMedium,
                ),
              ],
            ),
          ),
          StreamBuilder<List<AppNotification>>(
            stream: _repository.watchNotifications(),
            builder: (context, snapshot) {
              final unreadCount = (snapshot.data ?? const <AppNotification>[])
                  .where((item) => !item.isRead)
                  .length;

              return IconButton(
                tooltip: 'Thông báo',
                onPressed: () {
                  Navigator.of(context).pushNamed(AppRoutes.notifications);
                },
                icon: _NotificationBell(hasUnread: unreadCount > 0),
                color: AppColors.onSurfaceVariant,
              );
            },
          ),
        ],
      ),
    );
  }
}

class _NotificationBell extends StatelessWidget {
  const _NotificationBell({required this.hasUnread});

  final bool hasUnread;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        const Icon(Icons.notifications_none_rounded),
        if (hasUnread)
          Positioned(
            right: -1,
            top: -1,
            child: Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(
                color: AppColors.error,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.surface, width: 1.5),
              ),
            ),
          ),
      ],
    );
  }
}
