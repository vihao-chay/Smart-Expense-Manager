import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/app_formatters.dart';
import '../../data/services/exchange_rate_service.dart';

class CurrencyConverterScreen extends StatefulWidget {
  const CurrencyConverterScreen({super.key});

  @override
  State<CurrencyConverterScreen> createState() =>
      _CurrencyConverterScreenState();
}

class _CurrencyConverterScreenState extends State<CurrencyConverterScreen> {
  final _amountController = TextEditingController(text: '1');
  final _service = ExchangeRateService();

  var _fromCurrency = 'USD';
  var _toCurrency = 'VND';
  late Future<ExchangeRateResult> _ratesFuture;

  @override
  void initState() {
    super.initState();
    _ratesFuture = _service.latest(_fromCurrency);
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  void _refreshRates() {
    setState(() {
      _ratesFuture = _service.latest(_fromCurrency);
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
        ),
        title: Text(
          'Chuyển đổi tiền',
          style: AppTextStyles.headlineLargeMobile.copyWith(
            color: AppColors.primary,
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: FutureBuilder<ExchangeRateResult>(
              future: _ratesFuture,
              builder: (context, snapshot) {
                final result = snapshot.data;
                final rate = result?.rateFor(_toCurrency);
                final amount = double.tryParse(_amountController.text) ?? 0;
                final converted = rate == null ? null : amount * rate;

                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                  children: [
                    _ConverterCard(
                      amountController: _amountController,
                      fromCurrency: _fromCurrency,
                      toCurrency: _toCurrency,
                      convertedAmount: converted,
                      isLoading:
                          snapshot.connectionState == ConnectionState.waiting,
                      onAmountChanged: () => setState(() {}),
                      onFromChanged: (value) {
                        if (value == null || value == _fromCurrency) return;
                        setState(() {
                          _fromCurrency = value;
                          _ratesFuture = _service.latest(_fromCurrency);
                        });
                      },
                      onToChanged: (value) {
                        if (value == null) return;
                        setState(() => _toCurrency = value);
                      },
                      onSwap: () {
                        setState(() {
                          final oldFrom = _fromCurrency;
                          _fromCurrency = _toCurrency;
                          _toCurrency = oldFrom;
                          _ratesFuture = _service.latest(_fromCurrency);
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    if (snapshot.hasError)
                      _ErrorCard(
                        message:
                            'Không thể lấy tỷ giá. Kiểm tra mạng rồi thử lại.',
                        onRetry: _refreshRates,
                      )
                    else if (result != null) ...[
                      _RateInfoCard(
                        fromCurrency: _fromCurrency,
                        toCurrency: _toCurrency,
                        rate: rate,
                        updatedAt: result.updatedAt,
                      ),
                      const SizedBox(height: 16),
                      _PopularRatesCard(result: result, base: _fromCurrency),
                    ],
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

class _ConverterCard extends StatelessWidget {
  const _ConverterCard({
    required this.amountController,
    required this.fromCurrency,
    required this.toCurrency,
    required this.convertedAmount,
    required this.isLoading,
    required this.onAmountChanged,
    required this.onFromChanged,
    required this.onToChanged,
    required this.onSwap,
  });

  final TextEditingController amountController;
  final String fromCurrency;
  final String toCurrency;
  final double? convertedAmount;
  final bool isLoading;
  final VoidCallback onAmountChanged;
  final ValueChanged<String?> onFromChanged;
  final ValueChanged<String?> onToChanged;
  final VoidCallback onSwap;

  @override
  Widget build(BuildContext context) {
    return _SoftCard(
      child: Column(
        children: [
          _CurrencyInputRow(
            label: 'Bạn có',
            controller: amountController,
            currency: fromCurrency,
            onCurrencyChanged: onFromChanged,
            onChanged: onAmountChanged,
          ),
          IconButton(
            tooltip: 'Đổi chiều',
            onPressed: onSwap,
            icon: const Icon(Icons.swap_vert_rounded),
          ),
          _CurrencyResultRow(
            label: 'Bạn nhận',
            amount: convertedAmount,
            currency: toCurrency,
            isLoading: isLoading,
            onCurrencyChanged: onToChanged,
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
    required this.currency,
    required this.onCurrencyChanged,
    required this.onChanged,
  });

  final String label;
  final TextEditingController controller;
  final String currency;
  final ValueChanged<String?> onCurrencyChanged;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return _CurrencyShell(
      label: label,
      currency: currency,
      onCurrencyChanged: onCurrencyChanged,
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
        onChanged: (_) => onChanged(),
        style: AppTextStyles.headlineLarge,
        decoration: const InputDecoration(
          border: InputBorder.none,
          hintText: '0',
        ),
      ),
    );
  }
}

class _CurrencyResultRow extends StatelessWidget {
  const _CurrencyResultRow({
    required this.label,
    required this.amount,
    required this.currency,
    required this.isLoading,
    required this.onCurrencyChanged,
  });

  final String label;
  final double? amount;
  final String currency;
  final bool isLoading;
  final ValueChanged<String?> onCurrencyChanged;

  @override
  Widget build(BuildContext context) {
    return _CurrencyShell(
      label: label,
      currency: currency,
      onCurrencyChanged: onCurrencyChanged,
      child: isLoading
          ? const LinearProgressIndicator()
          : Text(
              amount == null ? '--' : _formatCurrencyAmount(amount!, currency),
              style: AppTextStyles.headlineLarge.copyWith(
                color: AppColors.primary,
              ),
            ),
    );
  }
}

class _CurrencyShell extends StatelessWidget {
  const _CurrencyShell({
    required this.label,
    required this.currency,
    required this.onCurrencyChanged,
    required this.child,
  });

  final String label;
  final String currency;
  final ValueChanged<String?> onCurrencyChanged;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppTextStyles.labelMedium),
                child,
              ],
            ),
          ),
          const SizedBox(width: 12),
          DropdownButton<String>(
            value: currency,
            items: _currencies.map((item) {
              return DropdownMenuItem(value: item, child: Text(item));
            }).toList(),
            onChanged: onCurrencyChanged,
          ),
        ],
      ),
    );
  }
}

class _RateInfoCard extends StatelessWidget {
  const _RateInfoCard({
    required this.fromCurrency,
    required this.toCurrency,
    required this.rate,
    required this.updatedAt,
  });

  final String fromCurrency;
  final String toCurrency;
  final double? rate;
  final DateTime updatedAt;

  @override
  Widget build(BuildContext context) {
    return _SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Tỷ giá hiện tại', style: AppTextStyles.titleMedium),
          const SizedBox(height: 8),
          Text(
            rate == null
                ? 'Không có tỷ giá cho $toCurrency'
                : '1 $fromCurrency = ${_formatCurrencyAmount(rate!, toCurrency)}',
            style: AppTextStyles.bodyLarge,
          ),
          const SizedBox(height: 4),
          Text(
            'Cập nhật: ${formatDateTime(updatedAt)} • ExchangeRate-API',
            style: AppTextStyles.labelMedium,
          ),
        ],
      ),
    );
  }
}

class _PopularRatesCard extends StatelessWidget {
  const _PopularRatesCard({required this.result, required this.base});

  final ExchangeRateResult result;
  final String base;

  @override
  Widget build(BuildContext context) {
    final codes = _currencies.where((item) => item != base).take(5);
    return _SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Tỷ giá phổ biến', style: AppTextStyles.titleMedium),
          const SizedBox(height: 8),
          for (final code in codes)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('$base → $code'),
              trailing: Text(
                result.rateFor(code) == null
                    ? '--'
                    : _formatCurrencyAmount(result.rateFor(code)!, code),
              ),
            ),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return _SoftCard(
      child: Column(
        children: [
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Thử lại'),
          ),
        ],
      ),
    );
  }
}

class _SoftCard extends StatelessWidget {
  const _SoftCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.outlineVariant.withValues(alpha: 0.20),
        ),
      ),
      child: child,
    );
  }
}

String _formatCurrencyAmount(double amount, String currency) {
  if (currency == 'VND') return formatVnd(amount);
  final decimals = currency == 'JPY' || currency == 'KRW' ? 0 : 2;
  return '${amount.toStringAsFixed(decimals)} $currency';
}

const _currencies = ['VND', 'USD', 'EUR', 'JPY', 'KRW', 'GBP', 'AUD', 'SGD'];
