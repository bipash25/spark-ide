import 'package:flutter/material.dart';

/// Core color constants for Spark IDE
class AppColors {
  AppColors._();

  // Brand colors
  static const sparkBlue = Color(0xFF89B4FA);
  static const sparkPurple = Color(0xFFCBA6F7);
  static const sparkGreen = Color(0xFFA6E3A1);
  static const sparkOrange = Color(0xFFFAB387);
  static const sparkRed = Color(0xFFF38BA8);
  static const sparkYellow = Color(0xFFF9E2AF);
  static const sparkPink = Color(0xFFF5C2E7);
  static const sparkTeal = Color(0xFF89DCEB);
}

/// Sizing constants
class AppSizes {
  AppSizes._();

  static const double sidebarMinWidth = 200.0;
  static const double sidebarMaxWidth = 500.0;
  static const double sidebarDefaultWidth = 260.0;
  static const double activityBarWidth = 48.0;
  static const double statusBarHeight = 24.0;
  static const double tabBarHeight = 36.0;
  static const double panelMinHeight = 100.0;
  static const double panelDefaultHeight = 200.0;
  static const double titleBarHeight = 32.0;

  static const double borderRadius = 6.0;
  static const double borderRadiusSm = 4.0;
  static const double borderRadiusLg = 8.0;

  static const double iconSize = 20.0;
  static const double iconSizeSm = 16.0;
  static const double iconSizeLg = 24.0;

  static const double fontSize = 13.0;
  static const double fontSizeSm = 11.0;
  static const double fontSizeLg = 14.0;
  static const double fontSizeEditor = 14.0;

  static const double spacing = 8.0;
  static const double spacingSm = 4.0;
  static const double spacingLg = 16.0;
  static const double spacingXl = 24.0;
}

/// Animation durations
class AppDurations {
  AppDurations._();

  static const fast = Duration(milliseconds: 100);
  static const normal = Duration(milliseconds: 200);
  static const slow = Duration(milliseconds: 300);
}
