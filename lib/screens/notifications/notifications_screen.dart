import 'package:flutter/material.dart';

import '../../app/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

enum _NotificationFilter { all, unread }

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  var _filter = _NotificationFilter.all;
  late final List<_NotificationItem> _notifications = _buildMockNotifications();

  int get _unreadCount =>
      _notifications.where((notification) => notification.unread).length;

  List<_NotificationItem> get _filteredNotifications {
    return switch (_filter) {
      _NotificationFilter.all => _notifications,
      _NotificationFilter.unread =>
        _notifications.where((notification) => notification.unread).toList(),
    };
  }

  void _goBack() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
      return;
    }

    Navigator.of(context).pushReplacementNamed(AppRoutes.home);
  }

  void _markAllAsRead() {
    setState(() {
      for (final notification in _notifications) {
        notification.unread = false;
      }
    });
  }

  void _openNotification(_NotificationItem notification) {
    setState(() {
      notification.unread = false;
    });

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(notification.actionMessage)));
  }

  @override
  Widget build(BuildContext context) {
    final filteredNotifications = _filteredNotifications;
    final groups = _groupNotifications(filteredNotifications);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          tooltip: 'Quay lại',
          onPressed: _goBack,
          icon: const Icon(Icons.arrow_back_rounded),
          color: AppColors.onSurfaceVariant,
        ),
        title: Text(
          'Thông báo',
          style: AppTextStyles.headlineLargeMobile.copyWith(
            color: AppColors.primary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: _unreadCount == 0 ? null : _markAllAsRead,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primary,
              disabledForegroundColor: AppColors.outline,
              textStyle: AppTextStyles.labelMedium.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            child: const Text('Đã đọc'),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 672),
            child: Column(
              children: [
                _NotificationHeader(unreadCount: _unreadCount),
                _FilterBar(
                  selectedFilter: _filter,
                  unreadCount: _unreadCount,
                  onChanged: (filter) {
                    setState(() {
                      _filter = filter;
                    });
                  },
                ),
                Expanded(
                  child: groups.isEmpty
                      ? const _EmptyNotifications()
                      : ListView(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                          children: [
                            for (final group in groups) ...[
                              _NotificationGroupSection(
                                group: group,
                                onNotificationTap: _openNotification,
                              ),
                              const SizedBox(height: 20),
                            ],
                          ],
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

class _NotificationHeader extends StatelessWidget {
  const _NotificationHeader({required this.unreadCount});

  final int unreadCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primaryContainer,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.onPrimary.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.notifications_active_outlined,
              color: AppColors.onPrimaryContainer,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  unreadCount == 0
                      ? 'Bạn đã đọc hết thông báo'
                      : '$unreadCount thông báo chưa đọc',
                  style: AppTextStyles.titleMedium.copyWith(
                    color: AppColors.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Cập nhật ngân sách, giao dịch và nhắc nhở chi tiêu.',
                  style: AppTextStyles.labelMedium.copyWith(
                    color: AppColors.onPrimaryContainer.withValues(alpha: 0.82),
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

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.selectedFilter,
    required this.unreadCount,
    required this.onChanged,
  });

  final _NotificationFilter selectedFilter;
  final int unreadCount;
  final ValueChanged<_NotificationFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      color: AppColors.surface,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            _FilterButton(
              label: 'Tất cả',
              selected: selectedFilter == _NotificationFilter.all,
              onTap: () => onChanged(_NotificationFilter.all),
            ),
            _FilterButton(
              label: unreadCount == 0 ? 'Chưa đọc' : 'Chưa đọc ($unreadCount)',
              selected: selectedFilter == _NotificationFilter.unread,
              onTap: () => onChanged(_NotificationFilter.unread),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterButton extends StatelessWidget {
  const _FilterButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? AppColors.surfaceContainerLowest : null,
            borderRadius: BorderRadius.circular(8),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: const Color(0xFF0F172A).withValues(alpha: 0.06),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.labelMedium.copyWith(
              color: selected ? AppColors.primary : AppColors.onSurfaceVariant,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

class _NotificationGroupSection extends StatelessWidget {
  const _NotificationGroupSection({
    required this.group,
    required this.onNotificationTap,
  });

  final _NotificationGroup group;
  final ValueChanged<_NotificationItem> onNotificationTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            group.title,
            style: AppTextStyles.titleMedium.copyWith(
              color: AppColors.onSurface,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.outlineVariant.withValues(alpha: 0.20),
            ),
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
              for (var index = 0; index < group.notifications.length; index++)
                _NotificationTile(
                  notification: group.notifications[index],
                  showDivider: index != group.notifications.length - 1,
                  onTap: () => onNotificationTap(group.notifications[index]),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.notification,
    required this.showDivider,
    required this.onTap,
  });

  final _NotificationItem notification;
  final bool showDivider;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: notification.unread
          ? AppColors.secondaryContainer.withValues(alpha: 0.12)
          : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            border: showDivider
                ? Border(
                    bottom: BorderSide(
                      color: AppColors.outlineVariant.withValues(alpha: 0.16),
                    ),
                  )
                : null,
          ),
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: notification.backgroundColor,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      notification.icon,
                      color: notification.iconColor,
                      size: 24,
                    ),
                  ),
                  if (notification.unread)
                    Positioned(
                      top: 0,
                      right: 0,
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: AppColors.error,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.surfaceContainerLowest,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            notification.title,
                            style: AppTextStyles.bodyLarge.copyWith(
                              color: AppColors.onSurface,
                              fontWeight: notification.unread
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          notification.time,
                          style: AppTextStyles.labelMedium.copyWith(
                            color: AppColors.outline,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notification.message,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyNotifications extends StatelessWidget {
  const _EmptyNotifications();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: AppColors.surfaceContainerHigh,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.notifications_none_rounded,
                color: AppColors.onSurfaceVariant,
                size: 30,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Không có thông báo',
              style: AppTextStyles.titleMedium.copyWith(
                color: AppColors.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Các nhắc nhở và cập nhật mới sẽ xuất hiện ở đây.',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

List<_NotificationGroup> _groupNotifications(
  List<_NotificationItem> notifications,
) {
  final groups = <String, List<_NotificationItem>>{};
  for (final notification in notifications) {
    groups.putIfAbsent(notification.group, () => []).add(notification);
  }

  return groups.entries
      .map((entry) => _NotificationGroup(entry.key, entry.value))
      .toList();
}

class _NotificationGroup {
  const _NotificationGroup(this.title, this.notifications);

  final String title;
  final List<_NotificationItem> notifications;
}

class _NotificationItem {
  _NotificationItem({
    required this.group,
    required this.title,
    required this.message,
    required this.time,
    required this.icon,
    required this.iconColor,
    required this.backgroundColor,
    required this.actionMessage,
    this.unread = false,
  });

  final String group;
  final String title;
  final String message;
  final String time;
  final IconData icon;
  final Color iconColor;
  final Color backgroundColor;
  final String actionMessage;
  bool unread;
}

List<_NotificationItem> _buildMockNotifications() {
  return [
    _NotificationItem(
      group: 'Hôm nay',
      title: 'Chi tiêu ăn uống tăng nhanh',
      message: 'Bạn đã dùng 72% ngân sách ăn uống của tháng này.',
      time: '09:20',
      icon: Icons.restaurant_outlined,
      iconColor: AppColors.error,
      backgroundColor: const Color(0x4DFFDAD6),
      actionMessage: 'Đã mở nhắc nhở ngân sách ăn uống.',
      unread: true,
    ),
    _NotificationItem(
      group: 'Hôm nay',
      title: 'Nhắc ghi giao dịch',
      message: 'Bạn có muốn thêm chi tiêu hôm nay trước 20:00 không?',
      time: '08:00',
      icon: Icons.edit_calendar_outlined,
      iconColor: AppColors.primary,
      backgroundColor: const Color(0x336DF5E1),
      actionMessage: 'Đã mở nhắc ghi giao dịch.',
      unread: true,
    ),
    _NotificationItem(
      group: 'Hôm qua',
      title: 'Đã cập nhật tỷ giá',
      message: 'USD/VND và EUR/VND vừa được làm mới từ Exchange Rate API.',
      time: '18:45',
      icon: Icons.currency_exchange_rounded,
      iconColor: AppColors.tertiary,
      backgroundColor: const Color(0x332F746F),
      actionMessage: 'Đã xem cập nhật tỷ giá.',
    ),
    _NotificationItem(
      group: 'Hôm qua',
      title: 'Thu nhập mới được ghi nhận',
      message: 'Lương tháng 10 đã được thêm vào tổng thu.',
      time: '10:00',
      icon: Icons.payments_outlined,
      iconColor: AppColors.secondary,
      backgroundColor: const Color(0x336DF5E1),
      actionMessage: 'Đã xem thông báo thu nhập.',
    ),
    _NotificationItem(
      group: 'Tuần này',
      title: 'Báo cáo tuần đã sẵn sàng',
      message: 'Chi tiêu tuần này thấp hơn 12% so với tuần trước.',
      time: 'T2',
      icon: Icons.leaderboard_outlined,
      iconColor: AppColors.primary,
      backgroundColor: AppColors.surfaceContainerHighest,
      actionMessage: 'Đã mở báo cáo tuần.',
    ),
  ];
}
