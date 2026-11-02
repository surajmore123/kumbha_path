import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:kumbha_path/src/modules/family/widgets/invite_share_sheet.dart';

/// The real platform calls, on a device.
///
///     flutter test integration_test/invite_share_device_test.dart -d <device>
///
/// Set WHATSAPP_INSTALLED=true on a phone that has WhatsApp.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const hasWhatsApp = bool.fromEnvironment('WHATSAPP_INSTALLED');
  const text = 'Join us: https://kumbhapath.in/join/family#t=test-token-value';
  const sharer = PlatformInviteSharer();

  // Plain tests, because opening another app stops this one drawing frames.
  // The clipboard goes first: Android only lets a foreground app read it.
  test('copying reaches the clipboard', () async {
    await sharer.copy(text);
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    expect(data?.text, text);
  });

  test('WhatsApp reports honestly whether it opened', () async {
    expect(await sharer.open(whatsAppUri(text)), hasWhatsApp);
  });

  test('a messages app opens', () async {
    expect(await sharer.open(smsUri(text, ios: false)), isTrue);
  });
}
