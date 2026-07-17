import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:ketamiz/src/ui/auth/verification_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../model/api/login_model.dart';
import '../../model/api/register_model.dart';
import '../../resources/repository.dart';
import '../../services/push_service.dart';
import '../../utils/secure_storage.dart';
import '../../utils/uz_phone_formatter.dart';
import '../../theme/app_theme.dart';
import '../../utils/validators.dart';
import '../dialogs/center_dialog.dart';
import '../dialogs/response_popup.dart';
import '../menu/main_screen.dart';
import '../widgets/auth_banner.dart';
import '../widgets/buttons/secondary_button.dart';
import '../widgets/textfield/labeled_input_field.dart';
import 'forgot_password_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool isLoading = false;
  bool isLogin = true;
  bool _agreedToTerms = false;

  // Opened from the terms & privacy links on the register form.
  static const String _websiteUrl = 'https://ketamiz.com';

  // Light-gray page background and the toggle track tone.
  static const Color _pageBg = Color(0xFFF2F3F5);
  static const Color _toggleTrack = Color(0xFFF1F2F4);

  // Keeps the focused field visible above the keyboard.
  static const EdgeInsets _fieldScrollPadding =
      EdgeInsets.only(left: 20, top: 20, right: 20, bottom: 110);

  final Repository _repository = Repository();

  /// Login
  TextEditingController phoneController = TextEditingController();
  TextEditingController passController = TextEditingController();

  /// Register
  TextEditingController phoneRegController = TextEditingController();
  TextEditingController passRegController = TextEditingController();
  TextEditingController passAgainController = TextEditingController();
  TextEditingController firstNameController = TextEditingController();
  TextEditingController lastNameController = TextEditingController();
  TextEditingController fatherNameController = TextEditingController();

  String _getErrorMessage(dynamic result) {
    if (result == null) return translate("auth.failed_msg");

    String message = "";
    if (result is Map) {
      message = (result['message'] ?? result['error'] ?? "").toString();
    } else {
      message = result.toString();
    }

    final lowerMsg = message.toLowerCase();

    if (lowerMsg.contains("selected phone is invalid")) {
      return translate("auth.invalid_phone");
    }
    if (lowerMsg.contains("tasdiqlang") || lowerMsg.contains("verify")) {
      return translate("auth.verify_account");
    }
    if (lowerMsg.contains("phone") && (lowerMsg.contains("taken") || lowerMsg.contains("already registered") || lowerMsg.contains("already been taken"))) {
      return translate("auth.phone_taken");
    }
    if (lowerMsg.contains("password") && (lowerMsg.contains("incorrect") || lowerMsg.contains("invalid") || lowerMsg.contains("not match") || lowerMsg.contains("wrong"))) {
      return translate("auth.incorrect_password");
    }

    // If it's a long stack trace or HTML, don't show it raw
    if (message.contains("Illuminate\\") || message.contains("<!DOCTYPE html>")) {
      return translate("auth.failed_msg");
    }

    return message.isNotEmpty ? message : translate("auth.failed_msg");
  }

  Future<void> _launch(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
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
                    // ── White header: banner (white bg) + heading ─────────
                    Container(
                      color: Colors.white,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const AuthBanner(),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(24, 8, 24, 22),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildHeading(),
                                const SizedBox(height: 8),
                                Text(
                                  isLogin
                                      ? translate("auth.please_enter")
                                      : translate("auth.register_subtitle"),
                                  style: const TextStyle(
                                    fontSize: 13,
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
                    // ── White form card (floating on the gray page) ───────
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                      child: _buildCard(),
                    ),
                  ],
                ),
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

  /// Heading with the trailing accent (after a `|` marker) painted purple.
  Widget _buildHeading() {
    final raw =
        translate(isLogin ? "auth.login_heading" : "auth.register_heading");
    final parts = raw.split('|');
    return RichText(
      text: TextSpan(
        style: const TextStyle(
          fontSize: 30,
          fontWeight: FontWeight.w700,
          fontFamily: AppTheme.fontFamily,
          height: 1.2,
          letterSpacing: 0.2,
          color: AppTheme.black,
        ),
        children: [
          TextSpan(text: parts.first),
          if (parts.length > 1)
            TextSpan(
              text: parts.sublist(1).join('|'),
              style: const TextStyle(color: AppTheme.purple),
            ),
        ],
      ),
    );
  }

  Widget _buildCard() {
    return Container(
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
          _buildToggle(),
          const SizedBox(height: 24),
          if (isLogin) ...[
            _buildLoginFields(),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ForgotPasswordScreen(),
                  ),
                ),
                child: Text(
                  translate("auth.forgot_password"),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    fontFamily: AppTheme.fontFamily,
                    color: AppTheme.purple,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            SecondaryButton(
              title: translate("auth.login"),
              showArrow: true,
              onTap: _handleSubmit,
            ),
          ] else ...[
            _buildRegisterFields(),
            const SizedBox(height: 18),
            _buildTermsCheckbox(),
            const SizedBox(height: 24),
            SecondaryButton(
              title: translate("auth.register"),
              showArrow: true,
              onTap: _handleSubmit,
            ),
          ],
        ],
      ),
    );
  }

  /// Text toggle with a sliding white pill (with shadow) that animates between
  /// the two tabs.
  Widget _buildToggle() {
    return Container(
      height: 56,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: _toggleTrack,
        borderRadius: BorderRadius.circular(40),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final tabWidth = constraints.maxWidth / 2;
          return Stack(
            children: [
              AnimatedAlign(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                alignment:
                    isLogin ? Alignment.centerLeft : Alignment.centerRight,
                child: Container(
                  width: tabWidth,
                  height: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(40),
                    boxShadow: [
                      BoxShadow(
                        offset: const Offset(0, 4),
                        blurRadius: 12,
                        color: AppTheme.dark.withOpacity(0.16),
                      ),
                    ],
                  ),
                ),
              ),
              Row(
                children: [
                  _toggleLabel(
                    translate("auth.login"),
                    isLogin,
                    () {
                      if (!isLogin) {
                        setState(() => isLogin = true);
                      }
                    },
                  ),
                  _toggleLabel(
                    translate("auth.sign_up"),
                    !isLogin,
                    () {
                      if (isLogin) {
                        setState(() => isLogin = false);
                      }
                    },
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _toggleLabel(String label, bool active, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Center(
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 250),
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              fontFamily: AppTheme.fontFamily,
              letterSpacing: 0.3,
              color: active ? AppTheme.purple : AppTheme.dark,
            ),
            child: Text(label),
          ),
        ),
      ),
    );
  }

  Widget _buildLoginFields() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LabeledInputField(
          key: const ValueKey('login_phone'),
          title: translate("auth.phone_number"),
          hint: 'XX XXX XX XX',
          icon: Icons.phone_outlined,
          controller: phoneController,
          phone: true,
          prefixText: '+998 ',
          inputFormatters: [UzPhoneFormatter()],
          scrollPadding: _fieldScrollPadding,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 14),
        LabeledInputField(
          key: const ValueKey('login_password'),
          title: translate("auth.password"),
          hint: translate("auth.password_hint"),
          icon: Icons.lock_outline_rounded,
          controller: passController,
          pass: true,
          scrollPadding: _fieldScrollPadding,
          textInputAction: TextInputAction.done,
        ),
      ],
    );
  }

  /// All registration fields shown in a single view.
  Widget _buildRegisterFields() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LabeledInputField(
          key: const ValueKey('reg_first_name'),
          title: translate("auth.first_name"),
          hint: translate("auth.first_name_hint"),
          icon: Icons.person_outline_rounded,
          controller: firstNameController,
          scrollPadding: _fieldScrollPadding,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.givenName],
        ),
        const SizedBox(height: 14),
        LabeledInputField(
          key: const ValueKey('reg_last_name'),
          title: translate("auth.last_name"),
          hint: translate("auth.last_name_hint"),
          icon: Icons.person_outline_rounded,
          controller: lastNameController,
          scrollPadding: _fieldScrollPadding,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.familyName],
        ),
        const SizedBox(height: 14),
        LabeledInputField(
          key: const ValueKey('reg_father_name'),
          title: translate("auth.father_name"),
          hint: translate("auth.father_name_hint"),
          icon: Icons.person_outline_rounded,
          controller: fatherNameController,
          scrollPadding: _fieldScrollPadding,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.middleName],
        ),
        const SizedBox(height: 14),
        LabeledInputField(
          key: const ValueKey('reg_phone'),
          title: translate("auth.phone_number"),
          hint: 'XX XXX XX XX',
          icon: Icons.phone_outlined,
          controller: phoneRegController,
          phone: true,
          prefixText: '+998 ',
          inputFormatters: [UzPhoneFormatter()],
          scrollPadding: _fieldScrollPadding,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.telephoneNumber],
        ),
        const SizedBox(height: 14),
        LabeledInputField(
          key: const ValueKey('reg_password'),
          title: translate("auth.password"),
          hint: translate("auth.password_min_hint"),
          icon: Icons.lock_outline_rounded,
          controller: passRegController,
          scrollPadding: _fieldScrollPadding,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.newPassword],
        ),
        const SizedBox(height: 14),
        LabeledInputField(
          key: const ValueKey('reg_confirm_password'),
          title: translate("auth.confirm_password"),
          hint: translate("auth.confirm_password_hint"),
          icon: Icons.lock_outline_rounded,
          controller: passAgainController,
          scrollPadding: _fieldScrollPadding,
          textInputAction: TextInputAction.done,
          autofillHints: const [AutofillHints.newPassword],
        ),
      ],
    );
  }


  Widget _buildTermsCheckbox() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 24,
          height: 24,
          child: Checkbox(
            value: _agreedToTerms,
            onChanged: (v) => setState(() => _agreedToTerms = v ?? false),
            activeColor: AppTheme.purple,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
            ),
            side: const BorderSide(color: AppTheme.inputBorder, width: 1.5),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(child: _buildTermsText()),
      ],
    );
  }

  /// Renders [auth.terms_agree], painting any `[[...]]`-wrapped phrase as a
  /// purple, tappable link that opens the website.
  Widget _buildTermsText() {
    final raw = translate("auth.terms_agree");
    final spans = <InlineSpan>[];
    final re = RegExp(r'\[\[(.*?)\]\]');
    int last = 0;
    for (final m in re.allMatches(raw)) {
      if (m.start > last) {
        spans.add(TextSpan(text: raw.substring(last, m.start)));
      }
      spans.add(
        TextSpan(
          text: m.group(1),
          style: const TextStyle(
            color: AppTheme.purple,
            fontWeight: FontWeight.w500,
          ),
          recognizer: TapGestureRecognizer()
            ..onTap = () => _launch(_websiteUrl),
        ),
      );
      last = m.end;
    }
    if (last < raw.length) {
      spans.add(TextSpan(text: raw.substring(last)));
    }
    return Text.rich(
      TextSpan(
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          fontFamily: AppTheme.fontFamily,
          height: 1.45,
          color: AppTheme.dark,
        ),
        children: spans,
      ),
    );
  }

  Future<void> _handleSubmit() async {
    if (isLogin == true) {
      if (phoneController.text.trim().isEmpty || passController.text.isEmpty) {
        CenterDialog.showActionFailed(
          context,
          translate("auth.error"),
          translate("auth.fill_login_fields"),
        );
        return;
      }
      setState(() {
        isLoading = true;
      });
      var response = await _repository.fetchLogin(
        uzFullPhone(phoneController.text),
        passController.text,
      );

      if (response.isSuccess) {
        var result = LoginModel.fromJson(response.result);
        setState(() {
          isLoading = false;
        });
        if (result.status == "success") {
          await SecureStorage.setToken(result.authorisation.token);
          // JWT is ready — register this device for push notifications.
          PushNotificationService.instance.registerToken();
          SharedPreferences prefs = await SharedPreferences.getInstance();
          prefs.setBool("isFirst", false);
          prefs.setString(
            "token_date",
            "${result.user.createdAt.day}-${result.user.createdAt.month}-${result.user.createdAt.year}",
          );
          showResponsePopup(
            context,
            status: result.status,
            message: result.message,
          );
          await _repository.cacheLoginUser(result.user);
          Navigator.of(context).popUntil(
            (route) => route.isFirst,
          );
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) {
                return const MainScreen();
              },
            ),
          );
        } else {
          showResponsePopup(
            context,
            status: result.status,
            message: result.message,
          );
        }
      } else {
        setState(() {
          isLoading = false;
        });
        if (response.status == 403) {
          final serverMsg = response.result['message'] ?? "";
          if (serverMsg.toString().toLowerCase().contains("tasdiqlang") ||
              serverMsg.toString().toLowerCase().contains("verify")) {
            final phone = uzFullPhone(phoneController.text);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => VerificationScreen(
                  phone: phone,
                ),
              ),
            );
            showResponsePopup(
              context,
              status: 'error',
              message: serverMsg.toString(),
            );
            return;
          }
        }

        if (response.status == -1) {
          showResponsePopup(
            context,
            status: 'error',
            message: translate("auth.connection_failed_msg"),
          );
        } else {
          showResponsePopup(
            context,
            status: 'error',
            message: _getErrorMessage(response.result),
          );
        }
      }
    } else {
      String phone = uzFullPhone(phoneRegController.text);

      if (!_agreedToTerms) {
        CenterDialog.showActionFailed(
          context,
          translate("auth.error"),
          translate("auth.must_agree"),
        );
        return;
      }

      if (firstNameController.text.isNotEmpty &&
          lastNameController.text.isNotEmpty &&
          phoneRegController.text.isNotEmpty &&
          passRegController.text.isNotEmpty &&
          Validators.phoneNumberValidator(phone) == true &&
          passAgainController.text == passRegController.text) {
        setState(() {
          isLoading = true;
        });
        // Email is collected later in the profile section, so it's not sent
        // here. The father's name stays optional.
        var response = await _repository.fetchRegister(
          firstNameController.text,
          lastNameController.text,
          fatherNameController.text,
          phone,
          passRegController.text,
          passAgainController.text,
        );
        if (response.isSuccess) {
          var result = RegisterModel.fromJson(
            response.result,
          );
          setState(() {
            isLoading = false;
          });
          if (result.status == "success") {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) {
                  return VerificationScreen(
                    phone: phone,
                  );
                },
              ),
            );
            showResponsePopup(
              context,
              status: result.status,
              message: result.message,
            );
          } else {
            showResponsePopup(
              context,
              status: result.status,
              message: result.message,
            );
          }
        } else {
          setState(() {
            isLoading = false;
          });
          if (response.status == -1) {
            showResponsePopup(
              context,
              status: 'error',
              message: translate("auth.connection_failed_msg"),
            );
          } else {
            showResponsePopup(
              context,
              status: 'error',
              message: _getErrorMessage(response.result),
            );
          }
        }
      } else if (firstNameController.text.isEmpty ||
          lastNameController.text.isEmpty ||
          phoneRegController.text.isEmpty ||
          passRegController.text.isEmpty ||
          passAgainController.text.isEmpty) {
        CenterDialog.showActionFailed(
          context,
          translate('auth.error'),
          translate('auth.fill_signup_fields'),
        );
      } else if (Validators.phoneNumberValidator(phone) == false) {
        CenterDialog.showActionFailed(
          context,
          translate('auth.error'),
          translate('auth.invalid_phone_format'),
        );
      } else if (passAgainController.text != passRegController.text) {
        CenterDialog.showActionFailed(
          context,
          translate('auth.password_error'),
          translate('auth.password_mismatch'),
        );
      } else {
        resetValues();
        CenterDialog.showActionFailed(
          context,
          translate('auth.error'),
          translate('auth.something_went_wrong'),
        );
      }
    }
  }

  void resetValues() {
    phoneController.clear();
    passController.clear();
    firstNameController.clear();
    lastNameController.clear();
    fatherNameController.clear();
    phoneRegController.clear();
    passRegController.clear();
    passAgainController.clear();
  }
}
