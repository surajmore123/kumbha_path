import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kumbha_path/src/constant/design_system/design_system.dart';

/// Standard text input, built on [TextFormField] so it works both inside a
/// `Form` (via [validator]) and standalone (via [errorText]).
///
/// Fill, borders, padding and hint / error styles come from the theme's
/// `inputDecorationTheme`. The label sits above the field rather than
/// floating inside it, so Devanagari labels are never clipped and the field
/// grows naturally with the font scale. No fixed heights.
class AppTextField extends StatefulWidget {
  const AppTextField({
    super.key,
    this.controller,
    this.initialValue,
    this.focusNode,
    this.label,
    this.hint,
    this.helperText,
    this.errorText,
    this.prefixIcon,
    this.suffixIcon,
    this.prefixText,
    this.suffix,
    this.obscureText = false,
    this.showObscureToggle = true,
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.inputFormatters,
    this.autofillHints,
    this.maxLength,
    this.maxLines = 1,
    this.minLines,
    this.enabled = true,
    this.readOnly = false,
    this.autofocus = false,
    this.autovalidateMode,
    this.validator,
    this.onChanged,
    this.onFieldSubmitted,
    this.onTap,
  });

  final TextEditingController? controller;

  /// Ignored when [controller] is provided.
  final String? initialValue;
  final FocusNode? focusNode;

  /// Shown above the field. Also used as the accessibility label.
  final String? label;
  final String? hint;
  final String? helperText;

  /// Externally managed error (e.g. from a BLoC state). Form validation
  /// errors from [validator] are shown automatically.
  final String? errorText;
  final IconData? prefixIcon;

  /// Replaced by the visibility toggle when [obscureText] and
  /// [showObscureToggle] are both true.
  final Widget? suffixIcon;

  /// Fixed leading text such as a country code (`+91 `).
  final String? prefixText;
  final Widget? suffix;

  final bool obscureText;

  /// Adds a show / hide button to obscured fields.
  final bool showObscureToggle;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final List<TextInputFormatter>? inputFormatters;
  final Iterable<String>? autofillHints;
  final int? maxLength;

  /// Pass `null` for an auto-growing multi-line field.
  final int? maxLines;
  final int? minLines;
  final bool enabled;
  final bool readOnly;
  final bool autofocus;
  final AutovalidateMode? autovalidateMode;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onFieldSubmitted;
  final GestureTapCallback? onTap;

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  late bool _obscured = widget.obscureText;

  @override
  void didUpdateWidget(covariant AppTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.obscureText != widget.obscureText) {
      _obscured = widget.obscureText;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final text = context.textTheme;

    Widget? suffixIcon = widget.suffixIcon;
    if (widget.obscureText && widget.showObscureToggle) {
      suffixIcon = IconButton(
        tooltip:
            _obscured
                ? 'common_show_password'.tr()
                : 'common_hide_password'.tr(),
        icon: Icon(
          _obscured ? Icons.visibility_outlined : Icons.visibility_off_outlined,
        ),
        onPressed: () => setState(() => _obscured = !_obscured),
      );
    }

    final field = TextFormField(
      controller: widget.controller,
      initialValue: widget.controller == null ? widget.initialValue : null,
      focusNode: widget.focusNode,
      obscureText: _obscured,
      keyboardType: widget.keyboardType,
      textInputAction: widget.textInputAction,
      textCapitalization: widget.textCapitalization,
      inputFormatters: widget.inputFormatters,
      autofillHints: widget.autofillHints,
      maxLength: widget.maxLength,
      maxLines: widget.obscureText ? 1 : widget.maxLines,
      minLines: widget.obscureText ? null : widget.minLines,
      enabled: widget.enabled,
      readOnly: widget.readOnly,
      autofocus: widget.autofocus,
      autovalidateMode: widget.autovalidateMode,
      validator: widget.validator,
      onChanged: widget.onChanged,
      onFieldSubmitted: widget.onFieldSubmitted,
      onTap: widget.onTap,
      style: text.bodyLarge,
      cursorColor: colors.primary,
      decoration: InputDecoration(
        hintText: widget.hint,
        helperText: widget.helperText,
        helperMaxLines: 3,
        errorText: widget.errorText,
        errorMaxLines: 3,
        prefixIcon: widget.prefixIcon != null ? Icon(widget.prefixIcon) : null,
        prefixText: widget.prefixText,
        prefixStyle: text.bodyLarge,
        suffixIcon: suffixIcon,
        suffix: widget.suffix,
      ),
    );

    if (widget.label == null) return field;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        ExcludeSemantics(
          child: Text(
            widget.label!,
            style: text.labelLarge?.copyWith(
              color:
                  widget.enabled
                      ? colors.onSurface
                      : colors.onSurface.withValues(alpha: 0.38),
            ),
          ),
        ),
        AppSpacing.gapSm,
        Semantics(label: widget.label, child: field),
      ],
    );
  }
}
