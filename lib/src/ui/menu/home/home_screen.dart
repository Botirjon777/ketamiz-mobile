import 'package:flutter/material.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:ketamiz/src/bloc/home_bloc.dart';
import 'package:ketamiz/src/model/api/trip_list_model.dart';
import 'package:ketamiz/src/model/location_model.dart';
import 'package:ketamiz/src/ui/dialogs/bottom_dialog.dart';
import 'package:ketamiz/src/ui/dialogs/center_dialog.dart';
import 'package:ketamiz/src/ui/menu/home/all_trips_screen.dart';
import 'package:ketamiz/src/ui/menu/home/search_result_screen.dart';
import 'package:ketamiz/src/ui/menu/home/trip_details_screen.dart';
import 'package:ketamiz/src/ui/menu/profile/support_screen.dart';
import 'package:ketamiz/src/ui/widgets/containers/active_trips_container.dart';
import 'package:ketamiz/src/utils/nav_constants.dart';
import 'package:ketamiz/src/utils/utils.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shimmer/shimmer.dart';
import 'package:lottie/lottie.dart';

import '../../../bloc/profile_bloc.dart';
import '../../../theme/app_theme.dart';
import '../../widgets/containers/destinations_container.dart';
import '../../widgets/language_button.dart';
import '../../widgets/notification_button.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String activeTripId = "0";
  String activeBookedId = "0";

  String _fromText = "";
  String _toText = "";

  LocationModel fromRegion = LocationModel(id: "0", text: "", parentID: '');
  LocationModel fromCity = LocationModel(id: "0", text: "", parentID: '');
  LocationModel fromNeighborhood =
      LocationModel(id: "0", text: "", parentID: '');

  LocationModel toRegion = LocationModel(id: "0", text: "", parentID: '');
  LocationModel toCity = LocationModel(id: "0", text: "", parentID: '');
  LocationModel toNeighborhood = LocationModel(id: "0", text: "", parentID: '');

  DateTime departureDate = DateTime.now();
  int passengerCount = 1;

  /// When on, the search only returns trips that accept parcels.
  bool _sendingParcel = false;

  int notificationNumber = 0;

  @override
  void initState() {
    getActiveTripsId();
    blocHome.fetchTripList();
    blocProfile.fetchMe();
    super.initState();
  }

  Future<void> _onRefresh() async {
    blocHome.fetchTripList();
    blocProfile.fetchMe();
    await Future.delayed(const Duration(milliseconds: 500));
  }

  Future<void> getActiveTripsId() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      activeTripId = prefs.getString('active_trip_id') ?? "0";
      activeBookedId = prefs.getString('active_booked_id') ?? "0";
    });
    if (activeTripId != "0") {
      blocHome.fetchOneDriverTrip(activeTripId);
    }
    if (activeBookedId != "0") {
      blocHome.fetchOneBookedTrip(activeBookedId);
    }
  }

  static int _asId(String id) => int.tryParse(id) ?? 0;

  // ── Pickers ─────────────────────────────────────────────────────────────

  void _pickFrom() {
    BottomDialog.showSelectLocation(
      context,
      fromRegion,
      fromCity,
      fromNeighborhood,
      (r, c, n) {
        setState(() {
          fromRegion = r;
          fromCity = c;
          fromNeighborhood = n;
          _fromText = [n.text, c.text, r.text]
              .where((s) => s.isNotEmpty)
              .join(', ');
        });
      },
    );
  }

  void _pickTo() {
    BottomDialog.showSelectLocation(
      context,
      toRegion,
      toCity,
      toNeighborhood,
      (r, c, n) {
        setState(() {
          toRegion = r;
          toCity = c;
          toNeighborhood = n;
          _toText =
              [n.text, c.text, r.text].where((s) => s.isNotEmpty).join(', ');
        });
      },
    );
  }

  void _swap() {
    setState(() {
      final tr = fromRegion;
      fromRegion = toRegion;
      toRegion = tr;
      final tc = fromCity;
      fromCity = toCity;
      toCity = tc;
      final tn = fromNeighborhood;
      fromNeighborhood = toNeighborhood;
      toNeighborhood = tn;
      final tt = _fromText;
      _fromText = _toText;
      _toText = tt;
    });
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: departureDate.isBefore(now) ? now : departureDate,
      firstDate: now,
      lastDate: now.add(const Duration(days: 90)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: AppTheme.purple,
            onPrimary: Colors.white,
            onSurface: AppTheme.black,
          ),
        ),
        child: child!,
      ),
    );
    if (date == null || !mounted) return;
    // Search filters by day only — pin to the start of the day.
    setState(() {
      departureDate = DateTime(date.year, date.month, date.day);
    });
  }

  void _pickPassengers() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: 32 + MediaQuery.of(context).padding.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: AppTheme.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Text(
                translate("home.number_passenger"),
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  fontFamily: AppTheme.fontFamily,
                  color: AppTheme.black,
                ),
              ),
              const SizedBox(height: 28),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _stepperButton(
                    icon: Icons.remove_rounded,
                    enabled: passengerCount > 1,
                    onTap: () {
                      setSheetState(() => passengerCount--);
                      setState(() {});
                    },
                  ),
                  SizedBox(
                    width: 80,
                    child: Text(
                      passengerCount.toString(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w700,
                        fontFamily: AppTheme.fontFamily,
                        color: AppTheme.black,
                      ),
                    ),
                  ),
                  _stepperButton(
                    icon: Icons.add_rounded,
                    enabled: passengerCount < 4,
                    onTap: () {
                      setSheetState(() => passengerCount++);
                      setState(() {});
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                translate(passengerCount == 1
                    ? "home.passenger"
                    : "home.passengers"),
                style: const TextStyle(
                  fontSize: 14,
                  fontFamily: AppTheme.fontFamily,
                  fontWeight: FontWeight.w400,
                  color: AppTheme.gray,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stepperButton({
    required IconData icon,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: enabled
              ? AppTheme.purple.withOpacity(0.1)
              : AppTheme.light,
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: enabled ? AppTheme.purple : AppTheme.gray,
          size: 22,
        ),
      ),
    );
  }

  // ── View all ────────────────────────────────────────────────────────────

  /// Resets the search form and opens the full list of available trips.
  void _showAllTrips() {
    setState(() {
      fromRegion = LocationModel(id: "0", text: "", parentID: '');
      fromCity = LocationModel(id: "0", text: "", parentID: '');
      fromNeighborhood = LocationModel(id: "0", text: "", parentID: '');
      toRegion = LocationModel(id: "0", text: "", parentID: '');
      toCity = LocationModel(id: "0", text: "", parentID: '');
      toNeighborhood = LocationModel(id: "0", text: "", parentID: '');
      _fromText = "";
      _toText = "";
      departureDate = DateTime.now();
      passengerCount = 1;
    });
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AllTripsScreen()),
    );
  }

  // ── Search ──────────────────────────────────────────────────────────────

  void _search() {
    if (fromRegion.id == "0" || toRegion.id == "0") {
      CenterDialog.showActionFailed(
        context,
        translate("home.missing_form"),
        translate("home.trip_search_error"),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SearchResultScreen(
          trip: TripListModel(
            id: 1,
            fromWhere: _fromText,
            toWhere: _toText,
            fromRegionId: _asId(fromRegion.id),
            toRegionId: _asId(toRegion.id),
            fromCityId: _asId(fromCity.id),
            toCityId: _asId(toCity.id),
            fromVillageId: _asId(fromNeighborhood.id),
            toVillageId: _asId(toNeighborhood.id),
            startTime: departureDate,
            endTime: departureDate,
            pricePerSeat: "",
            totalSeats: 0,
            availableSeats: 0,
            startLat: "",
            startLong: "",
            endLat: "",
            endLong: "",
            status: "",
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            driver: TripDriver(id: 0, name: "", role: "driver"),
            vehicle: TripVehicle(
              id: 0,
              model: "",
              seats: 0,
              carNumber: "",
              color: CarColor(
                id: 0,
                titleUz: "",
                titleRu: "",
                titleEn: "",
                code: "",
              ),
            ),
          ),
          isRoundTrip: false,
          requiredSeats: passengerCount,
          parcelOnly: _sendingParcel,
        ),
      ),
    );
  }

  // ── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          Container(
            color: AppTheme.cream,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: _buildHeader(),
              ),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              color: AppTheme.purple,
              onRefresh: _onRefresh,
              child: ListView(
                padding: const EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 16,
                  bottom: kNavBarTotalPadding,
                ),
                children: [
                  _buildSearchCard(),
                  const SizedBox(height: 24),
                  if (activeBookedId != "0") _buildActiveTrip(),
                  _buildRecommendedTrips(),
                  const SizedBox(height: 24),
                  _buildQuickActions(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Image.asset(
          'assets/logos/ketamiz-logo-small.png',
          height: 36,
          fit: BoxFit.contain,
        ),
        const Spacer(),
        const LanguageButton(),
        const SizedBox(width: 12),
        NotificationButton(hasUnread: notificationNumber > 0),
      ],
    );
  }

  Widget _buildSearchCard() {
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
          // ── From / To group ──────────────────────────────────────────────
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.border),
            ),
            child: Stack(
              alignment: Alignment.centerRight,
              children: [
                Column(
                  children: [
                    _locationField(
                      hint: translate("home.from"),
                      value: _fromText,
                      onTap: _pickFrom,
                      leading: _locationBadge(AppTheme.green),
                    ),
                    Container(
                      height: 1,
                      margin: const EdgeInsets.only(left: 58, right: 16),
                      color: AppTheme.border,
                    ),
                    _locationField(
                      hint: translate("home.to"),
                      value: _toText,
                      onTap: _pickTo,
                      leading: _locationBadge(AppTheme.blue),
                    ),
                  ],
                ),
                // Swap button
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: GestureDetector(
                    onTap: _swap,
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppTheme.border),
                        boxShadow: [
                          BoxShadow(
                            offset: const Offset(0, 2),
                            blurRadius: 6,
                            color: AppTheme.black.withOpacity(0.06),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.swap_vert_rounded,
                        color: AppTheme.purple,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // ── Date + passengers row ────────────────────────────────────────
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.border),
            ),
            child: IntrinsicHeight(
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: _selectorChip(
                      icon: Icons.calendar_today_outlined,
                      label: Utils.searchDateFormat(departureDate),
                      onTap: _pickDate,
                    ),
                  ),
                  Container(width: 1, color: AppTheme.border),
                  Expanded(
                    flex: 2,
                    child: _selectorChip(
                      icon: Icons.person_outline_rounded,
                      label:
                          "$passengerCount ${translate(passengerCount == 1 ? "home.passenger" : "home.passengers")}",
                      onTap: _pickPassengers,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          // ── Sending-parcel toggle (filters to trips accepting parcels) ────
          _buildParcelToggle(),
          const SizedBox(height: 16),
          // ── Search button (gradient) ─────────────────────────────────────
          GestureDetector(
            onTap: _search,
            child: Container(
              width: double.infinity,
              height: 52,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [AppTheme.blue, AppTheme.green],
                ),
                borderRadius: BorderRadius.circular(26),
                boxShadow: [
                  BoxShadow(
                    offset: const Offset(0, 6),
                    blurRadius: 16,
                    color: AppTheme.blue.withOpacity(0.25),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.search_rounded,
                      color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    translate("home.find_trip"),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      fontFamily: AppTheme.fontFamily,
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

  Widget _buildParcelToggle() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _sendingParcel ? AppTheme.green : AppTheme.border,
        ),
        color: _sendingParcel
            ? AppTheme.green.withOpacity(0.06)
            : Colors.white,
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppTheme.green.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.inventory_2_outlined,
                color: AppTheme.green, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  translate("home.sending_parcel"),
                  style: const TextStyle(
                    color: AppTheme.black,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    fontFamily: AppTheme.fontFamily,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  translate("home.sending_parcel_hint"),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.gray,
                    fontSize: 11.5,
                    fontFamily: AppTheme.fontFamily,
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: _sendingParcel,
            activeTrackColor: AppTheme.green,
            onChanged: (v) => setState(() => _sendingParcel = v),
          ),
        ],
      ),
    );
  }

  /// Circular colour-coded pin used for the From (green) / To (blue) fields.
  Widget _locationBadge(Color color) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        shape: BoxShape.circle,
      ),
      child: Icon(Icons.location_on_rounded, color: color, size: 18),
    );
  }

  Widget _locationField({
    required String hint,
    required String value,
    required VoidCallback onTap,
    required Widget leading,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            leading,
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                value.isNotEmpty ? value : hint,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: value.isNotEmpty ? AppTheme.black : AppTheme.text,
                  fontSize: 15,
                  fontFamily: AppTheme.fontFamily,
                  fontWeight:
                      value.isNotEmpty ? FontWeight.w500 : FontWeight.w400,
                ),
              ),
            ),
            // Reserve space so text never sits under the swap button.
            const SizedBox(width: 44),
          ],
        ),
      ),
    );
  }

  Widget _selectorChip({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: AppTheme.dark, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppTheme.black,
                  fontSize: 13,
                  fontFamily: AppTheme.fontFamily,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            offset: const Offset(0, 4),
            blurRadius: 20,
            color: AppTheme.black.withOpacity(0.05),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _quickAction(
            icon: Icons.directions_car_outlined,
            color: AppTheme.purple,
            title: translate("home.action_offer_trip"),
            subtitle: translate("home.action_offer_trip_sub"),
            onTap: _comingSoon,
          ),
          _quickAction(
            icon: Icons.inventory_2_outlined,
            color: AppTheme.green,
            title: translate("home.action_send_parcel"),
            subtitle: translate("home.action_send_parcel_sub"),
            onTap: _comingSoon,
          ),
          _quickAction(
            icon: Icons.local_offer_outlined,
            color: AppTheme.purple,
            title: translate("home.action_discounts"),
            subtitle: translate("home.action_discounts_sub"),
            onTap: _comingSoon,
          ),
          _quickAction(
            icon: Icons.headset_mic_outlined,
            color: AppTheme.blue,
            title: translate("home.action_support"),
            subtitle: translate("home.action_support_sub"),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SupportScreen()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _quickAction({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Column(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppTheme.black,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  height: 1.2,
                  fontFamily: AppTheme.fontFamily,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppTheme.gray,
                  fontSize: 9.5,
                  height: 1.1,
                  fontFamily: AppTheme.fontFamily,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _comingSoon() {
    CenterDialog.showInfo(
      context,
      translate("home.coming_soon"),
      translate("home.coming_soon_msg"),
    );
  }

  Widget _buildActiveTrip() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          translate("home.my_active_trips"),
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            fontFamily: AppTheme.fontFamily,
            color: AppTheme.black,
          ),
        ),
        const SizedBox(height: 12),
        StreamBuilder<TripListModel>(
          stream: blocHome.getOneBookedTrip,
          builder: (context, AsyncSnapshot<TripListModel> snapshot) {
            if (!snapshot.hasData) return const SizedBox();
            return ActiveTripsContainer(trip: snapshot.data!);
          },
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildRecommendedTrips() {
    return StreamBuilder(
      stream: blocHome.getTrips,
      builder: (context, AsyncSnapshot<List<TripListModel>> snapshot) {
        if (!snapshot.hasData) return _buildShimmer();

        // The "Sending a parcel?" toggle filters this list live — flipping it
        // calls setState, which rebuilds this StreamBuilder with the filter
        // applied (no re-fetch needed).
        final trips = snapshot.data!
            .where((t) => !_sendingParcel || t.acceptsParcels)
            .toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    translate("home.recommended_trips"),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      fontFamily: AppTheme.fontFamily,
                      color: AppTheme.black,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: _showAllTrips,
                  behavior: HitTestBehavior.opaque,
                  // Generous hit area for a small text button
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 4, vertical: 8),
                    child: Text(
                      translate("home.view_all"),
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.purple,
                        fontFamily: AppTheme.fontFamily,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (trips.isEmpty)
              Column(
                children: [
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 180,
                    width: 180,
                    child: Lottie.asset(
                      "assets/lottie/empty.json",
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: Text(
                      translate("ketamiz.No_trip_found"),
                      style: const TextStyle(
                        fontSize: 14,
                        fontFamily: AppTheme.fontFamily,
                        color: AppTheme.gray,
                      ),
                    ),
                  ),
                ],
              )
            else
              ...List.generate(
                trips.length,
                (index) => Padding(
                  padding: EdgeInsets.only(
                      bottom: index == trips.length - 1 ? 0 : 16),
                  child: GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              TripDetailsScreen(trip: trips[index]),
                        ),
                      );
                    },
                    child: DestinationsContainer(trip: trips[index]),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildShimmer() {
    return Shimmer.fromColors(
      baseColor: AppTheme.baseColor,
      highlightColor: AppTheme.highlightColor,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                height: 22,
                width: 180,
                decoration: BoxDecoration(
                  color: AppTheme.baseColor,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              Container(
                height: 14,
                width: 40,
                decoration: BoxDecoration(
                  color: AppTheme.baseColor,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...List.generate(
            6,
            (index) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                height: 130,
                decoration: BoxDecoration(
                  color: AppTheme.baseColor,
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
