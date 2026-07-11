import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';

/// A slide-to-confirm control: the user drags the thumb to the right edge to
/// trigger [onConfirmed]. Snaps back to the start if released before
/// reaching the threshold, and briefly parks at the end on success before
/// resetting.
class SlideToConfirmButton extends StatefulWidget {
  const SlideToConfirmButton({
    super.key,
    required this.label,
    required this.onConfirmed,
    this.icon = Icons.navigation_rounded,
    this.height = 56,
  });

  final String label;
  final VoidCallback onConfirmed;
  final IconData icon;
  final double height;

  @override
  State<SlideToConfirmButton> createState() => _SlideToConfirmButtonState();
}

class _SlideToConfirmButtonState extends State<SlideToConfirmButton>
    with SingleTickerProviderStateMixin {
  double _dragX = 0;
  double _trackWidth = 0;

  late final AnimationController _snapController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  );
  Animation<double> _snapAnimation = const AlwaysStoppedAnimation(0);

  double get _maxDrag => (_trackWidth - widget.height).clamp(0, double.infinity);

  void _onDragUpdate(DragUpdateDetails details) {
    setState(() {
      _dragX = (_dragX + details.delta.dx).clamp(0, _maxDrag);
    });
  }

  void _onDragEnd(DragEndDetails details) {
    if (_maxDrag > 0 && _dragX >= _maxDrag * 0.7) {
      _animateTo(_maxDrag);
      widget.onConfirmed();
      Future.delayed(const Duration(milliseconds: 450), () {
        if (mounted) _animateTo(0);
      });
    } else {
      _animateTo(0);
    }
  }

  void _animateTo(double target) {
    _snapAnimation = Tween<double>(begin: _dragX, end: target).animate(
      CurvedAnimation(parent: _snapController, curve: Curves.easeOut),
    )..addListener(() => setState(() => _dragX = _snapAnimation.value));
    _snapController.forward(from: 0);
  }

  @override
  void dispose() {
    _snapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _trackWidth = constraints.maxWidth;
        final progress = _maxDrag == 0 ? 0.0 : (_dragX / _maxDrag).clamp(0.0, 1.0);
        return Container(
          height: widget.height,
          decoration: BoxDecoration(
            color: Color.lerp(
              AppTheme.purple.withValues(alpha: 0.08),
              AppTheme.purple.withValues(alpha: 0.22),
              progress,
            ),
            borderRadius: BorderRadius.circular(widget.height / 2),
            border: Border.all(color: AppTheme.purple.withValues(alpha: 0.25)),
          ),
          child: Stack(
            alignment: Alignment.centerLeft,
            children: [
              Positioned.fill(
                child: Center(
                  child: Opacity(
                    opacity: 1 - progress,
                    child: Text(
                      widget.label,
                      style: const TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.purple,
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: _dragX,
                child: GestureDetector(
                  onHorizontalDragUpdate: _onDragUpdate,
                  onHorizontalDragEnd: _onDragEnd,
                  child: Container(
                    height: widget.height,
                    width: widget.height,
                    decoration: BoxDecoration(
                      color: AppTheme.purple,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.purple.withValues(alpha: 0.35),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Icon(widget.icon, color: Colors.white, size: 22),
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
