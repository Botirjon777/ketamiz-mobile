import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/svg.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../defaults/defaults.dart';
import '../../../model/color_model.dart';
import '../../../model/event_bus/http_result.dart';
import '../../../model/vehicle_model.dart';
import '../../../resources/repository.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/image_helper.dart';
import '../../../utils/input_formatters.dart';
import '../../dialogs/bottom_dialog.dart';
import '../../dialogs/center_dialog.dart';
import '../../dialogs/snack_bar.dart';
import '../../widgets/texts/text_14h_400w.dart';
import '../../widgets/texts/text_16h_500w.dart';
import '../main_screen.dart';

class AddVehicleScreen extends StatefulWidget {
  const AddVehicleScreen({super.key});

  @override
  State<AddVehicleScreen> createState() => _AddVehicleScreenState();
}

class _AddVehicleScreenState extends State<AddVehicleScreen> {
  final Repository _repository = Repository();

  bool isLoading = false;
  int currentStep = 1;
  final int totalSteps = 2;

  // Step 1 controllers
  TextEditingController carModelController = TextEditingController();
  TextEditingController carNumberController = TextEditingController();
  TextEditingController colorController = TextEditingController();
  TextEditingController techPassportController = TextEditingController();
  int seats = 1;

  // Step 2 images
  String techPassportFront = '';
  String techPassportBack = '';
  List<XFile> carImages = [];

  VehicleModel selectedVehicle = VehicleModel(id: 0, vehicleName: "");
  ColorModel selectedColor = ColorModel(
    titleEn: "", colorCode: Colors.transparent, id: 0, titleRu: '', titleUz: '');

  String vehicleId = "";

  final List<ColorModel> _previewColors = Defaults().colors.take(6).toList();

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    await Permission.camera.request();
    await Permission.photos.request();
  }

  // ── Step 1 ─────────────────────────────────────────────────────────────────

  Widget _buildStep1() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Car model
        _labelRow(translate("profile.car_model"), translate("ketamiz.hint_car_model")),
        const SizedBox(height: 8),
        _buildTapCard(
          icon: Icons.directions_car_outlined,
          hint: translate("ketamiz.car_model_hint"),
          value: carModelController.text.isNotEmpty ? carModelController.text : null,
          onTap: () {
            BottomDialog.showSelectCar(context, (value) {
              if (value.id != 0 &&
                  (selectedVehicle.id != value.id ||
                      selectedVehicle.vehicleName != value.vehicleName)) {
                setState(() {
                  selectedVehicle = value;
                  carModelController.text = selectedVehicle.vehicleName;
                });
              }
            }, selectedVehicle);
          },
        ),
        const SizedBox(height: 20),

        // Car number
        _labelRow(translate("profile.car_number"), translate("ketamiz.hint_car_number")),
        const SizedBox(height: 8),
        _buildTextCard(
          icon: Icons.tag_rounded,
          hint: translate("ketamiz.plate_example"),
          controller: carNumberController,
          formatters: [VehiclePlateFormatter()],
          keyboardType: TextInputType.text,
        ),
        const SizedBox(height: 20),

        // Car color
        _labelRow(translate("profile.car_color"), translate("ketamiz.hint_car_color")),
        const SizedBox(height: 8),
        _buildColorSection(),
        const SizedBox(height: 20),

        // Tech passport
        _labelRow(translate("profile.car_tech_passport"), translate("ketamiz.hint_tech_passport")),
        const SizedBox(height: 8),
        _buildTextCard(
          icon: Icons.description_outlined,
          hint: translate("ketamiz.tech_passport_hint"),
          controller: techPassportController,
          formatters: [TechPassportCombinedFormatter()],
          keyboardType: TextInputType.text,
        ),
        const SizedBox(height: 20),

        // Seats
        _labelRow(translate("profile.seats"), translate("ketamiz.hint_seats")),
        const SizedBox(height: 8),
        _buildSeatCounter(),
      ],
    );
  }

  Widget _labelRow(String text, String hint) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: text,
                style: const TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.black,
                ),
              ),
              const TextSpan(
                text: ' *',
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.red,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 6),
        GestureDetector(
          onTap: () => _showFieldHint(hint),
          child: const Icon(
            Icons.help_outline_rounded,
            size: 16,
            color: AppTheme.gray,
          ),
        ),
      ],
    );
  }

  void _showFieldHint(String message) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.info_outline_rounded,
                  color: AppTheme.purple, size: 28),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 14,
                  color: AppTheme.black,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () => Navigator.pop(ctx),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppTheme.purple,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    "OK",
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            offset: const Offset(0, 2),
            blurRadius: 10,
            color: AppTheme.black.withOpacity(0.05),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildTapCard({
    required IconData icon,
    required String hint,
    String? value,
    required VoidCallback onTap,
  }) {
    return _buildCard(
      child: GestureDetector(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          child: Row(
            children: [
              _cardIcon(icon),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  value ?? hint,
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 14,
                    color: value != null ? AppTheme.black : AppTheme.gray,
                  ),
                ),
              ),
              const Icon(Icons.keyboard_arrow_down_rounded,
                  color: AppTheme.gray, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextCard({
    required IconData icon,
    required String hint,
    required TextEditingController controller,
    List<TextInputFormatter> formatters = const [],
    TextInputType keyboardType = TextInputType.text,
  }) {
    return _buildCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            _cardIcon(icon),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: controller,
                cursorColor: AppTheme.purple,
                keyboardType: keyboardType,
                inputFormatters: formatters,
                style: const TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: AppTheme.black,
                ),
                decoration: InputDecoration(
                  hintText: hint,
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
    );
  }

  Widget _cardIcon(IconData icon) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: AppTheme.purple.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: AppTheme.purple, size: 20),
    );
  }

  Widget _buildColorSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildCard(
          child: GestureDetector(
            onTap: () {
              BottomDialog.showSelectColor(context, (value) {
                if (value.titleEn.isNotEmpty && selectedColor != value) {
                  setState(() {
                    selectedColor = value;
                    colorController.text = value.titleEn;
                  });
                }
              }, selectedColor);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
              child: Row(
                children: [
                  _cardIcon(Icons.palette_outlined),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      selectedColor.id == 0
                          ? translate("profile.select_car_color")
                          : colorController.text,
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 14,
                        color: selectedColor.id == 0
                            ? AppTheme.gray
                            : AppTheme.black,
                      ),
                    ),
                  ),
                  if (selectedColor.id != 0)
                    Container(
                      width: 22,
                      height: 22,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: selectedColor.colorCode,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppTheme.border),
                      ),
                    ),
                  const Icon(Icons.keyboard_arrow_down_rounded,
                      color: AppTheme.gray, size: 20),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            ..._previewColors.map((c) => _buildColorCircle(c)),
            const SizedBox(width: 4),
            _buildMoreColorsButton(),
          ],
        ),
      ],
    );
  }

  Widget _buildColorCircle(ColorModel c) {
    final isSelected = selectedColor.id == c.id;
    return GestureDetector(
      onTap: () => setState(() {
        selectedColor = c;
        colorController.text = c.titleEn;
      }),
      child: Container(
        width: 38,
        height: 38,
        margin: const EdgeInsets.only(right: 8),
        decoration: BoxDecoration(
          color: c.colorCode,
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? AppTheme.purple : AppTheme.border,
            width: isSelected ? 2.5 : 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: AppTheme.black.withOpacity(0.08),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: isSelected
            ? Icon(
                Icons.check_rounded,
                size: 16,
                color: c.colorCode == Colors.white ||
                        c.colorCode == const Color(0xFFFFFFFF)
                    ? AppTheme.purple
                    : Colors.white,
              )
            : null,
      ),
    );
  }

  Widget _buildMoreColorsButton() {
    return GestureDetector(
      onTap: () {
        BottomDialog.showSelectColor(context, (value) {
          if (value.titleEn.isNotEmpty && selectedColor != value) {
            setState(() {
              selectedColor = value;
              colorController.text = value.titleEn;
            });
          }
        }, selectedColor);
      },
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: AppTheme.border, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: AppTheme.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Icon(Icons.add_rounded, color: AppTheme.gray, size: 20),
      ),
    );
  }

  Widget _buildSeatCounter() {
    return _buildCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            _cardIcon(Icons.people_alt_outlined),
            const SizedBox(width: 12),
            const Expanded(child: SizedBox()),
            _counterBtn(Icons.remove_rounded, () {
              if (seats > 1) setState(() => seats--);
            }),
            SizedBox(
              width: 36,
              child: Center(
                child: Text(
                  "$seats",
                  style: const TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.black,
                  ),
                ),
              ),
            ),
            _counterBtn(Icons.add_rounded, () {
              if (seats < 8) setState(() => seats++);
            }),
          ],
        ),
      ),
    );
  }

  Widget _counterBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: AppTheme.purple.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: AppTheme.purple, size: 18),
      ),
    );
  }

  // ── Step 2 ─────────────────────────────────────────────────────────────────

  Widget _buildStep2() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildImageUpload(
          title: translate("ketamiz.tech_passport_front"),
          imagePath: techPassportFront,
          onUpload: (path) => setState(() => techPassportFront = path),
          uploadType: 'tech_front',
        ),
        const SizedBox(height: 16),
        _buildImageUpload(
          title: translate("ketamiz.tech_passport_back"),
          imagePath: techPassportBack,
          onUpload: (path) => setState(() => techPassportBack = path),
          uploadType: 'tech_back',
        ),
        const SizedBox(height: 24),
        _buildCarImagesSection(),
      ],
    );
  }

  Widget _buildImageUpload({
    required String title,
    required String imagePath,
    required Function(String) onUpload,
    required String uploadType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text16h500w(title: title),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () {
            if (imagePath.isEmpty) {
              BottomDialog.showUploadImage(
                context,
                onGallery: () => _handleImageSelection(
                    ImageSource.gallery, onUpload, uploadType),
                onCamera: () => _handleImageSelection(
                    ImageSource.camera, onUpload, uploadType),
              );
            }
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.purple, width: 2),
            ),
            child: imagePath.isEmpty
                ? Column(
                    children: [
                      const Icon(Icons.cloud_upload_outlined,
                          size: 48, color: AppTheme.purple),
                      const SizedBox(height: 8),
                      Text14h400w(title: translate("ketamiz.tap_to_upload")),
                    ],
                  )
                : Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(
                          File(imagePath),
                          height: 164,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: GestureDetector(
                          onTap: () => setState(() {
                            if (uploadType == 'tech_front') {
                              techPassportFront = '';
                            } else if (uploadType == 'tech_back') {
                              techPassportBack = '';
                            }
                          }),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.3),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.delete_outline,
                                color: AppTheme.red, size: 20),
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  Future<void> _handleImageSelection(
    ImageSource source,
    Function(String) onUpdate,
    String type,
  ) async {
    final pickedFile = await ImageHelper.pick(source);
    if (pickedFile == null) return;

    setState(() => isLoading = true);

    HttpResult response;
    if (type == 'tech_front') {
      response = await _repository.fetchUploadCarImages(
          vehicleId, pickedFile.path, '', []);
    } else if (type == 'tech_back') {
      response = await _repository.fetchUploadCarImages(
          vehicleId, '', pickedFile.path, []);
    } else {
      response = await _repository.fetchUploadCarImages(
          vehicleId, '', '', [pickedFile.path]);
    }

    if (!mounted) return;
    setState(() => isLoading = false);

    if (response.isSuccess) {
      final result = response.result;
      final ok = result is Map &&
          (result['status'] == 'success' || result['status'] == 200);
      if (ok) {
        onUpdate(pickedFile.path);
      } else {
        _showError(translate("ketamiz.upload_failed"));
      }
    } else {
      _showError(translate("auth.connection_failed"));
    }
  }

  Widget _buildCarImagesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text16h500w(title: translate("profile.car_images")),
        const SizedBox(height: 16),
        SizedBox(
          height: 112,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: carImages.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                return GestureDetector(
                  onTap: () {
                    BottomDialog.showUploadImage(
                      context,
                      onGallery: () => _pickCarImage(ImageSource.gallery),
                      onCamera: () => _pickCarImage(ImageSource.camera),
                    );
                  },
                  child: Container(
                    width: 112,
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      color: AppTheme.light,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.purple, width: 2),
                    ),
                    child: const Center(
                      child:
                          Icon(Icons.add, size: 40, color: AppTheme.purple),
                    ),
                  ),
                );
              }
              return Stack(
                children: [
                  Container(
                    width: 112,
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      image: DecorationImage(
                        image: FileImage(File(carImages[index - 1].path)),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  Positioned(
                    top: 0,
                    right: 12,
                    child: GestureDetector(
                      onTap: () =>
                          setState(() => carImages.removeAt(index - 1)),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.5),
                        ),
                        child: const Icon(Icons.delete,
                            color: Colors.red, size: 20),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _pickCarImage(ImageSource source) async {
    try {
      final XFile? image = await ImageHelper.pick(source);
      if (image == null) return;
      setState(() => isLoading = true);

      final response = await _repository.fetchUploadCarImages(
          vehicleId, '', '', [image.path]);
      setState(() => isLoading = false);

      if (response.isSuccess &&
          response.result is Map &&
          (response.result['status'] == 'success' ||
              response.result['status'] == 200)) {
        setState(() => carImages.add(image));
      } else {
        _showError(translate("ketamiz.upload_failed"));
      }
    } catch (e) {
      debugPrint("Error picking car image: $e");
      setState(() => isLoading = false);
    }
  }

  // ── Scaffold ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: InkWell(
          borderRadius: BorderRadius.circular(40),
          onTap: () =>
              currentStep == 1 ? Navigator.pop(context) : setState(() => currentStep--),
          child: Container(
            padding: const EdgeInsets.all(8),
            child: Center(
              child: SvgPicture.asset(
                'assets/icons/arrow_left.svg',
                height: 24,
                width: 24,
                colorFilter: const ColorFilter.mode(
                    AppTheme.black, BlendMode.srcIn),
              ),
            ),
          ),
        ),
        centerTitle: true,
        title: Text16h500w(title: _getAppBarTitle()),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(3),
          child: Container(height: 3, color: AppTheme.purple),
        ),
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Stack(
          children: [
            Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 24, 16, 96),
                    children: [
                      if (currentStep == 1) _buildStep1(),
                      if (currentStep == 2) _buildStep2(),
                    ],
                  ),
                ),
              ],
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: 32,
              child: _buildBottomButton(),
            ),
            if (isLoading)
              Container(
                color: AppTheme.black.withOpacity(0.45),
                child: Center(
                  child: Container(
                    height: 96,
                    width: 96,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Center(
                      child: CircularProgressIndicator(
                        valueColor:
                            AlwaysStoppedAnimation<Color>(AppTheme.purple),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _getAppBarTitle() {
    return currentStep == 1
        ? translate("ketamiz.vehicle_details")
        : translate("ketamiz.vehicle_photos");
  }

  Widget _buildBottomButton() {
    return GestureDetector(
      onTap: () {
        if (!_validateStep()) return;
        if (currentStep == 1) {
          _submitStep1();
        } else {
          _submitStep2();
        }
      },
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: AppTheme.purple,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: AppTheme.purple.withOpacity(0.28),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              currentStep == totalSteps
                  ? translate("ketamiz.submit")
                  : translate("next"),
              style: const TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Colors.white,
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.arrow_forward_rounded,
                color: Colors.white, size: 18),
          ],
        ),
      ),
    );
  }

  // ── Validation ──────────────────────────────────────────────────────────────

  bool _validateStep() {
    if (currentStep == 1) {
      if (carModelController.text.isEmpty) {
        _showError(translate("ketamiz.missing_docs"));
        return false;
      }
      final plateLen = carNumberController.text.length;
      if (plateLen != 10 && plateLen != 11) {
        _showError(translate("ketamiz.invalid_plate"));
        return false;
      }
      if (selectedColor.id == 0) {
        _showError(translate("ketamiz.select_color"));
        return false;
      }
      if (techPassportController.text.length != 10) {
        _showError(translate("ketamiz.invalid_tech_serie"));
        return false;
      }
    }
    if (currentStep == 2) {
      if (techPassportFront.isEmpty ||
          techPassportBack.isEmpty ||
          carImages.isEmpty) {
        _showError(translate("ketamiz.upload_all_docs"));
        return false;
      }
    }
    return true;
  }

  void _showError(String message) {
    CenterDialog.showActionFailed(
        context, translate("ketamiz.error"), message);
  }

  // ── Submit ──────────────────────────────────────────────────────────────────

  Future<void> _submitStep1() async {
    setState(() => isLoading = true);

    final response = await _repository.fetchAddVehicleInfo(
      carNumberController.text,
      selectedVehicle.vehicleName,
      selectedColor.id,
      techPassportController.text,
      seats,
    );

    if (!mounted) return;
    setState(() => isLoading = false);

    if (response.isSuccess) {
      if (response.result is Map &&
          response.result['status'] == 'success' &&
          response.result['data'] != null) {
        final newId = response.result['data']['id']?.toString();
        if (newId != null && newId.isNotEmpty) {
          vehicleId = newId;
          setState(() => currentStep++);
        } else {
          _showError(translate("ketamiz.vehicle_id_missing"));
        }
      } else {
        final msg = (response.result is Map
                ? response.result['message']?.toString()
                : null) ??
            translate("ketamiz.error");
        _showError(msg);
      }
    } else {
      _showError(translate("auth.connection_failed"));
    }
  }

  Future<void> _submitStep2() async {
    if (vehicleId.isEmpty) {
      _showError(translate("ketamiz.vehicle_id_missing"));
      return;
    }

    CustomSnackBar()
        .showSnackBar(context, translate("ketamiz.documents_uploaded"), 1);

    final prefs = await SharedPreferences.getInstance();
    prefs.setBool('isDocsAdded', true);
    prefs.setBool('isDocsVerified', false);
    prefs.setString("vehicle_id", vehicleId);

    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const MainScreen()),
    );
  }
}
