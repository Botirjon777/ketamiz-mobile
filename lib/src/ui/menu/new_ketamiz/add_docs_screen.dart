import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:ketamiz/src/ui/dialogs/bottom_dialog.dart';
import 'package:ketamiz/src/ui/dialogs/center_dialog.dart';
import 'package:ketamiz/src/ui/menu/main_screen.dart';
import 'package:ketamiz/src/ui/widgets/buttons/primary_button.dart';
import 'package:ketamiz/src/ui/widgets/textfield/main_textfield.dart';
import 'package:ketamiz/src/ui/widgets/textfield/labeled_input_field.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../model/api/apply_driver_response_model.dart';
import '../../../utils/input_formatters.dart';
import '../../../resources/repository.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/image_helper.dart';
import '../../dialogs/snack_bar.dart';
import '../../widgets/texts/text_14h_400w.dart';
import '../../widgets/texts/text_16h_500w.dart';

class AddDocsScreen extends StatefulWidget {
  const AddDocsScreen({super.key});

  @override
  State<AddDocsScreen> createState() => _AddDocsScreenState();
}

class _AddDocsScreenState extends State<AddDocsScreen> {
  final Repository _repository = Repository();
  
  bool isLoading = false;
  int currentStep = 1;
  int totalSteps = 2;

  // Step 1 Controllers (Driver)
  TextEditingController licenseNumController = TextEditingController();
  TextEditingController licenseExpiryDateController = TextEditingController();
  TextEditingController birthDateController = TextEditingController();

  // Step 2 Images (Driver)
  String frontImage = '';
  String backImage = '';
  String passportImage = '';

  DateTime birthDate = DateTime.now().subtract(const Duration(days: 365 * 18));
  DateTime licenseExpiryDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    await Permission.camera.request();
    await Permission.photos.request();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 76,
        leading: GestureDetector(
          onTap: () {
            if (currentStep > 1) {
              setState(() {
                currentStep--;
              });
            } else {
              Navigator.pop(context);
            }
          },
          child: Row(
            children: [
              const SizedBox(width: 12),
              InkWell(
                borderRadius: BorderRadius.circular(40),
                onTap: () {
                  setState(() {
                    currentStep==1 ? Navigator.pop(context) : currentStep--;
                  });
                },
                child: Container(
                  height: 40,
                  width: 40,
                  padding: const EdgeInsets.all(8),
                  child: Center(
                    child: SvgPicture.asset(
                      'assets/icons/arrow_left.svg',
                      height: 24,
                      width: 24,
                      colorFilter: const ColorFilter.mode(
                        AppTheme.black,
                        BlendMode.srcIn,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        elevation: 0,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: Column(
                children: [
                  // Scale long titles down to fit instead of overflowing.
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text16h500w(title: _getAppBarTitle()),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(totalSteps * 2 - 1, (index) {
                      if (index.isEven) {
                        return _buildStepCircle(index ~/ 2 + 1);
                      }
                      return _buildStepConnector((index - 1) ~/ 2 + 1);
                    }),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 52),
          ],
        ),
        centerTitle: true,
      ),
      body: GestureDetector(
        onTap: () {
          FocusScope.of(context).unfocus();
        },
        child: Stack(
          children: [
            Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 22),
                    children: [
                      if (currentStep == 1) _buildStep1(),
                      if (currentStep == 2) _buildStep2(),
                      const SizedBox(height: 96),
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
                      boxShadow: [
                        BoxShadow(
                          offset: const Offset(0, 5),
                          blurRadius: 25,
                          spreadRadius: 0,
                          color: AppTheme.dark.withOpacity(0.2),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(AppTheme.purple),
                      ),
                    ),
                  ),
                ),
              )
          ],
        ),
      ),
    );
  }

  String _getAppBarTitle() {
    if (currentStep == 1) return translate("ketamiz.driver_license_details");
    return translate("ketamiz.document_upload");
  }

  Widget _buildStepCircle(int step) {
    final bool isCompleted = step < currentStep;
    final bool isActive = step == currentStep;
    final Color fillColor = (isCompleted || isActive) ? AppTheme.purple : Colors.white;
    final Color borderColor = (isCompleted || isActive) ? AppTheme.purple : AppTheme.gray.withOpacity(0.4);
    final Color textColor = (isCompleted || isActive) ? Colors.white : AppTheme.gray;
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: fillColor,
        border: Border.all(color: borderColor, width: 1.5),
      ),
      child: Center(
        child: isCompleted
            ? const Icon(Icons.check, size: 14, color: Colors.white)
            : Text(
                '$step',
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
      ),
    );
  }

  Widget _buildStepConnector(int leftStep) {
    final bool isActive = leftStep < currentStep;
    return Container(
      width: 32,
      height: 2,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      color: isActive ? AppTheme.purple : AppTheme.gray.withOpacity(0.3),
    );
  }

  // --- Step 1 UI (Driver Details) ---
  Widget _buildStep1() {
    return Column(
      children: [
        // Reference image
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Image.asset(
            'assets/images/front-driving-lycence.png',
            width: double.infinity,
            fit: BoxFit.fitWidth,
          ),
        ),
        const SizedBox(height: 20),
        LabeledInputField(
          title: translate("ketamiz.driver_license_number"),
          hint: translate("ketamiz.driver_license_number"),
          icon: Icons.badge_outlined,
          controller: licenseNumController,
          inputFormatters: [DocumentNumberFormatter()],
          keyboardType: TextInputType.text,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 16),
        _buildDateField(
          controller: licenseExpiryDateController,
          label: translate("ketamiz.driver_license_expiry_date"),
          icon: Icons.date_range_outlined,
          onTap: () {
            BottomDialog.showBirthDate(
              context,
              (data) {
                setState(() {
                  licenseExpiryDate = data;
                  licenseExpiryDateController.text =
                      '${data.day}/${data.month}/${data.year}';
                });
              },
              licenseExpiryDate,
              false,
              translate("ketamiz.driver_license_expiry_date"),
            );
          },
        ),
        const SizedBox(height: 16),
        _buildDateField(
          controller: birthDateController,
          label: translate("profile.birth_date"),
          icon: Icons.cake_outlined,
          onTap: () {
            BottomDialog.showBirthDate(
              context,
              (data) {
                setState(() {
                  birthDate = data;
                  birthDateController.text =
                      '${data.day}/${data.month}/${data.year}';
                });
              },
              birthDate,
              true,
              translate("profile.birth_date"),
            );
          },
        ),
        const SizedBox(height: 24),
        // Support note
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFFF4F2FF),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.purple.withOpacity(0.2)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline_rounded, size: 18, color: AppTheme.purple),
              const SizedBox(width: 10),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    style: const TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 13,
                      color: AppTheme.black,
                      height: 1.5,
                    ),
                    children: [
                      TextSpan(text: '${translate("ketamiz.support_note")} '),
                      WidgetSpan(
                        alignment: PlaceholderAlignment.middle,
                        child: GestureDetector(
                          onTap: () async {
                            final uri = Uri.parse('https://t.me/ketamizcom');
                            if (await canLaunchUrl(uri)) {
                              await launchUrl(uri, mode: LaunchMode.externalApplication);
                            }
                          },
                          child: Text(
                            translate("ketamiz.support_link_label"),
                            style: const TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: 13,
                              color: AppTheme.purple,
                              fontWeight: FontWeight.w600,
                              decoration: TextDecoration.underline,
                              decorationColor: AppTheme.purple,
                            ),
                          ),
                        ),
                      ),
                      const TextSpan(text: '.'),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDateField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        onTap();
      },
      child: AbsorbPointer(
        child: LabeledInputField(
          title: label,
          hint: 'DD/MM/YYYY',
          icon: icon,
          controller: controller,
          textInputAction: TextInputAction.next,
        ),
      ),
    );
  }

  // --- Step 2 UI (Driver Docs) ---
  Widget _buildStep2() {
    return Column(
      children: [
        _buildImageUpload(
          title: translate("ketamiz.upload_driving_licence_front"), // "License Front"
          imagePath: frontImage,
          onUpload: (path) {
            setState(() {
              frontImage = path;
            });
            _saveToPrefs("driving_front_image", path);
          },
          uploadType: 'front',
        ),
        const SizedBox(height: 16),
        _buildImageUpload(
          title: translate("ketamiz.upload_driving_licence_back"), // "License Back"
          imagePath: backImage,
          onUpload: (path) {
            setState(() {
              backImage = path;
            });
            _saveToPrefs("driving_back_image", path);
          },
          uploadType: 'back',
        ),
        const SizedBox(height: 16),
        _buildImageUpload(
          title: translate("ketamiz.upload_passport"), // "Passport"
          imagePath: passportImage,
          onUpload: (path) {
            setState(() {
              passportImage = path;
            });
            _saveToPrefs("passport_image", path);
          },
          uploadType: 'passport',
        ),
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
                onGallery: () => _handleImageSelection(ImageSource.gallery, onUpload),
                onCamera: () => _handleImageSelection(ImageSource.camera, onUpload),
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
                const Icon(Icons.cloud_upload_outlined, size: 48, color: AppTheme.purple),
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
                    onTap: () {
                      setState(() {
                        // Reset the corresponding image path based on uploadType
                        if (uploadType == 'front') {
                          frontImage = '';
                        } else if (uploadType == 'back') {
                          backImage = '';
                        } else if (uploadType == 'passport') {
                          passportImage = '';
                        }
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.3),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.delete_outline,
                        color: AppTheme.red,
                        size: 20,
                      ),
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
  ) async {
    final pickedFile = await ImageHelper.pick(source);
    if (pickedFile == null) return;

    // Just stash the local path; upload happens in batch on Step submit.
    onUpdate(pickedFile.path);
  }

  /// Upload all 3 driver doc images in one multipart call (server requires it),
  /// then finalize the driver application. Vehicle info is added separately
  /// via AddVehicleScreen once the driver application is approved.
  Future<void> _submitStep2() async {
    setState(() => isLoading = true);

    final response = await _repository.fetchDriverDocsUpload(
      drivingLicenceFrontPath: frontImage,
      drivingLicenceBackPath: backImage,
      passportPath: passportImage,
    );

    if (!mounted) return;
    setState(() => isLoading = false);

    if (response.isSuccess) {
      final result = response.result;
      final success = result is Map &&
          (result['status'] == 'success' || result['status'] == 200);
      if (success) {
        await _finishDriverApplication();
      } else {
        final message = (result is Map ? result['message']?.toString() : null) ??
            translate("ketamiz.upload_failed");
        _showError(message);
      }
    } else {
      _showError(translate("auth.connection_failed"));
    }
  }

  Future<void> _finishDriverApplication() async {
    CustomSnackBar().showSnackBar(context, translate("ketamiz.documents_uploaded"), 1);

    final prefs = await SharedPreferences.getInstance();
    prefs.setBool('isDocsAdded', true);
    prefs.setBool('isDocsVerified', false);

    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const MainScreen()),
    );
  }

  // --- Navigation & Submit ---
  Widget _buildBottomButton() {
    return GestureDetector(
      onTap: () {
        if (!_validateStep()) return;

        if (currentStep == 1) {
          _submitStep1();
        } else if (currentStep == 2) {
          _submitStep2();
        }
      },
      child: PrimaryButton(
        title: currentStep == totalSteps
            ? translate("ketamiz.submit")
            : translate("next"),
      ),
    );
  }

  bool _validateStep() {
    if (currentStep == 1) {
      if (licenseExpiryDateController.text.isEmpty ||
          birthDateController.text.isEmpty) {
        _showError(translate("home.fill_all_fields"));
        return false;
      }
      if (licenseNumController.text.length != 9) {
        _showError(translate("ketamiz.invalid_license"));
        return false;
      }
      if (licenseExpiryDate.isBefore(DateTime.now())) {
        _showError(translate("ketamiz.license_expired"));
        return false;
      }
    }
    if (currentStep == 2) {
      if (frontImage.isEmpty || backImage.isEmpty || passportImage.isEmpty) {
        _showError(translate("ketamiz.upload_all_docs"));
        return false;
      }
    }
    return true;
  }

  void _showError(String message) {
    CenterDialog.showActionFailed(context, translate("ketamiz.error"), message);
  }

  // Step 1 Submit: Apply Driver
  Future<void> _submitStep1() async {
    setState(() => isLoading = true);

    var response = await _repository.fetchApplyDriver(
      licenseNumController.text,
      licenseExpiryDate,
      birthDate,
    );

    if (!mounted) return;

    setState(() => isLoading = false);

    if (response.isSuccess) {
      var result = ApplyDriverResponseModel.fromJson(response.result);
      if (result.status == "success") {
        setState(() {
           currentStep++;
        });
      } else {
         _showError(result.message);
      }
    } else {
      _showError(translate("auth.connection_failed"));
    }
  }

  void _saveToPrefs(String key, String value) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setString(key, value);
  }
}
