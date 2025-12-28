import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:kumbha_path/main_layout.dart';
import 'package:kumbha_path/src/bloc/app_details_bloc/app_details_bloc.dart';
import 'package:kumbha_path/src/bloc/app_details_bloc/app_details_event.dart';
import 'package:kumbha_path/src/bloc/main_bloc/app_bloc.dart';
import 'package:kumbha_path/src/bloc/main_bloc/app_event.dart';
import 'package:kumbha_path/src/bloc/main_bloc/app_state.dart';

import 'package:kumbha_path/src/constant/app_color.dart';
import 'package:kumbha_path/src/constant/app_responsive.dart';
import 'package:kumbha_path/src/constant/language_helper.dart';
import 'package:kumbha_path/src/constant/location_service.dart';

class NearTemples extends StatefulWidget {
  const NearTemples({super.key});

  @override
  State<NearTemples> createState() => _NearTemplesState();
}

class _NearTemplesState extends State<NearTemples> {
  int selectedRadius = 5;
  bool _locationInitialized = false;
  late String userLat;
  late String userLng;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_locationInitialized) return;

    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;

    if (args != null && args['lat'] != null && args['lng'] != null) {
      userLat = args['lat'];
      userLng = args['lng'];
    } else {
      final state = context.read<AppBloc>().state;

      if (state.lastUserLat != null && state.lastUserLng != null) {
        userLat = state.lastUserLat!;
        userLng = state.lastUserLng!;
      } else {
        _requestLocationAgain();
        return;
      }
    }

    _locationInitialized = true;
  }

  Future<void> _requestLocationAgain() async {
    final position = await LocationService.getCurrentLocation();

    userLat = position.latitude.toString();
    userLng = position.longitude.toString();

    context.read<AppBloc>().add(
      GetNearbyTemplesEvent(
        latitude: userLat,
        longitude: userLng,
        radius: selectedRadius.toString(),
        limit: 5,
      ),
    );

    _locationInitialized = true;
  }

  void _changeRadius(int radius) {
    setState(() => selectedRadius = radius);

    context.read<AppBloc>().add(
      GetNearbyTemplesEvent(
        latitude: userLat,
        longitude: userLng,
        radius: radius.toString(),
        limit: 5,
      ),
    );
  }

  void _showRadiusSelector() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder:
          (_) => Column(
            mainAxisSize: MainAxisSize.min,
            children:
                [2, 5, 10].map((km) {
                  return ListTile(
                    title: Text("$km km radius"),
                    trailing:
                        selectedRadius == km ? const Icon(Icons.check) : null,
                    onTap: () {
                      Navigator.pop(context);
                      _changeRadius(km);
                    },
                  );
                }).toList(),
          ),
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
        backgroundColor: cs.surface,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: cs.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Nearby Temples",
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: GestureDetector(
              onTap: _showRadiusSelector,
              child: Chip(
                label: Text("$selectedRadius km"),
                avatar: const Icon(Icons.tune, size: 18),
              ),
            ),
          ),
        ],
      ),
      body: ValueListenableBuilder<String>(
        valueListenable: LanguageHelper.currentLang,
        builder: (context, lang, _) {
          final titleStyle = Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
            fontSize:
                isMobile
                    ? 18
                    : isTablet
                    ? 20
                    : 22,
          );

          final subtitleStyle = Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(
            fontSize: isMobile ? 13 : 14,
            color: Colors.grey[700],
            height: 1.4,
          );
          return BlocBuilder<AppBloc, AppState>(
            builder: (context, state) {
              if (state.status == AppStatus.loading) {
                return const Center(child: CircularProgressIndicator());
              }

              final temples = state.nearbyTemples?.temples ?? [];

              if (temples.isEmpty) {
                return const Center(child: Text("No nearby temples found"));
              }

              return ListView(
                padding: EdgeInsets.symmetric(
                  horizontal:
                      isMobile
                          ? 16
                          : isTablet
                          ? 32
                          : 56,
                  vertical: isMobile ? 16 : 24,
                ),
                children: [
                  Card(
                    color: Colors.white,
                    elevation: 1.5,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Center(
                        child: SizedBox(
                          width: isMobile ? 260 : 300,
                          height: isMobile ? 260 : 300,
                          child: ClipOval(
                            child: Image.asset(
                              'assets/images/map_circle.png',
                              fit: BoxFit.cover, // fills the circle
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),
                  ...temples.map(
                    (temple) => Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: _TempleCard(
                        title: temple.name ?? '',
                        distanceaway:
                            "${temple.distanceKm?.toStringAsFixed(2)} km away",
                        crowdLevel:
                            " Crowd Level : ${temple.crowdLevel.toString()}",
                        imagePath:
                            temple.imageUrl ?? 'assets/images/placeholder.jpg',
                        onTap: () {
                          context.read<AppDetailsBloc>().add(
                            GetTempleDetail(
                              templeId: temple.templeId.toString(),
                            ),
                          );
                          Navigator.pushNamed(context, '/templeDetail');

                          // Navigator.pushNamed(
                          //   context,
                          //   '/templeDetail',
                          //   arguments: temple,
                          // );
                        },
                      ),
                    ),
                  ),

                  if (temples.length < (state.nearbyTemples.count ?? 0))
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: ElevatedButton(
                        onPressed: () {
                          context.read<AppBloc>().add(
                            GetNearbyTemplesEvent(
                              latitude: userLat,
                              longitude: userLng,
                              radius: selectedRadius.toString(),
                              limit: 5,
                              isLoadMore: true,
                            ),
                          );
                        },
                        child: const Text("Load More"),
                      ),
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _TempleCard extends StatelessWidget {
  final String title;
  final String distanceaway;
  final String crowdLevel;
  final String imagePath;
  final VoidCallback? onTap;

  const _TempleCard({
    required this.title,
    required this.distanceaway,
    required this.crowdLevel,
    required this.imagePath,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        gradient: buildThemeGradient(context, isPrimary: true),
        borderRadius: BorderRadius.circular(18),
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          // TEXT
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: cs.onPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  distanceaway,
                  style: TextStyle(
                    color: cs.onPrimary.withOpacity(0.85),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 6),

                Text(
                  crowdLevel,
                  style: TextStyle(
                    color: cs.onPrimary.withOpacity(0.85),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 6),

                Align(
                  alignment: Alignment.centerLeft,
                  child: ElevatedButton(
                    onPressed: onTap,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: cs.onPrimary,
                      foregroundColor: cs.primary,
                      shape: const StadiumBorder(),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 8,
                      ),
                    ),
                    child: const Text("Learn More"),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 12),

          // IMAGE
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Image.network(
              imagePath,
              width: 80,
              height: 80,
              fit: BoxFit.cover,
              errorBuilder:
                  (_, __, ___) => Image.asset(
                    'assets/images/placeholder.png',
                    width: 80,
                    height: 80,
                    fit: BoxFit.cover,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
