import 'package:flutter/widgets.dart';

/// Corner-radius scale. Keep the set small so surfaces feel related.
abstract final class AppRadius {
  static const double none = 0;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;

  /// Fully rounded ends (chips, pills, avatars with labels).
  static const double pill = 999;

  // Component aliases
  static const double button = md;
  static const double input = md;
  static const double chip = pill;
  static const double card = lg;
  static const double dialog = xl;
  static const double sheet = xl;

  static const BorderRadius xsAll = BorderRadius.all(Radius.circular(xs));
  static const BorderRadius smAll = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius mdAll = BorderRadius.all(Radius.circular(md));
  static const BorderRadius lgAll = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius xlAll = BorderRadius.all(Radius.circular(xl));
  static const BorderRadius pillAll = BorderRadius.all(Radius.circular(pill));

  static const BorderRadius buttonAll = mdAll;
  static const BorderRadius inputAll = mdAll;
  static const BorderRadius cardAll = lgAll;
  static const BorderRadius dialogAll = xlAll;
  static const BorderRadius sheetTop = BorderRadius.vertical(
    top: Radius.circular(sheet),
  );
}
