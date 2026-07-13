import 'package:flutter/material.dart';
import 'package:flutter_translate/flutter_translate.dart';
import '../../../model/api/trip_list_model.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/utils.dart';
import '../parcel_image.dart';

class DestinationsContainer extends StatelessWidget {
  const DestinationsContainer({super.key, required this.trip});

  final TripListModel trip;

  String get _fromPlace {
    final parts = [trip.fromVillage, trip.fromCity, trip.fromRegion]
        .where((s) => s.isNotEmpty)
        .toList();
    if (parts.isNotEmpty) return parts.join(', ');
    return trip.fromWhere;
  }

  String get _toPlace {
    final parts = [trip.toVillage, trip.toCity, trip.toRegion]
        .where((s) => s.isNotEmpty)
        .toList();
    if (parts.isNotEmpty) return parts.join(', ');
    return trip.toWhere;
  }

  Color get _seatsColor {
    if (trip.availableSeats <= 1) return AppTheme.red;
    if (trip.availableSeats <= 3) return AppTheme.yellow;
    return AppTheme.green;
  }

  String get _status => trip.status.toLowerCase();

  /// Seats only make sense while the trip can still be booked.
  bool get _isActive => _status.isEmpty || _status == 'active';

  Color get _statusColor {
    switch (_status) {
      case 'completed':
        return const Color(0xFF4CAF50);
      case 'canceled':
      case 'cancelled':
        return const Color(0xFFE53935);
      default:
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
        return trip.status;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            offset: const Offset(0, 4),
            blurRadius: 16,
            spreadRadius: 0,
            color: AppTheme.black.withOpacity(0.06),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Top row: status badge + seats badge (active only) + price ────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (trip.status.isNotEmpty) ...[
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: _statusColor.withOpacity(0.1),
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
              // Seats left — only while the trip is still bookable
              if (_isActive)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: _seatsColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    "${trip.availableSeats} ${translate("home.seats_left")}",
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
                    "${Utils.priceFormat(trip.pricePerSeat)} ${translate("currency")}",
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
          // ── Body row: timeline + driver ──────────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Timeline dots
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
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          Utils.timeFormat(trip.startTime),
                          style: const TextStyle(
                            color: AppTheme.black,
                            fontSize: 16,
                            fontFamily: AppTheme.fontFamily,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          Utils.dateFormat(trip.startTime),
                          style: const TextStyle(
                            color: AppTheme.gray,
                            fontSize: 13,
                            fontFamily: AppTheme.fontFamily,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      _fromPlace,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppTheme.dark,
                        fontSize: 13,
                        fontFamily: AppTheme.fontFamily,
                        fontWeight: FontWeight.w400,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          Utils.timeFormat(trip.endTime),
                          style: const TextStyle(
                            color: AppTheme.black,
                            fontSize: 16,
                            fontFamily: AppTheme.fontFamily,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          Utils.dateFormat(trip.endTime),
                          style: const TextStyle(
                            color: AppTheme.gray,
                            fontSize: 13,
                            fontFamily: AppTheme.fontFamily,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      _toPlace,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppTheme.dark,
                        fontSize: 13,
                        fontFamily: AppTheme.fontFamily,
                        fontWeight: FontWeight.w400,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Vehicle info — driver details stay hidden until the trip is booked.
              Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 84,
                    height: 52,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.light,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Image.asset(
                      'assets/images/distance.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                  if (trip.vehicle.model.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    SizedBox(
                      width: 92,
                      child: Text(
                        trip.vehicle.model.toUpperCase(),
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
                  if (trip.vehicle.color.titleEn.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: Utils.colorFromHex(trip.vehicle.color.code),
                            shape: BoxShape.circle,
                            border: Border.all(color: AppTheme.border),
                          ),
                        ),
                        const SizedBox(width: 4),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 74),
                          child: Text(
                            trip.vehicle.color.titleEn,
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
          if (trip.acceptsParcels && trip.parcel != null) ...[
            const SizedBox(height: 12),
            _buildParcelStrip(),
          ],
        ],
      ),
    );
  }

  /// Green strip advertising the driver's parcel rate for this trip, shown as
  /// a per-kilogram price (e.g. "5,000 UZS/kg").
  Widget _buildParcelStrip() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.green.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const ParcelImage(size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              translate("home.parcel_price"),
              style: const TextStyle(
                color: AppTheme.gray,
                fontSize: 12,
                fontFamily: AppTheme.fontFamily,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
          Text(
            "${Utils.priceFromNum(trip.parcel!.pricePerKg)} "
            "${translate("currency")}/${translate("parcel.kg")}",
            style: const TextStyle(
              color: AppTheme.green,
              fontSize: 13.5,
              fontFamily: AppTheme.fontFamily,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
