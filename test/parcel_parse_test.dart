import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:ketamiz/src/model/api/trip_list_model.dart';

/// Verifies the live backend trip payload (with the `parcel` block) parses into
/// TripListModel correctly — the shape used by both the home list and search.
const _payload = '''
{
  "data": [
    {
      "id": 38,
      "accepts_parcels": true,
      "price_per_seat": "50000.00",
      "available_seats": 3,
      "start_time": "2026-07-10 18:00:00",
      "end_time": "2026-07-10 19:30:00",
      "created_at": "2026-07-10 13:54:48",
      "updated_at": "2026-07-10 13:54:48",
      "parcel": {
        "id": 1,
        "max_weight": 20,
        "available_weight": 20,
        "price_per_kg": "5000.00",
        "max_length": 60,
        "max_width": 40,
        "max_height": 30,
        "types": [
          {"id": 1, "name": "Hujjat / konvert", "icon": "document"},
          {"id": 3, "name": "O'rta quti", "icon": "box_medium"}
        ]
      },
      "vehicle": {"id": 9, "model": "Malibu", "seats": 4, "car_number": "30-S386ER", "color": {"id": 5}},
      "driver": {"id": 22, "name": "Ramziddin", "last_name": "Rustamov", "role": "driver"}
    },
    {
      "id": 37,
      "accepts_parcels": false,
      "price_per_seat": "85000.00",
      "available_seats": 4,
      "start_time": "2026-07-10 20:00:00",
      "end_time": "2026-07-10 23:00:00",
      "created_at": "2026-07-09 23:02:32",
      "updated_at": "2026-07-09 23:02:32",
      "parcel": null,
      "vehicle": {"id": 9, "model": "Malibu", "seats": 4, "car_number": "30-S386ER", "color": {"id": 5}},
      "driver": {"id": 22, "name": "Ramziddin", "last_name": "Rustamov", "role": "driver"}
    }
  ]
}
''';

void main() {
  test('parses accepts_parcels + parcel block', () {
    final data = (jsonDecode(_payload)['data'] as List)
        .map((e) => TripListModel.fromJson(Map<String, dynamic>.from(e)))
        .toList();

    final withParcel = data[0];
    expect(withParcel.acceptsParcels, isTrue);
    expect(withParcel.parcel, isNotNull);
    expect(withParcel.parcel!.pricePerKg, 5000.0); // "5000.00" string → double
    expect(withParcel.parcel!.maxWeight, 20.0);
    expect(withParcel.parcel!.availableWeight, 20.0);
    expect(withParcel.parcel!.maxLength, 60);
    expect(withParcel.parcel!.hasDimensionLimits, isTrue);
    expect(withParcel.parcel!.types.map((t) => t.id).toList(), [1, 3]);
    expect(withParcel.parcel!.types[0].name, 'Hujjat / konvert');
    // Card strip shows price/kg × 5.
    expect(withParcel.parcel!.pricePerKg * 5, 25000.0);

    final noParcel = data[1];
    expect(noParcel.acceptsParcels, isFalse);
    expect(noParcel.parcel, isNull);
  });
}
