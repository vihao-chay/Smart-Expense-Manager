import 'package:flutter/material.dart';

import '../../app/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/app_formatters.dart';
import '../../core/utils/category_catalog.dart';
import '../../data/models/app_notification.dart';
import '../../data/models/app_transaction.dart';
import '../../data/repositories/firebase_auth_error_mapper.dart';
import '../../data/repositories/firestore_repository.dart';

class TransactionDetailArgs {
  const TransactionDetailArgs({required this.transactionId});

  final String transactionId;
}

class TransactionDetailScreen extends StatefulWidget {
  const TransactionDetailScreen({super.key});

  @override
  State<TransactionDetailScreen> createState() =>
      _TransactionDetailScreenState();
}

class _TransactionDetailScreenState extends State<TransactionDetailScreen> {
  final _repository = FirestoreRepository();
  var _isDeleting = false;

  Future<void> _deleteTransaction(AppTransaction transaction) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.surfaceContainerLowest,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text('Xóa giao dịch?'),
          content: Text(
            '“${transaction.title ?? transaction.category}” sẽ bị xóa vĩnh viễn.',
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
              child: const Text('Xóa'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    setState(() => _isDeleting = true);
    try {
      await _repository.deleteTransaction(transaction.id);
      await _repository.addNotification(
        AppNotification(
          id: '',
          title: 'Đã xóa giao dịch',
          body: transaction.title ?? transaction.category,
          type: 'transaction',
          isRead: false,
        ),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Đã xóa giao dịch.')));
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(firebaseAuthErrorMessage(error))));
    } finally {
      if (mounted) setState(() => _isDeleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final routeArgs = ModalRoute.of(context)?.settings.arguments;
    final transactionId = routeArgs is TransactionDetailArgs
        ? routeArgs.transactionId
        : null;

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
          'Chi tiết giao dịch',
          style: AppTextStyles.headlineLargeMobile.copyWith(
            color: AppColors.onSurface,
          ),
        ),
      ),
      body: transactionId == null
          ? const _MissingTransaction()
          : StreamBuilder<AppTransaction?>(
              stream: _repository.watchTransaction(transactionId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return _ErrorState(
                    message: firebaseAuthErrorMessage(snapshot.error!),
                  );
                }
                final transaction = snapshot.data;
                if (transaction == null) return const _MissingTransaction();
                return _DetailBody(
                  transaction: transaction,
                  isDeleting: _isDeleting,
                  onDelete: () => _deleteTransaction(transaction),
                );
              },
            ),
    );
  }
}

class _DetailBody extends StatelessWidget {
  const _DetailBody({
    required this.transaction,
    required this.isDeleting,
    required this.onDelete,
  });

  final AppTransaction transaction;
  final bool isDeleting;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final meta = categoryMeta(transaction.category, type: transaction.type);
    final isIncome = transaction.type == AppTransactionType.income;
    final amountColor = isIncome ? AppColors.primary : AppColors.expense;
    final note = transaction.note?.trim();
    final hasNote = note != null && note.isNotEmpty;
    final date = transaction.transactionDate;

    return Column(
      children: [
        Expanded(
          child: SafeArea(
            top: false,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  children: [
                    _HeroCard(
                      meta: meta,
                      title: transaction.title ?? transaction.category,
                      amountText: formatTransactionAmount(transaction),
                      amountColor: amountColor,
                      isIncome: isIncome,
                    ),
                    const SizedBox(height: 16),
                    _InfoCard(
                      children: [
                        _InfoTile(
                          icon: Icons.category_outlined,
                          label: 'Danh mục',
                          value: transaction.category,
                        ),
                        _InfoTile(
                          icon: Icons.event_outlined,
                          label: 'Thời gian',
                          value:
                              '${formatShortDate(date)}, ${date.day}/${date.month}/${date.year} • ${formatTime(date)}',
                        ),
                        _InfoTile(
                          icon: Icons.account_balance_wallet_outlined,
                          label: 'Phương thức',
                          value: transaction.paymentMethod ??
                              (isIncome ? 'Chuyển khoản' : 'Ví cá nhân'),
                          showDivider: hasNote,
                        ),
                        if (hasNote)
                          _InfoTile(
                            icon: Icons.notes_rounded,
                            label: 'Ghi chú',
                            value: note,
                            alignTop: true,
                            showDivider: false,
                          ),
                      ],
                    ),
                    if (transaction.createdAt != null ||
                        transaction.updatedAt != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        [
                          if (transaction.createdAt != null)
                            'Tạo lúc ${formatDateTime(transaction.createdAt)}',
                          if (transaction.updatedAt != null &&
                              transaction.updatedAt != transaction.createdAt)
                            'Cập nhật ${formatDateTime(transaction.updatedAt)}',
                        ].join('  ·  '),
                        textAlign: TextAlign.center,
                        style: AppTextStyles.labelMedium.copyWith(
                          color: AppColors.outline,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: 52,
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: isDeleting
                        ? null
                        : () {
                            Navigator.of(context).pushNamed(
                              AppRoutes.editTransaction,
                              arguments: TransactionDetailArgs(
                                transactionId: transaction.id,
                              ),
                            );
                          },
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primaryContainer,
                      foregroundColor: AppColors.onPrimaryContainer,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    icon: const Icon(Icons.edit_rounded, size: 18),
                    label: const Text('Chỉnh sửa'),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 48,
                  width: double.infinity,
                  child: TextButton(
                    onPressed: isDeleting ? null : onDelete,
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.expense,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: isDeleting
                        ? SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.expense,
                            ),
                          )
                        : const Text('Xóa giao dịch'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.meta,
    required this.title,
    required this.amountText,
    required this.amountColor,
    required this.isIncome,
  });

  final CategoryMeta meta;
  final String title;
  final String amountText;
  final Color amountColor;
  final bool isIncome;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 22),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: AppColors.outlineVariant.withValues(alpha: 0.14),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.05),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: meta.backgroundColor,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Icon(meta.icon, color: meta.color, size: 34),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: isIncome
                  ? AppColors.primary.withValues(alpha: 0.1)
                  : AppColors.expense.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isIncome
                      ? Icons.north_east_rounded
                      : Icons.south_west_rounded,
                  size: 14,
                  color: amountColor,
                ),
                const SizedBox(width: 4),
                Text(
                  isIncome ? 'Thu nhập' : 'Chi tiêu',
                  style: AppTextStyles.labelMedium.copyWith(
                    color: amountColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: AppTextStyles.headlineLargeMobile.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            amountText,
            textAlign: TextAlign.center,
            style: AppTextStyles.displayCurrency.copyWith(
              color: amountColor,
              fontSize: 34,
              height: 1.15,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
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
      child: Column(children: children),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
    this.alignTop = false,
    this.showDivider = true,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool alignTop;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Container(
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
        crossAxisAlignment: alignTop
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.center,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 20, color: AppColors.onSurfaceVariant),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTextStyles.labelMedium.copyWith(
                    color: AppColors.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
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

class _MissingTransaction extends StatelessWidget {
  const _MissingTransaction();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 48,
              color: AppColors.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text('Không tìm thấy giao dịch.', style: AppTextStyles.titleMedium),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(child: Text(message, textAlign: TextAlign.center));
  }
}
