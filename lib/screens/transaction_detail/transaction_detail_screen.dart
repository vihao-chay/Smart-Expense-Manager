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
          title: const Text('Xóa giao dịch?'),
          content: const Text('Giao dịch sẽ bị xóa khỏi Firestore.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
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
        centerTitle: true,
        leading: IconButton(
          tooltip: 'Quay lại',
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_rounded),
          color: AppColors.onSurfaceVariant,
        ),
        title: Text(
          'Chi tiết giao dịch',
          style: AppTextStyles.titleMedium.copyWith(color: AppColors.primary),
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
    final amountColor = isIncome ? AppColors.secondary : AppColors.error;

    return Column(
      children: [
        Expanded(
          child: SafeArea(
            top: false,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                  children: [
                    Column(
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: meta.backgroundColor,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(meta.icon, color: meta.color, size: 40),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          transaction.title ?? transaction.category,
                          textAlign: TextAlign.center,
                          style: AppTextStyles.headlineLargeMobile,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          formatTransactionAmount(transaction),
                          style: AppTextStyles.displayCurrency.copyWith(
                            color: amountColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),
                    _InfoCard(
                      rows: [
                        _InfoRowData(
                          icon: Icons.swap_horiz_rounded,
                          label: 'Loại giao dịch',
                          value: isIncome ? 'Thu nhập' : 'Chi tiêu',
                        ),
                        _InfoRowData(
                          icon: Icons.category_outlined,
                          label: 'Danh mục',
                          value: transaction.category,
                        ),
                        _InfoRowData(
                          icon: Icons.calendar_today_outlined,
                          label: 'Ngày',
                          value: formatShortDate(transaction.transactionDate),
                        ),
                        _InfoRowData(
                          icon: Icons.schedule_rounded,
                          label: 'Giờ',
                          value: formatTime(transaction.transactionDate),
                        ),
                        _InfoRowData(
                          icon: Icons.account_balance_wallet_outlined,
                          label: 'Phương thức',
                          value: transaction.paymentMethod ?? 'Ví cá nhân',
                        ),
                        _InfoRowData(
                          icon: Icons.notes_rounded,
                          label: 'Ghi chú',
                          value: transaction.note?.trim().isNotEmpty == true
                              ? transaction.note!.trim()
                              : 'Không có ghi chú',
                          alignTop: true,
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Ngày tạo: ${formatDateTime(transaction.createdAt)}',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.labelMedium.copyWith(
                        color: AppColors.outline,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Cập nhật lần cuối: ${formatDateTime(transaction.updatedAt)}',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.labelMedium.copyWith(
                        color: AppColors.outline,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: 48,
                  width: double.infinity,
                  child: FilledButton(
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
                    child: const Text('Chỉnh sửa giao dịch'),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 48,
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: isDeleting ? null : onDelete,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: BorderSide(color: AppColors.error),
                    ),
                    child: isDeleting
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
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

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.rows});

  final List<_InfoRowData> rows;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.outlineVariant.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        children: [
          for (var index = 0; index < rows.length; index++) ...[
            _InfoRow(data: rows[index]),
            if (index != rows.length - 1)
              Divider(
                height: 1,
                indent: 72,
                color: AppColors.outlineVariant.withValues(alpha: 0.25),
              ),
          ],
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.data});

  final _InfoRowData data;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: data.alignTop
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.center,
        children: [
          CircleAvatar(
            backgroundColor: AppColors.surfaceContainer,
            child: Icon(data.icon, color: AppColors.onSurfaceVariant),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.label.toUpperCase(),
                  style: AppTextStyles.labelMedium,
                ),
                const SizedBox(height: 2),
                Text(
                  data.value,
                  style: AppTextStyles.bodyLarge.copyWith(
                    fontWeight: FontWeight.w500,
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

class _InfoRowData {
  const _InfoRowData({
    required this.icon,
    required this.label,
    required this.value,
    this.alignTop = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool alignTop;
}

class _MissingTransaction extends StatelessWidget {
  const _MissingTransaction();

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Không tìm thấy giao dịch.'));
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
