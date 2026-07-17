import 'package:flutter/material.dart';
import 'package:flutter_translate/flutter_translate.dart';

import '../../widgets/containers/leading_back.dart';
import '../../widgets/texts/text_16h_500w.dart';
import 'my_parcels_view.dart';

/// Driver view of the parcels received for one specific trip.
class TripParcelsScreen extends StatelessWidget {
  const TripParcelsScreen({super.key, required this.tripId});

  final int tripId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const LeadingBack(),
        title: Text16h500w(title: translate("parcel.trip_parcels")),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: MyParcelsView(driver: true, tripId: tripId, topPadding: 12),
      ),
    );
  }
}
