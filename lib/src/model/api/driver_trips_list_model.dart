import 'dart:convert';

import 'parcel_model.dart';

DriverTripsListModel driverTripsListModelFromJson(String str) =>
    DriverTripsListModel.fromJson(json.decode(str));

String driverTripsListModelToJson(DriverTripsListModel data) =>
    json.encode(data.toJson());

int _asInt(dynamic v) {
  if (v == null) return 0;
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? 0;
  return 0;
}

DateTime _parseDate(dynamic v) {
  if (v is String && v.isNotEmpty) {
    return DateTime.tryParse(v) ?? DateTime.now();
  }
  return DateTime.now();
}

class DriverTripsListModel {
  String status;
  String message;
  List<DriverTripModel> data;
  Meta meta;

  DriverTripsListModel({
    required this.status,
    required this.message,
    required this.data,
    required this.meta,
  });

  factory DriverTripsListModel.fromJson(Map<String, dynamic> json) =>
      DriverTripsListModel(
        status: json["status"]?.toString() ?? "",
        message: json["message"]?.toString() ?? "",
        data: json["data"] is List
            ? (json["data"] as List)
                .whereType<Map>()
                .map((x) =>
                    DriverTripModel.fromJson(Map<String, dynamic>.from(x)))
                .toList()
            : <DriverTripModel>[],
        meta: json["meta"] is Map<String, dynamic>
            ? Meta.fromJson(json["meta"])
            : Meta.empty(),
      );

  Map<String, dynamic> toJson() => {
        "status": status,
        "message": message,
        "data": List<dynamic>.from(data.map((x) => x.toJson())),
        "meta": meta.toJson(),
      };
}

class DriverTripModel {
  int id;
  String googleMapUrl;
  String fromRegion;
  String fromCity;
  String fromVillage;
  String toRegion;
  String toCity;
  String toVillage;
  int fromRegionId;
  int toRegionId;
  int fromCityId;
  int toCityId;
  int fromVillageId;
  int toVillageId;
  DateTime startTime;
  DateTime endTime;
  String duration;
  String pricePerSeat;
  int totalSeats;
  int availableSeats;
  String startLat;
  String startLong;
  String endLat;
  String endLong;
  String status;
  DateTime createdAt;
  DateTime updatedAt;
  Driver driver;
  Vehicle vehicle;
  IngPoint startingPoint;
  IngPoint endingPoint;
  List<dynamic> bookings;
  // Parcel (posilka) config — present when the trip accepts parcels.
  bool acceptsParcels;
  ParcelInfo? parcel;

  DriverTripModel({
    required this.id,
    this.googleMapUrl = "",
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
    required this.duration,
    required this.pricePerSeat,
    required this.totalSeats,
    required this.availableSeats,
    required this.startLat,
    required this.startLong,
    required this.endLat,
    required this.endLong,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    required this.driver,
    required this.vehicle,
    required this.startingPoint,
    required this.endingPoint,
    required this.bookings,
    this.acceptsParcels = false,
    this.parcel,
  });

  factory DriverTripModel.fromJson(Map<String, dynamic> json) =>
      DriverTripModel(
        id: _asInt(json["id"]),
        googleMapUrl: json["google_map_url"]?.toString() ?? "",
        fromRegion: json["start_region"]?.toString() ?? "",
        fromCity: json["start_district"]?.toString() ?? "",
        fromVillage: json["start_quarter"]?.toString() ?? "",
        toRegion: json["end_region"]?.toString() ?? "",
        toCity: json["end_district"]?.toString() ?? "",
        toVillage: json["end_quarter"]?.toString() ?? "",
        fromRegionId: _asInt(json["from_region_id"]),
        toRegionId: _asInt(json["to_region_id"]),
        fromCityId: _asInt(json["from_district_id"]),
        toCityId: _asInt(json["to_district_id"]),
        fromVillageId: _asInt(json["from_quarter_id"]),
        toVillageId: _asInt(json["to_quarter_id"]),
        startTime: _parseDate(json["start_time"]),
        endTime: _parseDate(json["end_time"]),
        duration: json["duration"]?.toString() ?? "",
        pricePerSeat: json["price_per_seat"]?.toString() ?? "0",
        totalSeats: _asInt(json["total_seats"]),
        availableSeats: _asInt(json["available_seats"]),
        startLat: json["start_lat"]?.toString() ?? "",
        startLong: json["start_long"]?.toString() ?? "",
        endLat: json["end_lat"]?.toString() ?? "",
        endLong: json["end_long"]?.toString() ?? "",
        status: json["status"]?.toString() ?? "",
        createdAt: _parseDate(json["created_at"]),
        updatedAt: _parseDate(json["updated_at"]),
        driver: json["driver"] is Map<String, dynamic>
            ? Driver.fromJson(json["driver"])
            : Driver.empty(),
        vehicle: json["vehicle"] is Map<String, dynamic>
            ? Vehicle.fromJson(json["vehicle"])
            : Vehicle.empty(),
        startingPoint: json["starting_point"] is Map<String, dynamic>
            ? IngPoint.fromJson(json["starting_point"])
            : IngPoint.empty(),
        endingPoint: json["ending_point"] is Map<String, dynamic>
            ? IngPoint.fromJson(json["ending_point"])
            : IngPoint.empty(),
        bookings: json["bookings"] is List
            ? List<dynamic>.from((json["bookings"] as List).map((x) => x))
            : <dynamic>[],
        acceptsParcels: json["accepts_parcels"] == true ||
            json["accepts_parcels"] == 1 ||
            json["accepts_parcels"]?.toString() == "1",
        parcel: ParcelInfo.maybeFromJson(json["parcel"]),
      );

  Map<String, dynamic> toJson() => {
        "id": id,
        "google_map_url": googleMapUrl,
        "from_region_id": fromRegionId,
        "to_region_id": toRegionId,
        "from_district_id": fromCityId,
        "to_district_id": toCityId,
        "from_quarter_id": fromVillageId,
        "to_quarter_id": toVillageId,
        "start_time": startTime.toIso8601String(),
        "end_time": endTime.toIso8601String(),
        "duration": duration,
        "price_per_seat": pricePerSeat,
        "total_seats": totalSeats,
        "available_seats": availableSeats,
        "start_lat": startLat,
        "start_long": startLong,
        "end_lat": endLat,
        "end_long": endLong,
        "status": status,
        "created_at": createdAt.toIso8601String(),
        "updated_at": updatedAt.toIso8601String(),
        "driver": driver.toJson(),
        "vehicle": vehicle.toJson(),
        "starting_point": startingPoint.toJson(),
        "ending_point": endingPoint.toJson(),
        "bookings": List<dynamic>.from(bookings.map((x) => x)),
        "accepts_parcels": acceptsParcels,
      };

  factory DriverTripModel.defaultTrip() => DriverTripModel(
        id: 0,
        fromRegionId: 0,
        toRegionId: 0,
        fromCityId: 0,
        toCityId: 0,
        fromVillageId: 0,
        toVillageId: 0,
        startTime: DateTime.now(),
        endTime: DateTime.now(),
        duration: "",
        pricePerSeat: "0",
        totalSeats: 0,
        availableSeats: 0,
        startLat: "0.0",
        startLong: "0.0",
        endLat: "0.0",
        endLong: "0.0",
        status: "pending",
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        driver: Driver.empty(),
        vehicle: Vehicle.empty(),
        startingPoint: IngPoint(id: 0, lat: "0.0", long: "0.0"),
        endingPoint: IngPoint(id: 0, lat: "0.0", long: "0.0"),
        bookings: [],
      );
}

class Driver {
  int id;
  String firstName;
  String lastName;
  String email;
  String phone;
  String role;

  Driver({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.phone,
    required this.role,
  });

  factory Driver.empty() => Driver(
      id: 0, firstName: "", lastName: "", email: "", phone: "", role: "");

  factory Driver.fromJson(Map<String, dynamic> json) => Driver(
        id: _asInt(json["id"]),
        firstName: json["first_name"]?.toString() ?? "",
        lastName: json["last_name"]?.toString() ?? "",
        email: json["email"]?.toString() ?? "",
        phone: json["phone"]?.toString() ?? "",
        role: json["role"]?.toString() ?? "",
      );

  Map<String, dynamic> toJson() => {
        "id": id,
        "first_name": firstName,
        "last_name": lastName,
        "email": email,
        "phone": phone,
        "role": role,
      };
}

class IngPoint {
  int id;
  String lat;
  String long;

  IngPoint({
    required this.id,
    required this.lat,
    required this.long,
  });

  factory IngPoint.empty() => IngPoint(id: 0, lat: "", long: "");

  factory IngPoint.fromJson(Map<String, dynamic> json) => IngPoint(
        id: _asInt(json["id"]),
        lat: json["lat"]?.toString() ?? "",
        long: json["long"]?.toString() ?? "",
      );

  Map<String, dynamic> toJson() => {
        "id": id,
        "lat": lat,
        "long": long,
      };
}

class Vehicle {
  int id;
  String model;
  int seats;
  String carNumber;
  VehicleColor color;

  Vehicle({
    required this.id,
    required this.model,
    required this.seats,
    required this.carNumber,
    required this.color,
  });

  factory Vehicle.empty() => Vehicle(
        id: 0,
        model: "",
        seats: 0,
        carNumber: "",
        color: VehicleColor(id: 0),
      );

  factory Vehicle.fromJson(Map<String, dynamic> json) => Vehicle(
        id: _asInt(json["id"]),
        model: json["model"]?.toString() ?? "",
        seats: _asInt(json["seats"]),
        carNumber: json["car_number"]?.toString() ?? "",
        color: json["color"] is Map<String, dynamic>
            ? VehicleColor.fromJson(json["color"])
            : VehicleColor(id: 0),
      );

  Map<String, dynamic> toJson() => {
        "id": id,
        "model": model,
        "seats": seats,
        "car_number": carNumber,
        "color": color.toJson(),
      };
}

class VehicleColor {
  int id;

  VehicleColor({
    required this.id,
  });

  factory VehicleColor.fromJson(Map<String, dynamic> json) =>
      VehicleColor(id: _asInt(json["id"]));

  Map<String, dynamic> toJson() => {
        "id": id,
      };
}

class Meta {
  int currentPage;
  int lastPage;
  int perPage;
  int total;

  Meta({
    required this.currentPage,
    required this.lastPage,
    required this.perPage,
    required this.total,
  });

  factory Meta.empty() =>
      Meta(currentPage: 0, lastPage: 0, perPage: 0, total: 0);

  factory Meta.fromJson(Map<String, dynamic> json) => Meta(
        currentPage: _asInt(json["current_page"]),
        lastPage: _asInt(json["last_page"]),
        perPage: _asInt(json["per_page"]),
        total: _asInt(json["total"]),
      );

  Map<String, dynamic> toJson() => {
        "current_page": currentPage,
        "last_page": lastPage,
        "per_page": perPage,
        "total": total,
      };
}
