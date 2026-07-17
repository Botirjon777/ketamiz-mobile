import 'package:flutter/material.dart';
import 'package:flutter_translate/flutter_translate.dart';

import '../../resources/repository.dart';
import '../../theme/app_theme.dart';
import '../../utils/uz_phone_formatter.dart';
import '../dialogs/center_dialog.dart';
import '../dialogs/response_popup.dart';
import '../widgets/auth_banner.dart';
import '../widgets/buttons/secondary_button.dart';
import '../widgets/textfield/labeled_input_field.dart';
import 'reset_password_verification_screen.dart';

/// Collects the user's phone number to start the password-recovery flow.
/// A verification code is sent (reusing the resend endpoint) and the user is
/// taken to the verification screen.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final Repository _repository = Repository();
  bool _isLoading = false;

  static const Color _pageBg = Color(0xFFF2F3F5);

  Future<void> _submit() async {
    final digits = uzPhoneDigits(_phoneController.text);
    if (digits.length != 9) {
      CenterDialog.showActionFailed(
        context,
        translate("auth.error"),
        translate("auth.enter_phone"),
      );
      return;
    }

    final phone = uzFullPhone(_phoneController.text);
    setState(() => _isLoading = true);
    final response = await _repository.fetchSendResetCode(phone);
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (response.isSuccess) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ResetPasswordVerificationScreen(phone: phone),
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
      resizeToAvoidBottomInset: true,
      backgroundColor: _pageBg,
      body: GestureDetector(
        onTap: () {
          final currentFocus = FocusScope.of(context);
          if (!currentFocus.hasPrimaryFocus) {
            currentFocus.unfocus();
          }
        },
        child: SafeArea(
          child: Stack(
            children: [
              SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
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
                                  translate("auth.forgot_password"),
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w700,
                                    fontFamily: AppTheme.fontFamily,
                                    color: AppTheme.black,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  translate("auth.forgot_subtitle"),
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
                              title: translate("auth.phone_number"),
                              hint: 'XX XXX XX XX',
                              icon: Icons.phone_outlined,
                              controller: _phoneController,
                              phone: true,
                              prefixText: '+998 ',
                              inputFormatters: [UzPhoneFormatter()],
                              textInputAction: TextInputAction.done,
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
      ),
    );
  }
}
