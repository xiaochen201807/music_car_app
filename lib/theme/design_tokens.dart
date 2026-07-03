import 'package:flutter/material.dart';

class AppColor {
  const AppColor._();

  // Base atmosphere colors.
  static const bgBase = Color(0xFF0A0D12);
  static const bgDeep = Color(0xFF030507);
  static const glowViolet = Color(0xFF263647);
  static const glowCyan = Color(0xFF365167);
  static const glassTint = Color(0xFF111820);

  // Light paper theme colors.
  static const paperBase = Color(0xFFF7F5EF);
  static const paperWarm = Color(0xFFFFFDF8);
  static const paperCool = Color(0xFFEFF1EA);
  static const paperFiber = Color(0x168A806F);
  static const paperGlassTint = Color(0xFFFFFCF4);
  static const paperStrokeHairline = Color(0x2E7C735F);
  static const paperSheenTop = Color(0xD9FFFFFF);
  static const paperShadow = Color(0x184C4639);
  static const paperInk = Color(0xFF25231E);
  static const paperMuted = Color(0xFF686154);
  static const paperFaint = Color(0xFF8D8678);
  static const paperAccentContainer = Color(0xFFEDE7D8);
  static const paperOnAccentContainer = Color(0xFF3D382F);

  // Glass borders and highlights.
  static const strokeHairline = Color(0x1FFFFFFF);
  static const strokeStrong = Color(0x2EFFFFFF);
  static const sheenTop = Color(0x1AFFFFFF);

  // Restricted accent colors. Kept cool and low-saturation for a premium
  // automotive feel instead of the previous AI-style violet/rose palette.
  static const accentSteelStart = Color(0xFF5E7FA4);
  static const accentPlatinumEnd = Color(0xFFB8C2CC);
  static const accentVioletStart = accentSteelStart;
  static const accentRoseEnd = accentPlatinumEnd;
  static const carlife = Color(0xFF3D6F9F);

  // Neutral fills.
  static const fillNeutral = Color(0x12FFFFFF);
  static const fillNeutralHover = Color(0x1FFFFFFF);
  static const progressTrack = Color(0x1FFFFFFF);
  static const disabledWhite = Color(0x66FFFFFF);
  static const scrimStrong = Color(0xB3000000);

  // Text colors.
  static const textPrimary = Color(0xFFF0F3F5);
  static const textSecondary = Color(0xFFADB7C0);
  static const textTertiary = Color(0xFF6F7B85);
  static const error = Color(0xFFD25B61);

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
    color: Color(0x66000000),
    blurRadius: 34,
    offset: Offset(0, 18),
  );

  static BoxShadow get controlPrimary => BoxShadow(
    color: AppColor.accentVioletStart.withValues(alpha: 0.22),
    blurRadius: 18,
    offset: const Offset(0, 8),
  );
}

class AppGlass {
  const AppGlass._();

  static const tintAlpha = 0.48;
  static const glowVioletAlpha = 0.30;
  static const glowCyanAlpha = 0.16;
  static const ribbonWhiteAlpha = 0.10;
  static const ribbonVioletAlpha = 0.08;
  static const carlifeAlpha = 0.18;
  static const artworkShadowAlpha = 0.20;
}
