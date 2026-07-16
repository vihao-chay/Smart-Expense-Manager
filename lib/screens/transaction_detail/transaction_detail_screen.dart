import 'package:flutter/material.dart';

import '../../app/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

class TransactionDetailArgs {
  const TransactionDetailArgs({
    required this.title,
    required this.amount,
    required this.transactionType,
    required this.category,
    required this.date,
    required this.time,
    required this.paymentMethod,
    required this.note,
    required this.createdAt,
    required this.updatedAt,
    required this.icon,
    required this.accentColor,
    required this.iconBackgroundColor,
    required this.isIncome,
  });

  final String title;
  final String amount;
  final String transactionType;
  final String category;
  final String date;
  final String time;
  final String paymentMethod;
  final String note;
  final String createdAt;
  final String updatedAt;
  final IconData icon;
  final Color accentColor;
  final Color iconBackgroundColor;
  final bool isIncome;
}

class TransactionDetailScreen extends StatelessWidget {
  const TransactionDetailScreen({super.key});

  static const _fallbackArgs = TransactionDetailArgs(
    title: 'Ăn trưa tại The Workshop',
    amount: '-85.000 ₫',
    transactionType: 'Chi tiêu',
    category: 'Ăn uống',
    date: 'Hôm nay, 24 Th10 2023',
    time: '12:30',
    paymentMethod: 'Tiền mặt',
    note: 'Ăn trưa với đồng nghiệp tại quán quen',
    createdAt: '24/10/2023 12:35',
    updatedAt: '24/10/2023 12:35',
    icon: Icons.restaurant_rounded,
    accentColor: AppColors.error,
    iconBackgroundColor: Color(0x330F766E),
    isIncome: false,
  );

  @override
  Widget build(BuildContext context) {
    final routeArgs = ModalRoute.of(context)?.settings.arguments;
    final args = routeArgs is TransactionDetailArgs ? routeArgs : _fallbackArgs;
    final amountColor = args.isIncome ? AppColors.primary : AppColors.error;

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
        actions: [
          IconButton(
            tooltip: 'Tùy chọn',
            onPressed: () {},
            icon: const Icon(Icons.more_vert_rounded),
            color: AppColors.onSurfaceVariant,
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLowest,
            border: const Border(
              top: BorderSide(color: AppColors.surfaceVariant),
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withValues(alpha: 0.05),
                blurRadius: 12,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 48,
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    Navigator.of(
                      context,
                    ).pushNamed(AppRoutes.editTransaction, arguments: args);
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primaryContainer,
                    foregroundColor: AppColors.onPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    textStyle: AppTextStyles.titleMedium,
                  ),
                  child: const Text('Chỉnh sửa giao dịch'),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 48,
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Đã mock xóa giao dịch.')),
                    );
                    Navigator.of(context).pop();
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: const BorderSide(color: AppColors.error),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    textStyle: AppTextStyles.titleMedium,
                  ),
                  child: const Text('Xóa giao dịch'),
                ),
              ),
            ],
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                _DetailHero(args: args, amountColor: amountColor),
                const SizedBox(height: 32),
                _DetailInfoCard(
                  rows: [
                    _DetailRowData(
                      icon: Icons.swap_horiz_rounded,
                      label: 'Loại giao dịch',
                      value: args.transactionType,
                    ),
                    _DetailRowData(
                      icon: Icons.category_outlined,
                      label: 'Danh mục',
                      value: args.category,
                    ),
                    _DetailRowData(
                      icon: Icons.calendar_today_outlined,
                      label: 'Ngày',
                      value: args.date,
                    ),
                    _DetailRowData(
                      icon: Icons.schedule_rounded,
                      label: 'Giờ',
                      value: args.time,
                    ),
                    _DetailRowData(
                      icon: Icons.account_balance_wallet_outlined,
                      label: 'Phương thức thanh toán',
                      value: args.paymentMethod,
                    ),
                    _DetailRowData(
                      icon: Icons.notes_rounded,
                      label: 'Ghi chú',
                      value: args.note,
                      alignTop: true,
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _Metadata(createdAt: args.createdAt, updatedAt: args.updatedAt),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DetailHero extends StatelessWidget {
  const _DetailHero({required this.args, required this.amountColor});

  final TransactionDetailArgs args;
  final Color amountColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: args.iconBackgroundColor,
            shape: BoxShape.circle,
          ),
          child: Icon(args.icon, color: args.accentColor, size: 40),
        ),
        const SizedBox(height: 16),
        Text(
          args.title,
          textAlign: TextAlign.center,
          style: AppTextStyles.headlineLargeMobile.copyWith(
            color: AppColors.onSurface,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          args.amount,
          textAlign: TextAlign.center,
          style: AppTextStyles.displayCurrency.copyWith(color: amountColor),
        ),
      ],
    );
  }
}

class _DetailInfoCard extends StatelessWidget {
  const _DetailInfoCard({required this.rows});

  final List<_DetailRowData> rows;

  @override
  Widget build(BuildContext context) {
    return Container(
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
          for (var index = 0; index < rows.length; index++) ...[
            _DetailRow(data: rows[index]),
            if (index != rows.length - 1)
              Padding(
                padding: const EdgeInsets.only(left: 64, right: 16),
                child: Divider(
                  height: 1,
                  color: AppColors.outlineVariant.withValues(alpha: 0.30),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.data});

  final _DetailRowData data;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: data.alignTop
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.center,
        children: [
          Container(
            width: 40,
            height: 40,
            margin: EdgeInsets.only(top: data.alignTop ? 4 : 0),
            decoration: const BoxDecoration(
              color: AppColors.surfaceContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(data.icon, color: AppColors.onSurfaceVariant, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.label.toUpperCase(),
                  style: AppTextStyles.labelMedium.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  data.value,
                  style: AppTextStyles.bodyLarge.copyWith(
                    color: AppColors.onSurface,
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

class _Metadata extends StatelessWidget {
  const _Metadata({required this.createdAt, required this.updatedAt});

  final String createdAt;
  final String updatedAt;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          'Ngày tạo: $createdAt',
          textAlign: TextAlign.center,
          style: AppTextStyles.labelMedium.copyWith(color: AppColors.outline),
        ),
        const SizedBox(height: 4),
        Text(
          'Cập nhật lần cuối: $updatedAt',
          textAlign: TextAlign.center,
          style: AppTextStyles.labelMedium.copyWith(color: AppColors.outline),
        ),
      ],
    );
  }
}

class _DetailRowData {
  const _DetailRowData({
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
