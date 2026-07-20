import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
  final _repository = FirestoreRepository();

  var _type = AppTransactionType.expense;
  var _selectedDate = DateTime.now();
  var _selectedCategory = expenseCategories.first.label;
  var _didReadArgs = false;
  var _isSaving = false;

  List<CategoryMeta> get _categories => categoriesForType(_type);

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
        amount: int.parse(_amountController.text),
        category: _selectedCategory,
        transactionDate: _selectedDate,
        title: title,
        note: _noteController.text.trim(),
        paymentMethod: _type == AppTransactionType.income
            ? 'Chuyển khoản'
            : 'Ví cá nhân',
      );

      await _repository.addTransaction(transaction);
      await _repository.addNotification(
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
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
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
            color: AppColors.primary,
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            height: 52,
            child: FilledButton(
              onPressed: _isSaving ? null : _save,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.onPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isSaving
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
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
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                children: [
                  _TypeSegment(type: _type, onChanged: _setType),
                  const SizedBox(height: 20),
                  _TextFieldCard(
                    controller: _amountController,
                    label: 'Số tiền',
                    hint: '0',
                    icon: Icons.payments_outlined,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: (value) {
                      final amount = int.tryParse(value ?? '') ?? 0;
                      if (amount <= 0) return 'Vui lòng nhập số tiền hợp lệ';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  _TextFieldCard(
                    controller: _titleController,
                    label: 'Tên giao dịch',
                    hint: 'Ví dụ: Ăn trưa, Lương tháng này',
                    icon: Icons.edit_note_rounded,
                  ),
                  const SizedBox(height: 20),
                  _CategoryPicker(
                    categories: _categories,
                    selectedCategory: _selectedCategory,
                    onSelected: (value) {
                      setState(() => _selectedCategory = value);
                    },
                  ),
                  const SizedBox(height: 12),
                  _DateCard(date: _selectedDate, onTap: _pickDate),
                  const SizedBox(height: 12),
                  _TextFieldCard(
                    controller: _noteController,
                    label: 'Ghi chú',
                    hint: 'Ghi chú thêm...',
                    icon: Icons.notes_rounded,
                    maxLines: 3,
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
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _TypeButton(
            label: 'Chi tiêu',
            selected: type == AppTransactionType.expense,
            onTap: () => onChanged(AppTransactionType.expense),
          ),
          _TypeButton(
            label: 'Thu nhập',
            selected: type == AppTransactionType.income,
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
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
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

class _CategoryPicker extends StatelessWidget {
  const _CategoryPicker({
    required this.categories,
    required this.selectedCategory,
    required this.onSelected,
  });

  final List<CategoryMeta> categories;
  final String selectedCategory;
  final ValueChanged<String> onSelected;

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
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final category in categories)
              ChoiceChip(
                selected: selectedCategory == category.label,
                label: Text(category.label),
                avatar: Icon(category.icon, size: 18),
                onSelected: (_) => onSelected(category.label),
              ),
          ],
        ),
      ],
    );
  }
}

class _DateCard extends StatelessWidget {
  const _DateCard({required this.date, required this.onTap});

  final DateTime date;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _InputCard(
      icon: Icons.calendar_today_outlined,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 15),
          child: Text(
            '${formatShortDate(date)}, ${date.day}/${date.month}/${date.year}',
            style: AppTextStyles.bodyLarge,
          ),
        ),
      ),
    );
  }
}

class _TextFieldCard extends StatelessWidget {
  const _TextFieldCard({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.keyboardType,
    this.inputFormatters,
    this.validator,
    this.maxLines = 1,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final String? Function(String?)? validator;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTextStyles.labelMedium.copyWith(
            color: AppColors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        _InputCard(
          icon: icon,
          alignTop: maxLines > 1,
          child: TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            inputFormatters: inputFormatters,
            validator: validator,
            maxLines: maxLines,
            decoration: InputDecoration(
              hintText: hint,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 15),
            ),
          ),
        ),
      ],
    );
  }
}

class _InputCard extends StatelessWidget {
  const _InputCard({
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
        border: Border.all(
          color: AppColors.outlineVariant.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        crossAxisAlignment: alignTop
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.center,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(16, alignTop ? 14 : 0, 12, 0),
            child: Icon(icon, color: AppColors.onSurfaceVariant),
          ),
          Expanded(child: child),
          const SizedBox(width: 16),
        ],
      ),
    );
  }
}
