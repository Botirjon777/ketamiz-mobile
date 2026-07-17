import 'package:flutter/material.dart';
import 'package:flutter_translate/flutter_translate.dart';

import '../../../model/api/parcel_model.dart';
import '../../../theme/app_theme.dart';
import '../../widgets/parcel_image.dart';
import '../../../utils/utils.dart';
import 'parcel_status.dart';

/// A parcel booking row used in the client's "My parcels" list and the
/// driver's incoming-parcels list.
class ParcelBookingTile extends StatelessWidget {
  const ParcelBookingTile({
    super.key,
    required this.booking,
    required this.onTap,
  });

  final ParcelBooking booking;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final trip = booking.trip;
    final from = trip?.place(from: true) ?? '';
    final to = trip?.place(from: false) ?? '';

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ParcelStatusBadge(status: booking.status),
                const Spacer(),
                Text(
                  "${Utils.priceFromNum(booking.totalPrice)} ${translate("currency")}",
                  style: const TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.black,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (trip != null) ...[
              _routeLine(AppTheme.purple, from.isEmpty ? "—" : from),
              const SizedBox(height: 6),
              _routeLine(AppTheme.red, to.isEmpty ? "—" : to),
              const SizedBox(height: 10),
            ],
            Row(
              children: [
                const ParcelImage(size: 16),
                const SizedBox(width: 6),
                Text(
                  "${Utils.weightFormat(booking.weight)} ${translate("parcel.kg")}"
                  "${booking.type != null ? " · ${booking.type!.name}" : ""}",
                  style: const TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 12.5,
                    color: AppTheme.gray,
                  ),
                ),
                const Spacer(),
                if (booking.createdAt != null)
                  Text(
                    Utils.dateFormat(booking.createdAt!),
                    style: const TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 12,
                      color: AppTheme.gray,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _routeLine(Color color, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 4),
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 13.5,
              fontWeight: FontWeight.w500,
              color: AppTheme.black,
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }
}
