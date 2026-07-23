import 'package:flutter/material.dart';

import '../../app/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/app_formatters.dart';
import '../../core/utils/category_catalog.dart';
import '../../core/widgets/app_top_bar.dart';
import '../../data/models/app_transaction.dart';
import '../../data/models/app_user_profile.dart';
import '../../data/repositories/firebase_auth_error_mapper.dart';
import '../../data/repositories/firestore_repository.dart';
import '../add_transaction/add_transaction_screen.dart';
import '../transaction_detail/transaction_detail_screen.dart';

enum _TypeFilter { all, income, expense }

enum _DateFilter { all, today, thisMonth }

class TransactionsArgs {
  const TransactionsArgs({this.initialType, this.initialCategory});

  final AppTransactionType? initialType;
  final String? initialCategory;
}

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  final _repository = FirestoreRepository();
  final _searchController = TextEditingController();

  var _typeFilter = _TypeFilter.all;
  var _dateFilter = _DateFilter.all;
  var _categoryFilter = 'Tất cả';
  var _filtersExpanded = false;
  var _didApplyRouteArgs = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<AppTransaction> _filterTransactions(List<AppTransaction> transactions) {
    final query = _searchController.text.trim().toLowerCase();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return transactions.where((transaction) {
      final matchesType = switch (_typeFilter) {
        _TypeFilter.all => true,
        _TypeFilter.income => transaction.type == AppTransactionType.income,
        _TypeFilter.expense => transaction.type == AppTransactionType.expense,
      };

      final matchesDate = switch (_dateFilter) {
        _DateFilter.all => true,
        _DateFilter.today =>
          DateTime(
                transaction.transactionDate.year,
                transaction.transactionDate.month,
                transaction.transactionDate.day,
              ) ==
              today,
        _DateFilter.thisMonth =>
          isSameMonth(transaction.transactionDate, now),
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

  int _sumByType(List<AppTransaction> items, AppTransactionType type) {
    return items
        .where((item) => item.type == type)
        .fold<int>(0, (sum, item) => sum + item.amount);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didApplyRouteArgs) return;
    _didApplyRouteArgs = true;

    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is! TransactionsArgs) return;

    _typeFilter = switch (args.initialType) {
      AppTransactionType.income => _TypeFilter.income,
      AppTransactionType.expense => _TypeFilter.expense,
      null => _TypeFilter.all,
    };

    final category = args.initialCategory?.trim();
    if (category != null && category.isNotEmpty) {
      _categoryFilter = category;
    }

    if (_typeFilter != _TypeFilter.all ||
        (_categoryFilter.isNotEmpty && _categoryFilter != 'Tất cả')) {
      _filtersExpanded = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      floatingActionButton: FloatingActionButton(
        onPressed: _openAddTransaction,
        backgroundColor: AppColors.primaryContainer,
        foregroundColor: AppColors.onPrimaryContainer,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.add_rounded, size: 28),
      ),
      bottomNavigationBar: const _TransactionsBottomNavBar(),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 672),
            child: StreamBuilder<AppUserProfile?>(
              stream: _repository.watchProfile(),
              builder: (context, snapshot) {
                return Column(
                  children: [
                    AppTopBar(profile: snapshot.data),
                    Expanded(
                      child: StreamBuilder<List<AppTransaction>>(
                        stream: _repository.watchTransactions(),
                        builder: (context, transactionSnapshot) {
                          if (transactionSnapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }
                          if (transactionSnapshot.hasError) {
                            return _ErrorState(
                              message: firebaseAuthErrorMessage(
                                transactionSnapshot.error!,
                              ),
                            );
                          }

                          final transactions = _filterTransactions(
                            transactionSnapshot.data ?? [],
                          );
                          final groups = _groupTransactions(transactions);
                          final income = _sumByType(
                            transactions,
                            AppTransactionType.income,
                          );
                          final expense = _sumByType(
                            transactions,
                            AppTransactionType.expense,
                          );

                          return Column(
                            children: [
                              _SearchAndFilters(
                                searchController: _searchController,
                                selectedType: _typeFilter,
                                selectedDate: _dateFilter,
                                selectedCategory: _categoryFilter,
                                filtersExpanded: _filtersExpanded,
                                resultCount: transactions.length,
                                incomeTotal: income,
                                expenseTotal: expense,
                                onSearchChanged: () => setState(() {}),
                                onToggleFilters: () {
                                  setState(
                                    () => _filtersExpanded = !_filtersExpanded,
                                  );
                                },
                                onTypeChanged: (filter) {
                                  setState(() => _typeFilter = filter);
                                },
                                onDateChanged: (filter) {
                                  setState(() => _dateFilter = filter);
                                },
                                onCategoryChanged: (category) {
                                  setState(() => _categoryFilter = category);
                                },
                                onClearFilters: () {
                                  setState(() {
                                    _typeFilter = _TypeFilter.all;
                                    _dateFilter = _DateFilter.all;
                                    _categoryFilter = 'Tất cả';
                                  });
                                },
                              ),
                              Expanded(
                                child: groups.isEmpty
                                    ? _EmptyTransactions(
                                        hasActiveFilters:
                                            _typeFilter != _TypeFilter.all ||
                                            _dateFilter != _DateFilter.all ||
                                            _categoryFilter != 'Tất cả' ||
                                            _searchController.text
                                                .trim()
                                                .isNotEmpty,
                                      )
                                    : ListView(
                                        padding: const EdgeInsets.fromLTRB(
                                          16,
                                          0,
                                          16,
                                          104,
                                        ),
                                        children: [
                                          for (final group in groups) ...[
                                            _TransactionGroupSection(
                                              group: group,
                                              onTransactionTap: _openDetail,
                                            ),
                                            const SizedBox(height: 14),
                                          ],
                                        ],
                                      ),
                              ),
                            ],
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

class _SearchAndFilters extends StatelessWidget {
  const _SearchAndFilters({
    required this.searchController,
    required this.selectedType,
    required this.selectedDate,
    required this.selectedCategory,
    required this.filtersExpanded,
    required this.resultCount,
    required this.incomeTotal,
    required this.expenseTotal,
    required this.onSearchChanged,
    required this.onToggleFilters,
    required this.onTypeChanged,
    required this.onDateChanged,
    required this.onCategoryChanged,
    required this.onClearFilters,
  });

  final TextEditingController searchController;
  final _TypeFilter selectedType;
  final _DateFilter selectedDate;
  final String selectedCategory;
  final bool filtersExpanded;
  final int resultCount;
  final int incomeTotal;
  final int expenseTotal;
  final VoidCallback onSearchChanged;
  final VoidCallback onToggleFilters;
  final ValueChanged<_TypeFilter> onTypeChanged;
  final ValueChanged<_DateFilter> onDateChanged;
  final ValueChanged<String> onCategoryChanged;
  final VoidCallback onClearFilters;

  String get _dateLabel => switch (selectedDate) {
    _DateFilter.all => 'Mọi thời gian',
    _DateFilter.today => 'Hôm nay',
    _DateFilter.thisMonth => 'Tháng này',
  };

  String get _categoryLabel =>
      selectedCategory == 'Tất cả' ? 'Danh mục' : selectedCategory;

  bool get _hasActiveFilters =>
      selectedType != _TypeFilter.all ||
      selectedDate != _DateFilter.all ||
      selectedCategory != 'Tất cả';

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppColors.outlineVariant.withValues(alpha: 0.14),
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F172A).withValues(alpha: 0.04),
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
                Expanded(
                  child: TextField(
                    controller: searchController,
                    onChanged: (_) => onSearchChanged(),
                    style: AppTextStyles.bodyMedium,
                    decoration: InputDecoration(
                      hintText: 'Tìm kiếm giao dịch...',
                      hintStyle: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.onSurfaceVariant.withValues(
                          alpha: 0.7,
                        ),
                      ),
                      prefixIcon: Icon(
                        Icons.search_rounded,
                        color: AppColors.onSurfaceVariant,
                      ),
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
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _FilterToggleButton(
                  expanded: filtersExpanded,
                  active: _hasActiveFilters,
                  onTap: onToggleFilters,
                ),
              ],
            ),
            const SizedBox(height: 10),
            _SummaryStrip(
              resultCount: resultCount,
              incomeTotal: incomeTotal,
              expenseTotal: expenseTotal,
              showClear: _hasActiveFilters,
              onClear: onClearFilters,
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: filtersExpanded
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 12),
                        _TypeSegmentedControl(
                          selected: selectedType,
                          onChanged: onTypeChanged,
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _FilterMenuButton(
                                icon: Icons.calendar_today_outlined,
                                label: _dateLabel,
                                active: selectedDate != _DateFilter.all,
                                menuChildren: [
                                  for (final date in _DateFilter.values)
                                    MenuItemButton(
                                      onPressed: () => onDateChanged(date),
                                      trailingIcon: selectedDate == date
                                          ? Icon(
                                              Icons.check_rounded,
                                              size: 18,
                                              color: AppColors.primary,
                                            )
                                          : null,
                                      child: Text(switch (date) {
                                        _DateFilter.all => 'Mọi thời gian',
                                        _DateFilter.today => 'Hôm nay',
                                        _DateFilter.thisMonth => 'Tháng này',
                                      }),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _FilterMenuButton(
                                icon: Icons.category_outlined,
                                label: _categoryLabel,
                                active: selectedCategory != 'Tất cả',
                                menuChildren: [
                                  for (final category in [
                                    'Tất cả',
                                    ...allCategoryLabels,
                                  ])
                                    MenuItemButton(
                                      onPressed: () =>
                                          onCategoryChanged(category),
                                      trailingIcon: selectedCategory == category
                                          ? Icon(
                                              Icons.check_rounded,
                                              size: 18,
                                              color: AppColors.primary,
                                            )
                                          : null,
                                      child: Text(
                                        category == 'Tất cả'
                                            ? 'Tất cả danh mục'
                                            : category,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterToggleButton extends StatelessWidget {
  const _FilterToggleButton({
    required this.expanded,
    required this.active,
    required this.onTap,
  });

  final bool expanded;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final highlighted = expanded || active;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: highlighted
                ? AppColors.primaryFixed.withValues(alpha: 0.45)
                : AppColors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: highlighted
                  ? AppColors.primary.withValues(alpha: 0.28)
                  : AppColors.outlineVariant.withValues(alpha: 0.2),
            ),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(
                Icons.tune_rounded,
                color: highlighted
                    ? AppColors.primary
                    : AppColors.onSurfaceVariant,
              ),
              if (active)
                Positioned(
                  right: 10,
                  top: 10,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.surfaceContainerLowest,
                        width: 1.5,
                      ),
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

class _SummaryStrip extends StatelessWidget {
  const _SummaryStrip({
    required this.resultCount,
    required this.incomeTotal,
    required this.expenseTotal,
    required this.showClear,
    required this.onClear,
  });

  final int resultCount;
  final int incomeTotal;
  final int expenseTotal;
  final bool showClear;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final net = incomeTotal - expenseTotal;
    final netPositive = net >= 0;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                '$resultCount giao dịch',
                style: AppTextStyles.labelMedium.copyWith(
                  color: AppColors.onSurface,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (showClear) ...[
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: onClear,
                  child: Text(
                    'Xóa lọc',
                    style: AppTextStyles.labelMedium.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
              const Spacer(),
              Text(
                'Chênh lệch ',
                style: AppTextStyles.labelMedium.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
              Text(
                formatVnd(net, withSign: true),
                style: AppTextStyles.labelMedium.copyWith(
                  color: netPositive ? AppColors.primary : AppColors.expense,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _FlowChip(
                  label: 'Thu',
                  amount: incomeTotal,
                  color: AppColors.primary,
                  prefix: '+',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _FlowChip(
                  label: 'Chi',
                  amount: expenseTotal,
                  color: AppColors.expense,
                  prefix: '-',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FlowChip extends StatelessWidget {
  const _FlowChip({
    required this.label,
    required this.amount,
    required this.color,
    required this.prefix,
  });

  final String label;
  final int amount;
  final Color color;
  final String prefix;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Text(
            label,
            style: AppTextStyles.labelMedium.copyWith(
              color: AppColors.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          Text(
            '$prefix${formatVnd(amount)}',
            style: AppTextStyles.labelMedium.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _TypeSegmentedControl extends StatelessWidget {
  const _TypeSegmentedControl({
    required this.selected,
    required this.onChanged,
  });

  final _TypeFilter selected;
  final ValueChanged<_TypeFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          for (final type in _TypeFilter.values)
            Expanded(
              child: _TypeSegment(
                label: switch (type) {
                  _TypeFilter.all => 'Tất cả',
                  _TypeFilter.income => 'Thu nhập',
                  _TypeFilter.expense => 'Chi tiêu',
                },
                selected: selected == type,
                onTap: () => onChanged(type),
              ),
            ),
        ],
      ),
    );
  }
}

class _TypeSegment extends StatelessWidget {
  const _TypeSegment({
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
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.primaryContainer : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.18),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: AppTextStyles.labelMedium.copyWith(
            color: selected
                ? AppColors.onPrimaryContainer
                : AppColors.onSurfaceVariant,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _FilterMenuButton extends StatelessWidget {
  const _FilterMenuButton({
    required this.icon,
    required this.label,
    required this.active,
    required this.menuChildren,
  });

  final IconData icon;
  final String label;
  final bool active;
  final List<Widget> menuChildren;

  @override
  Widget build(BuildContext context) {
    return MenuAnchor(
      builder: (context, controller, child) {
        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              if (controller.isOpen) {
                controller.close();
              } else {
                controller.open();
              }
            },
            borderRadius: BorderRadius.circular(14),
            child: Ink(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              decoration: BoxDecoration(
                color: active
                    ? AppColors.primaryFixed.withValues(alpha: 0.4)
                    : AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: active
                      ? AppColors.primary.withValues(alpha: 0.28)
                      : AppColors.outlineVariant.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    icon,
                    size: 18,
                    color: active
                        ? AppColors.primary
                        : AppColors.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      label,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: active
                            ? AppColors.primary
                            : AppColors.onSurface,
                        fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 20,
                    color: AppColors.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
        );
      },
      menuChildren: menuChildren,
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

  int get _dayNet {
    var income = 0;
    var expense = 0;
    for (final item in group.transactions) {
      if (item.type == AppTransactionType.income) {
        income += item.amount;
      } else {
        expense += item.amount;
      }
    }
    return income - expense;
  }

  @override
  Widget build(BuildContext context) {
    final dayNet = _dayNet;
    final netPositive = dayNet >= 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 2, 4, 8),
          child: Row(
            children: [
              Text(
                group.title,
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${group.transactions.length} giao dịch',
                style: AppTextStyles.labelMedium,
              ),
              const Spacer(),
              Text(
                formatVnd(dayNet, withSign: true),
                style: AppTextStyles.labelMedium.copyWith(
                  color: netPositive ? AppColors.primary : AppColors.expense,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
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
              for (var i = 0; i < group.transactions.length; i++)
                _TransactionCard(
                  transaction: group.transactions[i],
                  onTap: () => onTransactionTap(group.transactions[i]),
                  showDivider: i != group.transactions.length - 1,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TransactionCard extends StatelessWidget {
  const _TransactionCard({
    required this.transaction,
    required this.onTap,
    this.showDivider = false,
  });

  final AppTransaction transaction;
  final VoidCallback onTap;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final meta = categoryMeta(transaction.category, type: transaction.type);
    final isIncome = transaction.type == AppTransactionType.income;
    final time =
        '${transaction.transactionDate.hour.toString().padLeft(2, '0')}:'
        '${transaction.transactionDate.minute.toString().padLeft(2, '0')}';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: meta.backgroundColor,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(meta.icon, color: meta.color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      transaction.title ?? transaction.category,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [
                        transaction.category,
                        time,
                        transaction.paymentMethod ??
                            (isIncome ? 'Chuyển khoản' : 'Ví cá nhân'),
                      ].join(' · '),
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.labelMedium,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                formatTransactionAmount(transaction),
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.w700,
                  color: isIncome ? AppColors.primary : AppColors.expense,
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
  const _EmptyTransactions({required this.hasActiveFilters});

  final bool hasActiveFilters;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 12, 28, 96),
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
                hasActiveFilters
                    ? Icons.filter_alt_off_outlined
                    : Icons.receipt_long_rounded,
                size: 40,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              hasActiveFilters
                  ? 'Không tìm thấy giao dịch'
                  : 'Chưa có giao dịch',
              style: AppTextStyles.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              hasActiveFilters
                  ? 'Thử đổi bộ lọc hoặc từ khóa tìm kiếm.'
                  : 'Nhấn + để thêm khoản thu hoặc chi đầu tiên.',
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
        decoration: BoxDecoration(color: AppColors.surface),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _NavItem(
              label: 'Trang chủ',
              icon: Icons.home_outlined,
              onTap: () {
                Navigator.of(context).pushReplacementNamed(AppRoutes.home);
              },
            ),
            const _NavItem(
              label: 'Giao dịch',
              icon: Icons.receipt_rounded,
              selected: true,
            ),
            _NavItem(
              label: 'Thống kê',
              icon: Icons.leaderboard_outlined,
              onTap: () {
                Navigator.of(
                  context,
                ).pushReplacementNamed(AppRoutes.statistics);
              },
            ),
            _NavItem(
              label: 'Cá nhân',
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
  final orderKeys = <String, DateTime>{};

  for (final transaction in transactions) {
    final key = formatShortDate(transaction.transactionDate);
    groups.putIfAbsent(key, () => []).add(transaction);
    orderKeys.putIfAbsent(
      key,
      () => DateTime(
        transaction.transactionDate.year,
        transaction.transactionDate.month,
        transaction.transactionDate.day,
      ),
    );
  }

  for (final entries in groups.values) {
    entries.sort(
      (a, b) => b.transactionDate.compareTo(a.transactionDate),
    );
  }

  final sortedKeys = orderKeys.keys.toList()
    ..sort((a, b) => orderKeys[b]!.compareTo(orderKeys[a]!));

  return [
    for (final key in sortedKeys)
      _TransactionGroup(key, groups[key]!),
  ];
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
