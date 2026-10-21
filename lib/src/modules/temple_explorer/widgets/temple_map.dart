import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:kumbha_path/src/components/maps/app_map.dart';

export 'package:kumbha_path/src/components/maps/app_map.dart';

/// Temple Explorer names for the shared map (kept for existing code).
typedef TempleMap = AppMap;
typedef TempleMapConfig = AppMapConfig;
typedef TempleMapBuilder = AppMapBuilder;

/// See [parseLatLng].
LatLng? parseTempleLatLng(Object? lat, Object? lng) => parseLatLng(lat, lng);
