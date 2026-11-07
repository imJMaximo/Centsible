import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Brand palette lifted from the Centsible prototype.
abstract final class Brand {
  static const primary = Color(0xFF0E6B58);
  static const primaryDeep = Color(0xFF0A4F41);
  static const primarySoft = Color(0xFFCFE6DE);
  static const ground = Color(0xFFF4F6F5);
  static const ink = Color(0xFF10201B);
  static const muted = Color(0xFF56635E);
  static const border = Color(0xFFC9D3CF);
  static const divider = Color(0xFFE1E7E4);
}

/// Semantic colours the M3 scheme has no slot for (income, expense, pending…).
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.income,
    required this.incomeBg,
    required this.expense,
    required this.expenseBg,
    required this.expenseBar,
    required this.pending,
    required this.pendingBg,
    required this.info,
    required this.infoBg,
    required this.card,
    required this.surfaceMuted,
    required this.muted,
    required this.border,
    required this.selected,
    required this.selectedBg,
  });

  final Color income, incomeBg, expense, expenseBg, expenseBar;
  final Color pending, pendingBg, info, infoBg, card;
  final Color surfaceMuted, muted, border, selected, selectedBg;

  static const light = AppColors(
    income: Color(0xFF0E6B58),
    incomeBg: Color(0xFFE3F1EC),
    expense: Color(0xFFA8432A),
    expenseBg: Color(0xFFFBEBE5),
    expenseBar: Color(0xFFC2603F),
    pending: Color(0xFF5C4310),
    pendingBg: Color(0xFFFFF4DE),
    info: Color(0xFF1E3F78),
    infoBg: Color(0xFFEDF2FB),
    card: Color(0xFF2457A6),
    surfaceMuted: Color(0xFFEEF2F0),
    muted: Brand.muted,
    border: Brand.border,
    selected: Brand.primaryDeep,
    selectedBg: Brand.primarySoft,
  );

  static const dark = AppColors(
    income: Color(0xFF6FD3B8),
    incomeBg: Color(0xFF173A31),
    expense: Color(0xFFF2A48C),
    expenseBg: Color(0xFF41241C),
    expenseBar: Color(0xFFE08868),
    pending: Color(0xFFF3D39A),
    pendingBg: Color(0xFF3A2E14),
    info: Color(0xFFAFC6F2),
    infoBg: Color(0xFF1C2A42),
    card: Color(0xFF7FA6EA),
    surfaceMuted: Color(0xFF243330),
    muted: Color(0xFFA5B3AE),
    border: Color(0xFF3A4A45),
    selected: Color(0xFFBFEBDD),
    selectedBg: Color(0xFF1D4A3F),
  );

  @override
  AppColors copyWith() => this;

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) =>
      t < 0.5 ? this : (other as AppColors? ?? this);
}

extension AppThemeX on BuildContext {
  AppColors get colors => Theme.of(this).extension<AppColors>()!;
  ColorScheme get scheme => Theme.of(this).colorScheme;
  TextTheme get text => Theme.of(this).textTheme;
}

/// Display face for figures and the wordmark.
TextStyle figureStyle(double size, {Color? color, FontWeight weight = FontWeight.w700}) =>
    GoogleFonts.spaceGrotesk(fontSize: size, fontWeight: weight, color: color, letterSpacing: -0.5);

ThemeData buildTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final scheme = dark
      ? const ColorScheme.dark(
          primary: Color(0xFF6FD3B8),
          onPrimary: Color(0xFF00382D),
          primaryContainer: Color(0xFF1D4A3F),
          onPrimaryContainer: Color(0xFFBFEBDD),
          secondaryContainer: Color(0xFF1D4A3F),
          onSecondaryContainer: Color(0xFFBFEBDD),
          surface: Color(0xFF1A2623),
          onSurface: Color(0xFFE3ECE9),
          surfaceContainerLowest: Color(0xFF111A18),
          surfaceContainerHighest: Color(0xFF2A3935),
          outline: Color(0xFF3A4A45),
          outlineVariant: Color(0xFF2A3935),
          error: Color(0xFFF2A48C),
          inverseSurface: Color(0xFFE3ECE9),
          onInverseSurface: Color(0xFF10201B),
        )
      : const ColorScheme.light(
          primary: Brand.primary,
          onPrimary: Colors.white,
          primaryContainer: Brand.primarySoft,
          onPrimaryContainer: Brand.primaryDeep,
          secondaryContainer: Brand.primarySoft,
          onSecondaryContainer: Brand.primaryDeep,
          surface: Colors.white,
          onSurface: Brand.ink,
          surfaceContainerLowest: Brand.ground,
          surfaceContainerHighest: Color(0xFFEEF2F0),
          outline: Brand.border,
          outlineVariant: Brand.divider,
          error: Color(0xFFA8432A),
          inverseSurface: Brand.ink,
          onInverseSurface: Colors.white,
        );

  final base = ThemeData(useMaterial3: true, colorScheme: scheme, brightness: brightness);
  final textTheme = GoogleFonts.plusJakartaSansTextTheme(base.textTheme).apply(
    bodyColor: scheme.onSurface,
    displayColor: scheme.onSurface,
  );

  final pill = RoundedRectangleBorder(borderRadius: BorderRadius.circular(999));
  return base.copyWith(
    scaffoldBackgroundColor: scheme.surfaceContainerLowest,
    textTheme: textTheme,
    extensions: [dark ? AppColors.dark : AppColors.light],
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surfaceContainerLowest,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        shape: pill,
        textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700, fontSize: 15),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        shape: pill,
        foregroundColor: scheme.onSurface,
        side: BorderSide(color: scheme.outline),
        textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700, fontSize: 15),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(44, 44),
        textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: scheme.outline)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: scheme.outline)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: scheme.primary, width: 2)),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: scheme.inverseSurface,
      contentTextStyle: textTheme.bodyMedium?.copyWith(color: scheme.onInverseSurface, fontWeight: FontWeight.w600),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
    dividerTheme: DividerThemeData(color: scheme.outlineVariant, space: 1, thickness: 1),
    switchTheme: SwitchThemeData(
      trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
    ),
  );
}
