import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/app_motion.dart';
import '../theme/app_typography.dart';

/// Form field: label above, warm border, 2px petróleo on focus,
/// help text always visible and replaced by the error when there is one.
class AppTextField extends StatefulWidget {
  const AppTextField({
    super.key,
    required this.label,
    required this.hint,
    this.help,
    this.error,
    this.obscure = false,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.onChanged,
    this.onSubmitted,
    this.onFocusLost,
    this.controller,
    this.initialValue,
    this.inputFormatters,
    this.maxLines = 1,
    this.minLines,
    this.maxLength,
    this.enabled = true,
    this.suffix,
    this.capitalization = TextCapitalization.none,
    this.autofocus = false,
  });

  final String label;
  final String hint;
  final String? help;
  final String? error;
  final bool obscure;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onFocusLost;
  final TextEditingController? controller;

  /// Used only when no [controller] is given.
  final String? initialValue;
  final List<TextInputFormatter>? inputFormatters;
  final int maxLines;
  final int? minLines;

  /// Shows a "{n}/{max}" counter beside the help text.
  final int? maxLength;
  final bool enabled;
  final Widget? suffix;
  final TextCapitalization capitalization;
  final bool autofocus;

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  final _focus = FocusNode();
  late bool _hidden = widget.obscure;
  late final TextEditingController _ctrl = widget.controller ?? TextEditingController(text: widget.initialValue);

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      setState(() {});
      if (!_focus.hasFocus) widget.onFocusLost?.call();
    });
    if (widget.maxLength != null) _ctrl.addListener(_onText);
  }

  void _onText() => setState(() {});

  @override
  void dispose() {
    _focus.dispose();
    _ctrl.removeListener(_onText);
    if (widget.controller == null) _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasError = widget.error != null;
    final focused = _focus.hasFocus;
    final border = hasError
        ? AppColors.erroBase
        : focused
        ? AppColors.petroleo600
        : AppColors.cinza200;
    final note = widget.error ?? widget.help;
    final counter = widget.maxLength == null ? null : '${_ctrl.text.characters.length}/${widget.maxLength}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label, style: AppType.label(size: 14)),
        const SizedBox(height: 6),
        AnimatedContainer(
          duration: AppMotion.medium,
          curve: AppMotion.smooth,
          decoration: BoxDecoration(
            color: !widget.enabled
                ? AppColors.cinza100
                : focused
                ? AppColors.white
                : AppColors.cinza50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: border, width: focused || hasError ? 2 : 1),
          ),
          child: TextField(
            controller: _ctrl,
            focusNode: _focus,
            enabled: widget.enabled,
            autofocus: widget.autofocus,
            obscureText: _hidden,
            keyboardType: widget.maxLines > 1 ? TextInputType.multiline : widget.keyboardType,
            textInputAction: widget.textInputAction,
            textCapitalization: widget.capitalization,
            autofillHints: widget.autofillHints,
            inputFormatters: [
              ...?widget.inputFormatters,
              if (widget.maxLength != null) LengthLimitingTextInputFormatter(widget.maxLength),
            ],
            maxLines: widget.obscure ? 1 : widget.maxLines,
            minLines: widget.minLines,
            onChanged: widget.onChanged,
            onSubmitted: widget.onSubmitted,
            cursorColor: AppColors.petroleo600,
            style: AppType.body(color: widget.enabled ? AppColors.cinza900 : AppColors.cinza600),
            decoration: InputDecoration(
              isDense: true,
              border: InputBorder.none,
              hintText: widget.hint,
              hintMaxLines: 3,
              hintStyle: AppType.body(color: AppColors.cinza500),
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: focused || hasError ? 13 : 14),
              suffixIcon: widget.obscure
                  ? IconButton(
                      tooltip: _hidden ? 'Mostrar senha' : 'Esconder senha',
                      onPressed: () => setState(() => _hidden = !_hidden),
                      icon: Icon(
                        _hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                        size: 20,
                        color: AppColors.cinza600,
                      ),
                    )
                  : widget.suffix,
              suffixIconConstraints: const BoxConstraints(minWidth: 44, minHeight: 24),
            ),
          ),
        ),
        AnimatedSize(
          duration: AppMotion.medium,
          curve: AppMotion.smooth,
          alignment: Alignment.topLeft,
          child: note == null && counter == null
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: AnimatedSwitcher(
                          duration: AppMotion.medium,
                          layoutBuilder: (current, previous) =>
                              Stack(alignment: Alignment.topLeft, children: [...previous, ?current]),
                          child: Text(
                            note ?? '',
                            key: ValueKey(note),
                            style: AppType.body(size: 13, color: hasError ? AppColors.erroTexto : AppColors.cinza600),
                          ),
                        ),
                      ),
                      if (counter != null) ...[
                        const SizedBox(width: 12),
                        Text(
                          counter,
                          style: AppType.body(size: 13).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
                        ),
                      ],
                    ],
                  ),
                ),
        ),
      ],
    );
  }
}
