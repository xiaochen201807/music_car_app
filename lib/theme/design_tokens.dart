import 'package:flutter/material.dart';

class AppColor {
  const AppColor._();

  // Base atmosphere colors.
  static const bgBase = Color(0xFF0B1020);
  static const bgDeep = Color(0xFF04060D);
  static const glowViolet = Color(0xFF5B4B8A);
  static const glowCyan = Color(0xFF2E6F9E);
  static const glassTint = Color(0xFF0E1426);

  // Glass borders and highlights.
  static const strokeHairline = Color(0x1FFFFFFF);
  static const strokeStrong = Color(0x2EFFFFFF);
  static const sheenTop = Color(0x1AFFFFFF);

  // Restricted accent colors.
  static const accentVioletStart = Color(0xFF7C5CFF);
  static const accentRoseEnd = Color(0xFFFF5C9E);
  static const carlife = Color(0xFF2D7DFF);

  // Neutral fills.
  static const fillNeutral = Color(0x14FFFFFF);
  static const fillNeutralHover = Color(0x24FFFFFF);
  static const progressTrack = Color(0x1FFFFFFF);
  static const disabledWhite = Color(0x66FFFFFF);
  static const scrimStrong = Color(0xB3000000);

  // Text colors.
  static const textPrimary = Color(0xFFF4F6FB);
  static const textSecondary = Color(0xFFAEB6C8);
  static const textTertiary = Color(0xFF6E7891);
  static const error = Color(0xFFFF5A5F);

  static const accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[accentVioletStart, accentRoseEnd],
  );
}

class AppSpace {
  const AppSpace._();

  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 20.0;
  static const xl2 = 24.0;
  static const xl3 = 32.0;
  static const xl4 = 40.0;

  static const screen = xl2;
  static const cardPadding = xl;
  static const gap = lg;
}

class AppRadius {
  const AppRadius._();

  static const pill = 999.0;
  static const panel = 28.0;
  static const card = 22.0;
  static const tile = 16.0;
  static const control = 14.0;
}

class AppType {
  const AppType._();

  static const display = TextStyle(
    fontSize: 40,
    fontWeight: FontWeight.w800,
    color: AppColor.textPrimary,
    height: 1.2,
  );
  static const h1 = TextStyle(
    fontSize: 30,
    fontWeight: FontWeight.w800,
    color: AppColor.textPrimary,
    height: 1.2,
  );
  static const h2 = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w700,
    color: AppColor.textPrimary,
    height: 1.2,
  );
  static const cardTitle = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w700,
    color: AppColor.textPrimary,
    height: 1.2,
  );
  static const body = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w500,
    color: AppColor.textPrimary,
    height: 1.2,
  );
  static const caption = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    color: AppColor.textSecondary,
    height: 1.2,
  );
  static const micro = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    color: AppColor.textTertiary,
    height: 1.2,
  );
}

class AppShadow {
  const AppShadow._();

  static const card = BoxShadow(
    color: Color(0x59000000),
    blurRadius: 40,
    offset: Offset(0, 20),
  );

  static BoxShadow get controlPrimary => BoxShadow(
    color: AppColor.accentVioletStart.withValues(alpha: 0.30),
    blurRadius: 24,
    offset: const Offset(0, 10),
  );
}

class AppGlass {
  const AppGlass._();

  static const tintAlpha = 0.35;
  static const glowVioletAlpha = 0.42;
  static const glowCyanAlpha = 0.22;
  static const ribbonWhiteAlpha = 0.10;
  static const ribbonVioletAlpha = 0.14;
  static const carlifeAlpha = 0.24;
  static const artworkShadowAlpha = 0.24;
}
