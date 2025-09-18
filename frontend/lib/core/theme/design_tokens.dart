import 'package:flutter/material.dart';

class Spacing {
  static const double xs = 4;
  static const double s = 8;
  static const double m = 12;
  static const double l = 16;
  static const double xl = 24;
  static const double x2 = 32;
  static const double x3 = 48;
}

class Radii {
  static const Radius sm = Radius.circular(6);
  static const Radius md = Radius.circular(12);
  static const Radius lg = Radius.circular(20);
  static const BorderRadius brSm = BorderRadius.all(sm);
  static const BorderRadius brMd = BorderRadius.all(md);
  static const BorderRadius brLg = BorderRadius.all(lg);
}

class DurationsT {
  static const fast = Duration(milliseconds: 120);
  static const medium = Duration(milliseconds: 220);
  static const slow = Duration(milliseconds: 400);
}

class Elevations {
  static const double level0 = 0;
  static const double level1 = 1;
  static const double level2 = 3;
  static const double level3 = 6;
}

class Breakpoints {
  static const double mobile = 600;
  static const double tablet = 1024;
  static const double desktop = 1440;
}

class Layout {
  static const double maxContentWidth = 1320;
}

class Shadows {
  static List<BoxShadow> subtle = [
    BoxShadow(
      blurRadius: 16,
      spreadRadius: -4,
      offset: const Offset(0, 6),
      color: Colors.black.withOpacity(.07),
    ),
  ];
}