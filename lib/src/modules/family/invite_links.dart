import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/widgets.dart';
import 'package:kumbha_path/src/components/navigation/app_navigation.dart';
import 'package:kumbha_path/src/constant/config.dart';

const _host = 'kumbhapath.in';
const _path = '/join/family';
final _token = RegExp(r'^[A-Za-z0-9_-]{32,128}$');

/// An opened invitation link. [token] is null if the link is ours but damaged,
/// for instance cut short when it was copied.
@immutable
class InviteLink {
  const InviteLink(this.token);

  final String? token;

  /// The token is a secret, so this must never print it.
  @override
  String toString() => 'InviteLink';
}

/// An invitation link, or null for any other address. Everything is checked
/// here because any app can send this app an address.
InviteLink? parseInviteLink(Uri uri) {
  if (uri.scheme != 'https' || uri.host != _host) return null;
  if (uri.hasPort && uri.port != 443) return null;
  if (uri.path != _path && uri.path != '$_path/') return null;
  final fragment = uri.fragment;
  if (!fragment.startsWith('t=')) return const InviteLink(null);
  final token = fragment.substring(2);
  return InviteLink(_token.hasMatch(token) ? token : null);
}

/// Opens invitation links, in the same way [NotificationRouter] opens tapped
/// notifications. Until the signed-in app is on screen, the link is held so it
/// survives sign-in, and being closed by the phone during sign-in.
class InviteLinkRouter {
  InviteLinkRouter._();

  static const _shell = '/dashboardScreen';
  static const _storageKey = 'pending_family_invite';

  static GlobalKey<NavigatorState>? _navigatorKey;
  static StreamSubscription<Uri>? _links;
  static InviteLink? _pending;

  /// Whether the signed-in app is on screen.
  @visibleForTesting
  static bool Function() shellVisible =
      () => AppNavigation.observer.contains(_shell);

  static void attach(GlobalKey<NavigatorState> key) => _navigatorKey = key;

  /// Starts receiving links, including the one that launched the app.
  static void listen([Stream<Uri>? links]) {
    _links?.cancel();
    _links = (links ?? AppLinks().uriLinkStream).listen(
      (uri) => unawaited(handle(uri)),
      onError: (Object _) {},
    );
  }

  /// Handles one address. Anything that isn't an invitation is ignored.
  static Future<void> handle(Uri uri) async {
    final link = parseInviteLink(uri);
    if (link == null) return;
    final navigator = _navigatorKey?.currentState;
    if (navigator == null || !shellVisible()) {
      _pending = link;
      await _save(link.token);
      return;
    }
    await _open(navigator, link);
  }

  /// Called once the dashboard is visible.
  static Future<void> consumePending() async {
    var link = _pending;
    if (link == null) {
      final saved = await _read();
      if (saved == null) return;
      link = InviteLink(saved);
    }
    await clearPending();
    final navigator = _navigatorKey?.currentState;
    if (navigator != null) await _open(navigator, link);
  }

  /// Also called on sign-out: a held link must not pass to the next account.
  static Future<void> clearPending() async {
    _pending = null;
    try {
      await storage.delete(key: _storageKey);
    } catch (_) {
      // Nothing was saved, or storage isn't available.
    }
  }

  static Future<void> _open(NavigatorState navigator, InviteLink link) async {
    final joined = await navigator.pushNamed('/familyJoin', arguments: link);
    if (joined == true) await navigator.pushNamed('/family');
  }

  static Future<void> _save(String? token) async {
    if (token == null) return;
    try {
      await storage.write(key: _storageKey, value: token);
    } catch (_) {
      // Still held in memory for this run.
    }
  }

  static Future<String?> _read() async {
    try {
      return await storage.read(key: _storageKey);
    } catch (_) {
      return null;
    }
  }

  @visibleForTesting
  static InviteLink? get pending => _pending;

  @visibleForTesting
  static void reset() {
    _links?.cancel();
    _links = null;
    _pending = null;
    _navigatorKey = null;
  }
}
