import 'package:flutter/material.dart';

import '../../app/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/app_formatters.dart';
import '../../core/utils/category_catalog.dart';
import '../../data/models/app_transaction.dart';
import '../../data/repositories/firebase_auth_error_mapper.dart';
import '../../data/repositories/firestore_repository.dart';
import '../add_transaction/add_transaction_screen.dart';
import '../transaction_detail/transaction_detail_screen.dart';

enum _TransactionFilter { all, income, expense }

enum _DateFilter { all, today, thisMonth }

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  final _repository = FirestoreRepository();
  final _searchController = TextEditingController();

  var _filter = _TransactionFilter.all;
  var _dateFilter = _DateFilter.all;
  var _categoryFilter = 'Tất cả';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<AppTransaction> _filterTransactions(List<AppTransaction> transactions) {
    final query = _searchController.text.trim().toLowerCase();
    final now = DateTime.now();

    return transactions.where((transaction) {
      final matchesType = switch (_filter) {
        _TransactionFilter.all => true,
        _TransactionFilter.income =>
          transaction.type == AppTransactionType.income,
        _TransactionFilter.expense =>
          transaction.type == AppTransactionType.expense,
      };

      final matchesDate = switch (_dateFilter) {
        _DateFilter.all => true,
        _DateFilter.today =>
          DateTime(
                transaction.transactionDate.year,
                transaction.transactionDate.month,
                transaction.transactionDate.day,
              ) ==
              DateTime(now.year, now.month, now.day),
        _DateFilter.thisMonth => isSameMonth(transaction.transactionDate, now),
      };

      final matchesCategory =
          _categoryFilter == 'Tất cả' ||
          transaction.category == _categoryFilter;

      final searchable = [
        transaction.title,
        transaction.note,
        transaction.category,
        transaction.paymentMethod,
      ].whereType<String>().join(' ').toLowerCase();

      return matchesType &&
          matchesDate &&
          matchesCategory &&
          (query.isEmpty || searchable.contains(query));
    }).toList();
  }

  void _openAddTransaction() {
    Navigator.of(context).pushNamed(
      AppRoutes.addTransaction,
      arguments: const AddTransactionArgs(
        initialType: AddTransactionType.expense,
      ),
    );
  }

  void _openDetail(AppTransaction transaction) {
    Navigator.of(context).pushNamed(
      AppRoutes.transactionDetail,
      arguments: TransactionDetailArgs(transactionId: transaction.id),
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
          'Giao dịch',
          style: AppTextStyles.headlineLargeMobile.copyWith(
            color: AppColors.primary,
          ),
        ),
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
            child: StreamBuilder<List<AppTransaction>>(
              stream: _repository.watchTransactions(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return _ErrorState(
                    message: firebaseAuthErrorMessage(snapshot.error!),
                  );
                }

                final transactions = _filterTransactions(snapshot.data ?? []);
                final groups = _groupTransactions(transactions);

                return Column(
                  children: [
                    _SearchAndFilters(
                      searchController: _searchController,
                      selectedFilter: _filter,
                      selectedDateFilter: _dateFilter,
                      selectedCategory: _categoryFilter,
                      onSearchChanged: () => setState(() {}),
                      onFilterChanged: (filter) {
                        setState(() => _filter = filter);
                      },
                      onDateFilterChanged: (filter) {
                        setState(() => _dateFilter = filter);
                      },
                      onCategoryChanged: (category) {
                        setState(() => _categoryFilter = category ?? 'Tất cả');
                      },
                    ),
                    Expanded(
                      child: groups.isEmpty
                          ? const _EmptyTransactions()
                          : ListView(
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                              children: [
                                for (final group in groups) ...[
                                  _TransactionGroupSection(
                                    group: group,
                                    onTransactionTap: _openDetail,
                                  ),
                                  const SizedBox(height: 20),
                                ],
                              ],
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

class _SearchAndFilters extends StatelessWidget {
  const _SearchAndFilters({
    required this.searchController,
    required this.selectedFilter,
    required this.selectedDateFilter,
    required this.selectedCategory,
    required this.onSearchChanged,
    required this.onFilterChanged,
    required this.onDateFilterChanged,
    required this.onCategoryChanged,
  });

  final TextEditingController searchController;
  final _TransactionFilter selectedFilter;
  final _DateFilter selectedDateFilter;
  final String selectedCategory;
  final VoidCallback onSearchChanged;
  final ValueChanged<_TransactionFilter> onFilterChanged;
  final ValueChanged<_DateFilter> onDateFilterChanged;
  final ValueChanged<String?> onCategoryChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface.withValues(alpha: 0.96),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: TextField(
              controller: searchController,
              onChanged: (_) => onSearchChanged(),
              decoration: InputDecoration(
                hintText: 'Tìm kiếm giao dịch...',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: searchController.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Xóa tìm kiếm',
                        onPressed: () {
                          searchController.clear();
                          onSearchChanged();
                        },
                        icon: const Icon(Icons.close_rounded),
                      ),
                filled: true,
                fillColor: AppColors.surfaceContainerLow,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(999),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Row(
              children: [
                _FilterChipButton(
                  label: 'Tất cả',
                  selected: selectedFilter == _TransactionFilter.all,
                  onTap: () => onFilterChanged(_TransactionFilter.all),
                ),
                _FilterChipButton(
                  label: 'Thu nhập',
                  selected: selectedFilter == _TransactionFilter.income,
                  onTap: () => onFilterChanged(_TransactionFilter.income),
                ),
                _FilterChipButton(
                  label: 'Chi tiêu',
                  selected: selectedFilter == _TransactionFilter.expense,
                  onTap: () => onFilterChanged(_TransactionFilter.expense),
                ),
                _FilterChipButton(
                  label: 'Hôm nay',
                  selected: selectedDateFilter == _DateFilter.today,
                  onTap: () => onDateFilterChanged(
                    selectedDateFilter == _DateFilter.today
                        ? _DateFilter.all
                        : _DateFilter.today,
                  ),
                ),
                _FilterChipButton(
                  label: 'Tháng này',
                  selected: selectedDateFilter == _DateFilter.thisMonth,
                  onTap: () => onDateFilterChanged(
                    selectedDateFilter == _DateFilter.thisMonth
                        ? _DateFilter.all
                        : _DateFilter.thisMonth,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: DropdownButtonFormField<String>(
              initialValue: selectedCategory,
              decoration: InputDecoration(
                labelText: 'Danh mục',
                filled: true,
                fillColor: AppColors.surfaceContainerLowest,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              items: ['Tất cả', ...allCategoryLabels].map((category) {
                return DropdownMenuItem(value: category, child: Text(category));
              }).toList(),
              onChanged: onCategoryChanged,
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
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        selected: selected,
        label: Text(label),
        onSelected: (_) => onTap(),
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
  final ValueChanged<AppTransaction> onTransactionTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(group.title, style: AppTextStyles.titleMedium),
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

  final AppTransaction transaction;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final meta = categoryMeta(transaction.category, type: transaction.type);
    final isIncome = transaction.type == AppTransactionType.income;
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
            border: Border.all(
              color: AppColors.outlineVariant.withValues(alpha: 0.20),
            ),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: meta.backgroundColor,
                child: Icon(meta.icon, color: meta.color),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      transaction.title ?? transaction.category,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.titleMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${formatShortDate(transaction.transactionDate)} • ${transaction.paymentMethod ?? 'Ví cá nhân'}',
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.labelMedium,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  formatTransactionAmount(transaction),
                  textAlign: TextAlign.end,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.titleMedium.copyWith(
                    color: isIncome ? AppColors.secondary : AppColors.error,
                  ),
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
            const CircleAvatar(
              radius: 32,
              backgroundColor: AppColors.surfaceContainerHigh,
              child: Icon(Icons.receipt_long_outlined),
            ),
            const SizedBox(height: 16),
            Text('Chưa có giao dịch phù hợp', style: AppTextStyles.titleMedium),
            const SizedBox(height: 4),
            Text(
              'Thử đổi từ khóa, bộ lọc hoặc thêm giao dịch mới.',
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

class _TransactionsBottomNavBar extends StatelessWidget {
  const _TransactionsBottomNavBar();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        decoration: const BoxDecoration(color: AppColors.surface),
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
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: selected
                    ? AppColors.primary
                    : AppColors.onSurfaceVariant,
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: AppTextStyles.labelMedium.copyWith(
                  color: selected
                      ? AppColors.primary
                      : AppColors.onSurfaceVariant,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

List<_TransactionGroup> _groupTransactions(List<AppTransaction> transactions) {
  final groups = <String, List<AppTransaction>>{};
  for (final transaction in transactions) {
    groups
        .putIfAbsent(formatShortDate(transaction.transactionDate), () => [])
        .add(transaction);
  }
  return groups.entries
      .map((entry) => _TransactionGroup(entry.key, entry.value))
      .toList();
}

class _TransactionGroup {
  const _TransactionGroup(this.title, this.transactions);

  final String title;
  final List<AppTransaction> transactions;
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(child: Text(message, textAlign: TextAlign.center));
  }
}
