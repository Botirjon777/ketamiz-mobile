import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_svg/svg.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:http/http.dart' as http;
import 'package:ketamiz/src/model/api/created_trip_model.dart';
import 'package:ketamiz/src/model/api/driver_trips_list_model.dart';
import 'package:ketamiz/src/model/api/parcel_model.dart';
import 'package:ketamiz/src/ui/widgets/buttons/primary_button.dart';
import 'package:ketamiz/src/ui/widgets/containers/leading_back.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../lan_localization/load_places.dart';
import '../../../model/api/vehicles_list_model.dart';
import '../../../model/color_model.dart';
import '../../../model/location_model.dart';
import '../../../model/vehicle_model.dart';
import '../../../resources/repository.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/text_formatters.dart';
import '../../../utils/utils.dart';
import '../../dialogs/bottom_dialog.dart';
import '../../dialogs/center_dialog.dart';
import '../../dialogs/snack_bar.dart';
import '../../widgets/containers/car_container.dart';
import '../../widgets/texts/text_12h_400w.dart';
import '../../widgets/texts/text_14h_400w.dart';
import '../../widgets/texts/text_16h_500w.dart';
import '../../widgets/info_tooltip.dart';
import '../profile/add_vehicle_screen.dart';
import 'map_select_screen.dart';

// Light neutral border on white-filled input fields.
const _kBorderColor = Color(0xFFE2E8F0);

class CreateNewKetamizScreen extends StatefulWidget {
  const CreateNewKetamizScreen({
    super.key,
    required this.driverTrip,
  });

  final DriverTripModel driverTrip;

  @override
  State<CreateNewKetamizScreen> createState() => _CreateNewKetamizScreenState();
}

class _CreateNewKetamizScreenState extends State<CreateNewKetamizScreen> {
  TextEditingController fromController = TextEditingController();
  TextEditingController toController = TextEditingController();
  TextEditingController departureController = TextEditingController();
  TextEditingController endController = TextEditingController();
  TextEditingController priceController = TextEditingController();

  String startLat = "";
  String startLong = "";
  String endLat = "";
  String endLong = "";

  final Repository _repository = Repository();

  final MapController _fromMapController = MapController();
  final MapController _toMapController = MapController();

  // Default map center (Tashkent) shown until a point is picked.
  static const LatLng _defaultPosition = LatLng(41.2995, 69.2401);

  String vehicleId = "0";
  bool isLoading = false;

  // Route preview
  List<LatLng> _routePoints = [];
  bool _routeLoading = false;
  final MapController _routeMapController = MapController();

  // Rule checkboxes
  bool _check1 = false;
  bool _check2 = false;
  bool _check3 = false;

  LocationModel fromRegion = LocationModel(id: "0", text: "", parentID: '0');
  LocationModel fromCity = LocationModel(id: "0", text: "", parentID: '0');
  LocationModel fromNeighborhood =
      LocationModel(id: "0", text: "", parentID: '0');

  LocationModel toRegion = LocationModel(id: "0", text: "", parentID: '0');
  LocationModel toCity = LocationModel(id: "0", text: "", parentID: '0');
  LocationModel toNeighborhood =
      LocationModel(id: "0", text: "", parentID: '0');

  DateTime departureDate = DateTime.now();
  DateTime endDate = DateTime.now().add(const Duration(hours: 3));

  VehicleModel selectedVehicle = VehicleModel(id: 0, vehicleName: '');

  int passengersNum = 1;

  List<VehicleModel> myVehicles = [];

  // ── Parcel (posilka) acceptance ─────────────────────────────────────────────
  bool _acceptsParcels = false;
  final _parcelMaxWeightController = TextEditingController();
  final _parcelPriceController = TextEditingController();
  final _parcelLengthController = TextEditingController();
  final _parcelWidthController = TextEditingController();
  final _parcelHeightController = TextEditingController();
  List<ParcelType> _parcelTypes = [];
  final Set<int> _selectedParcelTypeIds = {};

  @override
  void dispose() {
    fromController.dispose();
    toController.dispose();
    departureController.dispose();
    endController.dispose();
    priceController.dispose();
    _parcelMaxWeightController.dispose();
    _parcelPriceController.dispose();
    _parcelLengthController.dispose();
    _parcelWidthController.dispose();
    _parcelHeightController.dispose();
    super.dispose();
  }

  int? _parcelIntOrNull(String s) {
    final t = s.trim();
    if (t.isEmpty) return null;
    return int.tryParse(t);
  }

  Future<void> _fetchParcelTypes() async {
    final response = await _repository.fetchParcelTypes();
    if (!mounted) return;
    if (response.isSuccess) {
      setState(() => _parcelTypes = ParcelType.listFromResult(response.result));
    }
  }

  static final _unknownLocation =
      LocationModel(id: "0", text: "—", parentID: "0");

  void setLocations() {
    fromRegion = LocationData.regions.firstWhere(
        (r) => r.id == widget.driverTrip.fromRegionId.toString(),
        orElse: () => _unknownLocation);
    fromCity = LocationData.cities.firstWhere(
        (c) => c.id == widget.driverTrip.fromCityId.toString(),
        orElse: () => _unknownLocation);
    fromNeighborhood = LocationData.villages.firstWhere(
        (n) => n.id == widget.driverTrip.fromVillageId.toString(),
        orElse: () => _unknownLocation);

    toRegion = LocationData.regions.firstWhere(
        (r) => r.id == widget.driverTrip.toRegionId.toString(),
        orElse: () => _unknownLocation);
    toCity = LocationData.cities.firstWhere(
        (c) => c.id == widget.driverTrip.toCityId.toString(),
        orElse: () => _unknownLocation);
    toNeighborhood = LocationData.villages.firstWhere(
        (n) => n.id == widget.driverTrip.toVillageId.toString(),
        orElse: () => _unknownLocation);

    fromController.text =
        "${fromNeighborhood.text}, ${fromCity.text}, ${fromRegion.text}";
    toController.text =
        "${toNeighborhood.text}, ${toCity.text}, ${toRegion.text}";
  }

  @override
  void initState() {
    getVehicleId();
    getVehicles();
    _fetchParcelTypes();
    if (widget.driverTrip.id != 0) {
      setLocations();
      departureDate = widget.driverTrip.startTime;
      endDate = widget.driverTrip.endTime;
      departureController.text = Utils.tripDateFormat(departureDate);
      endController.text = Utils.tripDateFormat(endDate);
      priceController.text = widget.driverTrip.pricePerSeat;
      selectedVehicle = VehicleModel(
        id: widget.driverTrip.vehicle.id,
        vehicleName: widget.driverTrip.vehicle.model,
        color: ColorModel(
            id: widget.driverTrip.vehicle.color.id,
            titleEn: "",
            titleRu: "",
            titleUz: "",
            colorCode: AppTheme.black),
        capacity: widget.driverTrip.vehicle.seats,
      );
      passengersNum = selectedVehicle.capacity;
    }
    super.initState();
  }

  Future<void> getVehicles() async {
    var response = await _repository.fetchVehiclesList();
    if (response.isSuccess) {
      List<dynamic> data = [];
      if (response.result is List) {
        data = response.result;
      } else if (response.result is Map &&
          response.result.containsKey('data')) {
        data = response.result['data'];
      }

      setState(() {
        myVehicles = data.map((e) {
          MyVehiclesModel m = MyVehiclesModel.fromJson(e);
          return VehicleModel(
            id: m.id,
            vehicleName: m.model,
            color: ColorModel(
              id: 0,
              titleEn: m.color.titleEn,
              titleRu: m.color.titleRu,
              titleUz: m.color.titleUz,
              colorCode: Color(
                int.parse(m.color.code.replaceFirst('#', '0xff')),
              ),
            ),
            capacity: m.seats,
          );
        }).toList();

        if (myVehicles.isNotEmpty) {
          bool found = false;
          for (var v in myVehicles) {
            if (v.id.toString() == vehicleId) {
              selectedVehicle = v;
              found = true;
              break;
            }
          }
          if (!found) {
            selectedVehicle = myVehicles.first;
          }
          passengersNum = selectedVehicle.capacity;
        }
      });
    }
  }

  Future<void> _onCreateTrip() async {
    if (fromController.text.isEmpty ||
        toController.text.isEmpty ||
        departureController.text.isEmpty ||
        endController.text.isEmpty ||
        selectedVehicle.id == 0 ||
        priceController.text.isEmpty) {
      CustomSnackBar().showSnackBar(
        context,
        translate("ketamiz.fill_all_fields"),
        2,
      );
      return;
    }

    if (startLat.isEmpty ||
        startLong.isEmpty ||
        endLat.isEmpty ||
        endLong.isEmpty) {
      CustomSnackBar().showSnackBar(
        context,
        translate("ketamiz.select_location_on_map"),
        2,
      );
      return;
    }

    if (endDate.isBefore(departureDate) ||
        endDate.isAtSameMomentAs(departureDate)) {
      CustomSnackBar().showSnackBar(
        context,
        translate("ketamiz.end_date_after_departure"),
        2,
      );
      return;
    }

    final price = Utils().stringToInt(priceController.text);
    if (price <= 0) {
      CustomSnackBar().showSnackBar(
        context,
        translate("ketamiz.price_must_be_positive"),
        2,
      );
      return;
    }

    if (!_check1 || !_check2 || !_check3) {
      CustomSnackBar().showSnackBar(
        context,
        translate("ketamiz.accept_rules"),
        2,
      );
      return;
    }

    // Validate parcel settings when the driver opts to accept parcels.
    double? parcelMaxWeight;
    double? parcelPricePerKg;
    if (_acceptsParcels) {
      parcelMaxWeight = double.tryParse(_parcelMaxWeightController.text.trim());
      parcelPricePerKg = double.tryParse(_parcelPriceController.text.trim());
      if (parcelMaxWeight == null || parcelMaxWeight <= 0) {
        CustomSnackBar()
            .showSnackBar(context, translate("parcel.max_weight_error"), 2);
        return;
      }
      if (parcelPricePerKg == null || parcelPricePerKg <= 0) {
        CustomSnackBar()
            .showSnackBar(context, translate("parcel.price_error"), 2);
        return;
      }
      if (_selectedParcelTypeIds.isEmpty) {
        CustomSnackBar()
            .showSnackBar(context, translate("parcel.types_error"), 2);
        return;
      }
    }

    setState(() {
      isLoading = true;
    });

    try {
      var response = await _repository.fetchCreateTrip(
        selectedVehicle.id.toString(),
        departureDate,
        endDate,
        Utils().stringToInt(priceController.text).toString(),
        passengersNum.toString(),
        startLat,
        startLong,
        endLat,
        endLong,
        fromRegion.id,
        fromCity.id,
        fromNeighborhood.id,
        toRegion.id,
        toCity.id,
        toNeighborhood.id,
        acceptsParcels: _acceptsParcels,
        parcelMaxWeight: parcelMaxWeight,
        parcelPricePerKg: parcelPricePerKg,
        parcelMaxLength: _parcelIntOrNull(_parcelLengthController.text),
        parcelMaxWidth: _parcelIntOrNull(_parcelWidthController.text),
        parcelMaxHeight: _parcelIntOrNull(_parcelHeightController.text),
        parcelTypeIds: _selectedParcelTypeIds.toList(),
      );

      if (response.isSuccess) {
        final dataMap =
            response.result is Map && response.result.containsKey('data')
                ? response.result['data']
                : response.result;

        var result = CreatedTripResponseModel.fromJson(dataMap);

        if (result.id != 0) {
          SharedPreferences prefs = await SharedPreferences.getInstance();
          await prefs.setString("active_trip_id", result.id.toString());

          if (mounted) {
            CustomSnackBar().showSnackBar(
              context,
              translate("ketamiz.trip_created"),
              1,
            );
            Navigator.pop(context);
          }
        } else {
          _showError(translate("ketamiz.trip_creation_failed_msg"));
        }
      } else {
        if (response.status == -1) {
          _showError(translate("auth.connection_failed_msg"));
        } else {
          String errorMessage =
              response.result is Map && response.result.containsKey('message')
                  ? response.result['message']
                  : translate("auth.failed_msg");
          _showError(errorMessage);
        }
      }
    } catch (e) {
      debugPrint("Error creating trip: $e");
      _showError(translate("auth.something_went_wrong"));
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  void _showError(String message) {
    CenterDialog.showActionFailed(
      context,
      translate("auth.something_went_wrong"),
      message,
    );
  }

  LatLng? get _fromPoint => _parsePoint(startLat, startLong);
  LatLng? get _toPoint => _parsePoint(endLat, endLong);

  LatLng? _parsePoint(String lat, String lng) {
    if (lat.isEmpty || lng.isEmpty) return null;
    final dLat = double.tryParse(lat);
    final dLng = double.tryParse(lng);
    if (dLat == null || dLng == null) return null;
    return LatLng(dLat, dLng);
  }

  void _recenter(MapController controller, LatLng point) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        controller.move(point, 15);
      } catch (_) {}
    });
  }

  void _openFromPicker() {
    BottomDialog.showSelectLocation(
      context,
      fromRegion,
      fromCity,
      fromNeighborhood,
      (r, c, n) {
        setState(() {
          fromRegion = r;
          fromCity = c;
          fromNeighborhood = n;
          fromController.text =
              "${fromNeighborhood.text}, ${fromCity.text}, ${fromRegion.text}";
        });
      },
    );
  }

  void _openToPicker() {
    BottomDialog.showSelectLocation(
      context,
      toRegion,
      toCity,
      toNeighborhood,
      (r, c, n) {
        setState(() {
          toRegion = r;
          toCity = c;
          toNeighborhood = n;
          toController.text =
              "${toNeighborhood.text}, ${toCity.text}, ${toRegion.text}";
        });
      },
    );
  }

  void _openFromMap() {
    if (fromController.text.isEmpty) {
      CustomSnackBar().showSnackBar(
          context, translate("ketamiz.select_location_first"), 2);
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MapSelectScreen(
          place: fromController.text,
          onSelected: (data) {
            setState(() {
              startLat = data.latitude.toString();
              startLong = data.longitude.toString();
            });
            _recenter(_fromMapController, data);
            if (endLat.isNotEmpty && endLong.isNotEmpty) _fetchRoute();
          },
        ),
      ),
    );
  }

  void _openToMap() {
    if (toController.text.isEmpty) {
      CustomSnackBar().showSnackBar(
          context, translate("ketamiz.select_location_first"), 2);
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MapSelectScreen(
          place: toController.text,
          onSelected: (data) {
            setState(() {
              endLat = data.latitude.toString();
              endLong = data.longitude.toString();
            });
            _recenter(_toMapController, data);
            if (startLat.isNotEmpty && startLong.isNotEmpty) _fetchRoute();
          },
        ),
      ),
    );
  }

  Future<void> _fetchRoute() async {
    final from = _fromPoint;
    final to = _toPoint;
    if (from == null || to == null) return;
    setState(() {
      _routeLoading = true;
      _routePoints = [];
    });
    final url = 'https://router.project-osrm.org/route/v1/driving/'
        '${from.longitude},${from.latitude};${to.longitude},${to.latitude}'
        '?overview=full&geometries=geojson';
    try {
      final response = await http
          .get(Uri.parse(url), headers: const {'User-Agent': 'uz.ketamiz.app'})
          .timeout(const Duration(seconds: 12));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['code'] == 'Ok' && (data['routes'] as List).isNotEmpty) {
          final coords = data['routes'][0]['geometry']['coordinates'] as List;
          final decoded = coords
              .map((c) => LatLng(
                    (c[1] as num).toDouble(),
                    (c[0] as num).toDouble(),
                  ))
              .toList();
          if (decoded.length >= 2 && mounted) {
            setState(() => _routePoints = decoded);
            WidgetsBinding.instance.addPostFrameCallback((_) {
              try {
                _routeMapController.fitCamera(CameraFit.bounds(
                  bounds: LatLngBounds(from, to),
                  padding: const EdgeInsets.all(40),
                ));
              } catch (_) {}
            });
          }
        }
      }
    } catch (e) {
      debugPrint('Route fetch error: $e');
      if (mounted) setState(() => _routePoints = [from, to]);
    }
    if (mounted) setState(() => _routeLoading = false);
  }

  void _openVehicleSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                height: 5,
                width: 80,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(5),
                  color: AppTheme.gray,
                ),
              ),
              const SizedBox(height: 16),
              Text16h500w(title: translate("ketamiz.select_car")),
              const SizedBox(height: 8),
              if (myVehicles.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(
                      vertical: 24, horizontal: 16),
                  child: Text14h400w(
                    title: translate("profile.no_vehicles_found"),
                    color: AppTheme.gray,
                  ),
                )
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    itemCount: myVehicles.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (c, i) => GestureDetector(
                      onTap: () {
                        setState(() {
                          selectedVehicle = myVehicles[i];
                          passengersNum = selectedVehicle.capacity;
                        });
                        Navigator.pop(sheetContext);
                      },
                      child: CarContainer(car: myVehicles[i]),
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: GestureDetector(
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _openAddVehicle();
                  },
                  child: Container(
                    height: 52,
                    decoration: BoxDecoration(
                      color: AppTheme.light,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _kBorderColor),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.add, size: 20, color: AppTheme.purple),
                        const SizedBox(width: 8),
                        Text14h400w(
                          title: translate("profile.add_vehicle"),
                          color: AppTheme.purple,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openAddVehicle() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AddVehicleScreen()),
    );
    await getVehicles();
  }

  @override
  Widget build(BuildContext context) {
    final bool isEdit = widget.driverTrip.id != 0;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: const LeadingBack(),
        backgroundColor: Colors.white,
        title: Text16h500w(
          title: isEdit
              ? translate("ketamiz.edit_trip")
              : translate("ketamiz.new_order"),
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 150),
            children: [
              _routeCard(
                dotColor: AppTheme.purple,
                title: translate("home.from"),
                controller: fromController,
                onAddressTap: _openFromPicker,
                onMapTap: _openFromMap,
                mapController: _fromMapController,
                point: _fromPoint,
                pinColor: AppTheme.purple,
              ),
              const SizedBox(height: 12),
              _dateField(
                icon: Icons.calendar_today_outlined,
                label: translate("ketamiz.start_time"),
                value: departureController.text,
                onTap: () {
                  BottomDialog.showTripDateTime(
                    context,
                    (date) {
                      setState(() {
                        departureDate = date;
                        departureController.text =
                            Utils.tripDateFormat(departureDate);
                        if (endDate.isBefore(departureDate)) {
                          endDate =
                              departureDate.add(const Duration(hours: 3));
                          endController.text = Utils.tripDateFormat(endDate);
                        }
                      });
                    },
                    departureDate,
                  );
                },
              ),
              const SizedBox(height: 16),
              _routeCard(
                dotColor: AppTheme.red,
                title: translate("home.to"),
                controller: toController,
                onAddressTap: _openToPicker,
                onMapTap: _openToMap,
                mapController: _toMapController,
                point: _toPoint,
                pinColor: AppTheme.red,
              ),
              const SizedBox(height: 12),
              _dateField(
                icon: Icons.event_available_outlined,
                label: translate("ketamiz.est_arrival_time"),
                value: endController.text,
                onTap: () {
                  BottomDialog.showTripDateTime(
                    context,
                    (date) {
                      setState(() {
                        endDate = date;
                        endController.text = Utils.tripDateFormat(endDate);
                      });
                    },
                    endDate,
                  );
                },
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: _vehicleCell()),
                  const SizedBox(width: 12),
                  Expanded(child: _passengersCell()),
                ],
              ),
              const SizedBox(height: 16),
              _priceCard(),
              const SizedBox(height: 16),
              _buildParcelSection(),
              _buildRouteSection(),
            ],
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  PrimaryButton(
                    title: isEdit
                        ? translate("ketamiz.edit_trip")
                        : translate("ketamiz.create_trip"),
                    isLoading: isLoading,
                    onTap: _onCreateTrip,
                  ),
                  const SizedBox(height: 12),
                  _footer(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // UI helpers
  // ---------------------------------------------------------------------------

  BoxDecoration _cardDecoration() => BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
        boxShadow: [
          BoxShadow(
            color: AppTheme.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      );

  BoxDecoration _fieldDecoration() => BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kBorderColor),
      );

  Widget _routeCard({
    required Color dotColor,
    required String title,
    required TextEditingController controller,
    required VoidCallback onAddressTap,
    required VoidCallback onMapTap,
    required MapController mapController,
    required LatLng? point,
    required Color pinColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Text16h500w(title: title),
            ],
          ),
          const SizedBox(height: 14),
          GestureDetector(
            onTap: onAddressTap,
            child: Container(
              height: 56,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: _fieldDecoration(),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      controller.text.isEmpty
                          ? translate("ketamiz.enter_address")
                          : controller.text,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 14,
                        fontWeight: controller.text.isEmpty
                            ? FontWeight.w400
                            : FontWeight.w500,
                        color: controller.text.isEmpty
                            ? AppTheme.gray
                            : AppTheme.black,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.gps_fixed, size: 18, color: AppTheme.gray),
                ],
              ),
            ),
          ),
          if (controller.text.isNotEmpty) ...[
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                controller.text,
                style: const TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: AppTheme.gray,
                  height: 1.4,
                ),
              ),
            ),
          ],
          const SizedBox(height: 10),
          GestureDetector(
            onTap: onMapTap,
            child: Container(
              height: 48,
              decoration: _fieldDecoration(),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SvgPicture.asset(
                    "assets/icons/map_pin.svg",
                    height: 18,
                    width: 18,
                    colorFilter: const ColorFilter.mode(
                      AppTheme.purple,
                      BlendMode.srcIn,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text14h400w(
                    title: translate("ketamiz.select_from_map"),
                    color: AppTheme.black,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          _mapPreview(
            controller: mapController,
            point: point,
            pinColor: pinColor,
            onTap: onMapTap,
          ),
        ],
      ),
    );
  }

  Widget _mapPreview({
    required MapController controller,
    required LatLng? point,
    required Color pinColor,
    required VoidCallback onTap,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        height: 150,
        child: Stack(
          children: [
            FlutterMap(
              mapController: controller,
              options: MapOptions(
                initialCenter: point ?? _defaultPosition,
                initialZoom: point != null ? 15 : 12,
                onTap: (_, __) => onTap(),
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.none,
                ),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'uz.ketamiz.app',
                ),
                if (point != null)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: point,
                        width: 40,
                        height: 40,
                        alignment: Alignment.topCenter,
                        child: Icon(
                          Icons.location_on,
                          color: pinColor,
                          size: 40,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            Positioned(
              right: 10,
              bottom: 10,
              child: GestureDetector(
                onTap: onTap,
                child: Container(
                  height: 38,
                  width: 38,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.black.withOpacity(0.12),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.my_location,
                    color: AppTheme.purple,
                    size: 20,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dateField({
    required IconData icon,
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    final bool hasValue = value.isNotEmpty;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: _fieldDecoration(),
        child: Row(
          children: [
            Icon(icon, size: 18, color: AppTheme.gray),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                hasValue ? value : label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 14,
                  fontWeight: hasValue ? FontWeight.w500 : FontWeight.w400,
                  color: hasValue ? AppTheme.black : AppTheme.gray,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _vehicleCell() {
    return GestureDetector(
      onTap: _openVehicleSheet,
      child: Container(
        height: 72,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: _cardDecoration(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text12h400w(
              title: translate("ketamiz.select_car"),
              color: AppTheme.gray,
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.directions_car_outlined,
                    size: 18, color: AppTheme.purple),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    selectedVehicle.vehicleName.isEmpty
                        ? "—"
                        : selectedVehicle.vehicleName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.black,
                    ),
                  ),
                ),
                const Icon(Icons.keyboard_arrow_down,
                    size: 20, color: AppTheme.gray),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _passengersCell() {
    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Flexible(
                child: Text(
                  translate("home.number_passenger"),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    height: 1.5,
                    color: AppTheme.gray,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              InfoTooltip(
                message: translate("ketamiz.seats_tooltip"),
                size: 14,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _counterButton(
                icon: Icons.remove,
                onTap: () {
                  if (passengersNum > 1) {
                    setState(() => passengersNum--);
                  } else {
                    CenterDialog.showActionFailed(
                      context,
                      translate("ketamiz.min_passengers_reached"),
                      translate("ketamiz.min_passengers_reached_msg"),
                    );
                  }
                },
              ),
              Text(
                passengersNum.toString(),
                style: const TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.black,
                ),
              ),
              _counterButton(
                icon: Icons.add,
                onTap: () {
                  if (passengersNum < selectedVehicle.capacity) {
                    setState(() => passengersNum++);
                  } else {
                    CenterDialog.showActionFailed(
                      context,
                      translate("ketamiz.max_passengers_reached"),
                      translate("ketamiz.max_passengers_reached_msg"),
                    );
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _counterButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: AppTheme.light,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Icon(icon, color: AppTheme.black, size: 20),
      ),
    );
  }

  Widget _priceCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.payments_outlined,
                  size: 18, color: AppTheme.purple),
              const SizedBox(width: 8),
              Text16h500w(title: translate("ketamiz.price_label")),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            height: 56,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: _fieldDecoration(),
            alignment: Alignment.center,
            child: TextField(
              controller: priceController,
              keyboardType: TextInputType.phone,
              cursorColor: AppTheme.purple,
              style: const TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: AppTheme.black,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                PriceInputFormatter(maxDigits: 10),
              ],
              decoration: InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                hintText: translate("ketamiz.enter_price"),
                hintStyle: const TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: AppTheme.gray,
                ),
                suffixText: translate("ketamiz.som"),
                suffixStyle: const TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.purple,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            translate("ketamiz.price_per_seat_note"),
            style: const TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: AppTheme.gray,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Route preview + rules
  // ---------------------------------------------------------------------------

  // ── Parcel acceptance section (driver) ─────────────────────────────────────
  Widget _buildParcelSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.inventory_2_outlined,
                  size: 18, color: AppTheme.purple),
              const SizedBox(width: 8),
              Expanded(
                child: Text16h500w(title: translate("parcel.accept_parcels")),
              ),
              Switch.adaptive(
                value: _acceptsParcels,
                activeTrackColor: AppTheme.purple,
                onChanged: (v) => setState(() => _acceptsParcels = v),
              ),
            ],
          ),
          Text12h400w(
            title: translate("parcel.accept_parcels_hint"),
            color: AppTheme.gray,
          ),
          if (_acceptsParcels) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _parcelField(
                    controller: _parcelMaxWeightController,
                    label: translate("parcel.max_weight_kg"),
                    hint: "20",
                    decimal: true,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _parcelField(
                    controller: _parcelPriceController,
                    label: translate("parcel.price_per_kg"),
                    hint: "5000",
                    decimal: false,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text12h400w(
              title: translate("parcel.max_dimensions_optional"),
              color: AppTheme.gray,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _parcelField(
                    controller: _parcelLengthController,
                    label: translate("parcel.length"),
                    hint: "60",
                    decimal: false,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _parcelField(
                    controller: _parcelWidthController,
                    label: translate("parcel.width"),
                    hint: "40",
                    decimal: false,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _parcelField(
                    controller: _parcelHeightController,
                    label: translate("parcel.height"),
                    hint: "30",
                    decimal: false,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text14h400w(title: translate("parcel.accepted_types")),
            const SizedBox(height: 8),
            if (_parcelTypes.isEmpty)
              Text12h400w(
                title: translate("parcel.types_loading"),
                color: AppTheme.gray,
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _parcelTypes.map((t) {
                  final selected = _selectedParcelTypeIds.contains(t.id);
                  return GestureDetector(
                    onTap: () => setState(() {
                      if (selected) {
                        _selectedParcelTypeIds.remove(t.id);
                      } else {
                        _selectedParcelTypeIds.add(t.id);
                      }
                    }),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 9),
                      decoration: BoxDecoration(
                        color: selected
                            ? AppTheme.purple.withValues(alpha: 0.1)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color:
                              selected ? AppTheme.purple : _kBorderColor,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (selected) ...[
                            const Icon(Icons.check,
                                size: 15, color: AppTheme.purple),
                            const SizedBox(width: 5),
                          ],
                          Text(
                            t.name,
                            style: TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: selected
                                  ? AppTheme.purple
                                  : AppTheme.black,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
          ],
        ],
      ),
    );
  }

  Widget _parcelField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required bool decimal,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text12h400w(title: label, color: AppTheme.gray),
        const SizedBox(height: 6),
        Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: _fieldDecoration(),
          alignment: Alignment.center,
          child: TextField(
            controller: controller,
            keyboardType: TextInputType.numberWithOptions(decimal: decimal),
            cursorColor: AppTheme.purple,
            inputFormatters: [
              decimal
                  ? FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))
                  : FilteringTextInputFormatter.digitsOnly,
            ],
            style: const TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: AppTheme.black,
            ),
            decoration: InputDecoration(
              isCollapsed: true,
              border: InputBorder.none,
              hintText: hint,
              hintStyle: const TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 14,
                color: AppTheme.gray,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRouteSection() {
    if (_fromPoint == null || _toPoint == null) return const SizedBox.shrink();
    return Column(
      children: [
        const SizedBox(height: 16),
        _routePreviewCard(),
        const SizedBox(height: 16),
        _rulesCard(),
      ],
    );
  }

  Widget _routePreviewCard() {
    final from = _fromPoint!;
    final to = _toPoint!;
    return Container(
      decoration: _cardDecoration(),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                const Icon(Icons.route_outlined, color: AppTheme.purple, size: 18),
                const SizedBox(width: 8),
                Text(
                  translate("ketamiz.route_preview_title"),
                  style: const TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.black,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 260,
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _routeMapController,
                  options: MapOptions(
                    initialCameraFit: CameraFit.bounds(
                      bounds: LatLngBounds(from, to),
                      padding: const EdgeInsets.all(48),
                    ),
                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.none,
                    ),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'uz.ketamiz.app',
                    ),
                    if (_routePoints.length >= 2)
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: _routePoints,
                            color: AppTheme.purple,
                            strokeWidth: 5,
                          ),
                        ],
                      ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: from,
                          width: 36,
                          height: 36,
                          alignment: Alignment.topCenter,
                          child: const Icon(Icons.location_on,
                              color: AppTheme.purple, size: 36),
                        ),
                        Marker(
                          point: to,
                          width: 36,
                          height: 36,
                          alignment: Alignment.topCenter,
                          child: const Icon(Icons.location_on,
                              color: AppTheme.red, size: 36),
                        ),
                      ],
                    ),
                  ],
                ),
                if (_routeLoading)
                  Container(
                    color: Colors.white.withOpacity(0.55),
                    child: const Center(
                      child: CircularProgressIndicator(
                        valueColor:
                            AlwaysStoppedAnimation<Color>(AppTheme.purple),
                      ),
                    ),
                  ),
                // Start / end labels
                Positioned(
                  left: 12,
                  bottom: 12,
                  child: _mapLegendBadge(
                      color: AppTheme.purple,
                      label: translate("home.from")),
                ),
                Positioned(
                  right: 12,
                  bottom: 12,
                  child: _mapLegendBadge(
                      color: AppTheme.red,
                      label: translate("home.to")),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _mapLegendBadge({required Color color, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppTheme.black.withOpacity(0.12),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _rulesCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Info banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF8E1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFFFE082)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline_rounded,
                    color: Color(0xFFB8860B), size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    translate("ketamiz.route_rules_info"),
                    style: const TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 13,
                      color: Color(0xFF7A5800),
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text(
            translate("ketamiz.route_rules_title"),
            style: const TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.black,
            ),
          ),
          const SizedBox(height: 12),
          _ruleCheckbox(
            value: _check1,
            text: translate("ketamiz.rule_radius"),
            onChanged: (v) => setState(() => _check1 = v ?? false),
          ),
          const SizedBox(height: 10),
          _ruleCheckbox(
            value: _check2,
            text: translate("ketamiz.rule_direction"),
            onChanged: (v) => setState(() => _check2 = v ?? false),
          ),
          const SizedBox(height: 10),
          _ruleCheckbox(
            value: _check3,
            text: translate("ketamiz.rule_route_distance"),
            onChanged: (v) => setState(() => _check3 = v ?? false),
          ),
        ],
      ),
    );
  }

  Widget _ruleCheckbox({
    required bool value,
    required String text,
    required ValueChanged<bool?> onChanged,
  }) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 22,
            height: 22,
            child: Checkbox(
              value: value,
              onChanged: onChanged,
              activeColor: AppTheme.purple,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4)),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                text,
                style: const TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 13,
                  color: AppTheme.black,
                  height: 1.45,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _footer() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.lock_outline, size: 12, color: AppTheme.gray),
        const SizedBox(width: 6),
        Flexible(
          child: Text.rich(
            TextSpan(
              text: "${translate("ketamiz.footer_safe")} ",
              style: const TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: AppTheme.gray,
              ),
              children: const [
                TextSpan(
                  text: "ketamiz.com",
                  style: TextStyle(
                    color: AppTheme.purple,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Future<void> getVehicleId() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      vehicleId = prefs.getString('vehicle_id') ?? "0";
    });
  }
}
