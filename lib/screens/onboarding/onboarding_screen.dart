import 'package:flutter/material.dart';

import '../../app/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../data/repositories/firestore_repository.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageController = PageController();
  final _firestoreRepository = FirestoreRepository();
  var _currentPage = 0;
  var _isFinishing = false;

  static const _slides = [
    _OnboardingSlideData(
      imageUrl:
          'https://lh3.googleusercontent.com/aida-public/AB6AXuA7WOpbl9UNROt2TBLGL-KHfHLOXG1YGkVAN_Zg_3bNf0wTrNr5Ux9FV8ufebJGpDHVoB3Of9Lhsvn0EDnznRdZumQxhn7GClFo1mQ1mJf58NfG-I2vOLDgCiFiD1YIBULhuljcSgpAO9yXLZ2gyIvJUQPT8_-Y3Q-U5m7wiAR9p2A9vGzl5e2sMSyyBN9GiOqeI6dwG5Qr_03u4hIN1Hgoxowysx4Q5ijrNSK2w7euGKz3AzeRsQ',
      title: 'Theo dõi mọi khoản chi',
      description: 'Ghi lại thu nhập và chi tiêu một cách nhanh chóng',
    ),
    _OnboardingSlideData(
      imageUrl:
          'https://lh3.googleusercontent.com/aida-public/AB6AXuA-K92Tnaj6IWtYBjIx4sSorI0gfpg5fOrRGfMiXPYltIe8Pe_cEQ-DTMPL0fMZutuVrKsY9BSc2DXukvM8aIFFZ2m88q2DcT9BwUD6asn8W5w5Ivd2laipT2s9aXoUmjPPiMEcbZAMLuycCcihDBzqqtSneZ_g_Nkhod0rB-ttGzl-J4wC33hHP-O6CwqyZDpV8hamAvzI2Dq0ch1ISrO1DdHIlSIYRaBbJKj3R7sj5QiAWeBeoA',
      title: 'Hiểu rõ tài chính của bạn',
      description: 'Theo dõi báo cáo và biểu đồ chi tiêu theo từng danh mục',
    ),
    _OnboardingSlideData(
      imageUrl:
          'https://lh3.googleusercontent.com/aida-public/AB6AXuCjWtPaQu8TH5A8NIcPMlG4au0PoPpLhGPFfBg0jr4ThwZXKhUR-R1KZmjKZtK2W9weNJK0lzwN4hOy_2ZfpEI4orKlfH3NUax2ZALT70CgE7Un1quiVmuALZAcEy18d8gPJdGz9q4YB5sLL4xt5p8sGcbQ718kyxub2dHfAdrmBrk7P-S7ydM4TS2zqqxWocMNR-mHX-UbJp7bhq_HkF4qDRcaSmhoFohm2vEvRWBh7PlamlVAzQ',
      title: 'Xây dựng thói quen tốt hơn',
      description: 'Đặt ngân sách và nhận các gợi ý tài chính thông minh',
    ),
  ];

  bool get _isLastPage => _currentPage == _slides.length - 1;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goToPage(int page) {
    _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOut,
    );
  }

  void _next() {
    if (_isLastPage) {
      _finishOnboarding();
      return;
    }

    _goToPage(_currentPage + 1);
  }

  void _skip() {
    _goToPage(_slides.length - 1);
  }

  Future<void> _finishOnboarding() async {
    if (_isFinishing) return;
    setState(() {
      _isFinishing = true;
    });

    try {
      await _firestoreRepository.markOnboardingCompleted();
    } catch (_) {
      // Direct preview routes may not have a signed-in user yet.
    }

    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed(AppRoutes.home);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Stack(
              children: [
                Column(
                  children: [
                    Expanded(
                      child: PageView.builder(
                        controller: _pageController,
                        itemCount: _slides.length,
                        onPageChanged: (page) {
                          setState(() {
                            _currentPage = page;
                          });
                        },
                        itemBuilder: (context, index) {
                          return _OnboardingSlide(slide: _slides[index]);
                        },
                      ),
                    ),
                    _OnboardingControls(
                      currentPage: _currentPage,
                      pageCount: _slides.length,
                      isLastPage: _isLastPage,
                      isFinishing: _isFinishing,
                      onNext: _next,
                    ),
                  ],
                ),
                Positioned(
                  top: 8,
                  right: 16,
                  child: AnimatedOpacity(
                    opacity: _isLastPage ? 0 : 1,
                    duration: const Duration(milliseconds: 200),
                    child: IgnorePointer(
                      ignoring: _isLastPage,
                      child: TextButton(
                        onPressed: _skip,
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          shape: const StadiumBorder(),
                          textStyle: AppTextStyles.labelMedium.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        child: const Text('Skip'),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OnboardingSlide extends StatelessWidget {
  const _OnboardingSlide({required this.slide});

  final _OnboardingSlideData slide;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(32, 64, 32, 24),
            child: Center(
              child: Image.network(
                slide.imageUrl,
                fit: BoxFit.contain,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) {
                    return child;
                  }

                  return const _IllustrationPlaceholder();
                },
                errorBuilder: (context, error, stackTrace) {
                  return const _IllustrationPlaceholder();
                },
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
          child: Column(
            children: [
              Text(
                slide.title,
                textAlign: TextAlign.center,
                style: AppTextStyles.headlineLargeMobile.copyWith(
                  color: AppColors.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 280),
                child: Text(
                  slide.description,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _OnboardingControls extends StatelessWidget {
  const _OnboardingControls({
    required this.currentPage,
    required this.pageCount,
    required this.isLastPage,
    required this.isFinishing,
    required this.onNext,
  });

  final int currentPage;
  final int pageCount;
  final bool isLastPage;
  final bool isFinishing;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(pageCount, (index) {
              return _PageIndicator(isActive: currentPage == index);
            }),
          ),
          const SizedBox(height: 32),
          SizedBox(
            height: 48,
            child: FilledButton(
              onPressed: isFinishing ? null : onNext,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primaryContainer,
                foregroundColor: AppColors.onPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                textStyle: AppTextStyles.titleMedium,
                elevation: 2,
              ),
              child: isFinishing
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.onPrimary,
                      ),
                    )
                  : Text(isLastPage ? 'Bắt đầu' : 'Tiếp tục'),
            ),
          ),
        ],
      ),
    );
  }
}

class _PageIndicator extends StatelessWidget {
  const _PageIndicator({required this.isActive});

  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOut,
      width: isActive ? 32 : 8,
      height: 8,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: isActive ? AppColors.primary : AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }
}

class _IllustrationPlaceholder extends StatelessWidget {
  const _IllustrationPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxHeight: 280),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
      ),
      child: const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
    );
  }
}

class _OnboardingSlideData {
  const _OnboardingSlideData({
    required this.imageUrl,
    required this.title,
    required this.description,
  });

  final String imageUrl;
  final String title;
  final String description;
}
