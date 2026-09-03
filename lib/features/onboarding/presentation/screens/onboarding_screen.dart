import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../application/onboarding_providers.dart';

class _Slide {
  const _Slide({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;
}

const _slides = [
  _Slide(
    icon: Icons.flag_rounded,
    title: 'Put your money on your goals',
    body: 'Pick a run, walk, cycle, swim, or weight-loss goal and stake '
        'real rand on hitting it.',
  ),
  _Slide(
    icon: Icons.photo_camera_rounded,
    title: 'Prove it with a quick screenshot',
    body: 'A screenshot of your fitness app or scale is all the proof '
        'you need — captured live, no gallery uploads.',
  ),
  _Slide(
    icon: Icons.local_fire_department_rounded,
    title: 'Keep your streak, keep your cash',
    body: 'Hit your goal and your stake is yours again. Miss it, and it '
        'goes to charity instead.',
  ),
];

/// First-launch-only carousel that explains what Forgo does before
/// handing off to login/signup. Gated behind [OnboardingRepository] so it
/// only ever shows once per install.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    await ref.read(onboardingRepositoryProvider).completeOnboarding();
    if (mounted) context.go('/login');
  }

  void _next() {
    if (_page == _slides.length - 1) {
      _finish();
      return;
    }
    _controller.nextPage(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final isLast = _page == _slides.length - 1;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Row(
                children: [
                  for (var i = 0; i < _slides.length; i++)
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(
                          right: i == _slides.length - 1 ? 0 : 8,
                        ),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          height: 4,
                          decoration: BoxDecoration(
                            color: i <= _page
                                ? AppColors.ink
                                : AppColors.surfaceBorder,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(width: 12),
                  TextButton(
                    onPressed: _finish,
                    child: const Text('Skip'),
                  ),
                ],
              ),
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  itemCount: _slides.length,
                  onPageChanged: (page) => setState(() => _page = page),
                  itemBuilder: (context, index) {
                    final slide = _slides[index];
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 140,
                          height: 140,
                          decoration: const BoxDecoration(
                            color: AppColors.accentDim,
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Icon(
                            slide.icon,
                            size: 64,
                            color: AppColors.accentDeep,
                          ),
                        ),
                        const SizedBox(height: 40),
                        Text(
                          slide.title,
                          textAlign: TextAlign.center,
                          style: textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          slide.body,
                          textAlign: TextAlign.center,
                          style: textTheme.bodyMedium,
                        ),
                      ],
                    );
                  },
                ),
              ),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _next,
                  child: Text(isLast ? 'Get started' : 'Continue'),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
