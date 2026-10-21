import 'package:geolocator/geolocator.dart';

class LocationService {
  static Future<Position> getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Location services are disabled');
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception('Location permission permanently denied');
    }

    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }
}

/// Whether the device location can be used, and why not.
enum LocationAccess {
  /// Not yet checked.
  checking,

  /// Permission granted and position known.
  available,

  /// Never asked, or denied once: the user can be asked.
  needsPermission,

  /// Services off or permanently denied: only device settings can fix it.
  unavailable,
}

/// Thin wrapper over the existing [LocationService] / geolocator, so the
/// features can check permission without prompting (and tests can fake it).
class LocationGateway {
  const LocationGateway();

  Future<LocationAccess> currentAccess() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return LocationAccess.unavailable;
      }
      return switch (await Geolocator.checkPermission()) {
        LocationPermission.always ||
        LocationPermission.whileInUse => LocationAccess.available,
        LocationPermission.deniedForever => LocationAccess.unavailable,
        _ => LocationAccess.needsPermission,
      };
    } catch (_) {
      return LocationAccess.unavailable;
    }
  }

  /// May show the system permission prompt.
  Future<Position> currentPosition() => LocationService.getCurrentLocation();

  /// Whether the device's location services (GPS) are switched on.
  Future<bool> servicesEnabled() async {
    try {
      return await Geolocator.isLocationServiceEnabled();
    } catch (_) {
      return false;
    }
  }

  /// Opens the system screen that fixes [LocationAccess.unavailable]:
  /// location settings when services are off, otherwise app settings
  /// (permission permanently denied). Returns false if it couldn't open.
  Future<bool> openSettings() async {
    try {
      return await servicesEnabled()
          ? await Geolocator.openAppSettings()
          : await Geolocator.openLocationSettings();
    } catch (_) {
      return false;
    }
  }
}
