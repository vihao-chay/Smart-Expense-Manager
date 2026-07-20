import 'dart:convert';

import 'package:http/http.dart' as http;

class ExchangeRateResult {
  const ExchangeRateResult({
    required this.baseCode,
    required this.rates,
    required this.updatedAt,
  });

  final String baseCode;
  final Map<String, double> rates;
  final DateTime updatedAt;

  double? rateFor(String code) => rates[code.toUpperCase()];
}

class ExchangeRateService {
  ExchangeRateService({http.Client? client})
    : _client = client ?? http.Client();

  final http.Client _client;

  Future<ExchangeRateResult> latest(String baseCode) async {
    final code = baseCode.toUpperCase();
    final uri = Uri.https('open.er-api.com', '/v6/latest/$code');
    final response = await _client
        .get(uri)
        .timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      throw Exception('Exchange Rate API trả về mã ${response.statusCode}.');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (data['result'] != 'success') {
      throw Exception(data['error-type'] ?? 'Không thể lấy tỷ giá.');
    }

    final rawRates = data['rates'] as Map<String, dynamic>? ?? {};
    final rates = <String, double>{};
    for (final entry in rawRates.entries) {
      final value = entry.value;
      if (value is num) {
        rates[entry.key.toUpperCase()] = value.toDouble();
      }
    }

    final updatedUnix = data['time_last_update_unix'];
    final updatedAt = updatedUnix is num
        ? DateTime.fromMillisecondsSinceEpoch(
            updatedUnix.toInt() * 1000,
            isUtc: true,
          ).toLocal()
        : DateTime.now();

    return ExchangeRateResult(
      baseCode: code,
      rates: rates,
      updatedAt: updatedAt,
    );
  }
}
