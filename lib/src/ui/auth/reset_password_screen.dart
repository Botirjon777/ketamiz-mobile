import 'package:flutter/material.dart';
import 'package:flutter_translate/flutter_translate.dart';

import '../../resources/repository.dart';
import '../../theme/app_theme.dart';
import '../dialogs/center_dialog.dart';
import '../dialogs/response_popup.dart';
import '../widgets/auth_banner.dart';
import '../widgets/buttons/secondary_button.dart';
import '../widgets/textfield/labeled_input_field.dart';
import 'login_screen.dart';

/// Step 2 of the password-reset flow.
///
/// Receives the [phone] and [verificationCode] collected in the previous
/// screens and lets the user choose a new password.
/// On success the user is redirected to [LoginScreen].
class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({
    super.key,
    required this.phone,
    required this.verificationCode,
    this.onSuccess,
  });

  final String phone;
  final String verificationCode;

  /// When set (e.g. changing password from the profile screen while already
  /// logged in), called instead of the default redirect to [LoginScreen].
  final VoidCallback? onSuccess;

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();
  final Repository _repository = Repository();
  bool _isLoading = false;

  static const Color _pageBg = Color(0xFFF2F3F5);

  Future<void> _submit() async {
    final password = _passwordController.text.trim();
    final confirm = _confirmController.text.trim();

    if (password.isEmpty || confirm.isEmpty) {
      CenterDialog.showActionFailed(
        context,
        translate('auth.error'),
        translate('auth.fill_login_fields'),
      );
      return;
    }

    if (password != confirm) {
      CenterDialog.showActionFailed(
        context,
        translate('auth.password_error'),
        translate('auth.password_mismatch'),
      );
      return;
    }

    setState(() => _isLoading = true);
    final response = await _repository.fetchResetPassword(
      widget.phone,
      widget.verificationCode,
      password,
      confirm,
    );
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (response.isSuccess) {
      showResponsePopup(
        context,
        status: 'success',
        message: translate('auth.reset_success'),
      );
      if (widget.onSuccess != null) {
        widget.onSuccess!();
      } else {
        // Pop back to the first route (splash/login gate) and push login.
        Navigator.of(context).popUntil((route) => route.isFirst);
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      }
    } else {
      CenterDialog.showActionFailed(
        context,
        translate('auth.reset_failed'),
        response.status == -1
            ? translate('auth.connection_failed_msg')
            : translate('auth.failed_msg'),
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
          final focus = FocusScope.of(context);
          if (!focus.hasPrimaryFocus) focus.unfocus();
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
                                    border: Border.all(
                                        color: AppTheme.inputBorder),
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
                            padding:
                                const EdgeInsets.fromLTRB(24, 8, 24, 22),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  translate('auth.reset_password'),
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w700,
                                    fontFamily: AppTheme.fontFamily,
                                    color: AppTheme.black,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  translate('auth.reset_subtitle'),
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
                        padding:
                            const EdgeInsets.fromLTRB(16, 20, 16, 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            LabeledInputField(
                              title: translate('auth.new_password'),
                              hint: translate('auth.new_password_hint'),
                              icon: Icons.lock_outline,
                              controller: _passwordController,
                              pass: true,
                              textInputAction: TextInputAction.next,
                            ),
                            const SizedBox(height: 16),
                            LabeledInputField(
                              title: translate('auth.confirm_password'),
                              hint: translate('auth.confirm_password_hint'),
                              icon: Icons.lock_outline,
                              controller: _confirmController,
                              pass: true,
                              textInputAction: TextInputAction.done,
                            ),
                            const SizedBox(height: 22),
                            SecondaryButton(
                              title: translate('auth.reset_password'),
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

