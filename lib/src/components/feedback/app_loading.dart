import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:kumbha_path/src/constant/design_system/design_system.dart';

/// In-place loading indicator for a screen body, list or section.
///
/// For blocking full-screen loading during a submit, keep using the
/// existing `CenterLoader.show / hide` overlay.
class AppLoading extends StatelessWidget {
  const AppLoading({super.key, this.message, this.compact = false});

  /// Small inline spinner with no message, e.g. at the end of a list.
  const AppLoading.compact({super.key}) : message = null, compact = true;

  /// Optional visible text under the spinner.
  final String? message;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final spinnerSize = compact ? 24.0 : 40.0;
    final semanticsLabel = message ?? 'common_loading'.tr();

    return Semantics(
      liveRegion: true,
      label: semanticsLabel,
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(compact ? AppSpacing.sm : AppSpacing.xxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox.square(
                dimension: spinnerSize,
                child: CircularProgressIndicator(
                  strokeWidth: compact ? 2.5 : 3,
                ),
              ),
              if (message != null) ...[
                AppSpacing.gapLg,
                ExcludeSemantics(
                  child: Text(
                    message!,
                    textAlign: TextAlign.center,
                    style: context.textTheme.bodyMedium?.copyWith(
                      color: context.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
