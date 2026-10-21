import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:kumbha_path/src/bloc/app_details_bloc/app_details_feed.dart';
import 'package:kumbha_path/src/bloc/app_details_bloc/app_details_event.dart';
import 'package:kumbha_path/src/bloc/app_details_bloc/app_details_state.dart';
import 'package:kumbha_path/src/bloc/main_bloc/app_event.dart';
import 'package:kumbha_path/src/bloc/main_bloc/app_state.dart';
import 'package:kumbha_path/src/constant/location_service.dart';

export 'package:kumbha_path/src/bloc/app_details_bloc/app_details_feed.dart';
export 'package:kumbha_path/src/constant/location_service.dart'
    show LocationAccess, LocationGateway;

/// Kept for existing references; the class is shared as [AppDetailsFeed].
typedef DashboardFeed = AppDetailsFeed;

/// Data owner for the dashboard. Created and disposed by the screen.
class DashboardController {
  DashboardController({
    required this.templesBloc,
    DashboardFeed? featured,
    DashboardFeed? upcoming,
    DashboardFeed? crowd,
    DashboardFeed? alerts,
    DashboardFeed? journal,
    LocationGateway? location,
  }) : featured =
           featured ??
           DashboardFeed(
             request: FeaturedEvent.new,
             isReady: (s) => s == AppDetailsStatus.success,
             isFailed: (s) => s == AppDetailsStatus.failed,
           ),
       upcoming =
           upcoming ??
           DashboardFeed(
             // Same default request the Events screen makes.
             request: UpcomingEvent.new,
             isReady: (s) => s == AppDetailsStatus.success,
             isFailed: (s) => s == AppDetailsStatus.failed,
           ),
       crowd =
           crowd ??
           DashboardFeed(
             request: CrowdLiveStatusEvent.new,
             isReady: (s) => s == AppDetailsStatus.success,
             isFailed: (s) => s == AppDetailsStatus.failed,
           ),
       alerts =
           alerts ??
           DashboardFeed(
             request: QuickAlertsEvent.new,
             isReady: (s) => s == AppDetailsStatus.success,
             isFailed: (s) => s == AppDetailsStatus.failed,
           ),
       journal =
           journal ??
           DashboardFeed(
             request: () => GetJournalEntry(page: 1),
             isReady: (s) => s == AppDetailsStatus.journalEntryoaded,
             isFailed: (s) => s == AppDetailsStatus.journalEntryError,
           ),
       location = location ?? const LocationGateway();

  /// The app-wide [AppBloc]. Nearby temples deliberately use the shared
  /// instance: it's what the existing Temple Explorer reads, so "See all"
  /// opens on the same results without fetching again.
  final Bloc<AppEvent, AppState> templesBloc;
  final DashboardFeed featured;
  final DashboardFeed upcoming;
  final DashboardFeed crowd;
  final DashboardFeed alerts;
  final DashboardFeed journal;
  final LocationGateway location;

  final ValueNotifier<LocationAccess> locationAccess = ValueNotifier(
    LocationAccess.checking,
  );
  Position? position;

  List<DashboardFeed> get _feeds => [
    featured,
    upcoming,
    crowd,
    alerts,
    journal,
  ];

  /// Initial load. Location is only *checked* here; the permission prompt
  /// appears only when the user taps "Allow location".
  void start() {
    for (final feed in _feeds) {
      feed.load();
    }
    _initLocation();
  }

  Future<void> refresh() async {
    await Future.wait([
      for (final feed in _feeds) feed.load(),
      if (locationAccess.value == LocationAccess.available) loadTemples(),
    ]);
  }

  Future<void> _initLocation() async {
    final access = await location.currentAccess();
    if (access == LocationAccess.available && await ensurePosition()) {
      await loadTemples();
    } else if (access != LocationAccess.available) {
      locationAccess.value = access;
    }
  }

  /// Gets the device position, showing the system permission prompt if it
  /// hasn't been answered yet. Returns false if no position is available.
  Future<bool> ensurePosition() async {
    try {
      position = await location.currentPosition();
    } catch (_) {
      final access = await location.currentAccess();
      // Granted but no fix (e.g. timeout): offer to try again.
      locationAccess.value =
          access == LocationAccess.available
              ? LocationAccess.needsPermission
              : access;
      return false;
    }
    locationAccess.value = LocationAccess.available;
    return true;
  }

  /// "Allow location" / retry: position, then nearby temples.
  Future<void> requestLocation() async {
    if (await ensurePosition()) await loadTemples();
  }

  /// Same event and defaults the Temple Explorer card used.
  Future<void> loadTemples() async {
    final pos = position;
    if (pos == null) return;
    final done = templesBloc.stream
        .firstWhere((s) => s.status != AppStatus.loading)
        .timeout(
          const Duration(seconds: 30),
          onTimeout: () => templesBloc.state,
        );
    templesBloc.add(
      GetNearbyTemplesEvent(
        latitude: pos.latitude.toString(),
        longitude: pos.longitude.toString(),
      ),
    );
    await done;
  }

  void dispose() {
    for (final feed in _feeds) {
      feed.dispose();
    }
    locationAccess.dispose();
  }
}
