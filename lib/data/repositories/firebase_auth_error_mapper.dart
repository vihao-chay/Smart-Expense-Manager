import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';

String firebaseAuthErrorMessage(Object error) {
  if (error is PlatformException) {
    return switch (error.code) {
      GoogleSignIn.kSignInCanceledError => 'Bạn đã hủy đăng nhập bằng Google.',
      GoogleSignIn.kNetworkError =>
        'Không thể kết nối Google. Vui lòng kiểm tra mạng.',
      GoogleSignIn.kSignInRequiredError =>
        'Bạn cần chọn tài khoản Google để tiếp tục.',
      GoogleSignIn.kSignInFailedError =>
        'Google Sign-In chưa được cấu hình đúng. Hãy kiểm tra Google provider và SHA-1.',
      _ => error.message ?? 'Không thể đăng nhập bằng Google.',
    };
  }

  if (error is FirebaseAuthException) {
    return switch (error.code) {
      'invalid-email' => 'Email không hợp lệ.',
      'user-disabled' => 'Tài khoản này đã bị vô hiệu hóa.',
      'user-not-found' => 'Không tìm thấy tài khoản với email này.',
      'wrong-password' => 'Mật khẩu không chính xác.',
      'invalid-credential' => 'Email hoặc mật khẩu không chính xác.',
      'email-already-in-use' => 'Email này đã được đăng ký.',
      'weak-password' => 'Mật khẩu quá yếu. Vui lòng dùng ít nhất 6 ký tự.',
      'operation-not-allowed' =>
        'Bạn cần bật Email/Password trong Firebase Authentication.',
      'network-request-failed' =>
        'Không thể kết nối Firebase. Vui lòng kiểm tra mạng.',
      'too-many-requests' => 'Bạn thao tác quá nhiều lần. Hãy thử lại sau.',
      'missing-google-id-token' =>
        'Không nhận được thông tin xác thực từ Google.',
      'account-exists-with-different-credential' =>
        'Email này đã được đăng ký bằng phương thức đăng nhập khác.',
      _ => error.message ?? 'Đã có lỗi xảy ra. Vui lòng thử lại.',
    };
  }

  if (error is FirebaseException) {
    return switch (error.code) {
      'permission-denied' =>
        'Firestore đang chặn ghi dữ liệu. Hãy kiểm tra lại Rules.',
      'unavailable' => 'Firebase tạm thời không khả dụng. Hãy thử lại sau.',
      _ => error.message ?? 'Đã có lỗi Firebase xảy ra. Vui lòng thử lại.',
    };
  }

  return switch (error) {
    StateError() => error.message,
    UnsupportedError() => error.message ?? 'Tính năng này chưa được hỗ trợ.',
    _ => 'Đã có lỗi xảy ra. Vui lòng thử lại.',
  };
}
