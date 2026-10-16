import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_motion.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/balanced_text.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/pills.dart';
import '../../core/widgets/reveal.dart';
import '../../core/widgets/step_progress.dart';

/// Layout of screens 10–12: an illustration behind a floating white card
/// with "Voltar" / skip pills, the step progress, title, content and CTA.
class StepCardScaffold extends StatelessWidget {
  const StepCardScaffold({
    super.key,
    required this.background,
    required this.cardTop,
    required this.step,
    required this.title,
    required this.subtitle,
    required this.primaryLabel,
    required this.onPrimary,
    this.content,
    this.skipLabel,
    this.onSkip,
    this.primaryIcon = 'assets/icons/arrow_right.svg',
    this.primaryLoading = false,
  });

  final Widget background;

  /// Card top in the 844pt Figma frame; scaled to the screen height.
  final double cardTop;
  final int step;
  final String title;
  final String subtitle;
  final Widget? content;
  final String primaryLabel;
  final VoidCallback? onPrimary;
  final String primaryIcon;
  final bool primaryLoading;
  final String? skipLabel;
  final VoidCallback? onSkip;

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
            final top = (cardTop / 844 * box.maxHeight).clamp(pad.top + 40, box.maxHeight);
            return Stack(
              children: [
                Positioned.fill(child: background),
                Positioned(
                  top: top,
                  left: 5,
                  right: 5,
                  bottom: 12 + pad.bottom,
                  child: Reveal(
                    offset: 60,
                    duration: AppMotion.page,
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(32),
                        border: Border.all(color: AppColors.sheetBorder),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.cinza900.withValues(alpha: .05),
                            blurRadius: 30,
                            offset: const Offset(0, -6),
                          ),
                        ],
                      ),
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: CustomScrollView(
                              slivers: [
                                SliverPadding(
                                  padding: EdgeInsets.fromLTRB(16, compact ? 64 : 72, 16, 16),
                                  sliver: SliverFillRemaining(
                                    hasScrollBody: false,
                                    child: Column(
                                      children: [
                                        StepProgress(step: step, fromStep: step - 1),
                                        SizedBox(height: compact ? 16 : 24),
                                        Reveal(
                                          delay: const Duration(milliseconds: 160),
                                          child: Column(
                                            children: [
                                              BalancedText(title, style: AppType.title()),
                                              const SizedBox(height: 5),
                                              BalancedText(subtitle, style: AppType.body()),
                                            ],
                                          ),
                                        ),
                                        const Spacer(),
                                        if (content != null) ...[
                                          SizedBox(height: compact ? 16 : 24),
                                          Reveal(delay: const Duration(milliseconds: 260), child: content!),
                                          const Spacer(),
                                        ],
                                        SizedBox(height: compact ? 16 : 24),
                                        PrimaryButton(
                                          label: primaryLabel,
                                          icon: primaryIcon,
                                          loading: primaryLoading,
                                          onPressed: onPrimary,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Positioned(top: 16, left: 16, child: BackPill(style: PillStyle.solid)),
                          if (skipLabel != null)
                            Positioned(
                              top: 16,
                              right: 16,
                              child: TextPill(label: skipLabel!, onTap: onSkip),
                            ),
                        ],
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
