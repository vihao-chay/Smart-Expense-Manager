import 'package:flutter/material.dart';

import '../../app/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/theme_controller.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/firestore_repository.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _loadingController;
  final _authRepository = AuthRepository();
  final _firestoreRepository = FirestoreRepository();

  @override
  void initState() {
    super.initState();
    _loadingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
    _openInitialRoute();
  }

  Future<void> _openInitialRoute() async {
    await Future<void>.delayed(const Duration(milliseconds: 1800));
    if (!mounted) return;

    final user = _authRepository.currentUser;
    if (user == null) {
      Navigator.of(context).pushReplacementNamed(AppRoutes.login);
      return;
    }

    try {
      final profile = await _firestoreRepository.fetchProfile();
      try {
        final settings = await _firestoreRepository.fetchSettings();
        ThemeController.instance.applyFirestoreValue(settings.themeMode);
        await _firestoreRepository.createDailyReminderIfNeeded(settings);
      } catch (_) {
        // Theme loading should not block app startup.
      }
      if (!mounted) return;

      if (profile?.isLocked == true) {
        await _authRepository.signOut();
        if (!mounted) return;
        Navigator.of(context).pushReplacementNamed(AppRoutes.login);
        return;
      }

      final route = profile != null && !profile.hasCompletedOnboarding
          ? AppRoutes.onboarding
          : AppRoutes.home;
      Navigator.of(context).pushReplacementNamed(route);
    } catch (_) {
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed(AppRoutes.home);
    }
  }

  @override
  void dispose() {
    _loadingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(child: ColoredBox(color: AppColors.surfaceBright)),
          const _BackgroundGlow(),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  const Expanded(child: Center(child: _SplashBrand())),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 32),
                    child: _LoadingDots(controller: _loadingController),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BackgroundGlow extends StatelessWidget {
  const _BackgroundGlow();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Center(
        child: Container(
          width: 256,
          height: 256,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.primaryFixed.withValues(alpha: 0.12),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryFixed.withValues(alpha: 0.20),
                blurRadius: 80,
                spreadRadius: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SplashBrand extends StatelessWidget {
  const _SplashBrand();

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeOut,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - value)),
            child: child,
          ),
        );
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _AppLogo(),
          const SizedBox(height: 24),
          Text(
            'Smart Expense Manager',
            textAlign: TextAlign.center,
            style: AppTextStyles.headlineLargeMobile.copyWith(
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 280),
            child: Text(
              'Quản lý thông minh, chi tiêu chủ động',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.onSurfaceVariant.withValues(alpha: 0.80),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AppLogo extends StatelessWidget {
  const _AppLogo();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 104,
      height: 104,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              color: AppColors.primaryContainer,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.18),
                  blurRadius: 18,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Icon(
              Icons.account_balance_wallet_rounded,
              size: 48,
              color: AppColors.onPrimaryContainer,
            ),
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.secondaryContainer,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.16),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Icon(
                Icons.show_chart_rounded,
                size: 24,
                color: AppColors.onSecondaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingDots extends StatelessWidget {
  const _LoadingDots({required this.controller});

  final AnimationController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (index) {
            return Padding(
              padding: EdgeInsets.only(right: index == 2 ? 0 : 8),
              child: Transform.scale(
                scale: _dotScale(index),
                child: Opacity(
                  opacity: const [1.0, 0.7, 0.4][index],
                  child: const _Dot(),
                ),
              ),
            );
          }),
        );
      },
    );
  }

  double _dotScale(int index) {
    final phaseOffsets = const [0.23, 0.11, 0.0];
    final phase = (controller.value + phaseOffsets[index]) % 1;

    if (phase <= 0.4) {
      return Curves.easeOut.transform(phase / 0.4);
    }
    if (phase <= 0.8) {
      return Curves.easeIn.transform(1 - ((phase - 0.4) / 0.4));
    }
    return 0;
  }
}

class _Dot extends StatelessWidget {
  const _Dot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        color: AppColors.primary,
        shape: BoxShape.circle,
      ),
    );
  }
}
