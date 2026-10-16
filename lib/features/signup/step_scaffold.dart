import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_motion.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/balanced_text.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/reveal.dart';
import '../../core/widgets/segment_progress.dart';
import '../../core/widgets/step_progress.dart';

/// Layout of the signup steps, in the language of the intro and location
/// screens: segment bar with a round back button on top, an optional
/// visual, centered title, content, CTA and an optional skip below it.
class StepScaffold extends StatelessWidget {
  const StepScaffold({
    super.key,
    required this.step,
    required this.title,
    required this.subtitle,
    required this.primaryLabel,
    required this.onPrimary,
    this.hero,
    this.content,
    this.skipLabel,
    this.onSkip,
    this.footer,
    this.centered = false,
    this.backdrop,
    this.primaryIcon = 'assets/icons/arrow_right.svg',
    this.primaryLoading = false,
  });

  /// Current step, 1 to 5. The bar fills this segment on arrival.
  final int step;
  final String title;
  final String subtitle;
  final Widget? content;
  final Widget? hero;
  final String primaryLabel;
  final VoidCallback? onPrimary;
  final String primaryIcon;
  final bool primaryLoading;
  final String? skipLabel;
  final VoidCallback? onSkip;

  /// Custom secondary action under the CTA, instead of a skip link.
  final Widget? footer;

  /// Centers hero and text vertically above the buttons, for screens
  /// whose content is short.
  final bool centered;

  /// Decorative layer drawn behind everything (full screen).
  final Widget? backdrop;

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.paddingOf(context);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: AppColors.white,
        body: LayoutBuilder(
          builder: (context, box) {
            final compact = box.maxHeight < 740;
            final page = Column(
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(16, pad.top + 6, 16, 0),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: step - 2.0, end: step - 1.0),
                    duration: const Duration(milliseconds: 900),
                    curve: AppMotion.smooth,
                    builder: (context, v, _) => SegmentProgress(
                      count: StepProgress.steps,
                      position: v,
                      onBack: () => Navigator.of(context).maybePop(),
                    ),
                  ),
                ),
                Expanded(
                  child: CustomScrollView(
                    slivers: [
                      // Padding inside the fill sliver: a SliverPadding around it
                      // would push the bottom gap below the fold.
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(16, compact ? 16 : 28, 16, AppSpacing.bottom + pad.bottom),
                          child: Column(
                            children: [
                              if (centered) const Spacer(),
                              if (hero != null) ...[
                                Reveal(child: RepaintBoundary(child: hero!)),
                                SizedBox(height: compact ? 20 : 32),
                              ],
                              Reveal(
                                delay: const Duration(milliseconds: 120),
                                child: Column(
                                  children: [
                                    BalancedText(title, style: AppType.display(size: compact ? 26 : 30)),
                                    const SizedBox(height: 8),
                                    BalancedText(subtitle, style: AppType.body(size: compact ? 15 : 16)),
                                  ],
                                ),
                              ),
                              if (content != null) ...[
                                SizedBox(height: compact ? 20 : 28),
                                Reveal(delay: const Duration(milliseconds: 220), child: content!),
                              ],
                              const Spacer(),
                              SizedBox(height: compact ? 16 : 24),
                              PrimaryButton(
                                label: primaryLabel,
                                icon: primaryIcon,
                                loading: primaryLoading,
                                onPressed: onPrimary,
                              ),
                              if (footer != null) ...[const SizedBox(height: 6), footer!],
                              if (skipLabel != null) ...[
                                const SizedBox(height: 6),
                                GhostButton(label: skipLabel!, onPressed: onSkip),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
            if (backdrop == null) return page;
            return Stack(
              children: [
                Positioned.fill(child: RepaintBoundary(child: backdrop!)),
                page,
              ],
            );
          },
        ),
      ),
    );
  }
}
