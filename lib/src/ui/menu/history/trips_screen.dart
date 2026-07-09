import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:lottie/lottie.dart';
import 'package:ketamiz/src/bloc/history_bloc.dart';
import 'package:ketamiz/src/bloc/ketamiz_bloc.dart';
import 'package:ketamiz/src/model/api/book_model.dart';
import 'package:ketamiz/src/model/api/driver_trips_list_model.dart';
import 'package:ketamiz/src/model/api/trip_list_model.dart';
import 'package:ketamiz/src/theme/app_theme.dart';
import 'package:ketamiz/src/ui/menu/home/booked_trip_details_screen.dart';
import 'package:ketamiz/src/ui/menu/home/trip_details_screen.dart';
import 'package:ketamiz/src/ui/menu/new_ketamiz/add_docs_screen.dart';
import 'package:ketamiz/src/ui/menu/new_ketamiz/create_new_ketamiz_screen.dart';
import 'package:ketamiz/src/ui/widgets/buttons/app_dropdown.dart';
import 'package:ketamiz/src/utils/nav_constants.dart';
import 'package:ketamiz/src/ui/widgets/buttons/secondary_button.dart';
import 'package:ketamiz/src/ui/menu/parcels/my_parcels_view.dart';
import 'package:ketamiz/src/ui/widgets/containers/destinations_container.dart';
import 'package:ketamiz/src/ui/widgets/containers/history_container.dart';
import 'package:ketamiz/src/ui/widgets/texts/text_14h_400w.dart';
import 'package:ketamiz/src/ui/widgets/texts/text_16h_500w.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shimmer/shimmer.dart';

class TripsScreen extends StatefulWidget {
  const TripsScreen({super.key});

  @override
  State<TripsScreen> createState() => _TripsScreenState();
}

class _TripsScreenState extends State<TripsScreen> {
  bool _asDriver = false;
  // 0=All, 1=InProgress, 2=Completed, 3=Canceled
  int _filterIndex = 0;
  // Client sub-tab: 0=Trips (bookings), 1=Parcels.
  int _clientTab = 0;

  /// Top padding for the client lists so content clears the overlay header.
  /// The header is taller on the Trips sub-tab (it also shows the status
  /// filter, which doesn't apply to parcels).
  double get _clientTopPad => _clientTab == 0 ? 200 : 150;

  bool _isDocsAdded = false;
  bool _isDocsVerified = false;
  bool _roleLoaded = false;

  static const _driverStatuses = ['all', 'active', 'completed', 'canceled'];

  @override
  void initState() {
    super.initState();
    _loadUserState();
  }

  Future<void> _loadUserState() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    final isDriver = prefs.getString('role') == 'driver';
    setState(() {
      _isDocsAdded = prefs.getBool('isDocsAdded') ?? false;
      _isDocsVerified =
          prefs.getString('driving_verification_status') == 'approved';
      _asDriver = isDriver;
      _roleLoaded = true;
    });
    _fetch();
  }

  void _fetch() {
    if (_asDriver) {
      if (_isDocsVerified) {
        if (_filterIndex == 0) {
          // /driver/trips omits nested vehicle/location data; fetch per-status
          // endpoints in parallel to get complete records for every trip.
          blocKetamiz.fetchAllDriverTrips();
        } else {
          blocKetamiz.fetchDriverTripList(_driverStatuses[_filterIndex]);
        }
      }
    } else {
      blocHistory.fetchBookingsByStatus(_filterIndex);
    }
  }

  Future<void> _onRefresh() async {
    _fetch();
    await Future.delayed(const Duration(milliseconds: 500));
  }

  void _switchRole(bool asDriver) {
    if (_asDriver == asDriver) return;
    setState(() {
      _asDriver = asDriver;
      _filterIndex = 0;
    });
    _fetch();
  }

  void _selectFilter(int index) {
    if (_filterIndex == index) return;
    setState(() => _filterIndex = index);
    _fetch();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text16h500w(title: translate('history.history')),
        centerTitle: true,
      ),
      // SizedBox.expand keeps the Stack full-screen even when its content is
      // short (e.g. one trip card), so the Positioned create button always
      // anchors to the screen bottom, right above the nav bar.
      body: SizedBox.expand(
        child: Stack(
          children: [
            if (!_roleLoaded)
              const Center(
                child: CircularProgressIndicator(color: AppTheme.black),
              )
            else if (_asDriver)
              _buildDriverContent()
            else
              _buildClientContent(),
            _buildHeader(),
            if (_asDriver) _buildCreateTripButton(),
          ],
        ),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 16),
        // Role toggle
        Container(
          padding: const EdgeInsets.all(6),
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(
                offset: const Offset(0, 5),
                blurRadius: 100,
                spreadRadius: 0,
                color: Colors.black.withValues(alpha: 0.15),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: _buildRoleTab(true, translate('history.as_driver')),
              ),
              Expanded(
                child: _buildRoleTab(false, translate('history.as_client')),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // Client-only sub-tabs: their trips (bookings) vs. their parcels.
        if (!_asDriver) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _buildClientTabs(),
          ),
          const SizedBox(height: 8),
        ],
        // Status filter applies to trips only (driver trips, or client bookings).
        if (_asDriver || _clientTab == 0)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: AppDropdown<int>(
              value: _filterIndex,
              onChanged: _selectFilter,
              items: [
                AppDropdownItem(
                  value: 0,
                  label: translate('history.all'),
                  color: AppTheme.gray,
                ),
                AppDropdownItem(
                  value: 1,
                  label: translate('history.in_progress'),
                  color: AppTheme.purple,
                ),
                AppDropdownItem(
                  value: 2,
                  label: translate('history.completed'),
                  color: const Color(0xFF4CAF50),
                ),
                AppDropdownItem(
                  value: 3,
                  label: translate('history.canceled'),
                  color: const Color(0xFFE53935),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildClientTabs() {
    Widget tab(int index, String label) {
      final active = _clientTab == index;
      return Expanded(
        child: GestureDetector(
          onTap: () {
            if (_clientTab == index) return;
            setState(() => _clientTab = index);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 9),
            decoration: BoxDecoration(
              color: active ? AppTheme.purple : AppTheme.light,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: active ? AppTheme.purple : AppTheme.border,
              ),
            ),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: active ? Colors.white : AppTheme.dark,
              ),
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        tab(0, translate('history.my_trips')),
        const SizedBox(width: 8),
        tab(1, translate('parcel.my_parcels')),
      ],
    );
  }

  Widget _buildRoleTab(bool asDriver, String label) {
    final active = _asDriver == asDriver;
    return GestureDetector(
      onTap: () => _switchRole(asDriver),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: active ? AppTheme.purple : Colors.transparent,
          borderRadius: BorderRadius.circular(32),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            fontFamily: AppTheme.fontFamily,
            fontWeight: FontWeight.w500,
            color: active ? Colors.white : AppTheme.dark,
          ),
        ),
      ),
    );
  }

  // ── Client content ────────────────────────────────────────────────────────

  Widget _buildClientContent() {
    // Parcels sub-tab has its own fetch/state, independent of the trip streams.
    if (_clientTab == 1) {
      return MyParcelsView(topPadding: _clientTopPad);
    }
    return RefreshIndicator(
      color: AppTheme.black,
      onRefresh: _onRefresh,
      child: StreamBuilder<bool>(
        stream: blocHistory.getLoading,
        builder: (context, loadingSnap) {
          if (loadingSnap.data == true) {
            return const Center(
              child: CircularProgressIndicator(color: AppTheme.black),
            );
          }
          return StreamBuilder<List<BookModel>>(
            stream: blocHistory.getBookings,
            builder: (context, snap) {
              if (!snap.hasData) {
                return const Center(
                  child: CircularProgressIndicator(color: AppTheme.black),
                );
              }
              final bookings = snap.data!;
              if (bookings.isEmpty) return _buildClientEmpty();
              return ListView.builder(
                padding: EdgeInsets.only(
                  top: _clientTopPad,
                  bottom: kNavBarTotalPadding,
                  left: 16,
                  right: 16,
                ),
                itemCount: bookings.length,
                itemBuilder: (context, i) => Column(
                  children: [
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () async {
                        final cancelled = await Navigator.push<bool>(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                BookedTripDetailsScreen(booking: bookings[i]),
                          ),
                        );
                        // Refresh the list if the booking was cancelled.
                        if (cancelled == true) _fetch();
                      },
                      child: HistoryContainer(booking: bookings[i]),
                    ),
                    if (i < bookings.length - 1) const SizedBox(height: 16),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildClientEmpty() {
    return ListView(
      padding: EdgeInsets.only(top: _clientTopPad),
      children: [
        SizedBox(
          height: MediaQuery.of(context).size.height - 300,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.history,
                  size: 64, color: AppTheme.gray.withValues(alpha: 0.5)),
              const SizedBox(height: 16),
              Text14h400w(
                title: translate('history.no_trips'),
                color: AppTheme.gray,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Driver content ────────────────────────────────────────────────────────

  Widget _buildDriverContent() {
    if (!_isDocsAdded && !_isDocsVerified) return _buildAddDocsState();
    if (!_isDocsVerified) return _buildVerificationPendingState();

    return RefreshIndicator(
      color: AppTheme.purple,
      onRefresh: _onRefresh,
      child: StreamBuilder<List<DriverTripModel>>(
        stream: blocKetamiz.getTrips,
        builder: (context, snap) {
          if (!snap.hasData) return _buildShimmer();
          final trips = snap.data!;
          if (trips.isEmpty) return _buildDriverEmpty();
          return ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(
              top: 140,
              bottom: kNavBarTotalPadding,
              left: 24,
              right: 24,
            ),
            itemCount: trips.length,
            itemBuilder: (context, i) => Column(
              children: [
                GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => TripDetailsScreen(
                        trip: _toTripListModel(trips[i]),
                        isDriver: true,
                        bookings: trips[i].bookings,
                      ),
                    ),
                  ),
                  child: DestinationsContainer(trip: _toTripListModel(trips[i])),
                ),
                if (i < trips.length - 1) const SizedBox(height: 16),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildAddDocsState() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(32, 130, 32, 120),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Lottie.asset('assets/lottie/add_docs.json',
                width: 200, height: 200, fit: BoxFit.cover),
            const SizedBox(height: 24),
            Text16h500w(title: translate('ketamiz.add_docs_title')),
            const SizedBox(height: 8),
            Text(
              translate('ketamiz.add_docs_msg'),
              style: const TextStyle(
                fontSize: 14,
                color: AppTheme.gray,
                fontWeight: FontWeight.w500,
                fontFamily: AppTheme.fontFamily,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SecondaryButton(
              title: translate('ketamiz.add_docs_button'),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AddDocsScreen()),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVerificationPendingState() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(32, 130, 32, 120),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Lottie.asset('assets/lottie/waiting.json',
                width: 200, height: 200, fit: BoxFit.cover),
            const SizedBox(height: 24),
            Text16h500w(title: translate('ketamiz.verification_in_progress')),
            const SizedBox(height: 8),
            Text(
              translate('ketamiz.verification_in_progress_msg'),
              style: const TextStyle(
                fontSize: 14,
                color: AppTheme.gray,
                fontWeight: FontWeight.w500,
                fontFamily: AppTheme.fontFamily,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDriverEmpty() {
    return ListView(
      padding: const EdgeInsets.only(top: 140),
      children: [
        SizedBox(
          height: MediaQuery.of(context).size.height -
              MediaQuery.of(context).padding.top -
              300,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Lottie.asset('assets/lottie/empty.json',
                  width: 200, height: 200, fit: BoxFit.cover),
              const SizedBox(height: 24),
              Text16h500w(title: translate('ketamiz.No_trip_found')),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  translate('ketamiz.No_trip_found_msg'),
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppTheme.gray,
                    fontWeight: FontWeight.w500,
                    fontFamily: AppTheme.fontFamily,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCreateTripButton() {
    final safeBottom = MediaQuery.of(context).padding.bottom;
    return Positioned(
      bottom: kNavBarHeight + kNavBarBottomMargin + kNavBarGap + safeBottom,
      left: 16,
      right: 16,
      child: SecondaryButton(
        title: translate('ketamiz.create_new_trip'),
        onTap: () {
          if (_isDocsVerified) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => CreateNewKetamizScreen(
                  driverTrip: DriverTripModel.defaultTrip(),
                ),
              ),
            );
          } else {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AddDocsScreen()),
            );
          }
        },
      ),
    );
  }

  Widget _buildShimmer() {
    return Shimmer.fromColors(
      baseColor: AppTheme.baseColor,
      highlightColor: AppTheme.highlightColor,
      child: ListView.builder(
        itemCount: 6,
        shrinkWrap: true,
        padding: const EdgeInsets.only(
          left: 24,
          right: 24,
          bottom: kNavBarTotalPadding,
          top: 140,
        ),
        itemBuilder: (context, i) => Column(
          children: [
            Container(
              height: 80,
              padding: const EdgeInsets.only(
                  left: 12, top: 10, bottom: 10, right: 20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppTheme.baseColor, width: 2),
              ),
              child: Row(
                children: [
                  Container(
                    height: 60,
                    width: 60,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      color: AppTheme.baseColor,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 14,
                        width: 120,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
                          color: AppTheme.baseColor,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        height: 10,
                        width: 88,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
                          color: AppTheme.baseColor,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Container(
                            height: 8,
                            width: 56,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(4),
                              color: AppTheme.baseColor,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            height: 8,
                            width: 60,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(4),
                              color: AppTheme.baseColor,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const Spacer(),
                  SvgPicture.asset(
                    'assets/icons/right.svg',
                    height: 20,
                    colorFilter: ColorFilter.mode(
                      AppTheme.baseColor,
                      BlendMode.srcIn,
                    ),
                  ),
                ],
              ),
            ),
            if (i < 5) const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  TripListModel _toTripListModel(DriverTripModel t) {
    return TripListModel(
      id: t.id,
      googleMapUrl: t.googleMapUrl,
      fromWhere: [t.fromVillage, t.fromCity, t.fromRegion]
          .where((s) => s.isNotEmpty)
          .join(', '),
      toWhere: [t.toVillage, t.toCity, t.toRegion]
          .where((s) => s.isNotEmpty)
          .join(', '),
      fromRegion: t.fromRegion,
      fromCity: t.fromCity,
      fromVillage: t.fromVillage,
      toRegion: t.toRegion,
      toCity: t.toCity,
      toVillage: t.toVillage,
      fromRegionId: t.fromRegionId,
      toRegionId: t.toRegionId,
      fromCityId: t.fromCityId,
      toCityId: t.toCityId,
      fromVillageId: t.fromVillageId,
      toVillageId: t.toVillageId,
      startTime: t.startTime,
      endTime: t.endTime,
      pricePerSeat: t.pricePerSeat,
      totalSeats: t.totalSeats,
      availableSeats: t.availableSeats,
      startLat: t.startLat,
      startLong: t.startLong,
      endLat: t.endLat,
      endLong: t.endLong,
      status: t.status,
      createdAt: t.createdAt,
      updatedAt: t.updatedAt,
      driver: TripDriver(
        id: t.driver.id,
        name: '${t.driver.firstName} ${t.driver.lastName}',
        role: t.driver.role,
      ),
      vehicle: TripVehicle(
        id: t.vehicle.id,
        model: t.vehicle.model,
        seats: t.vehicle.seats,
        carNumber: t.vehicle.carNumber,
        color: CarColor(
          id: t.vehicle.color.id,
          titleUz: '',
          titleRu: '',
          titleEn: '',
          code: '',
        ),
      ),
    );
  }
}
