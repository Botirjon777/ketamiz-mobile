import 'dart:convert';

import 'parcel_model.dart';

List<TripListModel> tripListModelFromJson(String str) => List<TripListModel>.from(json.decode(str).map((x) => TripListModel.fromJson(x)));

String tripListModelToJson(List<TripListModel> data) => json.encode(List<dynamic>.from(data.map((x) => x.toJson())));

class TripListModel {
  int id;
  String fromWhere;
  String toWhere;
  // String address parts (populated from API string fields)
  String fromRegion;
  String fromCity;
  String fromVillage;
  String toRegion;
  String toCity;
  String toVillage;
  // Legacy integer ID fields (kept for driver-trip construction via LocationData)
  int fromRegionId;
  int toRegionId;
  int fromCityId;
  int toCityId;
  int fromVillageId;
  int toVillageId;
  DateTime startTime;
  DateTime endTime;
  String pricePerSeat;
  int totalSeats;
  int availableSeats;
  String startLat;
  String startLong;
  String endLat;
  String endLong;
  String status;
  String googleMapUrl;
  DateTime createdAt;
  DateTime updatedAt;
  TripDriver driver;
  TripVehicle vehicle;
  // Parcel (posilka) config — present when the trip accepts parcels.
  bool acceptsParcels;
  ParcelInfo? parcel;

  TripListModel({
    required this.id,
    required this.fromWhere,
    required this.toWhere,
    this.fromRegion = "",
    this.fromCity = "",
    this.fromVillage = "",
    this.toRegion = "",
    this.toCity = "",
    this.toVillage = "",
    required this.fromRegionId,
    required this.toRegionId,
    required this.fromCityId,
    required this.toCityId,
    required this.fromVillageId,
    required this.toVillageId,
    required this.startTime,
    required this.endTime,
    required this.pricePerSeat,
    required this.totalSeats,
    required this.availableSeats,
    required this.startLat,
    required this.startLong,
    required this.endLat,
    required this.endLong,
    required this.status,
    this.googleMapUrl = "",
    required this.createdAt,
    required this.updatedAt,
    required this.driver,
    required this.vehicle,
    this.acceptsParcels = false,
    this.parcel,
  });

  factory TripListModel.fromJson(Map<String, dynamic> json) {
    final fromRegion = json["start_region"]?.toString() ?? "";
    final fromCity = json["start_district"]?.toString() ?? "";
    final fromVillage = json["start_quarter"]?.toString() ?? "";
    final toRegion = json["end_region"]?.toString() ?? "";
    final toCity = json["end_district"]?.toString() ?? "";
    final toVillage = json["end_quarter"]?.toString() ?? "";

    String _join(List<String> parts) =>
        parts.where((s) => s.isNotEmpty).join(", ");

    return TripListModel(
      id: _asInt(json["id"]),
      fromWhere: _join([fromVillage, fromCity, fromRegion]),
      toWhere: _join([toVillage, toCity, toRegion]),
      fromRegion: fromRegion,
      fromCity: fromCity,
      fromVillage: fromVillage,
      toRegion: toRegion,
      toCity: toCity,
      toVillage: toVillage,
      fromRegionId: _asInt(json["from_region_id"]),
      toRegionId: _asInt(json["to_region_id"]),
      fromCityId: _asInt(json["from_district_id"]),
      toCityId: _asInt(json["to_district_id"]),
      fromVillageId: _asInt(json["from_quarter_id"]),
      toVillageId: _asInt(json["to_quarter_id"]),
      startTime: _parseDate(json["start_time"]),
      endTime: _parseDate(json["end_time"]),
      pricePerSeat: json["price_per_seat"]?.toString() ?? "",
      totalSeats: _asInt(json["total_seats"]),
      availableSeats: _asInt(json["available_seats"]),
      startLat: json["start_lat"]?.toString() ?? "",
      startLong: json["start_long"]?.toString() ?? "",
      endLat: json["end_lat"]?.toString() ?? "",
      endLong: json["end_long"]?.toString() ?? "",
      status: json["status"]?.toString() ?? "",
      googleMapUrl: json["google_map_url"]?.toString() ?? "",
      createdAt: _parseDate(json["created_at"]),
      updatedAt: _parseDate(json["updated_at"]),
      driver: json["driver"] is Map<String, dynamic>
          ? TripDriver.fromJson(json["driver"])
          : TripDriver(id: 0, name: "", role: ""),
      vehicle: json["vehicle"] is Map<String, dynamic>
          ? TripVehicle.fromJson(json["vehicle"])
          : TripVehicle(
              id: 0,
              model: "",
              seats: 0,
              carNumber: "",
              color: CarColor(
                  id: 0, titleUz: "", titleRu: "", titleEn: "", code: ""),
            ),
      acceptsParcels: json["accepts_parcels"] == true ||
          json["accepts_parcels"] == 1 ||
          json["accepts_parcels"]?.toString() == "1",
      parcel: ParcelInfo.maybeFromJson(json["parcel"]),
    );
  }

  static int _asInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  static DateTime _parseDate(dynamic v) {
    if (v is String && v.isNotEmpty) {
      return DateTime.tryParse(v) ?? DateTime.now();
    }
    return DateTime.now();
  }

  Map<String, dynamic> toJson() => {
    "id": id,
    "from_where": fromWhere,
    "to_where": toWhere,
    "from_region_id": fromRegionId,
    "to_region_id": toRegionId,
    "from_district_id": fromCityId,
    "to_district_id": toCityId,
    "from_quarter_id": fromVillageId,
    "to_quarter_id": toVillageId,
    "start_time": startTime.toIso8601String(),
    "end_time": endTime.toIso8601String(),
    "price_per_seat": pricePerSeat,
    "total_seats": totalSeats,
    "available_seats": availableSeats,
    "start_lat": startLat,
    "start_long": startLong,
    "end_lat": endLat,
    "end_long": endLong,
    "status": status,
    "google_map_url": googleMapUrl,
    "created_at": createdAt.toIso8601String(),
    "updated_at": updatedAt.toIso8601String(),
    "driver": driver.toJson(),
    "vehicle": vehicle.toJson(),
  };
}

class TripDriver {
  int id;
  String name;
  String role;

  TripDriver({
    required this.id,
    required this.name,
    required this.role,
  });

  factory TripDriver.fromJson(Map<String, dynamic> json) => TripDriver(
    id: json["id"]??0,
    name: json["name"]??"",
    role: json["role"]??"",
  );

  Map<String, dynamic> toJson() => {
    "id": id,
    "name": name,
    "role": role,
  };
}

class TripVehicle {
  int id;
  String model;
  int seats;
  String carNumber;
  CarColor color;

  TripVehicle({
    required this.id,
    required this.model,
    required this.seats,
    required this.carNumber,
    required this.color,
  });

  factory TripVehicle.fromJson(Map<String, dynamic> json) => TripVehicle(
    id: TripListModel._asInt(json["id"]),
    model: json["model"]?.toString() ?? "",
    seats: TripListModel._asInt(json["seats"]),
    carNumber: json["car_number"]?.toString() ?? "",
    color: json["color"] is Map<String, dynamic>
        ? CarColor.fromJson(json["color"])
        : CarColor(id: 0, titleUz: "", titleRu: "", titleEn: "", code: ""),
  );

  Map<String, dynamic> toJson() => {
    "id": id,
    "model": model,
    "seats": seats,
    "car_number": carNumber,
    "color": color.toJson(),
  };
}

class CarColor {
  int id;
  String titleUz;
  String titleRu;
  String titleEn;
  String code;

  CarColor({
    required this.id,
    required this.titleUz,
    required this.titleRu,
    required this.titleEn,
    required this.code,
  });

  factory CarColor.fromJson(Map<String, dynamic> json) => CarColor(
    id: json["id"]??0,
    titleUz: json["title_uz"]??"",
    titleRu: json["title_ru"]??"",
    titleEn: json["title_en"]??"",
    code: json["code"]??"",
  );

  Map<String, dynamic> toJson() => {
    "id": id,
    "title_uz": titleUz,
    "title_ru": titleRu,
    "title_en": titleEn,
    "code": code,
  };
}
