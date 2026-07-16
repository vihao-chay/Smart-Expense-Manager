import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

class CurrencyConverterScreen extends StatefulWidget {
  const CurrencyConverterScreen({super.key});

  @override
  State<CurrencyConverterScreen> createState() =>
      _CurrencyConverterScreenState();
}

class _CurrencyConverterScreenState extends State<CurrencyConverterScreen> {
  final _amountController = TextEditingController(text: '1000000');

  _CurrencyOption _fromCurrency = _currencies.first;
  _CurrencyOption _toCurrency = _currencies[1];

  double get _amount => double.tryParse(_amountController.text) ?? 0;

  double get _convertedAmount {
    if (_amount <= 0) return 0;
    final amountInVnd = _amount * _fromCurrency.vndRate;
    return amountInVnd / _toCurrency.vndRate;
  }

  String get _rateText {
    final rate = _fromCurrency.vndRate / _toCurrency.vndRate;
    return '1 ${_fromCurrency.code} = ${_formatAmount(rate, _toCurrency)} ${_toCurrency.code}';
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  void _swapCurrencies() {
    setState(() {
      final oldFrom = _fromCurrency;
      _fromCurrency = _toCurrency;
      _toCurrency = oldFrom;
    });
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
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                Text(
                  'Chuyển đổi tiền',
                  style: AppTextStyles.headlineLarge.copyWith(
                    color: AppColors.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Quy đổi nhanh giữa các loại tiền tệ phổ biến',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 24),
                _ConverterCard(
                  amountController: _amountController,
                  fromCurrency: _fromCurrency,
                  toCurrency: _toCurrency,
                  convertedAmount: _convertedAmount,
                  rateText: _rateText,
                  onAmountChanged: () => setState(() {}),
                  onFromChanged: (currency) {
                    if (currency == null) return;
                    setState(() {
                      _fromCurrency = currency;
                    });
                  },
                  onToChanged: (currency) {
                    if (currency == null) return;
                    setState(() {
                      _toCurrency = currency;
                    });
                  },
                  onSwap: _swapCurrencies,
                ),
                const SizedBox(height: 24),
                const _RateInfoCard(),
                const SizedBox(height: 16),
                _PopularRatesCard(baseCurrency: _fromCurrency),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface.withValues(alpha: 0.92),
            border: Border(
              top: BorderSide(
                color: AppColors.outlineVariant.withValues(alpha: 0.30),
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withValues(alpha: 0.05),
                blurRadius: 12,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: SizedBox(
            height: 54,
            child: FilledButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Tỷ giá hiện đang dùng dữ liệu mẫu. Exchange Rate API sẽ được kết nối sau.',
                    ),
                  ),
                );
              },
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.onPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                textStyle: AppTextStyles.titleMedium,
              ),
              icon: const Icon(Icons.sync_rounded),
              label: const Text('Cập nhật tỷ giá'),
            ),
          ),
        ),
      ),
    );
  }
}

class _ConverterCard extends StatelessWidget {
  const _ConverterCard({
    required this.amountController,
    required this.fromCurrency,
    required this.toCurrency,
    required this.convertedAmount,
    required this.rateText,
    required this.onAmountChanged,
    required this.onFromChanged,
    required this.onToChanged,
    required this.onSwap,
  });

  final TextEditingController amountController;
  final _CurrencyOption fromCurrency;
  final _CurrencyOption toCurrency;
  final double convertedAmount;
  final String rateText;
  final VoidCallback onAmountChanged;
  final ValueChanged<_CurrencyOption?> onFromChanged;
  final ValueChanged<_CurrencyOption?> onToChanged;
  final VoidCallback onSwap;

  @override
  Widget build(BuildContext context) {
    return _SoftCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _CurrencyInputRow(
            label: 'Bạn có',
            controller: amountController,
            selectedCurrency: fromCurrency,
            onCurrencyChanged: onFromChanged,
            onAmountChanged: onAmountChanged,
          ),
          const SizedBox(height: 12),
          Center(
            child: IconButton.filled(
              tooltip: 'Đổi chiều quy đổi',
              onPressed: onSwap,
              style: IconButton.styleFrom(
                backgroundColor: AppColors.primaryContainer,
                foregroundColor: AppColors.onPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.swap_vert_rounded),
            ),
          ),
          const SizedBox(height: 12),
          _CurrencyResultRow(
            label: 'Bạn nhận',
            amount: convertedAmount,
            selectedCurrency: toCurrency,
            onCurrencyChanged: onToChanged,
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  size: 18,
                  color: AppColors.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    rateText,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
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

class _CurrencyInputRow extends StatelessWidget {
  const _CurrencyInputRow({
    required this.label,
    required this.controller,
    required this.selectedCurrency,
    required this.onCurrencyChanged,
    required this.onAmountChanged,
  });

  final String label;
  final TextEditingController controller;
  final _CurrencyOption selectedCurrency;
  final ValueChanged<_CurrencyOption?> onCurrencyChanged;
  final VoidCallback onAmountChanged;

  @override
  Widget build(BuildContext context) {
    return _CurrencyShell(
      label: label,
      currency: selectedCurrency,
      onCurrencyChanged: onCurrencyChanged,
      child: TextField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
        onChanged: (_) => onAmountChanged(),
        style: AppTextStyles.headlineLarge.copyWith(color: AppColors.primary),
        decoration: InputDecoration(
          hintText: '0',
          hintStyle: AppTextStyles.headlineLarge.copyWith(
            color: AppColors.outlineVariant,
          ),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: EdgeInsets.zero,
        ),
      ),
    );
  }
}

class _CurrencyResultRow extends StatelessWidget {
  const _CurrencyResultRow({
    required this.label,
    required this.amount,
    required this.selectedCurrency,
    required this.onCurrencyChanged,
  });

  final String label;
  final double amount;
  final _CurrencyOption selectedCurrency;
  final ValueChanged<_CurrencyOption?> onCurrencyChanged;

  @override
  Widget build(BuildContext context) {
    return _CurrencyShell(
      label: label,
      currency: selectedCurrency,
      onCurrencyChanged: onCurrencyChanged,
      child: Text(
        _formatAmount(amount, selectedCurrency),
        overflow: TextOverflow.ellipsis,
        style: AppTextStyles.headlineLarge.copyWith(color: AppColors.onSurface),
      ),
    );
  }
}

class _CurrencyShell extends StatelessWidget {
  const _CurrencyShell({
    required this.label,
    required this.child,
    required this.currency,
    required this.onCurrencyChanged,
  });

  final String label;
  final Widget child;
  final _CurrencyOption currency;
  final ValueChanged<_CurrencyOption?> onCurrencyChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.outlineVariant.withValues(alpha: 0.45),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTextStyles.labelMedium.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: child),
              const SizedBox(width: 12),
              _CurrencyDropdown(value: currency, onChanged: onCurrencyChanged),
            ],
          ),
        ],
      ),
    );
  }
}

class _CurrencyDropdown extends StatelessWidget {
  const _CurrencyDropdown({required this.value, required this.onChanged});

  final _CurrencyOption value;
  final ValueChanged<_CurrencyOption?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(999),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<_CurrencyOption>(
          value: value,
          borderRadius: BorderRadius.circular(12),
          icon: const Icon(Icons.keyboard_arrow_down_rounded),
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.onSurface,
            fontWeight: FontWeight.w600,
          ),
          items: _currencies.map((currency) {
            return DropdownMenuItem(
              value: currency,
              child: Text(currency.code),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _RateInfoCard extends StatelessWidget {
  const _RateInfoCard();

  @override
  Widget build(BuildContext context) {
    return _SoftCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(
              color: AppColors.secondaryContainer,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.currency_exchange_rounded,
              color: AppColors.onSecondaryContainer,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tỷ giá mẫu',
                  style: AppTextStyles.titleMedium.copyWith(
                    color: AppColors.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Màn này sẽ là nơi kết nối Exchange Rate API cho yêu cầu REST API của dự án.',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.onSurfaceVariant,
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

class _PopularRatesCard extends StatelessWidget {
  const _PopularRatesCard({required this.baseCurrency});

  final _CurrencyOption baseCurrency;

  @override
  Widget build(BuildContext context) {
    final rates = _currencies.where((item) => item != baseCurrency).take(4);

    return _SoftCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tỷ giá phổ biến',
            style: AppTextStyles.titleMedium.copyWith(
              color: AppColors.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          for (final currency in rates)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${baseCurrency.code} → ${currency.code}',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.onSurface,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Text(
                    _formatAmount(
                      baseCurrency.vndRate / currency.vndRate,
                      currency,
                    ),
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.primary,
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

class _SoftCard extends StatelessWidget {
  const _SoftCard({
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.outlineVariant.withValues(alpha: 0.20),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _CurrencyOption {
  const _CurrencyOption({
    required this.code,
    required this.name,
    required this.vndRate,
    required this.decimals,
  });

  final String code;
  final String name;
  final double vndRate;
  final int decimals;
}

const _currencies = [
  _CurrencyOption(code: 'VND', name: 'Vietnam Dong', vndRate: 1, decimals: 0),
  _CurrencyOption(code: 'USD', name: 'US Dollar', vndRate: 26000, decimals: 2),
  _CurrencyOption(code: 'EUR', name: 'Euro', vndRate: 30000, decimals: 2),
  _CurrencyOption(code: 'JPY', name: 'Japanese Yen', vndRate: 180, decimals: 0),
  _CurrencyOption(code: 'KRW', name: 'Korean Won', vndRate: 19, decimals: 0),
  _CurrencyOption(
    code: 'CNY',
    name: 'Chinese Yuan',
    vndRate: 3600,
    decimals: 2,
  ),
];

String _formatAmount(double amount, _CurrencyOption currency) {
  if (amount.isNaN || amount.isInfinite) return '0';
  final fixed = amount.toStringAsFixed(currency.decimals);
  final parts = fixed.split('.');
  final whole = parts.first;
  final buffer = StringBuffer();

  for (var i = 0; i < whole.length; i++) {
    final reverseIndex = whole.length - i;
    buffer.write(whole[i]);
    if (reverseIndex > 1 && reverseIndex % 3 == 1) {
      buffer.write('.');
    }
  }

  if (currency.decimals == 0) {
    return buffer.toString();
  }
  return '${buffer.toString()},${parts.last}';
}
