import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/app_formatters.dart';
import '../../data/models/app_notification.dart';
import '../../data/repositories/firebase_auth_error_mapper.dart';
import '../../data/repositories/firestore_repository.dart';

enum _NotificationFilter { all, unread }

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _repository = FirestoreRepository();
  var _filter = _NotificationFilter.all;
  var _isBusy = false;

  Future<void> _confirmDeleteAll() async {
    if (_isBusy) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.surfaceContainerLowest,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text('Xóa tất cả thông báo?'),
          content: Text(
            'Toàn bộ thông báo hiện tại sẽ bị xóa khỏi thiết bị.',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.expense,
                foregroundColor: Colors.white,
              ),
              child: const Text('Xóa hết'),
            ),
          ],
        );
      },
    );
    if (confirmed != true) return;

    setState(() => _isBusy = true);
    try {
      await _repository.deleteAllNotifications();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Đã xóa tất cả thông báo.')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(firebaseAuthErrorMessage(error))));
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _markAllRead() async {
    if (_isBusy) return;
    setState(() => _isBusy = true);
    try {
      await _repository.markAllNotificationsAsRead();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã đánh dấu tất cả là đã đọc.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(firebaseAuthErrorMessage(error))));
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _deleteOne(AppNotification notification) async {
    try {
      await _repository.deleteNotification(notification.id);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(firebaseAuthErrorMessage(error))));
    }
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
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_rounded),
          color: AppColors.onSurfaceVariant,
        ),
        title: Text(
          'Thông báo',
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
            child: StreamBuilder<List<AppNotification>>(
              stream: _repository.watchNotifications(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Text(firebaseAuthErrorMessage(snapshot.error!)),
                  );
                }

                final notifications = snapshot.data ?? [];
                final filtered = _filter == _NotificationFilter.all
                    ? notifications
                    : notifications.where((item) => !item.isRead).toList();
                final unread = notifications
                    .where((item) => !item.isRead)
                    .length;
                final groups = _groupNotifications(filtered);

                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainerLowest,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: AppColors.outlineVariant.withValues(
                              alpha: 0.14,
                            ),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(
                                0xFF0F172A,
                              ).withValues(alpha: 0.04),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryFixed.withValues(
                                      alpha: 0.45,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    Icons.notifications_active_outlined,
                                    color: AppColors.primary,
                                    size: 22,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        unread == 0
                                            ? 'Không có thông báo mới'
                                            : '$unread chưa đọc',
                                        style: AppTextStyles.titleMedium
                                            .copyWith(
                                              fontWeight: FontWeight.w700,
                                            ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        notifications.isEmpty
                                            ? 'Bạn sẽ thấy nhắc nhở và cập nhật tại đây'
                                            : '${notifications.length} thông báo',
                                        style: AppTextStyles.labelMedium,
                                      ),
                                    ],
                                  ),
                                ),
                                if (unread > 0)
                                  TextButton(
                                    onPressed: _isBusy ? null : _markAllRead,
                                    style: TextButton.styleFrom(
                                      foregroundColor: AppColors.primary,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                      ),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                    child: const Text('Đọc hết'),
                                  ),
                                IconButton(
                                  tooltip: 'Xóa tất cả',
                                  onPressed:
                                      notifications.isEmpty || _isBusy
                                      ? null
                                      : _confirmDeleteAll,
                                  icon: _isBusy
                                      ? SizedBox.square(
                                          dimension: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: AppColors.primary,
                                          ),
                                        )
                                      : Icon(
                                          Icons.delete_sweep_outlined,
                                          color: notifications.isEmpty
                                              ? AppColors.outlineVariant
                                              : AppColors.onSurfaceVariant,
                                        ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            _FilterSegment(
                              selected: _filter,
                              onChanged: (value) {
                                setState(() => _filter = value);
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    Expanded(
                      child: groups.isEmpty
                          ? _EmptyNotifications(
                              filteringUnread:
                                  _filter == _NotificationFilter.unread,
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                              itemCount: groups.length,
                              itemBuilder: (context, index) {
                                final group = groups[index];
                                return Padding(
                                  padding: EdgeInsets.only(
                                    bottom: index == groups.length - 1
                                        ? 0
                                        : 14,
                                  ),
                                  child: _NotificationGroupSection(
                                    group: group,
                                    onTap: (notification) {
                                      if (!notification.isRead) {
                                        _repository.markNotificationAsRead(
                                          notification.id,
                                        );
                                      }
                                    },
                                    onDelete: _deleteOne,
                                  ),
                                );
                              },
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
  }
}

class _FilterSegment extends StatelessWidget {
  const _FilterSegment({required this.selected, required this.onChanged});

  final _NotificationFilter selected;
  final ValueChanged<_NotificationFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          for (final filter in _NotificationFilter.values)
            Expanded(
              child: InkWell(
                onTap: () => onChanged(filter),
                borderRadius: BorderRadius.circular(11),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: selected == filter
                        ? AppColors.primaryContainer
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    filter == _NotificationFilter.all ? 'Tất cả' : 'Chưa đọc',
                    style: AppTextStyles.labelMedium.copyWith(
                      color: selected == filter
                          ? AppColors.onPrimaryContainer
                          : AppColors.onSurfaceVariant,
                      fontWeight: selected == filter
                          ? FontWeight.w700
                          : FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _NotificationGroupSection extends StatelessWidget {
  const _NotificationGroupSection({
    required this.group,
    required this.onTap,
    required this.onDelete,
  });

  final _NotificationGroup group;
  final ValueChanged<AppNotification> onTap;
  final ValueChanged<AppNotification> onDelete;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 2, 4, 8),
          child: Text(
            group.title,
            style: AppTextStyles.bodyMedium.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: AppColors.outlineVariant.withValues(alpha: 0.14),
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withValues(alpha: 0.035),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (var i = 0; i < group.items.length; i++)
                _NotificationTile(
                  notification: group.items[i],
                  showDivider: i != group.items.length - 1,
                  onTap: () => onTap(group.items[i]),
                  onDelete: () => onDelete(group.items[i]),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _NotificationVisual {
  const _NotificationVisual({
    required this.icon,
    required this.color,
    required this.background,
  });

  final IconData icon;
  final Color color;
  final Color background;
}

_NotificationVisual _visualFor(AppNotification notification) {
  final title = notification.title.toLowerCase();
  final type = notification.type.toLowerCase();

  if (type == 'budget' || title.contains('ngân sách')) {
    return _NotificationVisual(
      icon: Icons.pie_chart_outline_rounded,
      color: AppColors.primary,
      background: AppColors.primaryFixed.withValues(alpha: 0.45),
    );
  }

  if (type == 'reminder' || title.contains('nhắc')) {
    return _NotificationVisual(
      icon: Icons.alarm_rounded,
      color: const Color(0xFFD97706),
      background: const Color(0xFFFFF7ED),
    );
  }

  if (title.contains('xóa')) {
    return _NotificationVisual(
      icon: Icons.delete_outline_rounded,
      color: AppColors.expense,
      background: AppColors.expense.withValues(alpha: 0.12),
    );
  }

  if (title.contains('cập nhật') || title.contains('chỉnh sửa')) {
    return _NotificationVisual(
      icon: Icons.edit_outlined,
      color: AppColors.primary,
      background: AppColors.primaryFixed.withValues(alpha: 0.4),
    );
  }

  if (title.contains('thu nhập')) {
    return _NotificationVisual(
      icon: Icons.north_east_rounded,
      color: AppColors.primary,
      background: AppColors.primary.withValues(alpha: 0.12),
    );
  }

  if (title.contains('chi tiêu') || type == 'transaction') {
    return _NotificationVisual(
      icon: Icons.south_west_rounded,
      color: AppColors.expense,
      background: AppColors.expense.withValues(alpha: 0.12),
    );
  }

  return _NotificationVisual(
    icon: Icons.notifications_outlined,
    color: AppColors.primary,
    background: AppColors.primaryFixed.withValues(alpha: 0.4),
  );
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.notification,
    required this.showDivider,
    required this.onTap,
    required this.onDelete,
  });

  final AppNotification notification;
  final bool showDivider;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final visual = _visualFor(notification);
    final unread = !notification.isRead;

    return Dismissible(
      key: ValueKey(notification.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: AppColors.expense.withValues(alpha: 0.12),
        child: Icon(Icons.delete_outline_rounded, color: AppColors.expense),
      ),
      onDismissed: (_) => onDelete(),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: unread
                  ? AppColors.primaryFixed.withValues(alpha: 0.18)
                  : Colors.transparent,
              border: showDivider
                  ? Border(
                      bottom: BorderSide(
                        color: AppColors.outlineVariant.withValues(alpha: 0.16),
                      ),
                    )
                  : null,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: visual.background,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(visual.icon, color: visual.color, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              notification.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.bodyMedium.copyWith(
                                fontWeight: unread
                                    ? FontWeight.w700
                                    : FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            formatRelativeTime(notification.createdAt),
                            style: AppTextStyles.labelMedium.copyWith(
                              fontSize: 11,
                              color: AppColors.outline,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        notification.body,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.onSurfaceVariant,
                          height: 1.35,
                        ),
                      ),
                      if (unread) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            'Mới',
                            style: AppTextStyles.labelMedium.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700,
                              fontSize: 11,
                            ),
                          ),
                        ),
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

class _EmptyNotifications extends StatelessWidget {
  const _EmptyNotifications({required this.filteringUnread});

  final bool filteringUnread;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 12, 28, 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: AppColors.primaryFixed.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(28),
              ),
              child: Icon(
                filteringUnread
                    ? Icons.mark_email_read_outlined
                    : Icons.notifications_none_rounded,
                size: 40,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              filteringUnread
                  ? 'Không còn thông báo chưa đọc'
                  : 'Chưa có thông báo',
              style: AppTextStyles.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              filteringUnread
                  ? 'Bạn đã xem hết các cập nhật gần đây.'
                  : 'Khi có giao dịch, ngân sách hoặc nhắc nhở, chúng sẽ hiện tại đây.',
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
  List<AppNotification> notifications,
) {
  final groups = <String, List<AppNotification>>{};
  final orderKeys = <String, DateTime>{};

  for (final notification in notifications) {
    final date = notification.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    final key = formatShortDate(date);
    groups.putIfAbsent(key, () => []).add(notification);
    orderKeys.putIfAbsent(
      key,
      () => DateTime(date.year, date.month, date.day),
    );
  }

  final sortedKeys = orderKeys.keys.toList()
    ..sort((a, b) => orderKeys[b]!.compareTo(orderKeys[a]!));

  return [
    for (final key in sortedKeys) _NotificationGroup(key, groups[key]!),
  ];
}

class _NotificationGroup {
  const _NotificationGroup(this.title, this.items);

  final String title;
  final List<AppNotification> items;
}
