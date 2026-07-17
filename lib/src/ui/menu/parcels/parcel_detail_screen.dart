import 'package:flutter/material.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../model/api/parcel_model.dart';
import '../../../resources/repository.dart';
import '../../../theme/app_theme.dart';
import '../../widgets/parcel_image.dart';
import '../../../utils/utils.dart';
import '../../dialogs/center_dialog.dart';
import '../../dialogs/snack_bar.dart';
import '../../widgets/containers/leading_back.dart';
import '../../widgets/texts/text_16h_500w.dart';
import '../new_ketamiz/map_select_screen.dart';
import 'parcel_status.dart';

/// Full view of a single parcel booking. Used by both the client (with a
/// cancel action) and, read-only, the driver ([showCancel] = false).
class ParcelDetailScreen extends StatefulWidget {
  const ParcelDetailScreen({
    super.key,
    required this.bookingId,
    this.initial,
    this.isDriver = false,
  });

  final int bookingId;

  /// Optional already-loaded booking so content shows instantly.
  final ParcelBooking? initial;

  /// Driver view is read-only (no cancel).
  final bool isDriver;

  @override
  State<ParcelDetailScreen> createState() => _ParcelDetailScreenState();
}

class _ParcelDetailScreenState extends State<ParcelDetailScreen> {
  final Repository _repository = Repository();

  ParcelBooking? _booking;
  bool _loading = true;
  bool _cancelling = false;

  bool _editingLocation = false;
  bool _savingLocation = false;
  LatLng? _editPickup;
  LatLng? _editDropoff;

  @override
  void initState() {
    super.initState();
    _booking = widget.initial;
    _loading = widget.initial == null;
    _load();
  }

  /// Pickup/dropoff can only be changed for a not-yet-cancelled booking,
  /// before the trip actually starts.
  bool get _canEditLocation {
    final b = _booking;
    if (b == null || widget.isDriver || !b.isCancellable) return false;
    final start = b.trip?.startTime;
    return start != null && start.isAfter(DateTime.now());
  }

  Future<void> _load() async {
    // Driver detail isn't fetched individually — the list already carries the
    // full object, so only the client refetches for the freshest copy.
    if (widget.isDriver) {
      setState(() => _loading = false);
      return;
    }
    final response = await _repository.fetchClientParcelBooking(widget.bookingId);
    if (!mounted) return;
    if (response.isSuccess) {
      final fresh = ParcelBooking.fromResult(response.result);
      setState(() {
        if (fresh != null) _booking = fresh;
        _loading = false;
      });
    } else {
      setState(() => _loading = false);
    }
  }

  Future<void> _cancel() async {
    CenterDialog.showConfirmation(
      context,
      translate("parcel.cancel_parcel"),
      translate("parcel.cancel_confirm"),
      onConfirm: () async {
        Navigator.pop(context);
        setState(() => _cancelling = true);
        final response =
            await _repository.fetchCancelParcelBooking(widget.bookingId);
        if (!mounted) return;
        setState(() => _cancelling = false);
        if (response.isSuccess) {
          CustomSnackBar()
              .showSnackBar(context, translate("parcel.cancelled_success"), 1);
          Navigator.pop(context, true);
        } else {
          final msg = (response.result is Map
                  ? response.result['message']?.toString()
                  : null) ??
              translate("auth.something_went_wrong");
          CenterDialog.showActionFailed(
              context, translate("parcel.title"), msg);
        }
      },
    );
  }

  Future<void> _call(String phone) async {
    try {
      await launchUrl(Uri.parse('tel:$phone'),
          mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  void _startEditingLocation() {
    final b = _booking;
    if (b == null) return;
    setState(() {
      _editPickup = b.hasPickup ? LatLng(b.pickupLat!, b.pickupLong!) : null;
      _editDropoff =
          b.hasDropoff ? LatLng(b.dropoffLat!, b.dropoffLong!) : null;
      _editingLocation = true;
    });
  }

  void _cancelEditingLocation() {
    setState(() {
      _editingLocation = false;
      _editPickup = null;
      _editDropoff = null;
    });
  }

  Future<void> _pickEditPickup() async {
    final picked = await Navigator.push<LatLng>(
      context,
      MaterialPageRoute(
        builder: (_) => MapSelectScreen(
          place: _booking?.trip?.place(from: true) ?? '',
          onSelected: (_) {},
        ),
      ),
    );
    if (picked == null || !mounted) return;
    setState(() => _editPickup = picked);
  }

  Future<void> _pickEditDropoff() async {
    final picked = await Navigator.push<LatLng>(
      context,
      MaterialPageRoute(
        builder: (_) => MapSelectScreen(
          place: _booking?.trip?.place(from: false) ?? '',
          onSelected: (_) {},
        ),
      ),
    );
    if (picked == null || !mounted) return;
    setState(() => _editDropoff = picked);
  }

  Future<void> _saveLocation() async {
    final pickup = _editPickup;
    final dropoff = _editDropoff;
    if (pickup == null || dropoff == null) {
      CenterDialog.showActionFailed(
        context,
        translate("parcel.title"),
        pickup == null
            ? translate("parcel.set_pickup_location")
            : translate("parcel.set_dropoff_location"),
      );
      return;
    }

    setState(() => _savingLocation = true);
    final response = await _repository.fetchUpdateParcelLocation(
      bookingId: widget.bookingId,
      pickupLat: pickup.latitude.toString(),
      pickupLong: pickup.longitude.toString(),
      dropoffLat: dropoff.latitude.toString(),
      dropoffLong: dropoff.longitude.toString(),
    );

    if (!mounted) return;
    setState(() => _savingLocation = false);

    if (response.isSuccess) {
      final fresh = ParcelBooking.fromResult(response.result);
      setState(() {
        if (fresh != null) _booking = fresh;
        _editingLocation = false;
        _editPickup = null;
        _editDropoff = null;
      });
      CustomSnackBar()
          .showSnackBar(context, translate("home.pickup_updated"), 1);
    } else {
      final msg = (response.result is Map
              ? response.result['message']?.toString()
              : null) ??
          translate("auth.something_went_wrong");
      CenterDialog.showActionFailed(context, translate("parcel.title"), msg);
    }
  }

  @override
  Widget build(BuildContext context) {
    final b = _booking;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const LeadingBack(),
        title: Text16h500w(title: translate("parcel.parcel_details")),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.purple),
              ),
            )
          : b == null
              ? Center(
                  child: Text(
                    translate("parcel.not_found"),
                    style: const TextStyle(
                        fontFamily: AppTheme.fontFamily, color: AppTheme.gray),
                  ),
                )
              : Column(
                  children: [
                    Expanded(child: _buildContent(b)),
                    if (!widget.isDriver && b.isCancellable)
                      _buildCancelBar(),
                  ],
                ),
    );
  }

  Widget _buildContent(ParcelBooking b) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
      children: [
        Row(
          children: [
            ParcelStatusBadge(status: b.status),
            const Spacer(),
            if (b.createdAt != null)
              Text(
                '${Utils.dateFormat(b.createdAt!)} • ${Utils.timeFormat(b.createdAt!)}',
                style: const TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 12,
                  color: AppTheme.gray,
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        if (b.trip != null) _buildRouteCard(b.trip!),
        const SizedBox(height: 16),
        _buildLocationCard(b),
        const SizedBox(height: 16),
        _buildParcelCard(b),
        if (b.sender != null && b.sender!.fullName.isNotEmpty) ...[
          const SizedBox(height: 16),
          _buildPersonCard(
              translate("parcel.sender"), b.sender!, callable: false),
        ],
        if (b.driver != null && b.driver!.fullName.isNotEmpty) ...[
          const SizedBox(height: 16),
          _buildPersonCard(
              translate("parcel.driver"), b.driver!, callable: true),
        ],
      ],
    );
  }

  Widget _card({required Widget child}) {
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
      child: child,
    );
  }

  Widget _buildRouteCard(ParcelTripBrief trip) {
    final from = trip.place(from: true);
    final to = trip.place(from: false);
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text16h500w(title: translate("home.trip_details")),
          const SizedBox(height: 12),
          _routePoint(
            color: AppTheme.purple,
            time: trip.startTime,
            place: from.isEmpty ? "—" : from,
          ),
          Padding(
            padding: const EdgeInsets.only(left: 3.5),
            child: Container(width: 1, height: 18, color: AppTheme.border),
          ),
          _routePoint(
            color: AppTheme.red,
            time: trip.endTime,
            place: to.isEmpty ? "—" : to,
          ),
        ],
      ),
    );
  }

  Widget _routePoint({
    required Color color,
    required DateTime? time,
    required String place,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 4),
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (time != null)
                Text(
                  '${Utils.timeFormat(time)} · ${Utils.dateFormat(time)}',
                  style: const TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 12,
                    color: AppTheme.gray,
                  ),
                ),
              Text(
                place,
                style: const TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.black,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLocationCard(ParcelBooking b) {
    if (_editingLocation) return _buildLocationEditCard();

    final hasAny = b.hasPickup || b.hasDropoff;
    if (!hasAny && !_canEditLocation) return const SizedBox.shrink();

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child:
                    Text16h500w(title: translate("parcel.pickup_location")),
              ),
              if (_canEditLocation)
                GestureDetector(
                  onTap: _startEditingLocation,
                  child: Text(
                    translate("home.edit_pickup"),
                    style: const TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.purple,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          _routePoint(
            color: AppTheme.purple,
            time: null,
            place: b.hasPickup
                ? translate("parcel.pickup_set")
                : translate("parcel.set_pickup_location"),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 3.5),
            child: Container(width: 1, height: 18, color: AppTheme.border),
          ),
          _routePoint(
            color: AppTheme.red,
            time: null,
            place: b.hasDropoff
                ? translate("parcel.dropoff_set")
                : translate("parcel.set_dropoff_location"),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationEditCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text16h500w(title: translate("home.edit_pickup")),
          const SizedBox(height: 12),
          _editLocationField(
            location: _editPickup,
            label: translate("parcel.pickup_location"),
            setLabel: translate("parcel.pickup_set"),
            onTap: _pickEditPickup,
          ),
          const SizedBox(height: 10),
          _editLocationField(
            location: _editDropoff,
            label: translate("parcel.dropoff_location"),
            setLabel: translate("parcel.dropoff_set"),
            onTap: _pickEditDropoff,
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: _savingLocation ? null : _cancelEditingLocation,
                  child: Container(
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: Text(
                      translate("cancel"),
                      style: const TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.dark,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GestureDetector(
                  onTap: _savingLocation ? null : _saveLocation,
                  child: Container(
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppTheme.purple,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: _savingLocation
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : Text(
                            translate("home.save"),
                            style: const TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _editLocationField({
    required LatLng? location,
    required String label,
    required String setLabel,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: AppTheme.light,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: location == null ? AppTheme.border : AppTheme.purple,
          ),
        ),
        child: Row(
          children: [
            const Icon(Icons.location_on_outlined,
                color: AppTheme.purple, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                location == null
                    ? '$label · ${translate("home.pickup_choose_on_map")}'
                    : setLabel,
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 13.5,
                  color: location == null ? AppTheme.gray : AppTheme.black,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildParcelCard(ParcelBooking b) {
    final hasDims = b.length > 0 || b.width > 0 || b.height > 0;
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const ParcelImage(size: 20),
              const SizedBox(width: 8),
              Text16h500w(title: translate("parcel.parcel_info")),
            ],
          ),
          const SizedBox(height: 12),
          if (b.type != null)
            _row(translate("parcel.parcel_type"), b.type!.name),
          _row(translate("parcel.weight_kg"),
              "${Utils.weightFormat(b.weight)} ${translate("parcel.kg")}"),
          if (hasDims)
            _row(translate("parcel.size"),
                "${b.length}×${b.width}×${b.height} ${translate("parcel.cm")}"),
          _row(translate("parcel.receiver_phone"), b.receiverPhone),
          if (b.parcelDescription.isNotEmpty)
            _row(translate("parcel.description"), b.parcelDescription),
          const Divider(height: 24, color: AppTheme.border),
          Row(
            children: [
              Expanded(
                child: Text(
                  translate("parcel.total_price"),
                  style: const TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.black,
                  ),
                ),
              ),
              Text(
                "${Utils.priceFromNum(b.totalPrice)} ${translate("currency")}",
                style: const TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.purple,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPersonCard(String title, ParcelPerson person,
      {required bool callable}) {
    return _card(
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppTheme.purple.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.person_rounded,
                color: AppTheme.purple, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 12,
                    color: AppTheme.gray,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  person.fullName,
                  style: const TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.black,
                  ),
                ),
                if (person.phone.isNotEmpty)
                  Text(
                    person.phone,
                    style: const TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 13,
                      color: AppTheme.gray,
                    ),
                  ),
              ],
            ),
          ),
          if (callable && person.phone.isNotEmpty)
            GestureDetector(
              onTap: () => _call(person.phone),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.green.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.call, color: AppTheme.green, size: 20),
              ),
            ),
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 13,
              color: AppTheme.gray,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppTheme.black,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCancelBar() {
    return Container(
      padding: EdgeInsets.only(
        top: 14,
        left: 16,
        right: 16,
        bottom: 14 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(top: BorderSide(color: AppTheme.border)),
      ),
      child: GestureDetector(
        onTap: _cancelling ? null : _cancel,
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.red, width: 1.5),
          ),
          child: Center(
            child: _cancelling
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppTheme.red),
                  )
                : Text(
                    translate("parcel.cancel_parcel"),
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
    );
  }
}
