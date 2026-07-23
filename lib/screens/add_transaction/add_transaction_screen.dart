import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/app_formatters.dart';
import '../../core/utils/category_catalog.dart';
import '../../data/models/app_notification.dart';
import '../../data/models/app_transaction.dart';
import '../../data/repositories/firebase_auth_error_mapper.dart';
import '../../data/repositories/firestore_repository.dart';

enum AddTransactionType { expense, income }

class AddTransactionArgs {
  const AddTransactionArgs({required this.initialType});

  final AddTransactionType initialType;
}

class AddTransactionScreen extends StatefulWidget {
  const AddTransactionScreen({super.key});

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  final _amountFocus = FocusNode();
  final _repository = FirestoreRepository();

  var _type = AppTransactionType.expense;
  var _selectedDate = DateTime.now();
  var _selectedCategory = expenseCategories.first.label;
  var _didReadArgs = false;
  var _isSaving = false;

  List<CategoryMeta> get _categories => categoriesForType(_type);

  bool get _isIncome => _type == AppTransactionType.income;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didReadArgs) return;

    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is AddTransactionArgs) {
      _type = args.initialType == AddTransactionType.income
          ? AppTransactionType.income
          : AppTransactionType.expense;
      _selectedCategory = categoriesForType(_type).first.label;
    }
    _didReadArgs = true;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    _amountFocus.dispose();
    super.dispose();
  }

  void _setType(AppTransactionType type) {
    if (_type == type) return;
    setState(() {
      _type = type;
      _selectedCategory = categoriesForType(type).first.label;
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked == null) return;
    setState(() => _selectedDate = picked);
  }

  Future<void> _save() async {
    if (_isSaving || !(_formKey.currentState?.validate() ?? false)) return;

    FocusScope.of(context).unfocus();
    setState(() => _isSaving = true);

    try {
      final title = _titleController.text.trim().isEmpty
          ? _selectedCategory
          : _titleController.text.trim();
      final transaction = AppTransaction(
        id: '',
        type: _type,
        amount: parseVndInput(_amountController.text) ?? 0,
        category: _selectedCategory,
        transactionDate: _selectedDate,
        title: title,
        note: _noteController.text.trim(),
        paymentMethod: _type == AppTransactionType.income
            ? 'Chuyển khoản'
            : 'Ví cá nhân',
      );

      await _repository.addTransaction(transaction);
      await _repository.addNotificationIfEnabled(
        AppNotification(
          id: '',
          title: _type == AppTransactionType.income
              ? 'Đã thêm thu nhập'
              : 'Đã thêm chi tiêu',
          body:
              '$title - ${formatVnd(transaction.amount)} (${transaction.category})',
          type: 'transaction',
          isRead: false,
        ),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Đã lưu giao dịch.')));
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(firebaseAuthErrorMessage(error))));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = _isIncome ? AppColors.primary : AppColors.expense;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        leading: IconButton(
          tooltip: 'Đóng',
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close_rounded),
          color: AppColors.onSurfaceVariant,
        ),
        title: Text(
          'Thêm giao dịch',
          style: AppTextStyles.headlineLargeMobile.copyWith(
            color: AppColors.onSurface,
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: SizedBox(
            height: 52,
            child: FilledButton(
              onPressed: _isSaving ? null : _save,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primaryContainer,
                foregroundColor: AppColors.onPrimaryContainer,
                disabledBackgroundColor: AppColors.primaryContainer.withValues(
                  alpha: 0.55,
                ),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: _isSaving
                  ? SizedBox.square(
                      dimension: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: AppColors.onPrimaryContainer,
                      ),
                    )
                  : const Text('Lưu giao dịch'),
            ),
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Form(
              key: _formKey,
              child: ListView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.fromLTRB(
                  16,
                  4,
                  16,
                  16 + MediaQuery.viewInsetsOf(context).bottom,
                ),
                children: [
                  _TypeSegment(type: _type, onChanged: _setType),
                  const SizedBox(height: 20),
                  _AmountField(
                    controller: _amountController,
                    focusNode: _amountFocus,
                    accent: accent,
                    validator: (value) {
                      final amount = parseVndInput(value) ?? 0;
                      if (amount <= 0) return 'Nhập số tiền hợp lệ';
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                  _FieldLabel('Danh mục'),
                  const SizedBox(height: 8),
                  _CategoryScroller(
                    categories: _categories,
                    selectedCategory: _selectedCategory,
                    accent: accent,
                    onSelected: (value) {
                      setState(() => _selectedCategory = value);
                    },
                  ),
                  const SizedBox(height: 16),
                  _DetailCard(
                    children: [
                      _SoftInput(
                        controller: _titleController,
                        hint: 'Tên giao dịch (tuỳ chọn)',
                        icon: Icons.edit_note_rounded,
                      ),
                      const SizedBox(height: 10),
                      _DateRow(date: _selectedDate, onTap: _pickDate),
                      const SizedBox(height: 10),
                      _SoftInput(
                        controller: _noteController,
                        hint: 'Ghi chú (tuỳ chọn)',
                        icon: Icons.notes_rounded,
                        maxLines: 2,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TypeSegment extends StatelessWidget {
  const _TypeSegment({required this.type, required this.onChanged});

  final AppTransactionType type;
  final ValueChanged<AppTransactionType> onChanged;

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
          _TypeButton(
            label: 'Chi tiêu',
            icon: Icons.south_west_rounded,
            selected: type == AppTransactionType.expense,
            selectedColor: AppColors.expense,
            onTap: () => onChanged(AppTransactionType.expense),
          ),
          _TypeButton(
            label: 'Thu nhập',
            icon: Icons.north_east_rounded,
            selected: type == AppTransactionType.income,
            selectedColor: AppColors.primaryContainer,
            onTap: () => onChanged(AppTransactionType.income),
          ),
        ],
      ),
    );
  }
}

class _TypeButton extends StatelessWidget {
  const _TypeButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.selectedColor,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final Color selectedColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(11),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? selectedColor : Colors.transparent,
            borderRadius: BorderRadius.circular(11),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: selected ? Colors.white : AppColors.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: AppTextStyles.labelMedium.copyWith(
                  color: selected ? Colors.white : AppColors.onSurfaceVariant,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AmountField extends StatelessWidget {
  const _AmountField({
    required this.controller,
    required this.focusNode,
    required this.accent,
    required this.validator,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final Color accent;
  final String? Function(String?) validator;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          'Số tiền',
          style: AppTextStyles.labelMedium.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        TextFormField(
          controller: controller,
          focusNode: focusNode,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          inputFormatters: [VndInputFormatter()],
          validator: validator,
          style: AppTextStyles.displayCurrency.copyWith(
            fontSize: 40,
            height: 1.1,
            color: accent,
          ),
          decoration: InputDecoration(
            hintText: '0',
            hintStyle: AppTextStyles.displayCurrency.copyWith(
              fontSize: 40,
              height: 1.1,
              color: accent.withValues(alpha: 0.28),
            ),
            suffixText: 'đ',
            suffixStyle: AppTextStyles.titleMedium.copyWith(
              color: accent,
              fontWeight: FontWeight.w700,
            ),
            border: InputBorder.none,
            errorStyle: AppTextStyles.labelMedium.copyWith(
              color: AppColors.error,
            ),
            contentPadding: const EdgeInsets.symmetric(vertical: 4),
          ),
        ),
        Container(
          height: 2,
          margin: const EdgeInsets.symmetric(horizontal: 48),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(999),
          ),
        ),
      ],
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: AppTextStyles.labelMedium.copyWith(fontWeight: FontWeight.w600),
    );
  }
}

class _CategoryScroller extends StatelessWidget {
  const _CategoryScroller({
    required this.categories,
    required this.selectedCategory,
    required this.accent,
    required this.onSelected,
  });

  final List<CategoryMeta> categories;
  final String selectedCategory;
  final Color accent;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final category = categories[index];
          final selected = selectedCategory == category.label;
          return Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => onSelected(category.label),
              borderRadius: BorderRadius.circular(999),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: selected
                      ? accent.withValues(alpha: 0.12)
                      : AppColors.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: selected
                        ? accent.withValues(alpha: 0.5)
                        : AppColors.outlineVariant.withValues(alpha: 0.25),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      category.icon,
                      size: 16,
                      color: selected ? accent : AppColors.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      category.label,
                      style: AppTextStyles.labelMedium.copyWith(
                        color: selected ? accent : AppColors.onSurface,
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _DetailCard extends StatelessWidget {
  const _DetailCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.outlineVariant.withValues(alpha: 0.14),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}

class _DateRow extends StatelessWidget {
  const _DateRow({required this.date, required this.onTap});

  final DateTime date;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(
                Icons.calendar_today_outlined,
                size: 18,
                color: AppColors.primary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${formatShortDate(date)}, ${date.day}/${date.month}/${date.year}',
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: AppColors.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SoftInput extends StatelessWidget {
  const _SoftInput({
    required this.controller,
    required this.hint,
    required this.icon,
    this.maxLines = 1,
  });

  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: maxLines > 1
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.center,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(12, maxLines > 1 ? 12 : 0, 6, 0),
            child: Icon(icon, color: AppColors.onSurfaceVariant, size: 20),
          ),
          Expanded(
            child: TextFormField(
              controller: controller,
              maxLines: maxLines,
              style: AppTextStyles.bodyMedium,
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.onSurfaceVariant.withValues(alpha: 0.7),
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 4,
                  vertical: 12,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }
}
