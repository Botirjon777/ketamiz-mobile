import 'package:flutter/material.dart';
import 'package:flutter_translate/flutter_translate.dart';

import '../../../theme/app_theme.dart';

/// Colour + localized label for a parcel booking status. Shared by the list
/// and detail screens so statuses render consistently.
Color parcelStatusColor(String status) {
  switch (status.toLowerCase()) {
    case 'confirmed':
      return AppTheme.green;
    case 'pending':
      return AppTheme.yellow;
    case 'cancelled':
    case 'canceled':
    case 'rejected':
      return AppTheme.red;
    default:
      return AppTheme.gray;
  }
}

String parcelStatusLabel(String status) {
  switch (status.toLowerCase()) {
    case 'confirmed':
      return translate("parcel.status_confirmed");
    case 'pending':
      return translate("parcel.status_pending");
    case 'cancelled':
    case 'canceled':
      return translate("parcel.status_cancelled");
    case 'rejected':
      return translate("parcel.status_rejected");
    default:
      return status;
  }
}

class ParcelStatusBadge extends StatelessWidget {
  const ParcelStatusBadge({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    if (status.isEmpty) return const SizedBox.shrink();
    final color = parcelStatusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        parcelStatusLabel(status),
        style: TextStyle(
          fontFamily: AppTheme.fontFamily,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
