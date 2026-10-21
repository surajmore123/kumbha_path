
import 'package:flutter/material.dart';
import 'package:kumbha_path/src/components/loader/custom_progress_indicator.dart';

class CenterLoader extends StatelessWidget {
  static OverlayEntry? _currentLoader;

  static OverlayState? _overlayState;

  const CenterLoader({super.key});

  static void show(
    BuildContext context, {
    Widget? progressIndicator,
    ThemeData? themeData,
    Color? overlayColor,
  }) {
    _overlayState = Overlay.of(context);
    if (_currentLoader == null) {
      _currentLoader = OverlayEntry(builder: (context) {
        return Stack(
          children: <Widget>[
            SafeArea(
              child: Container(
                color: overlayColor ??
                    Theme.of(context).colorScheme.surface.withValues(alpha: 0.6),
              ),
            ),
            const Center(child: CenterLoader()),
          ],
        );
      });
      try {
        WidgetsBinding.instance.addPostFrameCallback(
            (_) => _overlayState?.insertAll([_currentLoader!]));
      } catch (e) {
        debugPrint('$e');
      }
    }
  }

  static void hide() {
    if (_currentLoader != null) {
      try {
        _currentLoader?.remove();
      } catch (e) {
        debugPrint('$e');
      } finally {
        _currentLoader = null;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Center(child: CustomProgressIndicator());
  }
}
