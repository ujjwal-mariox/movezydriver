/// The app's icon size ladder.
///
/// Icon sizes were written by hand at every call site, so the same glyph in
/// the same role rendered at 12/13/14/15 or 17/18/19/21 depending on the
/// screen — 27 distinct values across the app, several of them 1px apart and
/// visibly inconsistent side by side.
///
/// Every explicit `Icon(size:)` now sits on this ladder. Use these constants
/// for new work instead of a raw number; if a size here doesn't fit, the right
/// move is to discuss the rung, not to invent a value.
///
/// (Sizes below 12 are deliberately off the ladder: route bullets and status
/// dots at 6-9px are micro-glyphs, and rounding them up would double them.)
abstract final class AppIconSize {
  /// Inline with body text — trailing chevrons, small affordances.
  static const double xs = 12;
  static const double sm = 14;

  /// Default for list rows, app-bar actions, address rows.
  static const double md = 16;
  static const double lg = 18;
  static const double xl = 20;

  /// Primary row icons and section markers.
  static const double xxl = 22;
  static const double xxxl = 24;

  /// Feature and section headers.
  static const double header = 28;
  static const double headerLg = 32;

  /// Empty states and hero illustrations.
  static const double display = 40;
  static const double displayLg = 48;
  static const double hero = 56;
  static const double heroLg = 64;
}
