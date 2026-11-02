import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Device logs are readable by more than this app, so nothing in `lib` may
/// write to them with `print`, and nothing may log a credential at all.
void main() {
  final sources = Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((file) => file.path.endsWith('.dart'));

  String code(File file) => file
      .readAsLinesSync()
      .where((line) => !line.trimLeft().startsWith('//'))
      .join('\n');

  test('nothing prints to the device log', () {
    final bare = RegExp(r'(?<![\w.])print\(');
    final found = [
      for (final file in sources)
        if (bare.hasMatch(code(file))) file.path,
    ];
    expect(found, isEmpty);
  });

  test('no debug log includes a credential or a phone number', () {
    final risky = RegExp(
      r'''debugPrint\([^;]*\$\{?\w*(token|otp|password|phone|mobile)''',
      caseSensitive: false,
    );
    final found = [
      for (final file in sources)
        if (risky.hasMatch(code(file))) file.path,
    ];
    expect(found, isEmpty);
  });

  test('app data stays out of device cloud backups', () {
    final manifest = File('android/app/src/main/AndroidManifest.xml');
    expect(
      manifest.readAsStringSync(),
      contains('android:allowBackup="false"'),
    );
  });
}
