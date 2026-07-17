import 'package:flutter/material.dart';

/// The parcel (package box) illustration, shown wherever a parcel is
/// represented across the app so the visual stays consistent.
class ParcelImage extends StatelessWidget {
  const ParcelImage({super.key, this.size = 22});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/package.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
    );
  }
}
