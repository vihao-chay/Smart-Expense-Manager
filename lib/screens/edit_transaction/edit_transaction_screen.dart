import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../transaction_detail/transaction_detail_screen.dart';

enum _EditTransactionType { expense, income }

class EditTransactionScreen extends StatefulWidget {
  const EditTransactionScreen({super.key});

  @override
  State<EditTransactionScreen> createState() => _EditTransactionScreenState();
}

class _EditTransactionScreenState extends State<EditTransactionScreen> {
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

  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();

  _EditTransactionType _type = _EditTransactionType.expense;
  DateTime _selectedDate = DateTime.now();
  var _selectedCategoryIndex = 0;
  var _dateLabel = '';
  var _didReadArgs = false;

  List<_CategoryOption> get _categories => _type == _EditTransactionType.expense
      ? _expenseCategories
      : _incomeCategories;

  bool get _isExpense => _type == _EditTransactionType.expense;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didReadArgs) return;

    final routeArgs = ModalRoute.of(context)?.settings.arguments;
    final args = routeArgs is TransactionDetailArgs ? routeArgs : _fallbackArgs;
    _type = args.isIncome
        ? _EditTransactionType.income
        : _EditTransactionType.expense;
    _amountController.text = _amountDigitsFrom(args.amount);
    _noteController.text = args.note;
    _selectedDate = _dateFromLabel(args.date) ?? DateTime.now();
    _dateLabel = args.date;
    _selectedCategoryIndex = _categoryIndexFor(args.category, _categories);
    _didReadArgs = true;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _setType(_EditTransactionType type) {
    if (_type == type) return;
    setState(() {
      _type = type;
      _selectedCategoryIndex = 0;
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: AppColors.primary,
              onPrimary: AppColors.onPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked == null) return;
    setState(() {
      _selectedDate = picked;
      _dateLabel = _formatDate(picked);
    });
  }

  void _cancel() {
    Navigator.of(context).pop();
  }

  void _saveChanges() {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final typeLabel = _isExpense ? 'chi tiêu' : 'thu nhập';
    final category = _categories[_selectedCategoryIndex].label;
    FocusScope.of(context).unfocus();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Đã mock cập nhật $typeLabel: $category')),
    );
    Navigator.of(context).pop();
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
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_rounded),
          color: AppColors.onSurfaceVariant,
        ),
        title: Text(
          'Chỉnh sửa giao dịch',
          style: AppTextStyles.headlineLargeMobile.copyWith(
            color: AppColors.primary,
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withValues(alpha: 0.05),
                blurRadius: 12,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: OutlinedButton(
                    onPressed: _cancel,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.onSurfaceVariant,
                      side: const BorderSide(
                        color: AppColors.surfaceContainerHighest,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      textStyle: AppTextStyles.titleMedium,
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: FilledButton(
                    onPressed: _saveChanges,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.onPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      textStyle: AppTextStyles.titleMedium,
                      elevation: 3,
                    ),
                    child: const Text('Save Changes'),
                  ),
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
            constraints: const BoxConstraints(maxWidth: 480),
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                children: [
                  _TypeSegmentedControl(
                    selectedType: _type,
                    onChanged: _setType,
                  ),
                  const SizedBox(height: 24),
                  _AmountInput(controller: _amountController),
                  const SizedBox(height: 32),
                  _CategoryGrid(
                    categories: _categories,
                    selectedIndex: _selectedCategoryIndex,
                    onSelected: (index) {
                      setState(() {
                        _selectedCategoryIndex = index;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  _DateField(label: _dateLabel, onTap: _pickDate),
                  const SizedBox(height: 16),
                  _NoteField(controller: _noteController),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TypeSegmentedControl extends StatelessWidget {
  const _TypeSegmentedControl({
    required this.selectedType,
    required this.onChanged,
  });

  final _EditTransactionType selectedType;
  final ValueChanged<_EditTransactionType> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          _TypeSegment(
            label: 'Chi tiêu',
            selected: selectedType == _EditTransactionType.expense,
            onTap: () => onChanged(_EditTransactionType.expense),
          ),
          _TypeSegment(
            label: 'Thu nhập',
            selected: selectedType == _EditTransactionType.income,
            onTap: () => onChanged(_EditTransactionType.income),
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
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: const Color(0xFF0F172A).withValues(alpha: 0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: AppTextStyles.titleMedium.copyWith(
              color: selected
                  ? AppColors.onPrimary
                  : AppColors.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

class _AmountInput extends StatelessWidget {
  const _AmountInput({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          'Số tiền',
          style: AppTextStyles.labelMedium.copyWith(
            color: AppColors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            const SizedBox(width: 52),
            Expanded(
              child: TextFormField(
                controller: controller,
                textAlign: TextAlign.center,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: AppTextStyles.displayCurrency.copyWith(
                  color: AppColors.primary,
                ),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  errorBorder: InputBorder.none,
                  focusedErrorBorder: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
                validator: (value) {
                  final amount = int.tryParse(value ?? '') ?? 0;
                  if (amount <= 0) {
                    return 'Vui lòng nhập số tiền lớn hơn 0';
                  }
                  return null;
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: Text(
                'VND',
                style: AppTextStyles.titleMedium.copyWith(
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        ),
        Container(
          width: MediaQuery.sizeOf(context).width * 0.55,
          constraints: const BoxConstraints(maxWidth: 260),
          height: 1,
          color: AppColors.surfaceContainerHighest,
        ),
      ],
    );
  }
}

class _CategoryGrid extends StatelessWidget {
  const _CategoryGrid({
    required this.categories,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<_CategoryOption> categories;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Danh mục',
          style: AppTextStyles.labelMedium.copyWith(
            color: AppColors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: categories.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 0.88,
          ),
          itemBuilder: (context, index) {
            final category = categories[index];
            final selected = index == selectedIndex;
            return _CategoryTile(
              category: category,
              selected: selected,
              onTap: () => onSelected(index),
            );
          },
        ),
      ],
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.category,
    required this.selected,
    required this.onTap,
  });

  final _CategoryOption category;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.secondaryContainer
              : AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? Colors.transparent
                : AppColors.surfaceContainerHighest,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: const Color(0xFF0F172A).withValues(alpha: 0.05),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              category.icon,
              color: selected
                  ? AppColors.onSecondaryContainer
                  : AppColors.onSurfaceVariant,
              size: 26,
            ),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                category.label,
                maxLines: 1,
                style: AppTextStyles.labelMedium.copyWith(
                  color: selected
                      ? AppColors.onSecondaryContainer
                      : AppColors.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _InputShell(
      icon: Icons.calendar_today_outlined,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Text(
            label,
            style: AppTextStyles.bodyLarge.copyWith(color: AppColors.onSurface),
          ),
        ),
      ),
    );
  }
}

class _NoteField extends StatelessWidget {
  const _NoteField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return _InputShell(
      icon: Icons.description_outlined,
      alignTop: true,
      child: TextFormField(
        controller: controller,
        minLines: 3,
        maxLines: 3,
        style: AppTextStyles.bodyLarge.copyWith(color: AppColors.onSurface),
        decoration: InputDecoration(
          hintText: 'Ghi chú thêm...',
          hintStyle: AppTextStyles.bodyLarge.copyWith(
            color: AppColors.onSurfaceVariant.withValues(alpha: 0.70),
          ),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }
}

class _InputShell extends StatelessWidget {
  const _InputShell({
    required this.icon,
    required this.child,
    this.alignTop = false,
  });

  final IconData icon;
  final Widget child;
  final bool alignTop;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.surfaceContainerHighest),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: alignTop
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.center,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(16, alignTop ? 16 : 0, 12, 0),
            child: Icon(icon, color: AppColors.onSurfaceVariant, size: 22),
          ),
          Expanded(child: child),
          const SizedBox(width: 16),
        ],
      ),
    );
  }
}

class _CategoryOption {
  const _CategoryOption({required this.label, required this.icon});

  final String label;
  final IconData icon;
}

String _amountDigitsFrom(String amount) {
  final digits = amount.replaceAll(RegExp(r'[^0-9]'), '');
  return digits.isEmpty ? '0' : digits;
}

int _categoryIndexFor(String label, List<_CategoryOption> categories) {
  final normalizedLabel = label.trim().toLowerCase();
  final index = categories.indexWhere(
    (category) => category.label.toLowerCase() == normalizedLabel,
  );
  return index == -1 ? 0 : index;
}

DateTime? _dateFromLabel(String label) {
  final monthTextMatch = RegExp(
    r'(\d{1,2})\s*Th(\d{1,2})\s*(\d{4})',
  ).firstMatch(label);
  if (monthTextMatch != null) {
    return DateTime(
      int.parse(monthTextMatch.group(3)!),
      int.parse(monthTextMatch.group(2)!),
      int.parse(monthTextMatch.group(1)!),
    );
  }

  final slashMatch = RegExp(r'(\d{1,2})/(\d{1,2})/(\d{4})').firstMatch(label);
  if (slashMatch == null) return null;
  return DateTime(
    int.parse(slashMatch.group(3)!),
    int.parse(slashMatch.group(2)!),
    int.parse(slashMatch.group(1)!),
  );
}

String _formatDate(DateTime date) {
  final now = DateTime.now();
  final isToday =
      now.year == date.year && now.month == date.month && now.day == date.day;
  final prefix = isToday ? 'Hôm nay, ' : '';
  return '$prefix${date.day.toString().padLeft(2, '0')} Th${date.month} ${date.year}';
}

const _expenseCategories = [
  _CategoryOption(label: 'Ăn uống', icon: Icons.restaurant_outlined),
  _CategoryOption(label: 'Di chuyển', icon: Icons.directions_car_outlined),
  _CategoryOption(label: 'Mua sắm', icon: Icons.shopping_bag_outlined),
  _CategoryOption(label: 'Học tập', icon: Icons.school_outlined),
  _CategoryOption(label: 'Nhà cửa', icon: Icons.home_outlined),
  _CategoryOption(label: 'Khác', icon: Icons.more_horiz_rounded),
];

const _incomeCategories = [
  _CategoryOption(label: 'Lương', icon: Icons.payments_outlined),
  _CategoryOption(label: 'Thưởng', icon: Icons.card_giftcard_outlined),
  _CategoryOption(label: 'Đầu tư', icon: Icons.trending_up_rounded),
  _CategoryOption(label: 'Quà tặng', icon: Icons.redeem_outlined),
  _CategoryOption(label: 'Bán hàng', icon: Icons.storefront_outlined),
  _CategoryOption(label: 'Khác', icon: Icons.more_horiz_rounded),
];
