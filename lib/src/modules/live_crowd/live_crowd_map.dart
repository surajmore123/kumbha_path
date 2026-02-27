import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:kumbha_path/main_layout.dart';
import 'package:kumbha_path/src/bloc/app_details_bloc/app_details_bloc.dart';
import 'package:kumbha_path/src/bloc/app_details_bloc/app_details_event.dart';
import 'package:kumbha_path/src/bloc/app_details_bloc/app_details_state.dart';

import 'package:kumbha_path/src/constant/app_color.dart';

import 'package:kumbha_path/src/constant/app_responsive.dart';
import 'package:kumbha_path/src/constant/language_helper.dart';
import 'package:kumbha_path/src/constant/time_formator.dart';
import 'package:kumbha_path/src/models/featured_model.dart';
import 'package:kumbha_path/src/models/quick_alert.dart';
import 'package:kumbha_path/src/models/zone_model.dart';

class LiveCrowdMap extends StatefulWidget {
  const LiveCrowdMap({super.key});

  @override
  State<LiveCrowdMap> createState() => _LiveCrowdMapState();
}

class _LiveCrowdMapState extends State<LiveCrowdMap> {
  GoogleMapController? _mapController;
  Color getStatusColor(String status) {
    switch (status) {
      case "LOW":
        return Colors.green;
      case "MEDIUM":
        return Colors.yellow;
      case "HIGH":
        return Colors.orange;
      case "CRITICAL":
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  void _fitAllMarkers(List<ZoneModel> zones) {
    if (_mapController == null || zones.isEmpty) return;

    double minLat = zones.first.latitude!;
    double maxLat = zones.first.latitude!;
    double minLng = zones.first.longitude!;
    double maxLng = zones.first.longitude!;

    for (var z in zones) {
      if (z.latitude! < minLat) minLat = z.latitude!;
      if (z.latitude! > maxLat) maxLat = z.latitude!;
      if (z.longitude! < minLng) minLng = z.longitude!;
      if (z.longitude! > maxLng) maxLng = z.longitude!;
    }

    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        ),
        80,
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    context.read<AppDetailsBloc>().add(CrowdLiveStatusEvent());
    context.read<AppDetailsBloc>().add(QuickAlertsEvent());
    context.read<AppDetailsBloc>().add(FeaturedEvent());
  }

  void _showZoneDetailsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return BlocBuilder<AppDetailsBloc, AppDetailsState>(
          builder: (context, state) {
            final details = state.zoneDetails;

            if (state.status == AppDetailsStatus.loading) {
              return const SizedBox(
                height: 250,
                child: Center(child: CircularProgressIndicator()),
              );
            }

            if (details.zone == null) {
              return const SizedBox(
                height: 250,
                child: Center(child: Text("No data available")),
              );
            }

            final zone = details.zone!;

            return Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    zone.name ?? "",
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text("Capacity: ${zone.capacity}"),
                  Text("People: ${zone.totalPeople}"),
                  Text(
                    "Occupancy: ${zone.occupancyPercent?.toStringAsFixed(1)}%",
                  ),
                  const SizedBox(height: 12),

                  // 🔥 Alerts Section
                  if (details.alerts != null && details.alerts!.isNotEmpty) ...[
                    const Text(
                      "Alerts",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    ...details.alerts!.map(
                      (a) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.warning, color: Colors.red),
                        title: Text(a.title ?? ""),
                        subtitle: Text(a.severity ?? ""),
                      ),
                    ),
                  ],

                  const SizedBox(height: 16),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final isMobile = context.isMobile;
    final isTablet = context.isTablet;
    final isDesktop = context.isDesktop;

    return MainLayout(
      showDefaultBottom: true,
      ctx: 0,
      appBar: AppBar(
        backgroundColor: theme.appBarTheme.backgroundColor ?? cs.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: cs.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          LanguageHelper.t('live_crowd_location'),
          style: theme.textTheme.titleMedium?.copyWith(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: cs.onSurface,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: IconButton(
              onPressed: () {
                Navigator.pushNamed(context, '/notifications');
              },
              icon: Icon(Icons.notifications_none, color: cs.onSurface),
            ),
          ),
        ],
      ),
      body: ValueListenableBuilder<String>(
        valueListenable: LanguageHelper.currentLang,
        builder: (context, lang, _) {
          final titleStyle = theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
            fontSize:
                isMobile
                    ? 26
                    : isTablet
                    ? 30
                    : 32,
            color: cs.onBackground,
          );

          final subtitleStyle = theme.textTheme.bodyMedium?.copyWith(
            fontSize: isMobile ? 13 : 14,
            color: cs.onBackground.withOpacity(0.72),
          );

          return BlocBuilder<AppDetailsBloc, AppDetailsState>(
            builder: (context, state) {
              final quickAlerts = state.quickAlerts;
              final featuredEvent = state.eventDetailsModel;
              Set<Marker> markers = {};
              Set<Circle> circles = {};

              for (var zone in state.zoneModel) {
                if (zone.latitude == null || zone.longitude == null) continue;

                print(
                  '#########Zone ${zone.name}: Lat ${zone.latitude}, Lng ${zone.longitude}, Status ${zone.status}',
                );

                final color = getStatusColor(zone.status.toString());
                print('@@@@@Status: ${zone.status}, Color: $color');
                final position = LatLng(zone.latitude!, zone.longitude!);

                markers.add(
                  Marker(
                    markerId: MarkerId(zone.code ?? ""),
                    position: position,
                    icon: BitmapDescriptor.defaultMarkerWithHue(
                      zone.status == "LOW"
                          ? BitmapDescriptor.hueGreen
                          : zone.status == "MEDIUM"
                          ? BitmapDescriptor.hueYellow
                          : zone.status == "HIGH"
                          ? BitmapDescriptor.hueOrange
                          : BitmapDescriptor.hueRed,
                    ),
                    onTap: () {
                      context.read<AppDetailsBloc>().add(
                        GetZoneDetailEvent(zoneCode: zone.code ?? ""),
                      );
                      _showZoneDetailsSheet(context);
                    },
                    infoWindow: InfoWindow(
                      title: zone.name ?? "",
                      snippet:
                          "People: ${zone.totalPeople ?? 0}\n${(zone.occupancyPercent ?? 0).toStringAsFixed(1)}%",
                    ),
                  ),
                );

                circles.add(
                  Circle(
                    circleId: CircleId(zone.code ?? ""),
                    center: position,
                    radius: 30,
                    fillColor: color.withOpacity(0.25),
                    strokeColor: color,
                    strokeWidth: 2,
                  ),
                );
              }
              return Container(
                color: theme.scaffoldBackgroundColor,
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal:
                        isMobile
                            ? 16
                            : isTablet
                            ? 32
                            : 56,
                    vertical: isMobile ? 8 : 16,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: isDesktop ? 520 : 480,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 10),

                        Text(
                          LanguageHelper.t('live_crowd_title'),
                          style: titleStyle,
                        ),

                        const SizedBox(height: 16),

                        // ========== MAP IMAGE ==========
                        Card(
                          color: Colors.white,
                          elevation: 1.5,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Center(
                            child: SizedBox(
                              width: double.infinity,
                              height: isMobile ? 250 : 300,
                              child: GoogleMap(
                                initialCameraPosition: CameraPosition(
                                  target:
                                      state.zoneModel.isNotEmpty
                                          ? LatLng(
                                            state.zoneModel.first.latitude!,
                                            state.zoneModel.first.longitude!,
                                          )
                                          : const LatLng(20.008314, 73.790856),
                                  zoom: 14,
                                ),
                                onMapCreated: (controller) {
                                  _mapController = controller;
                                  _fitAllMarkers(state.zoneModel);
                                },
                                gestureRecognizers: {
                                  Factory<OneSequenceGestureRecognizer>(
                                    () => EagerGestureRecognizer(),
                                  ),
                                },
                                zoomControlsEnabled: true,
                                scrollGesturesEnabled: true,
                                zoomGesturesEnabled: true,
                                markers: markers,
                                circles: circles,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // ========== BOTTOM SHEET STYLE PANEL ==========
                        Container(
                          decoration: BoxDecoration(
                            color: cs.surface,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: cs.shadow.withOpacity(0.06),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // drag handle
                                Center(
                                  child: Container(
                                    width: 40,
                                    height: 4,
                                    margin: const EdgeInsets.only(bottom: 12),
                                    decoration: BoxDecoration(
                                      color: cs.outline.withOpacity(0.16),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                ),

                                Text(
                                  LanguageHelper.t('live_crowd_quick_alerts'),
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    fontSize: isMobile ? 16 : 18,
                                    color: cs.onSurface,
                                  ),
                                ),

                                const SizedBox(height: 14),

                                // ========== NEXT SNAN SCHEDULE CARD ==========
                                _ScheduleAlertCard(
                                  eventDetailsModel: featuredEvent,
                                  subtitleStyle: subtitleStyle,
                                ),

                                const SizedBox(height: 12),
                                if (quickAlerts != null &&
                                    quickAlerts.isNotEmpty) ...[
                                  ...quickAlerts.map(
                                    (alert) => _QuickAlertCard(alert: alert),
                                  ),
                                ] else ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    "No active alerts",
                                    style: subtitleStyle,
                                  ),
                                ],

                                // // ========== TRAFFIC ALERT ==========
                                // _AlertCard(
                                //   categoryKey: 'live_crowd_traffic_category',
                                //   titleKey: 'live_crowd_traffic_title',
                                //   descriptionKey:
                                //       'live_crowd_traffic_description',
                                //   imagePath: 'assets/images/kashi.png',
                                //   // map categoryColor to theme primary variant
                                //   categoryColor: cs.primary,
                                //   subtitleStyle: subtitleStyle,
                                // ),

                                // const SizedBox(height: 12),

                                // // ========== CROWD ALERT ==========
                                // _AlertCard(
                                //   categoryKey: 'live_crowd_crowd_category',
                                //   titleKey: 'live_crowd_crowd_title',
                                //   descriptionKey:
                                //       'live_crowd_crowd_description',
                                //   imagePath: 'assets/images/kashi.png',
                                //   categoryColor: cs.secondary,
                                //   subtitleStyle: subtitleStyle,
                                // ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _QuickAlertCard extends StatelessWidget {
  final AlertDetailsModel alert;

  const _QuickAlertCard({required this.alert});

  Color _getSeverityColor(String? severity) {
    switch (severity) {
      case "LOW":
        return Colors.green;
      case "MEDIUM":
        return Colors.orange;
      case "HIGH":
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getTypeIcon(String? type) {
    switch (type) {
      case "TRAFFIC":
        return Icons.traffic;
      case "CROWD":
        return Icons.groups;
      default:
        return Icons.warning;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = _getSeverityColor(alert.severity);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(_getTypeIcon(alert.type), color: color, size: 22),
          ),

          const SizedBox(width: 12),

          // Text Section
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Zone + Severity
                Text(
                  "${alert.zoneName} • ${alert.severity}",
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),

                const SizedBox(height: 4),

                // Title
                Text(
                  alert.title ?? "",
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: cs.onBackground,
                  ),
                ),

                const SizedBox(height: 4),

                // Description
                Text(
                  alert.description ?? "",
                  style: Theme.of(context).textTheme.bodySmall,
                ),

                const SizedBox(height: 6),

                // Start Time
                Text(
                  DateTimeHelper.formatAlertTime(alert.startTime),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: cs.onBackground.withOpacity(0.6),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
// =================== SCHEDULE CARD ===================

class _ScheduleAlertCard extends StatelessWidget {
  final TextStyle? subtitleStyle;
  final EventDetailsModel eventDetailsModel;

  const _ScheduleAlertCard({
    this.subtitleStyle,
    required this.eventDetailsModel,
  });

  @override
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.orange.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          // icon circle
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: cs.primaryContainer.withOpacity(0.22),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(Icons.access_time_rounded, color: cs.primary, size: 22),
          ),
          const SizedBox(width: 12),
          // text
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  LanguageHelper.t('live_crowd_next_snan_label'),
                  style: subtitleStyle?.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: cs.onBackground.withOpacity(0.64),
                  ),
                ),
                const SizedBox(height: 4),
                 Text(
                      DateTimeHelper.formatAlertTime(
                        eventDetailsModel.eventDate,
                      ),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: cs.onBackground.withOpacity(0.6),
                    fontSize: 12,
                  ),
                    ),
                    const SizedBox(height: 4),
                Text(
                  eventDetailsModel.eventName ?? "",
                 style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: cs.onBackground,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}


