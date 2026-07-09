import 'package:flutter/material.dart';
import 'package:flutter_translate/flutter_translate.dart';

import '../../../model/api/parcel_model.dart';
import '../../../model/event_bus/http_result.dart';
import '../../../resources/repository.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/nav_constants.dart';
import '../../widgets/texts/text_14h_400w.dart';
import 'parcel_booking_tile.dart';
import 'parcel_detail_screen.dart';

/// Parcels list embedded inside the Trips/Orders tab. For the client it shows
/// their sent parcels (`GET /client/parcel-bookings`); for the driver, parcels
/// received across their trips (`GET /driver/parcel-bookings`). Has loading /
/// empty / error states and pull-to-refresh; [topPadding] clears the tab's
/// overlay header.
class MyParcelsView extends StatefulWidget {
  const MyParcelsView({
    super.key,
    this.topPadding = 140,
    this.driver = false,
    this.tripId,
  });

  final double topPadding;

  /// Driver view: fetches received parcels and opens details read-only.
  final bool driver;

  /// When set (driver view), lists parcels for this trip only.
  final int? tripId;

  @override
  State<MyParcelsView> createState() => _MyParcelsViewState();
}

class _MyParcelsViewState extends State<MyParcelsView> {
  final Repository _repository = Repository();

  bool _loading = true;
  bool _hasError = false;
  List<ParcelBooking> _items = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _hasError = false;
      });
    }
    final HttpResult response;
    if (widget.driver) {
      response = widget.tripId != null
          ? await _repository.fetchDriverParcelBookingsByTrip(widget.tripId!)
          : await _repository.fetchDriverParcelBookings();
    } else {
      response = await _repository.fetchClientParcelBookings();
    }
    if (!mounted) return;
    if (response.isSuccess) {
      setState(() {
        _items = ParcelBooking.listFromResult(response.result);
        _loading = false;
      });
    } else {
      setState(() {
        _hasError = true;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: AppTheme.purple,
      onRefresh: _load,
      child: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading && _items.isEmpty) {
      return ListView(
        children: [
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.6,
            child: const Center(
              child: CircularProgressIndicator(color: AppTheme.purple),
            ),
          ),
        ],
      );
    }

    if ((_hasError || _items.isEmpty)) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.only(top: widget.topPadding),
        children: [
          SizedBox(
            height: MediaQuery.of(context).size.height - 300,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _hasError
                      ? Icons.wifi_off_rounded
                      : Icons.inventory_2_outlined,
                  size: 64,
                  color: AppTheme.gray.withValues(alpha: 0.5),
                ),
                const SizedBox(height: 16),
                Text14h400w(
                  title: _hasError
                      ? translate("parcel.load_error")
                      : translate("parcel.no_parcels"),
                  color: AppTheme.gray,
                ),
                if (_hasError) ...[
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: _load,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppTheme.purple,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        translate("home.retry"),
                        style: const TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.only(
        top: widget.topPadding,
        bottom: kNavBarTotalPadding,
        left: 16,
        right: 16,
      ),
      itemCount: _items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 14),
      itemBuilder: (context, i) => ParcelBookingTile(
        booking: _items[i],
        onTap: () async {
          final cancelled = await Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder: (_) => ParcelDetailScreen(
                bookingId: _items[i].id,
                initial: _items[i],
                isDriver: widget.driver,
              ),
            ),
          );
          if (cancelled == true) _load();
        },
      ),
    );
  }
}
