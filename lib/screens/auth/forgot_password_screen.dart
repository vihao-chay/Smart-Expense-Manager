import 'package:flutter/material.dart';

import '../../app/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();

  var _linkSent = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  void _goBackToLogin() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
      return;
    }

    Navigator.of(context).pushReplacementNamed(AppRoutes.login);
  }

  void _sendResetLink() {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _linkSent = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final showCard = constraints.maxWidth >= 720;

            return Column(
              children: [
                if (!showCard) _MobileHeader(onBackPressed: _goBackToLogin),
                Expanded(
                  child: SingleChildScrollView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: EdgeInsets.fromLTRB(
                      16,
                      showCard ? 32 : 16,
                      16,
                      24 + MediaQuery.viewInsetsOf(context).bottom,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 420),
                        child: _ForgotPasswordCard(
                          showCard: showCard,
                          linkSent: _linkSent,
                          formKey: _formKey,
                          emailController: _emailController,
                          onBackPressed: _goBackToLogin,
                          onSubmit: _sendResetLink,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _MobileHeader extends StatelessWidget {
  const _MobileHeader({required this.onBackPressed});

  final VoidCallback onBackPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 64,
      child: Row(
        children: [
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'Quay lại',
            onPressed: onBackPressed,
            icon: const Icon(Icons.arrow_back_rounded),
            color: AppColors.onSurfaceVariant,
          ),
        ],
      ),
    );
  }
}

class _ForgotPasswordCard extends StatelessWidget {
  const _ForgotPasswordCard({
    required this.showCard,
    required this.linkSent,
    required this.formKey,
    required this.emailController,
    required this.onBackPressed,
    required this.onSubmit,
  });

  final bool showCard;
  final bool linkSent;
  final GlobalKey<FormState> formKey;
  final TextEditingController emailController;
  final VoidCallback onBackPressed;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showCard) ...[
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: onBackPressed,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.onSurfaceVariant,
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 32),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                textStyle: AppTextStyles.labelMedium,
              ),
              icon: const Icon(Icons.arrow_back_rounded, size: 18),
              label: const Text('Quay lại'),
            ),
          ),
          const SizedBox(height: 24),
        ],
        if (linkSent)
          _SuccessState(onBackPressed: onBackPressed)
        else
          _DefaultState(
            formKey: formKey,
            emailController: emailController,
            onSubmit: onSubmit,
          ),
      ],
    );

    if (!showCard) {
      return content;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: content,
    );
  }
}

class _DefaultState extends StatelessWidget {
  const _DefaultState({
    required this.formKey,
    required this.emailController,
    required this.onSubmit,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController emailController;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Quên mật khẩu',
            style: AppTextStyles.headlineLargeMobile.copyWith(
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Nhập email của bạn để nhận liên kết khôi phục mật khẩu.',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 32),
          _EmailField(controller: emailController),
          const SizedBox(height: 32),
          SizedBox(
            height: 48,
            child: FilledButton(
              onPressed: onSubmit,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primaryContainer,
                foregroundColor: AppColors.onPrimaryContainer,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                textStyle: AppTextStyles.titleMedium,
              ),
              child: const Text('Gửi liên kết khôi phục'),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmailField extends StatelessWidget {
  const _EmailField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Email',
          style: AppTextStyles.labelMedium.copyWith(color: AppColors.onSurface),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          autofillHints: const [AutofillHints.email],
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.done,
          style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onSurface),
          decoration: InputDecoration(
            hintText: 'nhapemail@vidu.com',
            hintStyle: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.outline,
            ),
            prefixIcon: const Icon(Icons.mail_outline_rounded),
            prefixIconColor: AppColors.onSurfaceVariant,
            filled: true,
            fillColor: AppColors.surfaceContainerLowest,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.outlineVariant),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.outlineVariant),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.primary),
            ),
          ),
          validator: (value) {
            final email = value?.trim() ?? '';
            final emailPattern = RegExp(r'^[\w\-.]+@([\w-]+\.)+[\w-]{2,}$');
            if (email.isEmpty) {
              return 'Vui lòng nhập email';
            }
            if (!emailPattern.hasMatch(email)) {
              return 'Email không hợp lệ';
            }
            return null;
          },
          onFieldSubmitted: (_) {
            final form = Form.maybeOf(context);
            if (form?.validate() ?? false) {
              FocusScope.of(context).unfocus();
            }
          },
        ),
      ],
    );
  }
}

class _SuccessState extends StatelessWidget {
  const _SuccessState({required this.onBackPressed});

  final VoidCallback onBackPressed;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        Center(
          child: Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(
              color: AppColors.secondaryContainer,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle_outline_rounded,
              color: AppColors.onSecondaryContainer,
              size: 36,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Đã gửi liên kết!',
          textAlign: TextAlign.center,
          style: AppTextStyles.titleMedium.copyWith(color: AppColors.onSurface),
        ),
        const SizedBox(height: 16),
        Text(
          'Vui lòng kiểm tra hộp thư đến của bạn để biết hướng dẫn khôi phục mật khẩu.',
          textAlign: TextAlign.center,
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 32),
        SizedBox(
          height: 48,
          child: OutlinedButton(
            onPressed: onBackPressed,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primaryContainer,
              side: const BorderSide(color: AppColors.primaryContainer),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              textStyle: AppTextStyles.titleMedium,
            ),
            child: const Text('Quay lại đăng nhập'),
          ),
        ),
      ],
    );
  }
}
