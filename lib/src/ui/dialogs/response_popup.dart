import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

void showResponsePopup(BuildContext context, {
  required String status,
  required String message,
}) {
  final overlay = Overlay.of(context);
  final overlayEntry = OverlayEntry(
    builder: (context) => _ResponsePopupWidget(
      status: status,
      message: message,
    ),
  );

  overlay.insert(overlayEntry);

  Future.delayed(const Duration(seconds: 3), () {
    overlayEntry.remove();
  });
}

class _ResponsePopupWidget extends StatefulWidget {
  final String status;
  final String message;

  const _ResponsePopupWidget({
    required this.status,
    required this.message,
  });

  @override
  State<_ResponsePopupWidget> createState() => _ResponsePopupWidgetState();
}

class _ResponsePopupWidgetState extends State<_ResponsePopupWidget> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isSuccess = widget.status == 'success';
    final mainColor = isSuccess ? AppTheme.green : AppTheme.red;
    final backgroundColor = mainColor;
    final textColor = Colors.white;
    final icon = isSuccess ? Icons.check_circle_outline : Icons.error_outline;

    return Positioned(
      top: 76,
      left: 32,
      right: 32,
      child: Material(
        color: Colors.transparent,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: backgroundColor,
                border: Border.all(color: mainColor),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: mainColor.withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(icon, color: textColor, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.message,
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
