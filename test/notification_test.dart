import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumbha_path/src/components/navigation/app_navigation.dart';
import 'package:kumbha_path/src/services/local_notification_service.dart';
import 'package:kumbha_path/src/services/notification_router.dart';

void main() {
  tearDown(NotificationRouter.reset);

  group('notification routing (backend data → screen)', () {
    test('known routes and types only', () {
      expect(
        NotificationRouter.routeFor({'route': '/shahiEvents'}),
        '/shahiEvents',
      );
      expect(
        NotificationRouter.routeFor({'type': 'event_reminder'}),
        '/shahiEvents',
      );
      expect(
        NotificationRouter.routeFor({'type': 'crowd_alert', 'zone_id': '3'}),
        '/liveCroud',
      );
      expect(NotificationRouter.routeFor({'route': '/setting'}), isNull);
      expect(
        NotificationRouter.routeFor({'type': 'event_update'}),
        '/shahiEvents',
      );
      expect(
        NotificationRouter.routeFor({'type': 'new_event'}),
        '/shahiEvents',
      );
      expect(
        NotificationRouter.routeFor({'type': 'safety_alert'}),
        '/notifications',
      );
      expect(NotificationRouter.routeFor({'type': 'unknown'}), isNull);
      expect(NotificationRouter.routeFor(null), isNull);
    });

    test('channel follows the backend, else the type', () {
      expect(
        NotificationService.channelFor('event_reminders', {}),
        'event_reminders',
      );
      expect(
        NotificationService.channelFor(null, {'type': 'event_reminder'}),
        'event_reminders',
      );
      expect(
        NotificationService.channelFor('other', {'type': 'crowd_alert'}),
        'crowd_alerts',
      );
    });

    testWidgets('a tap before the dashboard is shown waits, then opens', (
      tester,
    ) async {
      final key = GlobalKey<NavigatorState>();
      NotificationRouter.attach(key);
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: key,
          navigatorObservers: [AppNavigation.observer],
          initialRoute: '/launchScreen',
          routes: {
            '/launchScreen': (_) => const Text('launch'),
            '/dashboardScreen': (_) => const Text('dashboard'),
            '/shahiEvents': (_) => const Text('events'),
          },
        ),
      );

      // App started from a notification while still on the launch screen.
      NotificationRouter.open({'type': 'event_reminder'});
      await tester.pumpAndSettle();
      expect(find.text('events'), findsNothing);
      expect(NotificationRouter.pendingRoute, '/shahiEvents');

      key.currentState!.pushReplacementNamed('/dashboardScreen');
      await tester.pumpAndSettle();
      NotificationRouter.consumePending();
      await tester.pumpAndSettle();
      expect(find.text('events'), findsOneWidget);
      expect(NotificationRouter.pendingRoute, isNull);

      // With the dashboard open, a tap opens the screen right away.
      key.currentState!.pop();
      await tester.pumpAndSettle();
      NotificationRouter.open({'route': '/shahiEvents'});
      await tester.pumpAndSettle();
      expect(find.text('events'), findsOneWidget);
    });
  });
}
