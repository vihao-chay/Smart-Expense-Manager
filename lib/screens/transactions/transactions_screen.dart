import 'package:flutter/material.dart';

import '../../app/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../add_transaction/add_transaction_screen.dart';
import '../transaction_detail/transaction_detail_screen.dart';

enum _TransactionFilter { all, income, expense }

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  final _searchController = TextEditingController();
  var _filter = _TransactionFilter.all;

  List<_TransactionData> get _filteredTransactions {
    final query = _searchController.text.trim().toLowerCase();

    return _transactions.where((transaction) {
      final matchesFilter = switch (_filter) {
        _TransactionFilter.all => true,
        _TransactionFilter.income => transaction.isIncome,
        _TransactionFilter.expense => !transaction.isIncome,
      };

      final matchesSearch =
          query.isEmpty ||
          transaction.title.toLowerCase().contains(query) ||
          transaction.method.toLowerCase().contains(query) ||
          transaction.category.toLowerCase().contains(query);

      return matchesFilter && matchesSearch;
    }).toList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openAddTransaction() {
    Navigator.of(context).pushNamed(
      AppRoutes.addTransaction,
      arguments: const AddTransactionArgs(
        initialType: AddTransactionType.expense,
      ),
    );
  }

  void _openDetail(_TransactionData transaction) {
    Navigator.of(context).pushNamed(
      AppRoutes.transactionDetail,
      arguments: transaction.toDetailArgs(),
    );
  }

  void _goBack() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
      return;
    }

    Navigator.of(context).pushReplacementNamed(AppRoutes.home);
  }

  @override
  Widget build(BuildContext context) {
    final groups = _groupTransactions(_filteredTransactions);

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
          'Smart Expense',
          style: AppTextStyles.headlineLargeMobile.copyWith(
            color: AppColors.primary,
          ),
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
      floatingActionButton: FloatingActionButton(
        onPressed: _openAddTransaction,
        backgroundColor: AppColors.primaryContainer,
        foregroundColor: AppColors.onPrimaryContainer,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.add_rounded, size: 28),
      ),
      bottomNavigationBar: const _TransactionsBottomNavBar(),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 672),
            child: Column(
              children: [
                _SearchAndFilters(
                  searchController: _searchController,
                  selectedFilter: _filter,
                  onSearchChanged: () => setState(() {}),
                  onFilterChanged: (filter) {
                    setState(() {
                      _filter = filter;
                    });
                  },
                ),
                Expanded(
                  child: groups.isEmpty
                      ? const _EmptyTransactions()
                      : ListView(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                          children: [
                            for (final group in groups) ...[
                              _TransactionGroupSection(
                                group: group,
                                onTransactionTap: _openDetail,
                              ),
                              const SizedBox(height: 24),
                            ],
                            const _EndOfListHint(),
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

class _SearchAndFilters extends StatelessWidget {
  const _SearchAndFilters({
    required this.searchController,
    required this.selectedFilter,
    required this.onSearchChanged,
    required this.onFilterChanged,
  });

  final TextEditingController searchController;
  final _TransactionFilter selectedFilter;
  final VoidCallback onSearchChanged;
  final ValueChanged<_TransactionFilter> onFilterChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface.withValues(alpha: 0.94),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.search_rounded,
                    color: AppColors.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: searchController,
                      onChanged: (_) => onSearchChanged(),
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.onSurface,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Tìm kiếm giao dịch...',
                        hintStyle: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.onSurfaceVariant,
                        ),
                        border: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        enabledBorder: InputBorder.none,
                      ),
                    ),
                  ),
                  if (searchController.text.isNotEmpty)
                    IconButton(
                      tooltip: 'Xóa tìm kiếm',
                      onPressed: () {
                        searchController.clear();
                        onSearchChanged();
                      },
                      icon: const Icon(Icons.close_rounded),
                      color: AppColors.onSurfaceVariant,
                    ),
                ],
              ),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Row(
              children: [
                _FilterChipButton(
                  label: 'Tất cả',
                  selected: selectedFilter == _TransactionFilter.all,
                  onTap: () => onFilterChanged(_TransactionFilter.all),
                ),
                const SizedBox(width: 8),
                _FilterChipButton(
                  label: 'Thu nhập',
                  selected: selectedFilter == _TransactionFilter.income,
                  onTap: () => onFilterChanged(_TransactionFilter.income),
                ),
                const SizedBox(width: 8),
                _FilterChipButton(
                  label: 'Chi tiêu',
                  selected: selectedFilter == _TransactionFilter.expense,
                  onTap: () => onFilterChanged(_TransactionFilter.expense),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChipButton extends StatelessWidget {
  const _FilterChipButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primaryContainer
              : AppColors.surfaceContainer,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected) ...[
              const Icon(
                Icons.done_rounded,
                size: 16,
                color: AppColors.onPrimaryContainer,
              ),
              const SizedBox(width: 8),
            ],
            Text(
              label,
              style: AppTextStyles.labelMedium.copyWith(
                color: selected
                    ? AppColors.onPrimaryContainer
                    : AppColors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TransactionGroupSection extends StatelessWidget {
  const _TransactionGroupSection({
    required this.group,
    required this.onTransactionTap,
  });

  final _TransactionGroup group;
  final ValueChanged<_TransactionData> onTransactionTap;

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
        for (final transaction in group.transactions) ...[
          _TransactionCard(
            transaction: transaction,
            onTap: () => onTransactionTap(transaction),
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _TransactionCard extends StatelessWidget {
  const _TransactionCard({required this.transaction, required this.onTap});

  final _TransactionData transaction;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final amountColor = transaction.isIncome
        ? AppColors.primary
        : transaction.prominentExpense
        ? AppColors.error
        : AppColors.onSurface;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          padding: const EdgeInsets.all(16),
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
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: transaction.iconBackground,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  transaction.icon,
                  color: transaction.iconColor,
                  size: 26,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      transaction.title,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.titleMedium.copyWith(
                        color: AppColors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${transaction.time} • ${transaction.method}',
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  transaction.amount,
                  textAlign: TextAlign.end,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.titleMedium.copyWith(color: amountColor),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyTransactions extends StatelessWidget {
  const _EmptyTransactions();

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
                Icons.receipt_long_outlined,
                color: AppColors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Không tìm thấy giao dịch',
              style: AppTextStyles.titleMedium.copyWith(
                color: AppColors.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Thử đổi từ khóa tìm kiếm hoặc bộ lọc.',
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

class _EndOfListHint extends StatelessWidget {
  const _EndOfListHint();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.check_circle_outline_rounded,
            size: 16,
            color: AppColors.onSurfaceVariant,
          ),
          const SizedBox(width: 4),
          Text(
            'Đã hiển thị tất cả giao dịch gần đây',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.onSurfaceVariant,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _TransactionsBottomNavBar extends StatelessWidget {
  const _TransactionsBottomNavBar();

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
            const _NavItem(
              label: 'Transactions',
              icon: Icons.receipt_long_rounded,
              selected: true,
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
              icon: Icons.person_outline_rounded,
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
        onTap: selected ? null : onTap,
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

List<_TransactionGroup> _groupTransactions(
  List<_TransactionData> transactions,
) {
  final groups = <String, List<_TransactionData>>{};

  for (final transaction in transactions) {
    groups.putIfAbsent(transaction.group, () => []).add(transaction);
  }

  return groups.entries
      .map((entry) => _TransactionGroup(entry.key, entry.value))
      .toList();
}

class _TransactionGroup {
  const _TransactionGroup(this.title, this.transactions);

  final String title;
  final List<_TransactionData> transactions;
}

class _TransactionData {
  const _TransactionData({
    required this.group,
    required this.title,
    required this.time,
    required this.method,
    required this.amount,
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    required this.isIncome,
    required this.category,
    required this.dateText,
    required this.note,
    this.prominentExpense = false,
  });

  final String group;
  final String title;
  final String time;
  final String method;
  final String amount;
  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
  final bool isIncome;
  final String category;
  final String dateText;
  final String note;
  final bool prominentExpense;

  TransactionDetailArgs toDetailArgs() {
    return TransactionDetailArgs(
      title: title == 'Ăn trưa' ? 'Ăn trưa tại The Workshop' : title,
      amount: amount,
      transactionType: isIncome ? 'Thu nhập' : 'Chi tiêu',
      category: category,
      date: dateText,
      time: time,
      paymentMethod: method,
      note: note,
      createdAt: _createdAt,
      updatedAt: _createdAt,
      icon: icon,
      accentColor: isIncome ? AppColors.primary : iconColor,
      iconBackgroundColor: iconBackground,
      isIncome: isIncome,
    );
  }

  String get _createdAt {
    if (group == 'Hôm nay') return '24/10/2023 $time';
    if (group == 'Hôm qua') return '23/10/2023 $time';
    return '24/10/2023 $time';
  }
}

const _transactions = [
  _TransactionData(
    group: 'Hôm nay',
    title: 'Lương tháng 7',
    time: '08:30 AM',
    method: 'Chuyển khoản',
    amount: '+12.000.000 ₫',
    icon: Icons.account_balance_rounded,
    iconColor: AppColors.onSecondaryContainer,
    iconBackground: AppColors.secondaryContainer,
    isIncome: true,
    category: 'Lương',
    dateText: 'Hôm nay, 24 Th10 2023',
    note: 'Khoản thu nhập được ghi nhận tự động từ tài khoản chính.',
  ),
  _TransactionData(
    group: 'Hôm nay',
    title: 'Ăn trưa',
    time: '12:15 PM',
    method: 'Tiền mặt',
    amount: '-65.000 ₫',
    icon: Icons.restaurant_rounded,
    iconColor: AppColors.error,
    iconBackground: Color(0x66FFDAD6),
    isIncome: false,
    category: 'Ăn uống',
    dateText: 'Hôm nay, 24 Th10 2023',
    note: 'Ăn trưa với đồng nghiệp tại quán quen',
    prominentExpense: true,
  ),
  _TransactionData(
    group: 'Hôm qua',
    title: 'Cà phê The Workshop',
    time: '09:00 AM',
    method: 'Thẻ tín dụng',
    amount: '-85.000 ₫',
    icon: Icons.local_cafe_outlined,
    iconColor: AppColors.onSurfaceVariant,
    iconBackground: AppColors.surfaceVariant,
    isIncome: false,
    category: 'Ăn uống',
    dateText: 'Hôm qua, 23 Th10 2023',
    note: 'Cà phê và làm việc buổi sáng.',
  ),
  _TransactionData(
    group: 'Hôm qua',
    title: 'Grab Bike',
    time: '06:45 PM',
    method: 'Ví điện tử',
    amount: '-32.000 ₫',
    icon: Icons.directions_car_outlined,
    iconColor: AppColors.onSurfaceVariant,
    iconBackground: AppColors.surfaceVariant,
    isIncome: false,
    category: 'Di chuyển',
    dateText: 'Hôm qua, 23 Th10 2023',
    note: 'Di chuyển từ trường về nhà.',
  ),
];
