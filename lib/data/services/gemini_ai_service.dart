import 'package:cloud_functions/cloud_functions.dart';

class GeminiAiService {
  GeminiAiService({FirebaseFunctions? functions})
    : _functions =
          functions ?? FirebaseFunctions.instanceFor(region: _functionRegion);

  static const _functionRegion = 'asia-southeast1';
  static const _functionName = 'generateaiinsights';

  final FirebaseFunctions _functions;

  Future<String> generateExpenseInsights(String prompt) async {
    try {
      final callable = _functions.httpsCallable(
        _functionName,
        options: HttpsCallableOptions(timeout: const Duration(seconds: 60)),
      );
      final result = await callable.call<Map<String, dynamic>>({
        'prompt': prompt,
      });
      final data = result.data;
      final text = data['text'];
      if (text is String && text.trim().isNotEmpty) return text.trim();
      throw const GeminiAiException('Functions chưa trả về nội dung AI.');
    } on FirebaseFunctionsException catch (error) {
      throw GeminiAiException(
        error.message ?? 'Không thể gọi Firebase Functions.',
      );
    } catch (error) {
      if (error is GeminiAiException) rethrow;
      throw GeminiAiException(error.toString());
    }
  }
}

class GeminiAiException implements Exception {
  const GeminiAiException(this.message);

  final String message;

  @override
  String toString() => message;
}
