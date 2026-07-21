import 'package:flutter/material.dart';

import '../../app/app_routes.dart';
import '../../data/models/app_user_profile.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

class AppTopBar extends StatelessWidget {
  const AppTopBar({super.key, required this.profile});

  final AppUserProfile? profile;

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
          CircleAvatar(
            radius: 20,
            backgroundColor: AppColors.surfaceContainerHigh,
            backgroundImage: profile?.avatarUrl == null
                ? null
                : NetworkImage(profile!.avatarUrl!),
            child: profile?.avatarUrl == null
                ? const Icon(Icons.person_rounded)
                : null,
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
          IconButton(
            tooltip: 'Thông báo',
            onPressed: () {
              Navigator.of(context).pushNamed(AppRoutes.notifications);
            },
            icon: const Icon(Icons.notifications_none_rounded),
            color: AppColors.onSurfaceVariant,
          ),
        ],
      ),
    );
  }
}
