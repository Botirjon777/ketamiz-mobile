import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:ketamiz/src/defaults/defaults.dart';
import 'package:ketamiz/src/model/location_model.dart';
import 'package:ketamiz/src/ui/widgets/texts/text_14h_500w.dart';
import 'package:ketamiz/src/ui/widgets/texts/text_16h_500w.dart';
import 'package:ketamiz/src/ui/widgets/texts/text_18h_500w.dart';

import '../../lan_localization/load_places.dart';
import '../../model/color_model.dart';
import '../../model/passenger_model.dart';
import '../../model/vehicle_model.dart';
import '../../theme/app_theme.dart';
import '../widgets/picker/custom_birth_date_picker.dart';
import '../widgets/picker/custom_date_picker.dart';
import '../widgets/textfield/main_textfield.dart';
import '../menu/new_ketamiz/map_select_screen.dart';
import 'snack_bar.dart';
import 'package:latlong2/latlong.dart';

class BottomDialog {
  /// Region → district → quarter picker. Each level is fetched live from the
  /// backend (see [LocationData.fetchRegions]/`fetchDistricts`/`fetchQuarters`)
  /// so the IDs and names handed back through [onChanged] match the server's
  /// data exactly — which is what the trip search filters on. The [region],
  /// [city] and [village] params are accepted for call-site compatibility; the
  /// sheet always starts fresh at the region level.
  static void showSelectLocation(
      BuildContext context,
      LocationModel? region,
      LocationModel? city,
      LocationModel? village,
      Function(LocationModel, LocationModel, LocationModel) onChanged,
      ) {
    showModalBottomSheet(
      barrierColor: Colors.black.withOpacity(0.45),
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _LocationPickerSheet(onChanged: onChanged),
    );
  }

  static void showTripDateTime(
    BuildContext context,
    Function(DateTime data) onChoose,
    DateTime initDate,
  ) {
    DateTime chooseDate = initDate;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: 400,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topRight: Radius.circular(24),
              topLeft: Radius.circular(24),
            ),
          ),
          child: Column(
            children: [
              const SizedBox(height: 8),
              Container(
                height: 4,
                width: 48,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  color: AppTheme.gray,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                translate("home.select_trip_date"),
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 18,
                  fontFamily: AppTheme.fontFamily,
                  height: 1.5,
                  color: AppTheme.black,
                ),
                textAlign: TextAlign.center,
              ),
              Expanded(
                child: DatePicker(
                  maximumDate: DateTime.now(),
                  minimumDate: DateTime(1900, 02, 16),
                  initialDateTime: initDate,
                  onDateTimeChanged: (date) {
                    chooseDate = date;
                  },
                ),
              ),
              GestureDetector(
                onTap: () {
                  Navigator.pop(context);
                  onChoose(chooseDate);
                },
                child: Container(
                  height: 56,
                  margin: const EdgeInsets.only(
                    left: 36,
                    right: 36,
                    bottom: 24,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: AppTheme.purple,
                    boxShadow: const [
                      BoxShadow(
                        offset: Offset(5, 9),
                        blurRadius: 15,
                        spreadRadius: 0,
                        color: AppTheme.gray,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      translate("home.apply"),
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                        fontFamily: AppTheme.fontFamily,
                        height: 1.5,
                        color: Colors.white,
                      ),
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

  static void showAddPassenger(
    BuildContext context,
    PassengerModel passenger,
    Function(PassengerModel data) onAdd, {
    String place = '',
    LatLng? sharedLocation,
  }) {
    final fullNameController = TextEditingController(text: passenger.fullName);
    final phoneController = TextEditingController(text: passenger.phoneNumber);
    String lat = passenger.latitude;
    String lng = passenger.longitude;

    final bool hasShared = sharedLocation != null;
    final String sharedLatStr =
        sharedLocation != null ? sharedLocation.latitude.toString() : '';
    final String sharedLngStr =
        sharedLocation != null ? sharedLocation.longitude.toString() : '';

    showModalBottomSheet(
      barrierColor: AppTheme.black.withOpacity(0.45),
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            final bool hasLoc = lat.isNotEmpty && lng.isNotEmpty;
            final bool isSame =
                hasLoc && hasShared && lat == sharedLatStr && lng == sharedLngStr;
            final bool isMapSel = hasLoc && !isSame;

            Widget optionTile({
              required IconData icon,
              required String title,
              required bool selected,
              required VoidCallback onTap,
              bool showChevron = false,
            }) {
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onTap,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(
                    color: selected
                        ? AppTheme.purple.withOpacity(0.08)
                        : AppTheme.light,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: selected ? AppTheme.purple : AppTheme.border,
                      width: selected ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(icon,
                          size: 20,
                          color: selected ? AppTheme.purple : AppTheme.gray),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          title,
                          style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color:
                                selected ? AppTheme.purple : AppTheme.black,
                          ),
                        ),
                      ),
                      if (selected)
                        const Icon(Icons.check_circle,
                            size: 20, color: AppTheme.purple)
                      else if (showChevron)
                        const Icon(Icons.chevron_right,
                            size: 20, color: AppTheme.gray),
                    ],
                  ),
                ),
              );
            }

            Future<void> pickOnMap() async {
              final picked = await Navigator.push<LatLng>(
                context,
                MaterialPageRoute(
                  builder: (_) => MapSelectScreen(
                    place: place,
                    onSelected: (_) {},
                  ),
                ),
              );
              if (picked != null) {
                setState(() {
                  lat = picked.latitude.toString();
                  lng = picked.longitude.toString();
                });
              }
            }

            void submit() {
              final name = fullNameController.text.trim();
              final phone = phoneController.text.trim();
              if (name.isEmpty || phone.isEmpty) {
                CustomSnackBar().showSnackBar(
                    context, translate("home.fill_passenger_details"), 2);
                return;
              }
              if (lat.isEmpty || lng.isEmpty) {
                CustomSnackBar().showSnackBar(
                    context, translate("home.set_pickup_location"), 2);
                return;
              }
              Navigator.pop(context);
              onAdd(PassengerModel(
                fullName: name,
                phoneNumber: phone,
                latitude: lat,
                longitude: lng,
              ));
            }

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                decoration: const BoxDecoration(
                  borderRadius: BorderRadius.only(
                    topRight: Radius.circular(24),
                    topLeft: Radius.circular(24),
                  ),
                  color: Colors.white,
                ),
                padding: const EdgeInsets.only(top: 16),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Center(
                        child: Container(
                          height: 5,
                          width: 80,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(5),
                            color: AppTheme.gray,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Center(
                        child: Text18h500w(
                          title: translate("home.passenger_info"),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: MainTextField(
                          hintText: translate("home.full_name"),
                          icon: Icons.person,
                          controller: fullNameController,
                          fillColor: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: MainTextField(
                          hintText: translate("home.phone_number"),
                          icon: Icons.phone,
                          controller: phoneController,
                          phone: true,
                          fillColor: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text14h500w(
                          title: translate("home.pickup_location"),
                          color: AppTheme.gray,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          children: [
                            if (hasShared)
                              optionTile(
                                icon: Icons.groups_outlined,
                                title:
                                    translate("home.pickup_same_as_others"),
                                selected: isSame,
                                onTap: () {
                                  setState(() {
                                    lat = sharedLatStr;
                                    lng = sharedLngStr;
                                  });
                                },
                              ),
                            optionTile(
                              icon: isMapSel
                                  ? Icons.location_on
                                  : Icons.add_location_alt_outlined,
                              title: isMapSel
                                  ? translate("home.pickup_location_set")
                                  : translate("home.pickup_choose_on_map"),
                              selected: isMapSel,
                              showChevron: true,
                              onTap: pickOnMap,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      Padding(
                        padding: const EdgeInsets.only(
                            left: 16, right: 16, bottom: 32),
                        child: GestureDetector(
                          onTap: submit,
                          child: Container(
                            height: 56,
                            decoration: BoxDecoration(
                              color: AppTheme.purple,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Center(
                              child: Text16h500w(
                                title: translate("home.add_passenger"),
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  static void showUploadImage(
      BuildContext context, {
        required VoidCallback onGallery,
        required VoidCallback onCamera,
      }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.45),
      builder: (context) {
        return SafeArea(
          child: StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                height: MediaQuery.of(context).size.height * 0.25,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          _buildHeader(context),
                          const Divider(height: 1, thickness: 1),
                          _buildOptionButton(
                            context,
                            text: 'Upload from Gallery',
                            onTap: () {
                              onGallery();
                              Navigator.pop(context);
                            },
                            textColor: Theme.of(context).colorScheme.primary,
                          ),
                          const Divider(height: 2, thickness: 1),
                          _buildOptionButton(
                            context,
                            text: 'Upload from Camera',
                            onTap: () {
                              onCamera();
                              Navigator.pop(context);
                            },
                            textColor: Theme.of(context).colorScheme.onSurface,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildOptionButton(
                      context,
                      text: 'Cancel',
                      onTap: () => Navigator.pop(context),
                      textColor: Theme.of(context).colorScheme.onSurface,
                      isCancel: true,
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  static Widget _buildHeader(BuildContext context) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        color: Theme.of(context).colorScheme.surface,
      ),
      child: Center(
        child: Text(
          'Upload Image',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w500,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          semanticsLabel: 'Upload Image Dialog',
        ),
      ),
    );
  }

  static Widget _buildOptionButton(
      BuildContext context, {
        required String text,
        required VoidCallback onTap,
        required Color textColor,
        bool isCancel = false,
      }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.vertical(
            bottom: isCancel ? const Radius.circular(16) : Radius.zero,
          ),
        ),
        child: Center(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              fontWeight: isCancel ? FontWeight.bold : FontWeight.w500,
              color: textColor,
            ),
            semanticsLabel: text,
          ),
        ),
      ),
    );
  }

  /// Marker id used for a vehicle model the driver typed in themselves,
  /// i.e. one that isn't in [Defaults.vehicles]. The name is still sent to the
  /// backend as a plain string, so custom models are accepted just like the
  /// preset ones.
  static const int customVehicleId = -1;

  static void showSelectCar(
    BuildContext context,
    Function(
      VehicleModel data,
    ) onChanged,
    VehicleModel car,
  ) {
    VehicleModel selectedCar = VehicleModel(id: 0, vehicleName: "");
    // Re-open straight into custom-entry mode if the caller already holds a
    // typed-in model, so the driver can edit it instead of losing their text.
    bool isCustomMode = car.id == customVehicleId;
    final TextEditingController customController = TextEditingController(
      text: car.id == customVehicleId ? car.vehicleName : "",
    );

    showModalBottomSheet(
      barrierColor: AppTheme.black.withOpacity(0.45),
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        if (car.id != 0 && car.id != customVehicleId) {
          selectedCar = car;
        }
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            final bool showList = selectedCar.id == 0 && !isCustomMode;
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                height: isCustomMode
                    ? 320
                    : showList
                        ? 524
                        : 256,
                decoration: const BoxDecoration(
                  borderRadius: BorderRadius.only(
                    topRight: Radius.circular(24),
                    topLeft: Radius.circular(24),
                  ),
                  color: Colors.white,
                ),
                padding: const EdgeInsets.only(top: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          height: 5,
                          width: 80,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(5),
                            color: AppTheme.gray,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text18h500w(
                          title: isCustomMode
                              ? translate("profile.enter_custom_model")
                              : translate("profile.select_car_model"),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 270),
                      curve: Curves.easeInOut,
                      child: isCustomMode
                          ? Expanded(
                              child: _buildCustomCarInput(
                                controller: customController,
                                onBack: () => setState(() {
                                  isCustomMode = false;
                                }),
                              ),
                            )
                          : showList
                              ? Expanded(
                                  child: ListView.builder(
                                    itemCount: Defaults().vehicles.length + 1,
                                    padding: const EdgeInsets.only(
                                        top: 4, bottom: 0, left: 16, right: 16),
                                    itemBuilder: (context, index) {
                                      // Last row lets the driver type a model
                                      // that isn't in the preset list.
                                      if (index == Defaults().vehicles.length) {
                                        return GestureDetector(
                                          onTap: () {
                                            setState(() {
                                              isCustomMode = true;
                                            });
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.all(16),
                                            color: AppTheme.light,
                                            child: Row(
                                              children: [
                                                const Icon(Icons.edit_outlined,
                                                    size: 20,
                                                    color: AppTheme.purple),
                                                const SizedBox(width: 10),
                                                Expanded(
                                                  child: Text14h500w(
                                                    title: translate(
                                                        "profile.other_car_model"),
                                                    color: AppTheme.purple,
                                                  ),
                                                ),
                                                const Icon(Icons.chevron_right,
                                                    size: 20,
                                                    color: AppTheme.purple),
                                              ],
                                            ),
                                          ),
                                        );
                                      }
                                      VehicleModel vehicle =
                                          Defaults().vehicles[index];
                                      return Column(
                                        children: [
                                          GestureDetector(
                                            onTap: () {
                                              setState(() {
                                                selectedCar = vehicle;
                                              });
                                            },
                                            child: Container(
                                              padding: const EdgeInsets.all(16),
                                              color: AppTheme.light,
                                              child: Row(
                                                children: [
                                                  Expanded(
                                                    child: Text14h500w(
                                                      title: vehicle.vehicleName,
                                                      color: vehicle.id ==
                                                              selectedCar.id
                                                          ? AppTheme.purple
                                                          : AppTheme.black,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                          Container(
                                            height: 1,
                                            color: AppTheme.blue,
                                            margin: const EdgeInsets.only(
                                                left: 8, right: 8),
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                                )
                              : Expanded(
                                  child: GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        selectedCar =
                                            VehicleModel(id: 0, vehicleName: "");
                                      });
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.all(16),
                                      margin: const EdgeInsets.only(
                                        top: 4,
                                        bottom: 12,
                                        left: 16,
                                        right: 16,
                                      ),
                                      decoration: BoxDecoration(
                                          color: AppTheme.light,
                                          borderRadius:
                                              BorderRadius.circular(16),
                                          border: Border.all(
                                              color: AppTheme.purple)),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Text16h500w(
                                                title: selectedCar.vehicleName),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                    ),
                    Container(
                      padding: const EdgeInsets.only(
                        top: 12,
                        left: 16,
                        right: 16,
                        bottom: 32,
                      ),
                      child: GestureDetector(
                        onTap: () {
                          if (isCustomMode) {
                            final name = customController.text.trim();
                            if (name.isNotEmpty) {
                              onChanged(VehicleModel(
                                  id: customVehicleId, vehicleName: name));
                              Navigator.pop(context);
                            }
                          } else if (selectedCar.id != 0) {
                            onChanged(selectedCar);
                            Navigator.pop(context);
                          }
                        },
                        child: Container(
                          height: 56,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: AppTheme.purple,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Center(
                              child: Text16h500w(
                            title: translate("home.apply"),
                            color: Colors.white,
                          )),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  static Widget _buildCustomCarInput({
    required TextEditingController controller,
    required VoidCallback onBack,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, left: 16, right: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: onBack,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.arrow_back_ios_new,
                    size: 14, color: AppTheme.purple),
                const SizedBox(width: 6),
                Text14h500w(
                  title: translate("profile.choose_from_list"),
                  color: AppTheme.purple,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: AppTheme.light,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.purple),
            ),
            child: Row(
              children: [
                const Icon(Icons.directions_car_outlined,
                    color: AppTheme.purple, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: controller,
                    autofocus: true,
                    cursorColor: AppTheme.purple,
                    textCapitalization: TextCapitalization.words,
                    style: const TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.black,
                    ),
                    decoration: InputDecoration(
                      hintText: translate("ketamiz.car_model_hint"),
                      hintStyle: const TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 14,
                        color: AppTheme.gray,
                      ),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 18),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static void showSelectColor(
    BuildContext context,
    Function(
      ColorModel data,
    ) onChanged,
    ColorModel color,
  ) {
    ColorModel selectedColor =
        ColorModel(titleEn: "", colorCode: Colors.transparent, id: 0, titleRu: '', titleUz: '');

    showModalBottomSheet(
      barrierColor: AppTheme.black.withOpacity(0.45),
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        if (color.titleEn != "") {
          selectedColor = color;
        }
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return Container(
              height: selectedColor.titleEn.isEmpty ? 524 : 256,
              decoration: const BoxDecoration(
                borderRadius: BorderRadius.only(
                  topRight: Radius.circular(24),
                  topLeft: Radius.circular(24),
                ),
                color: Colors.white,
              ),
              padding: const EdgeInsets.only(top: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        height: 5,
                        width: 80,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(5),
                          color: AppTheme.gray,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text18h500w(
                        title: translate("profile.select_car_color"),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 270),
                    curve: Curves.easeInOut,
                    child: selectedColor.titleEn.isEmpty
                        ? Expanded(
                            child: ListView.builder(
                              itemCount: Defaults().colors.length,
                              padding: const EdgeInsets.only(
                                  top: 4, bottom: 0, left: 16, right: 16),
                              itemBuilder: (context, index) {
                                ColorModel color = Defaults().colors[index];

                                return Column(
                                  children: [
                                    GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          selectedColor = color;
                                        });
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.all(16),
                                        color: AppTheme.light,
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: Text14h500w(
                                                title: color.titleEn,
                                                color: color.titleEn ==
                                                        selectedColor.titleEn
                                                    ? AppTheme.purple
                                                    : AppTheme.black,
                                              ),
                                            ),
                                            Container(
                                              width: 32,
                                              height: 32,
                                              decoration: BoxDecoration(
                                                color: color.colorCode,
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                border: Border.all(
                                                  color: AppTheme.purple,
                                                  width: 1.5,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    Container(
                                      height: 1,
                                      color: AppTheme.blue,
                                      margin: const EdgeInsets.only(
                                          left: 8, right: 8),
                                    ),
                                  ],
                                );
                              },
                            ),
                          )
                        : Expanded(
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  selectedColor = ColorModel(
                                    titleEn: "",
                                    colorCode: Colors.transparent, id: 0, titleRu: '', titleUz: '',
                                  );
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                margin: const EdgeInsets.only(
                                  top: 4,
                                  bottom: 12,
                                  left: 16,
                                  right: 16,
                                ),
                                decoration: BoxDecoration(
                                    color: AppTheme.light,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: AppTheme.purple)),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text16h500w(
                                          title: selectedColor.titleEn),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                  ),
                  Container(
                    padding: const EdgeInsets.only(
                      top: 12,
                      left: 16,
                      right: 16,
                      bottom: 32,
                    ),
                    child: GestureDetector(
                      onTap: () {
                        if (selectedColor.titleEn.isNotEmpty) {
                          onChanged(selectedColor);
                          Navigator.pop(context);
                        }
                      },
                      child: Container(
                        height: 56,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: AppTheme.purple,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Center(
                            child: Text16h500w(
                          title: translate("home.apply"),
                          color: Colors.white,
                        )),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  static void showBirthDate(BuildContext context,
      Function(DateTime data) onChoose, DateTime initDate, bool isBirth, String title) {
    DateTime chooseDate = initDate;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: 400,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topRight: Radius.circular(24),
              topLeft: Radius.circular(24),
            ),
          ),
          child: Column(
            children: [
              const SizedBox(height: 8),
              Container(
                height: 4,
                width: 48,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  color: AppTheme.gray,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 18,
                  fontFamily: AppTheme.fontFamily,
                  height: 1.5,
                  color: AppTheme.black,
                ),
                textAlign: TextAlign.center,
              ),
              Expanded(
                child: BirthDatePicker(
                  maximumDate: isBirth == true
                      ? DateTime.now().add(const Duration(days: -365*18))
                      : DateTime.now().add(
                          const Duration(days: 5475),
                        ),
                  minimumDate: isBirth == true
                      ? DateTime(1900, 02, 16) : DateTime.now(),
                  initialDateTime: initDate,
                  onDateTimeChanged: (date) {
                    chooseDate = date;
                  },
                ),
              ),
              GestureDetector(
                onTap: () {
                  Navigator.pop(context);
                  onChoose(chooseDate);
                },
                child: Container(
                  height: 56,
                  margin: const EdgeInsets.only(
                    left: 36,
                    right: 36,
                    bottom: 24,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: AppTheme.purple,
                    boxShadow: const [
                      BoxShadow(
                        offset: Offset(5, 9),
                        blurRadius: 15,
                        spreadRadius: 0,
                        color: AppTheme.gray,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      translate("home.select"),
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                        fontFamily: AppTheme.fontFamily,
                        height: 1.5,
                        color: Colors.white,
                      ),
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
}

enum _PickLevel { region, district, quarter }

/// Backend-driven location picker used by the search and create-trip screens.
/// Loads regions, then a region's districts, then a district's quarters — one
/// network level at a time, with caching handled by [LocationData].
class _LocationPickerSheet extends StatefulWidget {
  const _LocationPickerSheet({required this.onChanged});

  final Function(LocationModel, LocationModel, LocationModel) onChanged;

  @override
  State<_LocationPickerSheet> createState() => _LocationPickerSheetState();
}

class _LocationPickerSheetState extends State<_LocationPickerSheet> {
  static const _empty = LocationModel(id: '0', text: '', parentID: '0');

  _PickLevel _level = _PickLevel.region;
  List<LocationModel> _items = const [];
  bool _loading = true;

  LocationModel _region = _empty;
  LocationModel _city = _empty;

  @override
  void initState() {
    super.initState();
    _loadRegions();
  }

  Future<void> _loadRegions() async {
    setState(() => _loading = true);
    final list = await LocationData.fetchRegions();
    if (!mounted) return;
    setState(() {
      _items = list;
      _level = _PickLevel.region;
      _loading = false;
    });
  }

  Future<void> _onTap(LocationModel location) async {
    switch (_level) {
      case _PickLevel.region:
        setState(() {
          _region = location;
          _loading = true;
        });
        final districts = await LocationData.fetchDistricts(location.id);
        if (!mounted) return;
        setState(() {
          _items = districts;
          _level = _PickLevel.district;
          _loading = false;
        });
        break;
      case _PickLevel.district:
        setState(() {
          _city = location;
          _loading = true;
        });
        final quarters = await LocationData.fetchQuarters(location.id);
        if (!mounted) return;
        // A district with no quarters — finish with region + district only.
        if (quarters.isEmpty) {
          widget.onChanged(_region, _city, _empty);
          Navigator.pop(context);
          return;
        }
        setState(() {
          _items = quarters;
          _level = _PickLevel.quarter;
          _loading = false;
        });
        break;
      case _PickLevel.quarter:
        widget.onChanged(_region, _city, location);
        Navigator.pop(context);
        break;
    }
  }

  Future<void> _onBack() async {
    switch (_level) {
      case _PickLevel.quarter:
        setState(() {
          _city = _empty;
          _loading = true;
        });
        final districts = await LocationData.fetchDistricts(_region.id);
        if (!mounted) return;
        setState(() {
          _items = districts;
          _level = _PickLevel.district;
          _loading = false;
        });
        break;
      case _PickLevel.district:
        _region = _empty;
        _loadRegions();
        break;
      case _PickLevel.region:
        Navigator.pop(context);
        break;
    }
  }

  String get _title {
    switch (_level) {
      case _PickLevel.region:
        return translate("home.select_region");
      case _PickLevel.district:
        return translate("home.select_city");
      case _PickLevel.quarter:
        return translate("home.select_neighborhood");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 524,
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(24),
          topLeft: Radius.circular(24),
        ),
        color: Colors.white,
      ),
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              height: 5,
              width: 80,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(5),
                color: AppTheme.gray,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              _title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
            ),
          ),
          const SizedBox(height: 4),
          Expanded(child: _buildList()),
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            child: GestureDetector(
              onTap: _onBack,
              child: Container(
                height: 56,
                width: 72,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: AppTheme.purple.withOpacity(0.1),
                ),
                child: Center(
                  child: SvgPicture.asset(
                    'assets/icons/left.svg',
                    height: 24,
                    width: 24,
                    colorFilter: const ColorFilter.mode(
                      AppTheme.purple,
                      BlendMode.srcIn,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(AppTheme.purple),
        ),
      );
    }
    if (_items.isEmpty) {
      return Center(
        child: Text(
          translate("search.nothing_found"),
          style: const TextStyle(fontSize: 14, color: AppTheme.gray),
        ),
      );
    }
    return ListView.builder(
      itemCount: _items.length,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      itemBuilder: (context, index) {
        final location = _items[index];
        return Column(
          children: [
            GestureDetector(
              onTap: () => _onTap(location),
              child: Container(
                padding: const EdgeInsets.all(16),
                color: Colors.white,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        location.text,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const Icon(Icons.chevron_right,
                        color: AppTheme.gray, size: 20),
                  ],
                ),
              ),
            ),
            Container(
              height: 1,
              color: AppTheme.border,
              margin: const EdgeInsets.symmetric(horizontal: 8),
            ),
          ],
        );
      },
    );
  }
}
