import 'package:flutter/material.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:latlong2/latlong.dart';
import 'package:ketamiz/src/ui/dialogs/bottom_dialog.dart';
import 'package:ketamiz/src/ui/dialogs/center_dialog.dart';
import 'package:ketamiz/src/ui/menu/home/map_single_screen.dart';
import 'package:ketamiz/src/ui/menu/home/payment_screen.dart';
import 'package:ketamiz/src/ui/menu/new_ketamiz/map_select_screen.dart';
import 'package:ketamiz/src/ui/menu/main_screen.dart';
import 'package:ketamiz/src/ui/menu/parcels/parcel_detail_screen.dart';
import 'package:ketamiz/src/ui/menu/parcels/parcel_status.dart';
import 'package:ketamiz/src/ui/menu/parcels/send_parcel_screen.dart';
import '../../../model/api/parcel_model.dart';
import 'package:ketamiz/src/ui/widgets/buttons/slide_to_confirm_button.dart';
import 'package:ketamiz/src/ui/widgets/containers/leading_back.dart';
import 'package:ketamiz/src/ui/widgets/containers/passengers_container.dart';
import 'package:ketamiz/src/ui/widgets/texts/text_14h_400w.dart';
import 'package:ketamiz/src/ui/widgets/texts/text_16h_500w.dart';
import 'package:ketamiz/src/utils/utils.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../lan_localization/load_places.dart';
import '../../../model/api/trip_list_model.dart';
import '../../../model/location_model.dart';
import '../../../model/passenger_model.dart';
import '../../../resources/repository.dart';
import '../../../theme/app_theme.dart';
import '../../dialogs/snack_bar.dart';
import 'map_route_screen.dart';
import '../profile/terms_screen.dart';

/// How a passenger's pickup point is chosen when others already have one.
enum _PickupChoice { same, map }

/// Who the booking is being made for.
enum _BookingMode { self, withOthers, other }

/// A passenger on a driver's own trip — shown read-only in the driver view.
class _BookedPassenger {
  final String name;
  final String phone;
  final String lat;
  final String lng;
  final String status;

  _BookedPassenger(this.name, this.phone, this.lat, this.lng,
      {this.status = ''});

  bool get hasLocation =>
      lat.isNotEmpty &&
      lng.isNotEmpty &&
      lat != '0' &&
      lng != '0' &&
      double.tryParse(lat) != null &&
      double.tryParse(lng) != null;
}

class TripDetailsScreen extends StatefulWidget {
  const TripDetailsScreen({
    super.key,
    required this.trip,
    this.isDriver = false,
    this.isBooked = false,
    this.bookings = const [],
  });

  final TripListModel trip;
  final bool isDriver;

  /// Whether the current user has already booked this trip. Controls whether
  /// the exact route is shown on the map or only an approximate 25 km area.
  final bool isBooked;

  /// Raw bookings for this trip — only used in the driver view to list who
  /// booked, their contact numbers and pickup locations.
  final List<dynamic> bookings;

  @override
  State<TripDetailsScreen> createState() => _TripDetailsScreenState();
}

class _TripDetailsScreenState extends State<TripDetailsScreen> {
  static final _unknownLocation =
      LocationModel(id: "0", text: "—", parentID: "0");

  String pricePerSeat = "";
  int passengersNum = 1;

  String from = '';
  String to = '';

  String fromRegion = "";
  String fromCity = "";
  String fromNeighborhood = "";
  String toRegion = "";
  String toCity = "";
  String toNeighborhood = "";

  List<PassengerModel> passengers = [];
  bool _isCancelling = false;

  /// The current user as a passenger (null if we have no cached identity).
  PassengerModel? _me;

  /// Who the booking is for: just me, me + others, or someone else entirely.
  _BookingMode _mode = _BookingMode.self;

  /// True when the logged-in user is the driver of this trip — they can't
  /// book their own trip, so no passenger form should appear.
  bool _isOwnTrip = false;

  /// Parsed bookings for the driver view.
  List<_BookedPassenger> _bookedPassengers = [];

  /// Parcels booked on this trip (driver view). Loaded only when the trip
  /// accepts parcels; the section is hidden until at least one exists.
  List<ParcelBooking> _tripParcels = [];

  /// Whether this trip currently accepts new parcels (driver view). Starts
  /// from the trip payload and flips locally once the driver toggles it.
  late bool _acceptsParcels = widget.trip.acceptsParcels;
  bool _togglingParcels = false;

  @override
  void initState() {
    super.initState();
    final p = widget.trip.pricePerSeat;
    pricePerSeat = p.contains(".") ? p.split(".")[0] : p;
    setLocations();
    if (widget.isDriver) {
      _bookedPassengers = _parseBookings(widget.bookings);
      if (widget.trip.acceptsParcels) _loadTripParcels();
    } else {
      _initFirstPassenger();
    }
  }

  /// The endpoint is a blind toggle (no target value in the request) — it
  /// always flips whatever the server currently has, and echoes the actual
  /// resulting state back in `data.accepts_parcels`, which is what drives the
  /// switch rather than the tap itself.
  Future<void> _toggleParcelAcceptance(bool _) async {
    setState(() => _togglingParcels = true);

    final response = await Repository()
        .fetchToggleParcelAcceptance(widget.trip.id.toString());

    if (!mounted) return;
    setState(() => _togglingParcels = false);

    if (response.isSuccess) {
      final result = response.result;
      final data = result is Map ? result['data'] : null;
      final accepts = data is Map ? data['accepts_parcels'] : null;
      final newValue = accepts == true || accepts == 1 || accepts?.toString() == '1';
      setState(() => _acceptsParcels = newValue);
      CustomSnackBar().showSnackBar(
        context,
        newValue
            ? translate("parcel.acceptance_on")
            : translate("parcel.acceptance_off"),
        1,
      );
    } else {
      final msg = (response.result is Map
              ? response.result['message']?.toString()
              : null) ??
          translate("auth.something_went_wrong");
      CustomSnackBar().showSnackBar(context, msg, 2);
    }
  }

  Future<void> _loadTripParcels() async {
    final response =
        await Repository().fetchDriverParcelBookingsByTrip(widget.trip.id);
    if (!mounted) return;
    if (response.isSuccess) {
      setState(() {
        _tripParcels = ParcelBooking.listFromResult(response.result);
      });
    }
  }

  /// Flatten the trip's bookings into a flat passenger list. Handles both
  /// shapes seen from the API: a booking with a nested `passengers` array, or
  /// a booking that is itself the passenger record.
  List<_BookedPassenger> _parseBookings(List<dynamic> bookings) {
    final result = <_BookedPassenger>[];

    String pick(Map m, List<String> keys) {
      for (final k in keys) {
        final v = m[k];
        if (v != null && v.toString().isNotEmpty) return v.toString();
      }
      return '';
    }

    void addFrom(Map m) {
      result.add(_BookedPassenger(
        pick(m, ['name', 'full_name', 'fullName']),
        pick(m, ['phone', 'phone_number', 'phoneNumber']),
        pick(m, ['latitude', 'lat']),
        pick(m, ['longitude', 'long', 'lng']),
        status: pick(m, ['status']),
      ));
    }

    for (final b in bookings) {
      if (b is! Map) continue;
      final passengers = b['passengers'];
      if (passengers is List && passengers.isNotEmpty) {
        for (final p in passengers) {
          if (p is Map) addFrom(p);
        }
      } else {
        addFrom(b);
      }
    }
    return result
        .where((p) => p.name.isNotEmpty || p.phone.isNotEmpty)
        .toList();
  }

  Future<void> _initFirstPassenger() async {
    final user = await Repository().appCache.cacheGetMe();
    if (!mounted) return;
    // The trip's own driver isn't a passenger — never prefill them.
    if (user.id != 0 && user.id == widget.trip.driver.id) {
      setState(() => _isOwnTrip = true);
      return;
    }
    final fullName = "${user.firstName} ${user.lastName}".trim();
    // Nothing cached to prefill — booking must be for someone else, entered
    // manually, so start in "other" mode with an empty list.
    if (fullName.isEmpty && user.phone.isEmpty) {
      setState(() {
        _me = null;
        _mode = _BookingMode.other;
        passengers = [];
        passengersNum = 0;
      });
      return;
    }
    setState(() {
      _me = PassengerModel(fullName: fullName, phoneNumber: user.phone);
      _mode = _BookingMode.self;
      passengers = [_me!];
      passengersNum = 1;
    });
  }

  /// Switch who the booking is for, rebuilding the passenger list accordingly.
  void _setMode(_BookingMode mode) {
    if (_mode == mode) return;
    setState(() {
      _mode = mode;
      switch (mode) {
        case _BookingMode.self:
          passengers = _me != null ? [_me!] : [];
          break;
        case _BookingMode.withOthers:
          if (_me != null && !passengers.any((p) => identical(p, _me))) {
            passengers.insert(0, _me!);
          }
          break;
        case _BookingMode.other:
          passengers.removeWhere((p) => identical(p, _me));
          break;
      }
      passengersNum = passengers.length;
    });
  }

  /// Validate and proceed to payment. Booking needs at least one passenger,
  /// each with name, phone AND a pickup location. If only the pickup point is
  /// missing, prompt for it on the map instead of showing a blocking error —
  /// that's the common case for the pre-filled current user.
  Future<void> _onBookTap() async {
    if (passengers.isEmpty ||
        passengers.any((p) =>
            p.fullName.trim().isEmpty || p.phoneNumber.trim().isEmpty)) {
      CenterDialog.showActionFailed(
        context,
        translate("home.passenger_info"),
        translate("home.fill_passenger_details"),
      );
      return;
    }

    // Prompt for each passenger still missing a pickup point.
    var idx = passengers.indexWhere((p) => !p.hasLocation);
    while (idx != -1) {
      await _setPassengerLocation(idx);
      if (!mounted) return;
      final next = passengers.indexWhere((p) => !p.hasLocation);
      if (next == idx) {
        // User backed out of the picker — pickup is required, so stop here.
        CenterDialog.showActionFailed(
          context,
          translate("home.passenger_info"),
          translate("home.set_pickup_location"),
        );
        return;
      }
      idx = next;
    }

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PaymentScreen(
          trip: widget.trip,
          passengersNum: passengers.length,
          passengers: passengers,
        ),
      ),
    );
  }

  /// Add a passenger: collect name + phone, then a pickup location.
  void _onAddPassenger() {
    if (passengers.length >= widget.trip.availableSeats) {
      CenterDialog.showActionFailed(
        context,
        translate("home.passenger_info"),
        translate("home.no_seats_left"),
      );
      return;
    }
    // Offer the first existing passenger's pickup as a "same location" option.
    LatLng? shared;
    for (final p in passengers) {
      if (p.hasLocation) {
        shared = LatLng(double.parse(p.latitude), double.parse(p.longitude));
        break;
      }
    }
    BottomDialog.showAddPassenger(
      context,
      PassengerModel(fullName: ""),
      (data) {
        final exists = passengers.any((p) => p.fullName == data.fullName);
        if (exists || data.fullName.isEmpty) {
          CenterDialog.showActionFailed(
            context,
            translate("home.passenger_exist"),
            translate("home.passenger_exist_error"),
          );
          return;
        }
        setState(() {
          passengers.add(data);
          passengersNum++;
        });
      },
      place: from,
      sharedLocation: shared,
    );
  }

  /// Choose a pickup point for [index]. If other passengers already have a
  /// location, offer to reuse it (family booking) or pick a new one (friend).
  Future<void> _setPassengerLocation(int index) async {
    if (index < 0 || index >= passengers.length) return;

    final others = <PassengerModel>[
      for (var i = 0; i < passengers.length; i++)
        if (i != index && passengers[i].hasLocation) passengers[i]
    ];

    LatLng? picked;
    if (others.isNotEmpty) {
      final choice = await _showPickupChoice();
      if (choice == null || !mounted) return; // cancelled
      if (choice == _PickupChoice.same) {
        picked = LatLng(
          double.parse(others.first.latitude),
          double.parse(others.first.longitude),
        );
      }
    }

    if (!mounted) return;
    picked ??= await Navigator.push<LatLng>(
      context,
      MaterialPageRoute(
        builder: (_) => MapSelectScreen(
          place: from,
          onSelected: (_) {},
        ),
      ),
    );

    if (picked == null || !mounted) return;
    setState(() {
      passengers[index].latitude = picked!.latitude.toString();
      passengers[index].longitude = picked.longitude.toString();
    });
  }

  /// Bottom sheet: reuse another passenger's pickup point or pick on the map.
  Future<_PickupChoice?> _showPickupChoice() {
    return showModalBottomSheet<_PickupChoice>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text16h500w(title: translate("home.pickup_location")),
              const SizedBox(height: 16),
              _pickupOption(
                icon: Icons.people_alt_outlined,
                label: translate("home.pickup_same_as_others"),
                onTap: () =>
                    Navigator.pop(sheetContext, _PickupChoice.same),
              ),
              const SizedBox(height: 12),
              _pickupOption(
                icon: Icons.map_outlined,
                label: translate("home.pickup_choose_on_map"),
                onTap: () =>
                    Navigator.pop(sheetContext, _PickupChoice.map),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pickupOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppTheme.light,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppTheme.purple, size: 22),
            const SizedBox(width: 12),
            Expanded(child: Text16h500w(title: label)),
            const Icon(Icons.chevron_right, color: AppTheme.gray, size: 20),
          ],
        ),
      ),
    );
  }

  Future<void> setLocations() async {
    final trip = widget.trip;

    if (trip.fromRegion.isNotEmpty ||
        trip.fromCity.isNotEmpty ||
        trip.fromVillage.isNotEmpty) {
      fromRegion = trip.fromRegion;
      fromCity = trip.fromCity;
      fromNeighborhood = trip.fromVillage;
      toRegion = trip.toRegion;
      toCity = trip.toCity;
      toNeighborhood = trip.toVillage;
    } else {
      if (LocationData.regions.isEmpty) {
        await LocationData.loadPlaces(context);
      }
      fromRegion = LocationData.regions
          .firstWhere((r) => r.id == trip.fromRegionId.toString(),
              orElse: () => _unknownLocation)
          .text;
      fromCity = LocationData.cities
          .firstWhere((c) => c.id == trip.fromCityId.toString(),
              orElse: () => _unknownLocation)
          .text;
      fromNeighborhood = LocationData.villages
          .firstWhere((n) => n.id == trip.fromVillageId.toString(),
              orElse: () => _unknownLocation)
          .text;
      toRegion = LocationData.regions
          .firstWhere((r) => r.id == trip.toRegionId.toString(),
              orElse: () => _unknownLocation)
          .text;
      toCity = LocationData.cities
          .firstWhere((c) => c.id == trip.toCityId.toString(),
              orElse: () => _unknownLocation)
          .text;
      toNeighborhood = LocationData.villages
          .firstWhere((n) => n.id == trip.toVillageId.toString(),
              orElse: () => _unknownLocation)
          .text;
    }

    if (!mounted) return;
    setState(() {
      from = [fromNeighborhood, fromCity, fromRegion]
          .where((s) => s.isNotEmpty && s != "—")
          .join(", ");
      to = [toNeighborhood, toCity, toRegion]
          .where((s) => s.isNotEmpty && s != "—")
          .join(", ");
    });
  }

  Color get _seatsColor {
    final s = widget.trip.availableSeats;
    if (s <= 1) return AppTheme.red;
    if (s <= 3) return AppTheme.yellow;
    return AppTheme.green;
  }

  String get _status => widget.trip.status.toLowerCase();

  /// Only active trips can still be booked or cancelled.
  bool get _isActive => _status.isEmpty || _status == 'active';

  Color get _statusColor {
    switch (_status) {
      case 'completed':
        return AppTheme.green;
      case 'canceled':
      case 'cancelled':
        return AppTheme.red;
      default: // active / in_progress
        return AppTheme.purple;
    }
  }

  String get _statusText {
    switch (_status) {
      case 'active':
        return translate('history.active');
      case 'in_progress':
        return translate('history.in_progress');
      case 'completed':
        return translate('history.completed');
      case 'canceled':
      case 'cancelled':
        return translate('history.canceled');
      default:
        return widget.trip.status;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: const LeadingBack(),
        title: Text16h500w(title: translate("home.trip_details")),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
              children: [
                _buildRouteCard(),
                const SizedBox(height: 16),
                _buildDetailsCard(),
                // Driver view: who booked this trip (name, phone, location).
                if (widget.isDriver) ...[
                  const SizedBox(height: 16),
                  _buildBookedPassengersCard(),
                  // Let the driver turn parcel acceptance on/off for this
                  // trip (e.g. no room left in the car) — only for trips
                  // configured to accept parcels and not yet finished.
                  if (widget.trip.parcel != null &&
                      _status != 'completed' &&
                      _status != 'canceled' &&
                      _status != 'cancelled') ...[
                    const SizedBox(height: 16),
                    _buildParcelAcceptanceCard(),
                  ],
                  // Parcels booked on this trip — only when the driver accepts
                  // parcels and at least one is booked.
                  if (_acceptsParcels && _tripParcels.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _buildTripParcelsCard(),
                  ],
                  const SizedBox(height: 16),
                  _buildCancelInfoCard(),
                  const SizedBox(height: 12),
                  _buildDriverTermsButton(),
                ],
                // Send-parcel entry: client view, active trip that accepts
                // parcels, and not the viewer's own trip.
                if (!widget.isDriver &&
                    _isActive &&
                    !_isOwnTrip &&
                    widget.trip.acceptsParcels &&
                    widget.trip.parcel != null) ...[
                  const SizedBox(height: 16),
                  _buildSendParcelCard(),
                ],
                // Passenger form exists only for booking: active trip,
                // client view, and not the viewer's own trip.
                if (!widget.isDriver && _isActive && !_isOwnTrip) ...[
                  const SizedBox(height: 16),
                  _buildPassengerCard(),
                ],
              ],
            ),
          ),
          // Booking and cancelling are only possible while the trip is
          // active — in-progress/completed/cancelled trips get no action bar,
          // and a driver can't book their own trip.
          if (_isActive && (widget.isDriver || !_isOwnTrip))
            widget.isDriver
                ? _buildDriverBottomBar()
                : _buildPassengerBottomBar(),
        ],
      ),
    );
  }

  // ── Route hero card ────────────────────────────────────────────────────────
  Widget _buildRouteCard() {
    final driverName = widget.trip.driver.name.trim();
    final vehicleModel = widget.trip.vehicle.model;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            offset: const Offset(0, 4),
            blurRadius: 16,
            color: AppTheme.black.withValues(alpha: 0.06),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status badge + seats badge (active only) + price row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.trip.status.isNotEmpty) ...[
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: _statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _statusText,
                    style: TextStyle(
                      color: _statusColor,
                      fontSize: 12,
                      fontFamily: AppTheme.fontFamily,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              if (_isActive)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: _seatsColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    "${widget.trip.availableSeats} ${translate("home.seats_left")}",
                    style: TextStyle(
                      color: _seatsColor,
                      fontSize: 12,
                      fontFamily: AppTheme.fontFamily,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    "${Utils.priceFormat(pricePerSeat)} ${translate("currency")}",
                    style: const TextStyle(
                      color: AppTheme.black,
                      fontSize: 17,
                      fontFamily: AppTheme.fontFamily,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    translate("home.per_passenger"),
                    style: const TextStyle(
                      color: AppTheme.gray,
                      fontSize: 11,
                      fontFamily: AppTheme.fontFamily,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Timeline + places + driver block
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Vertical timeline
              Column(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      border: Border.all(color: AppTheme.purple, width: 2),
                    ),
                  ),
                  ...List.generate(
                    4,
                    (_) => Container(
                      margin: const EdgeInsets.symmetric(vertical: 2),
                      width: 2,
                      height: 6,
                      decoration: BoxDecoration(
                        color: AppTheme.border,
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                  ),
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTheme.purple,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              // Times + places
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      Utils.timeFormat(widget.trip.startTime),
                      style: const TextStyle(
                        color: AppTheme.black,
                        fontSize: 16,
                        fontFamily: AppTheme.fontFamily,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      from.isEmpty ? "—" : from,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppTheme.dark,
                        fontSize: 13,
                        fontFamily: AppTheme.fontFamily,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      Utils.timeFormat(widget.trip.endTime),
                      style: const TextStyle(
                        color: AppTheme.black,
                        fontSize: 16,
                        fontFamily: AppTheme.fontFamily,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      to.isEmpty ? "—" : to,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppTheme.dark,
                        fontSize: 13,
                        fontFamily: AppTheme.fontFamily,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Driver block
              Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppTheme.purple.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      widget.isBooked
                          ? Icons.person_rounded
                          : Icons.directions_car_rounded,
                      color: AppTheme.purple,
                      size: 24,
                    ),
                  ),
                  // Driver name is only revealed once the trip is booked.
                  if (widget.isBooked && driverName.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    SizedBox(
                      width: 92,
                      child: Text(
                        driverName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppTheme.black,
                          fontSize: 12,
                          fontFamily: AppTheme.fontFamily,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                  if (vehicleModel.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    SizedBox(
                      width: 92,
                      child: Text(
                        vehicleModel.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppTheme.black,
                          fontSize: 12,
                          fontFamily: AppTheme.fontFamily,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ],
                  if (widget.trip.vehicle.color.titleEn.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: Utils.colorFromHex(
                                widget.trip.vehicle.color.code),
                            shape: BoxShape.circle,
                            border: Border.all(color: AppTheme.border),
                          ),
                        ),
                        const SizedBox(width: 4),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 76),
                          child: Text(
                            widget.trip.vehicle.color.titleEn,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppTheme.gray,
                              fontSize: 11,
                              fontFamily: AppTheme.fontFamily,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Details card ───────────────────────────────────────────────────────────
  Widget _buildDetailsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            offset: const Offset(0, 4),
            blurRadius: 16,
            color: AppTheme.black.withValues(alpha: 0.06),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text16h500w(title: translate("home.details")),
          const SizedBox(height: 14),
          _infoRow(
            icon: Icons.radio_button_checked_rounded,
            iconColor: AppTheme.purple,
            label: translate("home.travelling_from"),
            child: Expanded(
              child: Text(
                from.isEmpty ? "—" : from,
                textAlign: TextAlign.end,
                style: const TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.black,
                ),
              ),
            ),
          ),
          _divider(),
          _infoRow(
            icon: Icons.location_on_rounded,
            iconColor: AppTheme.red,
            label: translate("home.where_to"),
            child: Expanded(
              child: Text(
                to.isEmpty ? "—" : to,
                textAlign: TextAlign.end,
                style: const TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.black,
                ),
              ),
            ),
          ),
          _divider(),
          _infoRow(
            icon: Icons.calendar_today_rounded,
            iconColor: AppTheme.purple,
            label: translate("home.departure_date"),
            value: Utils.searchDateFormat(widget.trip.startTime),
          ),
          _divider(),
          _infoRow(
            icon: Icons.flag_rounded,
            iconColor: AppTheme.green,
            label: translate("home.arrival_date"),
            value: Utils.searchDateFormat(widget.trip.endTime),
          ),
          _divider(),
          if (_isActive) ...[
            _infoRow(
              icon: Icons.event_seat_rounded,
              iconColor: _seatsColor,
              label: translate("home.available_seats"),
              value: "${widget.trip.availableSeats}",
            ),
            _divider(),
          ],
          _infoRow(
            icon: Icons.payments_rounded,
            iconColor: AppTheme.purple,
            label: translate("home.price_per_seat"),
            value: "${Utils.priceFormat(pricePerSeat)} ${translate("currency")}",
          ),
          const SizedBox(height: 14),
          // Map actions:
          //  • Driver who created this trip → open in Google Maps (exact).
          //  • Client → in-app map; exact route only after booking, otherwise
          //    an approximate 25 km area.
          if (widget.isDriver || _isOwnTrip) ...[
            if (_googleMapsUrl.isNotEmpty) _openInMapsButton(),
          ] else
            _routeMapButton(),
        ],
      ),
    );
  }

  // ── Booked passengers card (driver view) ───────────────────────────────────
  Widget _buildBookedPassengersCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            offset: const Offset(0, 4),
            blurRadius: 16,
            color: AppTheme.black.withValues(alpha: 0.06),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text16h500w(title: translate("home.booked_passengers")),
              ),
              if (_bookedPassengers.isNotEmpty)
                Text(
                  "${_bookedPassengers.length}",
                  style: const TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.purple,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (_bookedPassengers.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                translate("ketamiz.no_passenger"),
                style: const TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 13,
                  color: AppTheme.gray,
                ),
              ),
            )
          else ...[
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: AppTheme.purple.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline,
                      size: 18, color: AppTheme.purple),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      translate("home.driver_pickup_note"),
                      style: const TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 12.5,
                        height: 1.45,
                        fontWeight: FontWeight.w400,
                        color: AppTheme.black,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            ...List.generate(_bookedPassengers.length, (i) {
              final p = _bookedPassengers[i];
              return Container(
                margin: EdgeInsets.only(
                    bottom: i == _bookedPassengers.length - 1 ? 0 : 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.light,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: const Icon(Icons.person,
                          size: 22, color: AppTheme.black),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text14h400w(
                              title: p.name.isEmpty ? "—" : p.name),
                          if (p.phone.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text14h400w(title: p.phone, color: AppTheme.gray),
                          ],
                          if (p.status.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            _passengerStatusBadge(p.status),
                          ],
                        ],
                      ),
                    ),
                    // Call the passenger.
                    if (p.phone.isNotEmpty)
                      GestureDetector(
                        onTap: () => _callPassenger(p.phone),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: const Icon(Icons.call,
                              size: 20, color: AppTheme.green),
                        ),
                      ),
                    // View this passenger's pickup point on the map.
                    if (p.hasLocation) ...[
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => _showPassengerLocation(p),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: const Icon(Icons.location_on,
                              size: 20, color: AppTheme.purple),
                        ),
                      ),
                    ],
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _passengerStatusBadge(String status) {
    final s = status.toLowerCase();
    String label;
    Color color;
    switch (s) {
      case 'confirmed':
        label = translate("home.passenger_confirmed");
        color = AppTheme.green;
        break;
      case 'pending':
        label = translate("home.passenger_pending");
        color = AppTheme.yellow;
        break;
      case 'cancelled':
      case 'canceled':
        label = translate("home.passenger_cancelled");
        color = AppTheme.red;
        break;
      default:
        label = status;
        color = AppTheme.gray;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: AppTheme.fontFamily,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Future<void> _callPassenger(String phone) async {
    final uri = Uri.parse('tel:$phone');
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  void _showPassengerLocation(_BookedPassenger p) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MapSingleScreen(
          location: LatLng(double.parse(p.lat), double.parse(p.lng)),
          place: p.name.isEmpty ? translate("home.pickup_location") : p.name,
        ),
      ),
    );
  }

  // ── Send parcel entry (client view) ────────────────────────────────────────
  Widget _buildSendParcelCard() {
    final parcel = widget.trip.parcel!;
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SendParcelScreen(trip: widget.trip),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.purple.withValues(alpha: 0.3)),
          boxShadow: [
            BoxShadow(
              offset: const Offset(0, 4),
              blurRadius: 16,
              color: AppTheme.black.withValues(alpha: 0.06),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppTheme.purple.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.inventory_2_outlined,
                  color: AppTheme.purple, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text16h500w(title: translate("parcel.send_parcel")),
                  const SizedBox(height: 2),
                  Text(
                    translate("parcel.send_parcel_subtitle", args: {
                      "price":
                          "${Utils.priceFromNum(parcel.pricePerKg)} ${translate("currency")}",
                    }),
                    style: const TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 12.5,
                      color: AppTheme.gray,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: AppTheme.purple, size: 22),
          ],
        ),
      ),
    );
  }

  // ── Passenger card (client view) ───────────────────────────────────────────
  Widget _buildModeSelector() {
    Widget chip(_BookingMode mode, String label) {
      final active = _mode == mode;
      return Expanded(
        child: GestureDetector(
          onTap: () => _setMode(mode),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 3),
            padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
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
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
                height: 1.2,
                color: active ? Colors.white : AppTheme.dark,
              ),
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        chip(_BookingMode.self, translate("home.book_for_self")),
        chip(_BookingMode.withOthers, translate("home.book_with_others")),
        chip(_BookingMode.other, translate("home.book_for_other")),
      ],
    );
  }

  Widget _buildPassengerCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            offset: const Offset(0, 4),
            blurRadius: 16,
            color: AppTheme.black.withValues(alpha: 0.06),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                  child: Text16h500w(title: translate("home.passenger_info"))),
              Text(
                passengersNum.toString(),
                style: const TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.purple,
                ),
              ),
              if (_mode != _BookingMode.self) ...[
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _onAddPassenger,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppTheme.purple.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(
                      Icons.add,
                      color: AppTheme.purple,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (_me != null) ...[
            const SizedBox(height: 12),
            _buildModeSelector(),
          ],
          const SizedBox(height: 12),
          if (passengers.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                translate("home.fill_passenger_details"),
                style: const TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 13,
                  color: AppTheme.gray,
                ),
              ),
            ),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            itemCount: passengers.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) => PassengersContainer(
              passenger: passengers[index],
              onEdit: (data) {
                if (data.fullName.isNotEmpty) {
                  setState(() {
                    passengers[index].fullName = data.fullName;
                    passengers[index].phoneNumber = data.phoneNumber;
                    if (data.hasLocation) {
                      passengers[index].latitude = data.latitude;
                      passengers[index].longitude = data.longitude;
                    }
                  });
                }
              },
              onDelete: () {
                if (passengers.length > 1) {
                  setState(() {
                    passengers.removeAt(index);
                    passengersNum--;
                  });
                }
              },
              onSetLocation: () => _setPassengerLocation(index),
            ),
          ),
        ],
      ),
    );
  }

  // ── Bottom bars ────────────────────────────────────────────────────────────
  Widget _buildPassengerBottomBar() {
    final total = int.tryParse(pricePerSeat) ?? 0;
    return Container(
      padding: EdgeInsets.only(
        top: 16,
        left: 16,
        right: 16,
        bottom: 16 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppTheme.border)),
        boxShadow: [
          BoxShadow(
            offset: const Offset(0, -4),
            blurRadius: 16,
            color: AppTheme.black.withValues(alpha: 0.05),
          ),
        ],
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text14h400w(
                title: translate("home.total_price"),
                color: AppTheme.gray,
              ),
              Text(
                "${Utils.priceFormat((total * passengers.length).toString())} ${translate("currency")}",
                style: const TextStyle(
                  color: AppTheme.black,
                  fontSize: 18,
                  fontFamily: AppTheme.fontFamily,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: GestureDetector(
              onTap: _onBookTap,
              child: Container(
                height: 52,
                decoration: BoxDecoration(
                  color: AppTheme.purple,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: Text(
                    translate("home.book_now"),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontFamily: AppTheme.fontFamily,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCancelInfoCard() {
    final deadline =
        widget.trip.startTime.subtract(const Duration(minutes: 30));
    final deadlineStr = Utils.searchDateFormat(deadline);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.yellow.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.yellow.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded,
              color: AppTheme.yellow, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              translate("ketamiz.cancel_info_msg", args: {"time": deadlineStr}),
              style: const TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 13,
                color: AppTheme.dark,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Parcel acceptance toggle (driver view) ──────────────────────────────────
  Widget _buildParcelAcceptanceCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            offset: const Offset(0, 4),
            blurRadius: 16,
            color: AppTheme.black.withValues(alpha: 0.06),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.inventory_2_outlined,
              size: 18, color: AppTheme.purple),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text16h500w(title: translate("parcel.accept_parcels")),
                const SizedBox(height: 2),
                Text14h400w(
                  title: translate("parcel.accept_parcels_hint"),
                  color: AppTheme.gray,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _togglingParcels
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(AppTheme.purple),
                  ),
                )
              : Switch.adaptive(
                  value: _acceptsParcels,
                  activeTrackColor: AppTheme.purple,
                  onChanged: _toggleParcelAcceptance,
                ),
        ],
      ),
    );
  }

  // ── Parcels card (driver view) ─────────────────────────────────────────────
  Widget _buildTripParcelsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            offset: const Offset(0, 4),
            blurRadius: 16,
            color: AppTheme.black.withValues(alpha: 0.06),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text16h500w(title: translate("parcel.trip_parcels")),
              ),
              Text(
                "${_tripParcels.length}",
                style: const TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.purple,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...List.generate(_tripParcels.length, (i) {
            final p = _tripParcels[i];
            return Container(
              margin: EdgeInsets.only(
                  bottom: i == _tripParcels.length - 1 ? 0 : 10),
              child: _buildTripParcelRow(p),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildTripParcelRow(ParcelBooking p) {
    final typeAndWeight = [
      if (p.type != null) p.type!.name,
      "${Utils.weightFormat(p.weight)} ${translate("parcel.kg")}",
    ].join(" · ");

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ParcelDetailScreen(
            bookingId: p.id,
            initial: p,
            isDriver: true,
          ),
        ),
      ),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.light,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(Icons.inventory_2_outlined,
                  size: 22, color: AppTheme.purple),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text14h400w(title: typeAndWeight),
                  if (p.receiverPhone.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text14h400w(
                        title: p.receiverPhone, color: AppTheme.gray),
                  ],
                  const SizedBox(height: 6),
                  ParcelStatusBadge(status: p.status),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  "${Utils.priceFromNum(p.totalPrice)} ${translate("currency")}",
                  style: const TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.black,
                  ),
                ),
                const SizedBox(height: 4),
                const Icon(Icons.chevron_right_rounded,
                    size: 18, color: AppTheme.gray),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDriverTermsButton() {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const TermsScreen()),
        );
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          color: AppTheme.purple.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: AppTheme.purple.withValues(alpha: 0.18), width: 1),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.article_outlined,
                color: AppTheme.purple, size: 16),
            const SizedBox(width: 8),
            Text(
              translate("ketamiz.driver_terms"),
              style: const TextStyle(
                color: AppTheme.purple,
                fontSize: 13,
                fontFamily: AppTheme.fontFamily,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDriverBottomBar() {
    return Container(
      padding: EdgeInsets.only(
        top: 16,
        left: 16,
        right: 16,
        bottom: 16 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppTheme.border)),
        boxShadow: [
          BoxShadow(
            offset: const Offset(0, -4),
            blurRadius: 16,
            color: AppTheme.black.withValues(alpha: 0.05),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SlideToConfirmButton(
            label: translate("ketamiz.slide_to_start"),
            onConfirmed: _openGoogleMapsNavigation,
          ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: _isCancelling ? null : _cancelTrip,
            child: Container(
              height: 52,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.red, width: 1.5),
              ),
              child: Center(
                child: _isCancelling
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppTheme.red,
                        ),
                      )
                    : Text(
                        translate("ketamiz.cancel_trip"),
                        style: const TextStyle(
                          color: AppTheme.red,
                          fontSize: 15,
                          fontFamily: AppTheme.fontFamily,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Opens the backend-provided (or locally built) Google Maps directions
  /// link — see [_googleMapsUrl] — in the external Maps app.
  Future<void> _openGoogleMapsNavigation() async {
    final url = _googleMapsUrl;
    if (url.isEmpty) return;
    final uri = Uri.parse(url);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      await launchUrl(uri, mode: LaunchMode.platformDefault);
    }
  }

  Future<void> _cancelTrip() async {
    CenterDialog.showConfirmation(
      context,
      translate("ketamiz.cancel_trip"),
      translate("ketamiz.cancel_trip_confirm"),
      onConfirm: () async {
        Navigator.pop(context);
        setState(() => _isCancelling = true);

        final response = await Repository()
            .fetchCancelDriverTrip(widget.trip.id.toString());

        if (!mounted) return;
        setState(() => _isCancelling = false);

        if (response.isSuccess) {
          CustomSnackBar()
              .showSnackBar(context, translate("ketamiz.trip_cancelled"), 1);
          Navigator.of(context).popUntil((route) => route.isFirst);
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const MainScreen()),
          );
        } else {
          CenterDialog.showActionFailed(
            context,
            translate("ketamiz.error"),
            translate("auth.something_went_wrong"),
          );
        }
      },
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────
  Widget _infoRow({
    required IconData icon,
    required Color iconColor,
    required String label,
    String? value,
    Widget? valueWidget,
    Widget? child,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: iconColor, size: 16),
          ),
          const SizedBox(width: 10),
          // When an Expanded value (child) follows, the label must NOT take a
          // flex share — otherwise label and value split the row 50/50 and the
          // value right-aligns to the middle, leaving empty space on the right.
          (child != null || value != null)
              ? Text(
                  label,
                  style: const TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 13,
                    color: AppTheme.gray,
                    fontWeight: FontWeight.w400,
                  ),
                )
              : Flexible(
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 13,
                      color: AppTheme.gray,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
          if (child != null) ...[const SizedBox(width: 8), child],
          if (valueWidget != null) ...[const Spacer(), valueWidget],
          if (value != null) ...[
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                value,
                textAlign: TextAlign.end,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.black,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _divider() => const Divider(height: 1, color: AppTheme.border);

  /// Backend-provided link when available, otherwise a directions deep link
  /// built from the trip coordinates. Both open the installed Google Maps
  /// app via LaunchMode.externalApplication.
  String get _googleMapsUrl {
    if (widget.trip.googleMapUrl.isNotEmpty) return widget.trip.googleMapUrl;
    final t = widget.trip;
    if (t.startLat.isEmpty ||
        t.startLong.isEmpty ||
        t.endLat.isEmpty ||
        t.endLong.isEmpty) {
      return '';
    }
    return 'https://www.google.com/maps/dir/?api=1'
        '&origin=${t.startLat},${t.startLong}'
        '&destination=${t.endLat},${t.endLong}'
        '&travelmode=driving';
  }

  Widget _openInMapsButton() {
    return GestureDetector(
      onTap: () async {
        final uri = Uri.parse(_googleMapsUrl);
        try {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } catch (_) {
          // No handler for external launch — fall back to in-app browser.
          await launchUrl(uri, mode: LaunchMode.platformDefault);
        }
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          color: const Color(0xFF4285F4),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.map_outlined, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text(
              translate("home.open_in_google_maps"),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontFamily: AppTheme.fontFamily,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _routeMapButton() {
    // Exact route is revealed only after the user has booked this trip.
    final showExact = widget.isBooked;
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => MapRouteScreen(
              start: LatLng(double.tryParse(widget.trip.startLat) ?? 0,
                  double.tryParse(widget.trip.startLong) ?? 0),
              end: LatLng(double.tryParse(widget.trip.endLat) ?? 0,
                  double.tryParse(widget.trip.endLong) ?? 0),
              startText: from,
              endText: to,
              approximate: !showExact,
            ),
          ),
        );
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          color: AppTheme.purple.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: AppTheme.purple.withValues(alpha: 0.2), width: 1),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(showExact ? Icons.route_rounded : Icons.map_outlined,
                color: AppTheme.purple, size: 18),
            const SizedBox(width: 8),
            Text(
              translate("home.show_on_map"),
              style: const TextStyle(
                color: AppTheme.purple,
                fontSize: 14,
                fontFamily: AppTheme.fontFamily,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
