import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:flutter/material.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:pinput/pinput.dart';

import '../../resources/repository.dart';
import '../../theme/app_theme.dart';
import '../dialogs/center_dialog.dart';
import '../dialogs/response_popup.dart';
import '../widgets/buttons/secondary_button.dart';
import '../widgets/containers/leading_back.dart';
import '../widgets/texts/text_14h_500w.dart';
import '../widgets/texts/text_16h_500w.dart';
import 'reset_password_screen.dart';

/// OTP screen used exclusively in the password-reset flow.
///
/// After the user enters the 6-digit code they are forwarded to
/// [ResetPasswordScreen] to choose a new password.
class ResetPasswordVerificationScreen extends StatefulWidget {
  const ResetPasswordVerificationScreen({
    super.key,
    required this.phone,
    this.onSuccess,
  });

  final String phone;

  /// Forwarded to [ResetPasswordScreen]; see its doc for details.
  final VoidCallback? onSuccess;

  @override
  State<ResetPasswordVerificationScreen> createState() =>
      _ResetPasswordVerificationScreenState();
}

class _ResetPasswordVerificationScreenState
    extends State<ResetPasswordVerificationScreen> {
  final _pinPutFocusNode = FocusNode();
  final _pinPutController = TextEditingController();
  bool _isLoading = false;
  int timer = 90;
  Timer? _timer;

  final Repository _repository = Repository();

  @override
  void initState() {
    _startTimer();
    super.initState();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pinPutFocusNode.dispose();
    _pinPutController.dispose();
    super.dispose();
  }

  final defaultPinTheme = PinTheme(
    width: 68,
    height: 72,
    textStyle: const TextStyle(
      fontSize: 22,
      fontFamily: AppTheme.fontFamily,
      color: Colors.black,
      fontWeight: FontWeight.normal,
    ),
    decoration: BoxDecoration(
      border: Border.all(
        color: AppTheme.gray.withOpacity(0.6),
        width: 2,
      ),
      borderRadius: BorderRadius.circular(20),
    ),
  );

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (t) {
        if (!mounted) {
          t.cancel();
          return;
        }
        setState(() {
          timer--;
          if (timer <= 0) {
            timer = 0;
            t.cancel();
          }
        });
      },
    );
  }

  Future<void> _resendCode() async {
    setState(() => _isLoading = true);
    final response = await _repository.fetchSendResetCode(widget.phone);
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (response.isSuccess) {
      showResponsePopup(
        context,
        status: 'success',
        message: translate('auth.code_resent'),
      );
      setState(() => timer = 120);
      _startTimer();
    } else {
      CenterDialog.showActionFailed(
        context,
        translate('auth.resend_failed'),
        response.status == -1
            ? translate('auth.connection_failed_msg')
            : translate('auth.failed_msg'),
      );
    }
  }

  void _submit() {
    final pin = _pinPutController.text.trim();
    if (pin.length != 6) {
      CenterDialog.showActionFailed(
        context,
        translate('auth.error'),
        translate('auth.pin_incorrect'),
      );
      return;
    }
    // Navigate to the new-password form, passing phone + code.
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ResetPasswordScreen(
          phone: widget.phone,
          verificationCode: pin,
          onSuccess: widget.onSuccess,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leadingWidth: 60,
        leading: const LeadingBack(),
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: ListView(
              padding: const EdgeInsets.only(
                left: 24,
                right: 24,
                top: 22,
                bottom: 32,
              ),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text14h500w(
                        title:
                            '${translate("auth.enter_reset_code")} (${widget.phone})',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                if (timer > 0)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '$timer s.',
                        style: const TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 22,
                          fontWeight: FontWeight.normal,
                          height: 1.8,
                          color: AppTheme.gray,
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 40),
                Pinput(
                  length: 6,
                  controller: _pinPutController,
                  defaultPinTheme: defaultPinTheme,
                  focusedPinTheme: defaultPinTheme.copyDecorationWith(
                    border: Border.all(
                      color: AppTheme.purple,
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  submittedPinTheme: defaultPinTheme,
                  onSubmitted: (_) => _submit(),
                  focusNode: _pinPutFocusNode,
                  pinputAutovalidateMode: PinputAutovalidateMode.onSubmit,
                  showCursor: true,
                  onCompleted: (_) {},
                ),
                if (timer == 0)
                  Column(
                    children: [
                      const SizedBox(height: 32),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text16h500w(
                            title: translate('auth.no_code'),
                            color: AppTheme.black,
                          ),
                          GestureDetector(
                            onTap: _resendCode,
                            child: Text16h500w(
                              title: translate('auth.send_again'),
                              color: AppTheme.purple,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
              ],
            ),
          ),
          Column(
            children: [
              const Spacer(),
              Row(
                children: [
                  const SizedBox(width: 24),
                  Expanded(
                    child: SecondaryButton(
                      title: translate('auth.verify'),
                      onTap: _submit,
                    ),
                  ),
                  const SizedBox(width: 24),
                ],
              ),
              SizedBox(height: (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) ? 24 : 32),
            ],
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
    );
  }
}
