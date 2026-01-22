import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:kumbha_path/src/constant/api_constatnt.dart';
import 'package:kumbha_path/src/constant/location_service.dart';
import 'package:url_launcher/url_launcher.dart';

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
  
  bool _navigationStarted = false;
final apiKey = ApiConst.googleMapsKey;
  GoogleMapController? _mapController;
  LatLng? _userLocation;
  String _travelMode = 'driving';
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
        "origin=$origin&destination=$destination&mode=$_travelMode&"
        "&key=$apiKey";

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

    _mapController?.animateCamera(CameraUpdate.newLatLngBounds(bounds, 120));
  }

  Future<void> _startNavigation() async {
    final url =
        "https://www.google.com/maps/dir/?api=1"
        "&origin=${_userLocation!.latitude},${_userLocation!.longitude}"
        "&destination=${widget.templelat},${widget.templelng}"
        "&travelmode=$_travelMode";

    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    if (_userLocation == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final templeLatLng = LatLng(widget.templelat, widget.templelng);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: null,
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _userLocation!,
              zoom: 14,
            ),
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            markers: {
              // Marker(
              //   markerId: const MarkerId("user"),
              //   position: _userLocation!,
              // ),
              Marker(
                markerId: const MarkerId("temple"),
                position: templeLatLng,
                icon: BitmapDescriptor.defaultMarkerWithHue(
                  BitmapDescriptor.hueRed,
                ),
              ),
            },
            polylines: _polylines,
            onMapCreated: (controller) async {
              _mapController = controller;
              await _fetchRoute(); // ✅ now map exists
            },
            // onMapCreated: (controller) => _mapController = controller,
          ),

          if (!_navigationStarted)
            Positioned(
              bottom: 120,
              left: 16,
              right: 16,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _modeChip(Icons.directions_car, 'driving'),
                  // _modeChip(Icons.directions_bus, 'transit'),
                  _modeChip(Icons.directions_walk, 'walking'),
                ],
              ),
            ),

          Positioned(
            right: 16,
            bottom: 160,
            child: FloatingActionButton(
              mini: true,
              onPressed: () {
                _mapController?.animateCamera(
                  CameraUpdate.newLatLng(_userLocation!),
                );
              },
              child: const Icon(Icons.my_location),
            ),
          ),

          // DISTANCE CARD
          if (distance != null && duration != null)
            Positioned(
              bottom: 20,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "$duration • $distance",
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          _travelMode.toUpperCase(),
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),

                    ElevatedButton.icon(
                      onPressed: _startNavigation,
                      icon: const Icon(Icons.navigation),
                      label: const Text("Start"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _modeChip(IconData icon, String mode) {
    final bool isSelected = _travelMode == mode;

    return GestureDetector(
      onTap: () {
        setState(() {
          _travelMode = mode;
        });
        _fetchRoute(); // refetch route on mode change
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue : Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 6),
          ],
        ),
        child: Icon(icon, color: isSelected ? Colors.white : Colors.black87),
      ),
    );
  }
}



