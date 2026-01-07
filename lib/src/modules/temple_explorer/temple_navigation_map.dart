import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:kumbha_path/src/constant/location_service.dart';

class TempleNavigationMap extends StatefulWidget {
  final double templelat;
  final double templelng;
  final String templeName;

  const TempleNavigationMap({
    super.key,
    required this.templelat,
    required this.templelng,
    required this.templeName,
  });

  @override
  State<TempleNavigationMap> createState() => _TempleNavigationMapState();
}

class _TempleNavigationMapState extends State<TempleNavigationMap> {
  GoogleMapController? _mapController;
  LatLng? _userLocation;

  final Set<Polyline> _polylines = {};
  String? distance;
  String? duration;

  @override
  void initState() {
    super.initState();
    _getUserLocation();
    // _init();
  }

  Future<void> _getUserLocation() async {
    final position = await LocationService.getCurrentLocation();
    setState(() {
      _userLocation = LatLng(position.latitude, position.longitude);
    });
  }

  // Future<void> _init() async {
  //   final position = await LocationService.getCurrentLocation();
  //   _userLocation = LatLng(position.latitude, position.longitude);
  //   await _fetchRoute();
  //   setState(() {});
  // }

  Future<void> _fetchRoute() async {
    final origin = "${_userLocation!.latitude},${_userLocation!.longitude}";
    final destination = "${widget.templelat},${widget.templelng}";

    final url =
        "https://maps.googleapis.com/maps/api/directions/json?"
        "origin=$origin&destination=$destination&mode=driving"
        "&key=AIzaSyDrCtJ_iPEwBypNyXMyAL_Vet0nrnVa9ZQ";

    final response = await http.get(Uri.parse(url));
    final data = json.decode(response.body);
    print("Directions status: ${data['status']}");
print("Routes count: ${data['routes']?.length}");

    if (data['status'] != 'OK') return;

    // distance & duration
    final leg = data['routes'][0]['legs'][0];
    distance = leg['distance']['text'];
    duration = leg['duration']['text'];

    // polyline
    final points = data['routes'][0]['overview_polyline']['points'];
    final String encodedPolyline =
        data['routes'][0]['overview_polyline']['points'];

    final List<PointLatLng> decodedPoints = PolylinePoints.decodePolyline(
      encodedPolyline,
    );

    final polylineCoordinates =
        decodedPoints.map((e) => LatLng(e.latitude, e.longitude)).toList();


    setState(() {
      _polylines.clear();
      _polylines.add(
        Polyline(
          polylineId: const PolylineId("route"),
          color: Colors.blue,
          width: 6,
          points: polylineCoordinates,
        ),
      );
    });

    _zoomToFit();

  }

  void _zoomToFit() {
    final bounds = LatLngBounds(
      southwest: LatLng(
        math.min(_userLocation!.latitude, widget.templelat),
        math.min(_userLocation!.longitude, widget.templelng),
      ),
      northeast: LatLng(
        math.max(_userLocation!.latitude, widget.templelat),
        math.max(_userLocation!.longitude, widget.templelng),
      ),
    );

  _mapController?.animateCamera(
  CameraUpdate.newLatLngBounds(bounds, 120),
);

  }

  @override
  Widget build(BuildContext context) {
    if (_userLocation == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final templeLatLng = LatLng(widget.templelat, widget.templelng);

    return Scaffold(
      appBar: AppBar(title: Text(widget.templeName)),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _userLocation!,
              zoom: 14,
            ),
            myLocationEnabled: true,
            markers: {
              Marker(
                markerId: const MarkerId("user"),
                position: _userLocation!,
              ),
              Marker(
                markerId: const MarkerId("temple"),
                position: templeLatLng,
              ),
            },
            polylines: _polylines,
            onMapCreated: (controller) async {
              _mapController = controller;
              await _fetchRoute(); // ✅ now map exists
            },
            // onMapCreated: (controller) => _mapController = controller,
          ),

          // DISTANCE CARD
          if (distance != null && duration != null)
            Positioned(
              bottom: 20,
              left: 16,
              right: 16,
              child: Card(
                elevation: 6,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Distance: $distance",
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        "ETA: $duration",
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
