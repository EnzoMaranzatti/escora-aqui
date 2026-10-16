import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import '../../core/icons.dart';

import '../theme/app_colors.dart';
import '../theme/app_motion.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'app_text_field.dart';
import 'buttons.dart';
import 'kit.dart';

/// Floating sheet in the language of the city sheet: inset from the
/// edges, 32 radius, grab handle, rises with the keyboard.
Future<T?> showAppSheet<T>(BuildContext context, {required WidgetBuilder builder, bool dismissible = true}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useRootNavigator: true,
    isDismissible: dismissible,
    enableDrag: dismissible,
    backgroundColor: Colors.transparent,
    barrierColor: AppColors.cinza900.withValues(alpha: .28),
    sheetAnimationStyle: const AnimationStyle(duration: AppMotion.slow, curve: AppMotion.smooth),
    builder: (context) => _SheetFrame(child: builder(context)),
  );
}

class _SheetFrame extends StatelessWidget {
  const _SheetFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final keyboard = mq.viewInsets.bottom;
    return AnimatedPadding(
      duration: AppMotion.medium,
      curve: AppMotion.smooth,
      padding: EdgeInsets.fromLTRB(6, mq.padding.top + 24, 6, (keyboard > 0 ? keyboard : mq.padding.bottom) + 8),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(32),
          boxShadow: [
            BoxShadow(color: AppColors.cinza900.withValues(alpha: .14), blurRadius: 32, offset: const Offset(0, 12)),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 40,
                height: 5,
                decoration: BoxDecoration(color: AppColors.cinza200, borderRadius: BorderRadius.circular(3)),
              ),
              Flexible(
                child: SingleChildScrollView(padding: const EdgeInsets.fromLTRB(20, 18, 20, 20), child: child),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Title + description block used at the top of sheets.
class SheetHeader extends StatelessWidget {
  const SheetHeader({super.key, required this.title, this.text, this.icon, this.iconTone = Tone.info});

  final String title;
  final String? text;
  final IconData? icon;
  final Tone iconTone;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (icon != null) ...[
          IconBadge(icon!, size: 48, color: iconTone.fg, bg: iconTone.bg),
          const SizedBox(height: 14),
        ],
        Text(title, style: AppType.title().copyWith(fontSize: 22, height: 1.25)),
        if (text != null) ...[const SizedBox(height: 8), Text(text!, style: AppType.body(size: 15.5))],
      ],
    );
  }
}

/// Field configuration for [confirmSheet].
class SheetField {
  const SheetField({required this.label, this.hint = '', this.required = false, this.error, this.help});

  final String label;
  final String hint;
  final bool required;

  /// Shown when [required] and the field is empty.
  final String? error;
  final String? help;
}

/// Confirmation sheet: title, description, an optional text field, a main
/// action and a secondary one. Returns the field text ('' without a field)
/// when confirmed, or null when the person backs out.
Future<String?> confirmSheet(
  BuildContext context, {
  required String title,
  String? text,
  required String confirm,
  required String cancel,
  bool destructive = false,
  SheetField? field,
  IconData? icon,
  Tone iconTone = Tone.info,
  VoidCallback? onCancel,
}) {
  return showAppSheet<String>(
    context,
    builder: (_) => _ConfirmBody(
      title: title,
      text: text,
      confirm: confirm,
      cancel: cancel,
      destructive: destructive,
      field: field,
      icon: icon,
      iconTone: iconTone,
      onCancel: onCancel,
    ),
  );
}

class _ConfirmBody extends StatefulWidget {
  const _ConfirmBody({
    required this.title,
    required this.text,
    required this.confirm,
    required this.cancel,
    required this.destructive,
    required this.field,
    required this.icon,
    required this.iconTone,
    required this.onCancel,
  });

  final String title;
  final String? text;
  final String confirm;
  final String cancel;
  final bool destructive;
  final SheetField? field;
  final IconData? icon;
  final Tone iconTone;
  final VoidCallback? onCancel;

  @override
  State<_ConfirmBody> createState() => _ConfirmBodyState();
}

class _ConfirmBodyState extends State<_ConfirmBody> {
  String _value = '';
  bool _tried = false;

  bool get _ok => widget.field == null || !widget.field!.required || _value.trim().isNotEmpty;

  void _submit() {
    if (!_ok) {
      setState(() => _tried = true);
      return;
    }
    HapticFeedback.mediumImpact();
    Navigator.pop(context, _value.trim());
  }

  @override
  Widget build(BuildContext context) {
    final f = widget.field;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SheetHeader(title: widget.title, text: widget.text, icon: widget.icon, iconTone: widget.iconTone),
        if (f != null) ...[
          const SizedBox(height: 20),
          AppTextField(
            label: f.label,
            hint: f.hint,
            help: f.help,
            maxLines: 3,
            minLines: 2,
            capitalization: TextCapitalization.sentences,
            error: _tried && !_ok ? (f.error ?? 'Preencha este campo para continuar.') : null,
            onChanged: (v) => setState(() => _value = v),
          ),
        ],
        const SizedBox(height: 24),
        if (widget.destructive)
          SoftButton(label: widget.confirm, onTap: _submit, filled: true, destructive: true, expand: true, height: 56)
        else
          PrimaryButton(label: widget.confirm, icon: null, onPressed: _submit),
        const SizedBox(height: 4),
        GhostButton(
          label: widget.cancel,
          onPressed: () {
            Navigator.pop(context);
            widget.onCancel?.call();
          },
        ),
      ],
    );
  }
}

/// Short notice ("aviso curto") that slides in above the bottom bar and
/// leaves by itself after about 3 seconds.
abstract final class Toast {
  static OverlayEntry? _entry;
  static Timer? _timer;

  static void show(
    BuildContext context,
    String text, {
    IconData icon = PhosphorIconsFill.checkCircle,
    Duration duration = const Duration(seconds: 3),
  }) {
    _timer?.cancel();
    _entry?.remove();
    final overlay = Overlay.of(context, rootOverlay: true);
    final key = GlobalKey<_ToastViewState>();
    final entry = OverlayEntry(
      builder: (_) => _ToastView(key: key, text: text, icon: icon),
    );
    _entry = entry;
    overlay.insert(entry);
    SemanticsService.sendAnnouncement(View.of(context), text, TextDirection.ltr);
    _timer = Timer(duration, () async {
      await key.currentState?.hide();
      if (_entry == entry) {
        entry.remove();
        _entry = null;
      }
    });
  }
}

class _ToastView extends StatefulWidget {
  const _ToastView({super.key, required this.text, required this.icon});

  final String text;
  final IconData icon;

  @override
  State<_ToastView> createState() => _ToastViewState();
}

class _ToastViewState extends State<_ToastView> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: AppMotion.slow)..forward();

  Future<void> hide() async {
    if (mounted) await _c.reverse();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.paddingOf(context);
    final a = CurvedAnimation(parent: _c, curve: AppMotion.smooth, reverseCurve: Curves.easeIn);
    return Positioned(
      left: 16,
      right: 16,
      bottom: pad.bottom + 96,
      child: IgnorePointer(
        child: FadeTransition(
          opacity: a,
          child: SlideTransition(
            position: Tween(begin: const Offset(0, .4), end: Offset.zero).animate(a),
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.fromLTRB(14, 13, 16, 13),
                decoration: BoxDecoration(
                  color: AppColors.cinza900,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.cinza900.withValues(alpha: .25),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Icon(widget.icon, size: 20, color: AppColors.petroleo200),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        widget.text,
                        style: AppType.body(color: AppColors.white, size: 14.5).copyWith(height: 1.35),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Bottom area with the main button and an optional secondary one,
/// shared by flows and sheets.
class ActionArea extends StatelessWidget {
  const ActionArea({
    super.key,
    required this.primary,
    required this.onPrimary,
    this.secondary,
    this.onSecondary,
    this.loading = false,
    this.icon,
    this.note,
  });

  final String primary;
  final VoidCallback? onPrimary;
  final String? secondary;
  final VoidCallback? onSecondary;
  final bool loading;
  final String? icon;

  /// Small line above the button ("Confira todos os itens para aprovar.").
  final Widget? note;

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.paddingOf(context);
    final keyboard = MediaQuery.viewInsetsOf(context).bottom > 0;
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.white,
        border: Border(top: BorderSide(color: AppColors.cinza100)),
      ),
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        keyboard ? 12 : (secondary == null ? AppSpacing.bottom : 8) + pad.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (note != null) ...[note!, const SizedBox(height: 10)],
          PrimaryButton(label: primary, onPressed: onPrimary, loading: loading, icon: icon),
          if (secondary != null && !keyboard) ...[
            const SizedBox(height: 2),
            GhostButton(label: secondary!, onPressed: onSecondary),
          ],
        ],
      ),
    );
  }
}
