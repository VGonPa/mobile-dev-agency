# Mobile Visual Design — Reference

Implementation tokens and Flutter code for the design decisions in [SKILL.md](SKILL.md).

---

## Spacing Tokens (Flutter)

```dart
abstract class AppSpacing {
  static const double xs  = 4.0;
  static const double sm  = 8.0;
  static const double md  = 16.0;
  static const double lg  = 24.0;
  static const double xl  = 32.0;
  static const double xxl = 48.0;
  static const double xxxl = 64.0;

  /// Consistent screen-edge padding
  static const EdgeInsets screenPadding = EdgeInsets.symmetric(
    horizontal: md,
    vertical: lg,
  );

  /// Standard card internal padding
  static const EdgeInsets cardPadding = EdgeInsets.all(md);

  /// Tight list item padding
  static const EdgeInsets listItemPadding = EdgeInsets.symmetric(
    horizontal: md,
    vertical: sm,
  );

  /// Gap between cards in a list
  static const double cardGap = md;

  /// Section separator gap
  static const double sectionGap = xl;
}
```

**Usage:**
```dart
Padding(
  padding: AppSpacing.screenPadding,
  child: Column(
    children: [
      HeaderWidget(),
      SizedBox(height: AppSpacing.sectionGap),
      CardWidget(),
      SizedBox(height: AppSpacing.cardGap),
      CardWidget(),
    ],
  ),
)
```

---

## Font Pairing Implementation

### Google Fonts Setup

```yaml
# pubspec.yaml
dependencies:
  google_fonts: ^6.0.0
```

### TextTheme Factory

```dart
import 'package:google_fonts/google_fonts.dart';

/// Creates a complete TextTheme from a heading + body font pairing.
///
/// Personality pairings (see SKILL.md Section 2):
///   Editorial:   heading: 'Playfair Display', body: 'Source Sans 3'
///   Tech:        heading: 'Space Grotesk',    body: 'Inter'
///   Friendly:    heading: 'Sora',             body: 'DM Sans'
///   Athletic:    heading: 'Plus Jakarta Sans', body: 'Outfit'
///   Minimal:     heading: 'Cormorant Garamond', body: 'Nunito Sans'
TextTheme buildTextTheme({
  required String headingFamily,
  required String bodyFamily,
}) {
  final heading = GoogleFonts.getTextTheme(headingFamily);
  final body = GoogleFonts.getTextTheme(bodyFamily);

  return TextTheme(
    // Display
    displayLarge:  heading.displayLarge!.copyWith(fontSize: 34, fontWeight: FontWeight.w700, height: 1.1),
    displayMedium: heading.displayMedium!.copyWith(fontSize: 28, fontWeight: FontWeight.w700, height: 1.15),

    // Headings
    headlineLarge:  heading.headlineLarge!.copyWith(fontSize: 22, fontWeight: FontWeight.w600, height: 1.2),
    headlineMedium: heading.headlineMedium!.copyWith(fontSize: 18, fontWeight: FontWeight.w500, height: 1.25),

    // Body
    bodyLarge:  body.bodyLarge!.copyWith(fontSize: 16, fontWeight: FontWeight.w400, height: 1.5),
    bodyMedium: body.bodyMedium!.copyWith(fontSize: 14, fontWeight: FontWeight.w400, height: 1.4),

    // Caption / Overline
    bodySmall:    body.bodySmall!.copyWith(fontSize: 12, fontWeight: FontWeight.w400, height: 1.4),
    labelSmall:   body.labelSmall!.copyWith(fontSize: 11, fontWeight: FontWeight.w500, height: 1.5, letterSpacing: 1.2),
  );
}
```

### Example: Athletic Personality

```dart
final athleticTheme = buildTextTheme(
  headingFamily: 'Plus Jakarta Sans',
  bodyFamily: 'Outfit',
);

// Apply to MaterialApp
MaterialApp(
  theme: ThemeData(
    textTheme: athleticTheme,
  ),
)
```

---

## Color System Implementation

### Seed-Based Generation (Material 3)

```dart
// Minimal: just provide the seed color
final lightScheme = ColorScheme.fromSeed(
  seedColor: const Color(0xFF1A73E8), // your brand primary
  brightness: Brightness.light,
);

final darkScheme = ColorScheme.fromSeed(
  seedColor: const Color(0xFF1A73E8),
  brightness: Brightness.dark,
);
```

### Custom Overrides for Brand Precision

`ColorScheme.fromSeed` generates harmonious palettes but may not match exact brand specs. Override specific roles:

```dart
final brandLight = ColorScheme.fromSeed(
  seedColor: const Color(0xFFFF6B35), // energetic orange for fitness
  brightness: Brightness.light,
).copyWith(
  // Override where brand precision matters
  primary: const Color(0xFFFF6B35),
  onPrimary: Colors.white,
  error: const Color(0xFFDC2626),
  // Let .fromSeed handle the rest (surfaces, containers, outlines)
);
```

### Semantic Extension Colors

For roles Material 3 doesn't cover natively (success, warning):

```dart
@immutable
class AppSemanticColors extends ThemeExtension<AppSemanticColors> {
  final Color success;
  final Color onSuccess;
  final Color successContainer;
  final Color warning;
  final Color onWarning;
  final Color warningContainer;

  const AppSemanticColors({
    required this.success,
    required this.onSuccess,
    required this.successContainer,
    required this.warning,
    required this.onWarning,
    required this.warningContainer,
  });

  // Light theme defaults
  static const light = AppSemanticColors(
    success: Color(0xFF16A34A),
    onSuccess: Colors.white,
    successContainer: Color(0xFFDCFCE7),
    warning: Color(0xFFD97706),
    onWarning: Colors.white,
    warningContainer: Color(0xFFFEF3C7),
  );

  // Dark theme defaults (desaturated 15-20%)
  static const dark = AppSemanticColors(
    success: Color(0xFF4ADE80),
    onSuccess: Color(0xFF121212),
    successContainer: Color(0xFF1A3A2A),
    warning: Color(0xFFFBBF24),
    onWarning: Color(0xFF121212),
    warningContainer: Color(0xFF3D2E0A),
  );

  @override
  AppSemanticColors copyWith({ /* ... */ }) => AppSemanticColors(/* ... */);

  @override
  AppSemanticColors lerp(AppSemanticColors? other, double t) {
    if (other is! AppSemanticColors) return this;
    return AppSemanticColors(
      success: Color.lerp(success, other.success, t)!,
      onSuccess: Color.lerp(onSuccess, other.onSuccess, t)!,
      successContainer: Color.lerp(successContainer, other.successContainer, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      onWarning: Color.lerp(onWarning, other.onWarning, t)!,
      warningContainer: Color.lerp(warningContainer, other.warningContainer, t)!,
    );
  }
}

// Register in ThemeData
ThemeData(
  colorScheme: brandLight,
  extensions: const [AppSemanticColors.light],
)

// Access in widgets
final semantic = Theme.of(context).extension<AppSemanticColors>()!;
Container(color: semantic.success)
```

---

## Border Radius Tokens (Flutter)

```dart
abstract class AppRadius {
  static const double sm   = 4.0;
  static const double md   = 8.0;
  static const double lg   = 16.0;
  static const double xl   = 24.0;
  static const double full = 9999.0;

  static final BorderRadius smAll   = BorderRadius.circular(sm);
  static final BorderRadius mdAll   = BorderRadius.circular(md);
  static final BorderRadius lgAll   = BorderRadius.circular(lg);
  static final BorderRadius xlAll   = BorderRadius.circular(xl);
  static final BorderRadius fullAll = BorderRadius.circular(full);
}
```

---

## Elevation Tokens (Flutter)

```dart
abstract class AppElevation {
  /// Level 0: No shadow (flat on surface)
  static const List<BoxShadow> level0 = [];

  /// Level 1: Subtle lift (cards, list items)
  static const List<BoxShadow> level1 = [
    BoxShadow(
      blurRadius: 2,
      offset: Offset(0, 1),
      color: Color(0x14000000), // black 8%
    ),
    BoxShadow(
      blurRadius: 6,
      offset: Offset(0, 2),
      color: Color(0x0A000000), // black 4%
    ),
  ];

  /// Level 2: Floating interactive (raised buttons, active cards)
  static const List<BoxShadow> level2 = [
    BoxShadow(
      blurRadius: 3,
      offset: Offset(0, 1),
      color: Color(0x1A000000), // black 10%
    ),
    BoxShadow(
      blurRadius: 10,
      offset: Offset(0, 4),
      color: Color(0x0F000000), // black 6%
    ),
  ];

  /// Level 3: Overlay (dropdowns, tooltips)
  static const List<BoxShadow> level3 = [
    BoxShadow(
      blurRadius: 4,
      offset: Offset(0, 2),
      color: Color(0x1F000000), // black 12%
    ),
    BoxShadow(
      blurRadius: 16,
      offset: Offset(0, 8),
      color: Color(0x14000000), // black 8%
    ),
  ];

  /// Level 4: Sheet (bottom sheets, drawers)
  static const List<BoxShadow> level4 = [
    BoxShadow(
      blurRadius: 6,
      offset: Offset(0, 4),
      color: Color(0x24000000), // black 14%
    ),
    BoxShadow(
      blurRadius: 24,
      offset: Offset(0, 12),
      color: Color(0x1A000000), // black 10%
    ),
  ];

  /// Level 5: Modal (dialogs, critical overlays)
  static const List<BoxShadow> level5 = [
    BoxShadow(
      blurRadius: 8,
      offset: Offset(0, 6),
      color: Color(0x29000000), // black 16%
    ),
    BoxShadow(
      blurRadius: 32,
      offset: Offset(0, 16),
      color: Color(0x1F000000), // black 12%
    ),
  ];
}

// Usage
Container(
  decoration: BoxDecoration(
    color: Theme.of(context).colorScheme.surface,
    borderRadius: AppRadius.lgAll,
    boxShadow: AppElevation.level1,
  ),
)
```

---

## Dark Mode Implementation

### Theme Configuration

```dart
ThemeData buildTheme(Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  final colorScheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFFFF6B35),
    brightness: brightness,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: isDark
        ? const Color(0xFF121212)  // NOT pure black
        : colorScheme.surface,
    extensions: [
      isDark ? AppSemanticColors.dark : AppSemanticColors.light,
    ],
  );
}

// In MaterialApp
MaterialApp(
  theme: buildTheme(Brightness.light),
  darkTheme: buildTheme(Brightness.dark),
  themeMode: ThemeMode.system,
)
```

### Dark Mode Surface Tinting Helper

```dart
/// Returns progressively lighter surfaces for dark mode elevation.
/// In dark mode, higher = lighter (simulating light hitting raised surfaces).
Color elevatedSurface(BuildContext context, int level) {
  final scheme = Theme.of(context).colorScheme;
  if (scheme.brightness == Brightness.light) return scheme.surface;

  // Each level adds 5% white overlay
  final overlay = level.clamp(0, 5) * 0.05;
  return Color.lerp(
    const Color(0xFF121212),
    Colors.white,
    overlay,
  )!;
}

// Usage: surface for a level-2 card in dark mode
Container(color: elevatedSurface(context, 2)) // → #1E1E1E area
```

---

## Animation Tokens (Flutter)

### Duration Constants

```dart
abstract class AppDuration {
  static const Duration fast   = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 250);
  static const Duration slow   = Duration(milliseconds: 350);

  /// For loading skeletons and pulse animations
  static const Duration pulse  = Duration(milliseconds: 1500);
}
```

### Spring Configurations

```dart
abstract class AppSpring {
  /// Snappy — toggles, checkboxes, small interactions
  static const SpringDescription snappy = SpringDescription(
    mass: 1.0,
    stiffness: 400,
    damping: 22, // damping ratio ≈ 0.85
  );

  /// Standard — card transitions, tab switches
  static const SpringDescription standard = SpringDescription(
    mass: 1.0,
    stiffness: 300,
    damping: 20, // damping ratio ≈ 0.80
  );

  /// Bouncy — sheet reveals, celebrations, playful elements
  static const SpringDescription bouncy = SpringDescription(
    mass: 1.0,
    stiffness: 300,
    damping: 18, // damping ratio ≈ 0.70
  );
}

// Usage with SpringSimulation in AnimationController
final simulation = SpringSimulation(AppSpring.standard, 0, 1, 0);
controller.animateWith(simulation);
```

### Common Animation Curves

```dart
abstract class AppCurves {
  /// Default for most transitions
  static const Curve standard = Curves.easeOutCubic;

  /// Elements entering the screen
  static const Curve enter = Curves.easeOut;

  /// Elements leaving the screen (fast exit)
  static const Curve exit = Curves.easeIn;

  /// Emphasis — overshoot then settle
  static const Curve emphasis = Curves.easeOutBack;

  /// Skeleton loading pulse
  static const Curve pulse = Curves.easeInOut;
}
```

### Staggered List Animation Helper

```dart
/// Animates list items with staggered entrance.
/// Each item fades in and slides up with a 50ms delay from the previous.
class StaggeredListAnimation extends StatelessWidget {
  final int itemCount;
  final Widget Function(BuildContext, int, Animation<double>) itemBuilder;
  final Duration staggerDelay;

  const StaggeredListAnimation({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.staggerDelay = const Duration(milliseconds: 50),
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: itemCount,
      itemBuilder: (context, index) {
        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: AppDuration.normal,
          curve: AppCurves.enter,
          // Delay proportional to index
          builder: (context, value, child) {
            return Opacity(
              opacity: value,
              child: Transform.translate(
                offset: Offset(0, 16 * (1 - value)),
                child: itemBuilder(context, index, AlwaysStoppedAnimation(value)),
              ),
            );
          },
        );
      },
    );
  }
}
```

### Tactile Press Effect

```dart
/// Adds a press-down scale effect (2026 tactile UI trend).
/// Scale to 0.97 on press, spring back on release.
class TactilePressEffect extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;

  const TactilePressEffect({super.key, required this.child, this.onTap});

  @override
  State<TactilePressEffect> createState() => _TactilePressEffectState();
}

class _TactilePressEffectState extends State<TactilePressEffect>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppDuration.fast,
    );
    _scale = Tween<double>(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(parent: _controller, curve: AppCurves.standard),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        widget.onTap?.call();
      },
      onTapCancel: () => _controller.reverse(),
      child: ScaleTransition(scale: _scale, child: widget.child),
    );
  }
}
```
