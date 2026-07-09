/// Models for the parcel (posilka) subsystem.
///
/// The API wraps payloads in a `{ status, message, data }` envelope; the
/// `*FromResult` helpers here unwrap that (and Laravel pagination) tolerantly,
/// so callers can pass `HttpResult.result` straight in. All localized strings
/// (`name`, region/district names, messages) already arrive in the user's
/// language from the backend.

/// A parcel type (document, small box, …) — shown in the send-parcel form and
/// echoed back on a booking.
class ParcelType {
  final int id;
  final String name;
  final String icon;

  const ParcelType({required this.id, required this.name, this.icon = ''});

  factory ParcelType.fromJson(Map<String, dynamic> json) => ParcelType(
        id: _asInt(json['id']),
        name: json['name']?.toString() ?? '',
        icon: json['icon']?.toString() ?? '',
      );

  static List<ParcelType> listFromResult(dynamic result) {
    final payload = _unwrap(result);
    if (payload is List) {
      return payload
          .whereType<Map>()
          .map((e) => ParcelType.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    return const [];
  }
}

/// A trip's parcel configuration (the `parcel` block on a trip). Present only
/// when the trip accepts parcels.
class ParcelInfo {
  final int id;
  final double maxWeight;
  final double availableWeight;
  final double pricePerKg;
  final int maxLength;
  final int maxWidth;
  final int maxHeight;
  final List<ParcelType> types;

  const ParcelInfo({
    required this.id,
    required this.maxWeight,
    required this.availableWeight,
    required this.pricePerKg,
    this.maxLength = 0,
    this.maxWidth = 0,
    this.maxHeight = 0,
    this.types = const [],
  });

  bool get hasDimensionLimits =>
      maxLength > 0 || maxWidth > 0 || maxHeight > 0;

  factory ParcelInfo.fromJson(Map<String, dynamic> json) => ParcelInfo(
        id: _asInt(json['id']),
        maxWeight: _asDouble(json['max_weight']),
        availableWeight: _asDouble(json['available_weight']),
        pricePerKg: _asDouble(json['price_per_kg']),
        maxLength: _asInt(json['max_length']),
        maxWidth: _asInt(json['max_width']),
        maxHeight: _asInt(json['max_height']),
        types: json['types'] is List
            ? (json['types'] as List)
                .whereType<Map>()
                .map((e) => ParcelType.fromJson(Map<String, dynamic>.from(e)))
                .toList()
            : const [],
      );

  static ParcelInfo? maybeFromJson(dynamic json) {
    if (json is Map) {
      return ParcelInfo.fromJson(Map<String, dynamic>.from(json));
    }
    return null;
  }
}

/// A person attached to a booking (sender or driver).
class ParcelPerson {
  final int id;
  final String firstName;
  final String lastName;
  final String phone;

  const ParcelPerson({
    this.id = 0,
    this.firstName = '',
    this.lastName = '',
    this.phone = '',
  });

  String get fullName => '$firstName $lastName'.trim();

  factory ParcelPerson.fromJson(Map<String, dynamic> json) => ParcelPerson(
        id: _asInt(json['id']),
        firstName: json['first_name']?.toString() ?? '',
        lastName: json['last_name']?.toString() ?? '',
        phone: json['phone']?.toString() ?? '',
      );

  static ParcelPerson? maybeFromJson(dynamic json) {
    if (json is Map) {
      return ParcelPerson.fromJson(Map<String, dynamic>.from(json));
    }
    return null;
  }
}

/// The lightweight trip summary embedded in a booking.
class ParcelTripBrief {
  final int id;
  final String startRegion;
  final String endRegion;
  final String startDistrict;
  final String endDistrict;
  final String startQuarter;
  final String endQuarter;
  final DateTime? startTime;
  final DateTime? endTime;
  final String status;

  const ParcelTripBrief({
    this.id = 0,
    this.startRegion = '',
    this.endRegion = '',
    this.startDistrict = '',
    this.endDistrict = '',
    this.startQuarter = '',
    this.endQuarter = '',
    this.startTime,
    this.endTime,
    this.status = '',
  });

  factory ParcelTripBrief.fromJson(Map<String, dynamic> json) =>
      ParcelTripBrief(
        id: _asInt(json['id']),
        startRegion: json['start_region']?.toString() ?? '',
        endRegion: json['end_region']?.toString() ?? '',
        startDistrict: json['start_district']?.toString() ?? '',
        endDistrict: json['end_district']?.toString() ?? '',
        startQuarter: json['start_quarter']?.toString() ?? '',
        endQuarter: json['end_quarter']?.toString() ?? '',
        startTime: _asDate(json['start_time']),
        endTime: _asDate(json['end_time']),
        status: json['status']?.toString() ?? '',
      );

  /// "Quarter, District, Region" for an endpoint (narrow → broad), skipping
  /// empty parts. [from] picks the start side, otherwise the end side.
  String place({required bool from}) {
    final parts = from
        ? [startQuarter, startDistrict, startRegion]
        : [endQuarter, endDistrict, endRegion];
    return parts.where((s) => s.isNotEmpty).join(', ');
  }

  static ParcelTripBrief? maybeFromJson(dynamic json) {
    if (json is Map) {
      return ParcelTripBrief.fromJson(Map<String, dynamic>.from(json));
    }
    return null;
  }
}

/// A parcel booking — the client's sent parcel / the driver's received one.
class ParcelBooking {
  final int id;
  final String status;
  final double weight;
  final int length;
  final int width;
  final int height;
  final double totalPrice;
  final String receiverPhone;
  final String parcelDescription;
  final DateTime? createdAt;
  final ParcelType? type;
  final ParcelTripBrief? trip;
  final ParcelPerson? sender;
  final ParcelPerson? driver;

  const ParcelBooking({
    required this.id,
    this.status = '',
    this.weight = 0,
    this.length = 0,
    this.width = 0,
    this.height = 0,
    this.totalPrice = 0,
    this.receiverPhone = '',
    this.parcelDescription = '',
    this.createdAt,
    this.type,
    this.trip,
    this.sender,
    this.driver,
  });

  bool get isCancellable => status == 'pending' || status == 'confirmed';

  factory ParcelBooking.fromJson(Map<String, dynamic> json) => ParcelBooking(
        id: _asInt(json['id']),
        status: json['status']?.toString() ?? '',
        weight: _asDouble(json['weight']),
        length: _asInt(json['length']),
        width: _asInt(json['width']),
        height: _asInt(json['height']),
        totalPrice: _asDouble(json['total_price']),
        receiverPhone: json['receiver_phone']?.toString() ?? '',
        parcelDescription: json['parcel_description']?.toString() ?? '',
        createdAt: _asDate(json['created_at']),
        type: json['type'] is Map
            ? ParcelType.fromJson(Map<String, dynamic>.from(json['type']))
            : null,
        trip: ParcelTripBrief.maybeFromJson(json['trip']),
        sender: ParcelPerson.maybeFromJson(json['sender']),
        driver: ParcelPerson.maybeFromJson(json['driver']),
      );

  static List<ParcelBooking> listFromResult(dynamic result) {
    final payload = _unwrap(result);
    if (payload is List) {
      return payload
          .whereType<Map>()
          .map((e) => ParcelBooking.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    return const [];
  }

  static ParcelBooking? fromResult(dynamic result) {
    final payload = _unwrap(result);
    if (payload is Map) {
      return ParcelBooking.fromJson(Map<String, dynamic>.from(payload));
    }
    return null;
  }
}

// ── Shared helpers ──────────────────────────────────────────────────────────

/// Unwraps the `{ data: ... }` envelope and Laravel pagination
/// (`{ data: { data: [...] } }`).
dynamic _unwrap(dynamic result) {
  dynamic p = result;
  if (p is Map && p.containsKey('data')) p = p['data'];
  if (p is Map && p['data'] is List) p = p['data'];
  return p;
}

int _asInt(dynamic v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v?.toString() ?? '') ?? 0;
}

double _asDouble(dynamic v) {
  if (v is num) return v.toDouble();
  return double.tryParse(v?.toString() ?? '') ?? 0;
}

DateTime? _asDate(dynamic v) {
  if (v == null) return null;
  return DateTime.tryParse(v.toString())?.toLocal();
}
