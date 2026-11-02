import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:kumbha_path/src/components/components.dart';
import 'package:kumbha_path/src/constant/design_system/design_system.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

/// Always all three, whatever language the phone is using, because the person
/// reading a card isn't the person who printed it.
const _helpLines = [
  'If I am lost, please take me to the nearest police post or help desk.',
  'मैं खो जाऊँ तो कृपया मुझे नज़दीकी पुलिस चौकी या सहायता केंद्र ले जाएँ।',
  'मी हरवलो तर कृपया मला जवळच्या पोलीस चौकीत किंवा मदत केंद्रात घेऊन जा.',
];

/// The first letter only, so a family can tell its cards apart while a card
/// worn in a crowd names nobody.
String cardInitial(String name) {
  final trimmed = name.trim();
  return trimmed.isEmpty ? '' : '${trimmed.characters.first.toUpperCase()}.';
}

/// The printable card. It's always in the light palette at a fixed size, so it
/// looks the same in dark mode or at any font size, and the code stays
/// dark-on-white for scanners. It has no name, number, or family on it.
class SafetyCard extends StatelessWidget {
  const SafetyCard({super.key, required this.payload, required this.initial});

  static const size = Size(300, 470);

  final String payload;
  final String initial;

  @override
  Widget build(BuildContext context) {
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
      child: Theme(
        data: AppTheme.light,
        child: Builder(
          builder: (context) {
            final colors = context.colorScheme;
            final e = context.editorial;
            final gold = context.semanticColors.gold;
            return SizedBox.fromSize(
              size: size,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: gold, width: 1.5),
                  borderRadius: AppRadius.lgAll,
                ),
                child: ClipRRect(
                  borderRadius: AppRadius.lgAll,
                  child: Column(
                    children: [
                      ClipPath(
                        clipper: const GhatEdgeClipper(stepHeight: 4),
                        child: Container(
                          width: double.infinity,
                          color: colors.primary,
                          padding: const EdgeInsets.fromLTRB(
                            AppSpacing.lg,
                            AppSpacing.md,
                            AppSpacing.lg,
                            AppSpacing.xl,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Kumbh Path Safety Card',
                                  style: e.title.copyWith(
                                    color: colors.onPrimary,
                                  ),
                                ),
                              ),
                              Text(
                                initial,
                                style: e.title.copyWith(
                                  color: colors.onPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      QrImageView(
                        data: payload,
                        size: 232,
                        padding: const EdgeInsets.all(8),
                        backgroundColor: Colors.white,
                        errorCorrectionLevel: QrErrorCorrectLevel.Q,
                        semanticsLabel: 'Safety QR',
                      ),
                      // Scales down rather than ever clipping on paper.
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.lg,
                          ),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: SizedBox(
                              width: 268,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  for (final line in _helpLines)
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 2),
                                      child: Text(
                                        line,
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          fontSize: 10.5,
                                          height: 1.25,
                                          color: Color(0xFF1F1A14),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.only(bottom: AppSpacing.sm),
                        child: Text(
                          'Registered helpers only  ·  Emergency 112',
                          style: TextStyle(
                            fontSize: 9,
                            color: Color(0xFF5C5346),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Renders the card on screen to a PNG. Flutter draws the text, so Hindi and
/// Marathi come out correctly shaped, which the PDF library can't do itself.
Future<Uint8List> captureCard(GlobalKey boundaryKey) async {
  final boundary =
      boundaryKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final image = await boundary.toImage(pixelRatio: 4);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return data!.buffer.asUint8List();
}

/// One card per A6 page, the size of a card holder or a pocket.
Future<Uint8List> buildCardPdf(Uint8List png) async {
  final document = pw.Document(title: 'Kumbh Path Safety Card');
  final image = pw.MemoryImage(png);
  document.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a6,
      margin: const pw.EdgeInsets.all(12),
      build: (_) => pw.Center(child: pw.Image(image)),
    ),
  );
  return document.save();
}

/// What the phone does with a card. A fake in tests.
abstract class SafetyCardActions {
  /// False if the person cancelled.
  Future<bool> save(Uint8List png);
  Future<bool> printCard(Uint8List pdf);
  Future<void> share(Uint8List png, Rect? origin);
}

class PlatformCardActions implements SafetyCardActions {
  const PlatformCardActions();

  static const _name = 'kumbh-path-safety-card';

  @override
  Future<bool> save(Uint8List png) async {
    final path = await FilePicker.platform.saveFile(
      fileName: '$_name.png',
      bytes: png,
      type: FileType.image,
    );
    return path != null;
  }

  @override
  Future<bool> printCard(Uint8List pdf) =>
      Printing.layoutPdf(onLayout: (_) async => pdf, name: _name);

  @override
  Future<void> share(Uint8List png, Rect? origin) async {
    await Share.shareXFiles(
      [XFile.fromData(png, mimeType: 'image/png', name: '$_name.png')],
      fileNameOverrides: ['$_name.png'],
      sharePositionOrigin: origin,
    );
  }
}

class SafetyCardServices {
  SafetyCardServices._();

  static SafetyCardActions actions = const PlatformCardActions();
}

/// A round action, in the same style as the family screen's.
class SafetyAction extends StatelessWidget {
  const SafetyAction({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    return Expanded(
      child: Pressable(
        onTap: onTap,
        label: label.tr(),
        child: ExcludeSemantics(
          child: Column(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: colors.surfaceContainerHigh,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: colors.primary),
              ),
              AppSpacing.gapXs,
              Text(
                label.tr(),
                textAlign: TextAlign.center,
                style: context.editorial.meta,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
