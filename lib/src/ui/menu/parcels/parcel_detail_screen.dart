import 'package:flutter/material.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../model/api/parcel_model.dart';
import '../../../resources/repository.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/utils.dart';
import '../../dialogs/center_dialog.dart';
import '../../dialogs/snack_bar.dart';
import '../../widgets/containers/leading_back.dart';
import '../../widgets/texts/text_16h_500w.dart';
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

  @override
  void initState() {
    super.initState();
    _booking = widget.initial;
    _loading = widget.initial == null;
    _load();
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

  Widget _buildParcelCard(ParcelBooking b) {
    final hasDims = b.length > 0 || b.width > 0 || b.height > 0;
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text16h500w(title: translate("parcel.parcel_info")),
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
