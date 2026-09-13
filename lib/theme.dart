// lib/theme.dart
// ستايل التطبيق العام: ألوان، تدرجات، نصوص.
// مستوحى من نفس روح التصميم المرجعي (كحلي/بنفسجي غامق) بس بتصميمنا الخاص.

import 'package:flutter/material.dart';

class AppColors {
  // خلفية التطبيق (تدرج غامق)
  static const bgTop = Color(0xFF0F0257);
  static const bgDeep = Color(0xFF050516);
  static const bgMid = Color(0xFF0F0A3E);

  // بطاقات وعناصر زجاجية شفافة
  static const glass = Color(0x59071064); // rgba(7,16,100,0.35)
  static const glassBorder = Color(0x592A21A8); // rgba(42,33,168,0.35)

  // نصوص
  static const textPrimary = Color(0xFFF3F4F6);
  static const textMuted = Color(0xFFB0A8FF);

  // ألوان الحالة
  static const green = Color(0xFF4ADE80);
  static const red = Color(0xFFF87171);
  static const blueAccent = Color(0xFF60A5FA);
  static const purple = Color(0xFF818CF8);
  static const cyan = Color(0xFF22D3EE);

  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [bgTop, bgDeep, bgMid],
    stops: [0.0, 0.46, 1.0],
  );

  static const LinearGradient connectButtonGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [blueAccent, Color(0xFF2B05D5), Color(0xFF001482)],
  );
}

class AppTextStyles {
  static const title = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 20,
    fontWeight: FontWeight.bold,
  );

  static const label = TextStyle(
    color: AppColors.textMuted,
    fontSize: 12,
    letterSpacing: 0.4,
  );

  static const value = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 28,
    fontWeight: FontWeight.bold,
    letterSpacing: 1,
  );

  static const pill = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 14,
    fontWeight: FontWeight.w700,
  );
}

/// بطاقة زجاجية (Glassmorphism) بتستخدم بكل مكان بالتصميم
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;

  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.radius = 18,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.glass,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: AppColors.glassBorder, width: 1),
      ),
      child: child,
    );
  }
}
