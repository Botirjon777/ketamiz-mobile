import 'package:flutter/material.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../resources/repository.dart';
import '../../../theme/app_theme.dart';
import '../../auth/reset_password_verification_screen.dart';
import '../../dialogs/response_popup.dart';
import '../../widgets/auth_banner.dart';
import '../../widgets/buttons/secondary_button.dart';
import '../../widgets/textfield/labeled_input_field.dart';

/// Entry point for changing the password of an already logged-in user.
///
/// The phone number is read from the cached profile and shown read-only —
/// the user only confirms it. A verification code is then sent to it and the
/// existing forgot-password screens ([ResetPasswordVerificationScreen] /
/// ResetPasswordScreen) are reused to collect the code and the new password.
class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final Repository _repository = Repository();
  bool _isLoading = false;

  static const Color _pageBg = Color(0xFFF2F3F5);

  @override
  void initState() {
    super.initState();
    _loadPhone();
  }

  Future<void> _loadPhone() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _phoneController.text = prefs.getString('phone') ?? '';
    });
  }

  Future<void> _submit() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) return;

    setState(() => _isLoading = true);
    final response = await _repository.fetchSendResetCode(phone);
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (response.isSuccess) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ResetPasswordVerificationScreen(
            phone: phone,
            // Already logged in: return to the app instead of the login screen.
            onSuccess: () =>
                Navigator.of(context).popUntil((route) => route.isFirst),
          ),
        ),
      );
    } else {
      showResponsePopup(
        context,
        status: 'error',
        message: response.status == -1
            ? translate("auth.connection_failed_msg")
            : translate("auth.failed_msg"),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _pageBg,
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── White header: back button + banner + heading ──────
                  Container(
                    color: Colors.white,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: GestureDetector(
                              onTap: () => Navigator.pop(context),
                              child: Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: _pageBg,
                                  shape: BoxShape.circle,
                                  border:
                                      Border.all(color: AppTheme.inputBorder),
                                ),
                                child: const Icon(
                                  Icons.arrow_back_rounded,
                                  size: 20,
                                  color: AppTheme.black,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const AuthBanner(),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(24, 8, 24, 22),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                translate("profile.change_password"),
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w700,
                                  fontFamily: AppTheme.fontFamily,
                                  color: AppTheme.black,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                translate("profile.change_password_subtitle"),
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w400,
                                  fontFamily: AppTheme.fontFamily,
                                  height: 1.45,
                                  color: AppTheme.gray,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  // ── White form card ───────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            offset: const Offset(0, 10),
                            blurRadius: 28,
                            color: AppTheme.black.withOpacity(0.05),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          LabeledInputField(
                            title: translate("profile.phone_number"),
                            hint: '',
                            icon: Icons.phone_outlined,
                            controller: _phoneController,
                            enabled: false,
                          ),
                          const SizedBox(height: 22),
                          SecondaryButton(
                            title: translate("auth.send_code"),
                            showArrow: true,
                            onTap: _submit,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (_isLoading)
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
                          color: AppTheme.dark.withOpacity(0.2),
                        ),
                      ],
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
}
