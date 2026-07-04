import 'package:flutter/material.dart';

class AppColor {
  const AppColor._();

  // Spotify-inspired dark surfaces: achromatic, near-black, content-first.
  static const bgBase = Color(0xFF121212);
  static const bgDeep = Color(0xFF000000);
  static const glowViolet = Color(0xFF1F1F1F);
  static const glowCyan = Color(0xFF252525);
  static const glassTint = Color(0xFF181818);

  // BMW-inspired light surfaces: clean white/gray canvas with blue CTAs.
  static const paperBase = Color(0xFFFFFFFF);
  static const paperWarm = Color(0xFFF7F7F7);
  static const paperCool = Color(0xFFEBEBEB);
  static const paperFiber = Color(0x00FFFFFF);
  static const paperGlassTint = Color(0xFFFAFAFA);
  static const paperStrokeHairline = Color(0xFFE6E6E6);
  static const paperSheenTop = Color(0xFFFFFFFF);
  static const paperShadow = Color(0x14000000);
  static const paperInk = Color(0xFF262626);
  static const paperMuted = Color(0xFF6B6B6B);
  static const paperFaint = Color(0xFF9A9A9A);
  static const paperAccentContainer = Color(0xFFE8F1FC);
  static const paperOnAccentContainer = Color(0xFF123B71);

  // Glass borders and highlights.
  static const strokeHairline = Color(0x1FFFFFFF);
  static const strokeStrong = Color(0x2EFFFFFF);
  static const sheenTop = Color(0x1AFFFFFF);

  // Brand accents from awesome-design-md references.
  static const spotifyGreen = Color(0xFF1ED760);
  static const spotifyGreenPressed = Color(0xFF1DB954);
  static const bmwBlue = Color(0xFF1C69D4);
  static const bmwBlueActive = Color(0xFF0653B6);

  // Compatibility names used by existing widgets. Primary transport controls
  // stay Spotify green; light-theme navigation and settings use BMW blue via
  // ColorScheme.
  static const accentSteelStart = spotifyGreen;
  static const accentPlatinumEnd = spotifyGreenPressed;
  static const accentVioletStart = accentSteelStart;
  static const accentRoseEnd = accentPlatinumEnd;
  static const carlife = Color(0xFF539DF5);

  // Neutral fills.
  static const fillNeutral = Color(0x12FFFFFF);
  static const fillNeutralHover = Color(0x1FFFFFFF);
  static const progressTrack = Color(0x1FFFFFFF);
  static const disabledWhite = Color(0x66FFFFFF);
  static const scrimStrong = Color(0xB3000000);

  // Text colors.
  static const textPrimary = Color(0xFFFFFFFF);
  static const textSecondary = Color(0xFFB3B3B3);
  static const textTertiary = Color(0xFF7C7C7C);
  static const error = Color(0xFFF3727F);

  // Neutral material colors for the turntable artwork.
  static const vinylBase = Color(0xFF090A0E);
  static const vinylHead = Color(0xFF1C1C1E);
  static const vinylJoint = Color(0xFF48484A);
  static const vinylMetalDark = Color(0xFF3A3A3C);
  static const vinylMetalMid = Color(0xFF8E8E93);
  static const vinylMetalLight = Color(0xFFD1D1D6);
  static const vinylMetalHighlight = Color(0xFFE5E5EA);

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
