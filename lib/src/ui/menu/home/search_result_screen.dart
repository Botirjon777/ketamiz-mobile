import 'package:flutter/material.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:lottie/lottie.dart';
import 'package:ketamiz/src/bloc/home_bloc.dart';
import 'package:ketamiz/src/model/api/trip_list_model.dart';
import 'package:ketamiz/src/ui/menu/home/trip_details_screen.dart';
import 'package:ketamiz/src/ui/widgets/containers/destinations_container.dart';
import 'package:ketamiz/src/ui/widgets/containers/leading_back.dart';
import 'package:ketamiz/src/utils/utils.dart';
import 'package:shimmer/shimmer.dart';
import '../../../lan_localization/load_places.dart';
import '../../../model/api/trip_search_model.dart';
import '../../../model/location_model.dart';
import '../../../theme/app_theme.dart';
import '../../widgets/texts/text_16h_500w.dart';

class SearchResultScreen extends StatefulWidget {
  const SearchResultScreen({
    super.key,
    required this.trip,
    this.isRoundTrip = false,
    this.requiredSeats = 1,
    this.parcelOnly = false,
  });

  final TripListModel trip;
  final bool isRoundTrip;
  final int requiredSeats;

  /// Only show trips that accept parcels (driven by the home parcel toggle).
  final bool parcelOnly;

  @override
  State<SearchResultScreen> createState() => _SearchResultScreenState();
}

class _SearchResultScreenState extends State<SearchResultScreen> {
  static final _unknownLocation =
      LocationModel(id: "0", text: "", parentID: "0");

  @override
  void initState() {
    _search();
    super.initState();
  }

  void _search() {
    blocHome.fetchTripSearch(
      widget.trip.fromRegionId.toString(),
      widget.trip.toRegionId.toString(),
      widget.trip.fromCityId.toString(),
      widget.trip.toCityId.toString(),
      widget.trip.fromVillageId.toString(),
      widget.trip.toVillageId.toString(),
      widget.trip.startTime,
      widget.isRoundTrip ? widget.trip.endTime : null,
      widget.isRoundTrip,
      acceptsParcels: widget.parcelOnly,
    );
  }

  Future<void> _onRefresh() async {
    _search();
    await Future.delayed(const Duration(milliseconds: 500));
  }

  /// "Village, District, Region" — most specific part first, like the home
  /// search form shows it.
  String _placeText(int villageId, int cityId, int regionId, String fallback) {
    String lookup(List<LocationModel> list, int id) {
      if (id == 0) return '';
      return list
          .firstWhere((l) => l.id == id.toString(),
              orElse: () => _unknownLocation)
          .text;
    }

    final parts = [
      lookup(LocationData.villages, villageId),
      lookup(LocationData.cities, cityId),
      lookup(LocationData.regions, regionId),
    ].where((s) => s.isNotEmpty).toList();
    return parts.isEmpty ? fallback : parts.join(', ');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: const LeadingBack(),
        title: Text16h500w(title: translate("home.search_result")),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
      ),
      body: RefreshIndicator(
        color: AppTheme.purple,
        onRefresh: _onRefresh,
        child: StreamBuilder(
          stream: blocHome.getTripSearch,
          builder: (context, AsyncSnapshot<TripSearchModel> snapshot) {
            final List<Widget> results;
            if (snapshot.hasData) {
              // Only show trips with enough free seats for the requested
              // passenger count, and — when sending a parcel — only trips that
              // accept parcels (belt-and-braces alongside the backend filter).
              final trips = snapshot.data!.departureTrips
                  .where((t) => t.availableSeats >= widget.requiredSeats)
                  .where((t) => !widget.parcelOnly || t.acceptsParcels)
                  .toList();
              if (trips.isNotEmpty) {
                results = [
                  for (var i = 0; i < trips.length; i++) ...[
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) {
                              return TripDetailsScreen(trip: trips[i]);
                            },
                          ),
                        );
                      },
                      child: DestinationsContainer(trip: trips[i]),
                    ),
                    if (i != trips.length - 1) const SizedBox(height: 16),
                  ],
                ];
              } else {
                results = [
                  const SizedBox(height: 48),
                  Center(
                    child: Lottie.asset(
                      "assets/lottie/empty.json",
                      width: 200,
                      height: 200,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Center(
                    child:
                        Text16h500w(title: translate("ketamiz.No_trip_found")),
                  ),
                ];
              }
            } else {
              results = [
                Shimmer.fromColors(
                  baseColor: AppTheme.baseColor,
                  highlightColor: AppTheme.highlightColor,
                  child: Column(
                    children: List.generate(
                      6,
                      (_) => Container(
                        height: 150,
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: AppTheme.baseColor,
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                ),
              ];
            }
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                _buildRouteCard(),
                const SizedBox(height: 16),
                ...results,
              ],
            );
          },
        ),
      ),
    );
  }

  // ── Route summary card — mirrors the home screen search card ─────────────

  Widget _buildRouteCard() {
    // Prefer the exact names captured from the backend-driven picker
    // (fromWhere/toWhere); fall back to a local lookup only if absent.
    final fromText = widget.trip.fromWhere.isNotEmpty
        ? widget.trip.fromWhere
        : _placeText(widget.trip.fromVillageId, widget.trip.fromCityId,
            widget.trip.fromRegionId, '');
    final toText = widget.trip.toWhere.isNotEmpty
        ? widget.trip.toWhere
        : _placeText(widget.trip.toVillageId, widget.trip.toCityId,
            widget.trip.toRegionId, '');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            offset: const Offset(0, 4),
            blurRadius: 20,
            spreadRadius: 0,
            color: AppTheme.black.withOpacity(0.05),
          ),
        ],
      ),
      child: Column(
        children: [
          _routeRow(
            leading: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                border: Border.all(color: AppTheme.purple, width: 2),
              ),
            ),
            text: fromText,
          ),
          Container(
            height: 1,
            margin: const EdgeInsets.only(left: 28, top: 12, bottom: 12),
            color: AppTheme.border,
          ),
          _routeRow(
            leading: const Icon(
              Icons.location_on_rounded,
              color: AppTheme.purple,
              size: 16,
            ),
            text: toText,
          ),
          const SizedBox(height: 14),
          // Date + passengers summary
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.light,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.calendar_today_outlined,
                  color: AppTheme.dark,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  Utils.searchDateFormat(widget.trip.startTime),
                  style: const TextStyle(
                    color: AppTheme.dark,
                    fontSize: 13,
                    fontFamily: AppTheme.fontFamily,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                const Icon(
                  Icons.person_outline_rounded,
                  color: AppTheme.dark,
                  size: 18,
                ),
                const SizedBox(width: 6),
                Text(
                  "${widget.requiredSeats} ${translate(widget.requiredSeats == 1 ? "home.passenger" : "home.passengers")}",
                  style: const TextStyle(
                    color: AppTheme.dark,
                    fontSize: 13,
                    fontFamily: AppTheme.fontFamily,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _routeRow({required Widget leading, required String text}) {
    return Row(
      children: [
        SizedBox(width: 16, child: Center(child: leading)),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppTheme.black,
              fontSize: 15,
              fontFamily: AppTheme.fontFamily,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}
