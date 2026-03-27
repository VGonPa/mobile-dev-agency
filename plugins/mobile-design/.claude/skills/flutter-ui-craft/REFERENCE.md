# Flutter UI Craft — Implementation Reference

Implementation templates for UI patterns described in [SKILL.md](SKILL.md). Every template here corresponds to a decision made in SKILL.md — don't implement without reading the design context first.

## Full Theme Setup

**Context:** SKILL.md Section 1 — M3 Theming with dynamic color and component overrides.

```dart
import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// Brand fallback when dynamic color is unavailable
const _brandSeed = Color(0xFF1B5E20);

ColorScheme _fallbackScheme(Brightness brightness) =>
    ColorScheme.fromSeed(seedColor: _brandSeed, brightness: brightness);

ThemeData _buildTheme(ColorScheme scheme) {
  final textTheme = GoogleFonts.interTextTheme(
    ThemeData(colorScheme: scheme).textTheme,
  );

  return ThemeData(
    // useMaterial3 is true by default since Flutter 3.16 — no need to set it
    colorScheme: scheme,
    textTheme: textTheme,
    // Component overrides
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        textStyle: textTheme.labelLarge,
      ),
    ),
    cardTheme: const CardThemeData(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.31),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    appBarTheme: AppBarTheme(
      centerTitle: false,
      scrolledUnderElevation: 1,
      backgroundColor: scheme.surface,
    ),
    // Register ThemeExtensions here
    extensions: const <ThemeExtension>[
      AppSpacing(),
      AppRadius(),
      AppElevations(),
    ],
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return DynamicColorBuilder(
      builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
        // Use dynamic color if available, fall back to brand seed
        final lightScheme = lightDynamic ?? _fallbackScheme(Brightness.light);
        final darkScheme = darkDynamic ?? _fallbackScheme(Brightness.dark);

        return MaterialApp(
          theme: _buildTheme(lightScheme),
          darkTheme: _buildTheme(darkScheme),
          themeMode: ThemeMode.system,
          home: const HomePage(),
        );
      },
    );
  }
}
```

**Dependency:** `dynamic_color: ^1.7.0` — provides `DynamicColorBuilder`. On Android 12+, extracts wallpaper colors. On other platforms, returns null (triggering fallback).

## Complete Token System

**Context:** SKILL.md Section 2 — Three-tier token hierarchy (primitive → semantic → component).

### Primitive Tokens (Raw Values)

```dart
/// Primitive tokens: raw palette values.
/// WHY a separate class: Isolates brand palette changes to one location.
/// Widgets NEVER reference these directly — only semantic tokens use them.
abstract final class PrimitiveTokens {
  // Brand palette
  static const green50 = Color(0xFFE8F5E9);
  static const green500 = Color(0xFF4CAF50);
  static const green900 = Color(0xFF1B5E20);

  // Neutral palette
  static const grey50 = Color(0xFFFAFAFA);
  static const grey100 = Color(0xFFF5F5F5);
  static const grey200 = Color(0xFFEEEEEE);
  static const grey800 = Color(0xFF424242);
  static const grey900 = Color(0xFF212121);

  // Spacing scale (4px grid)
  static const space4 = 4.0;
  static const space8 = 8.0;
  static const space12 = 12.0;
  static const space16 = 16.0;
  static const space24 = 24.0;
  static const space32 = 32.0;
  static const space48 = 48.0;

  // Radius scale
  static const radius4 = 4.0;
  static const radius8 = 8.0;
  static const radius12 = 12.0;
  static const radius16 = 16.0;
  static const radiusFull = 999.0;
}
```

### Semantic Tokens (ThemeExtensions)

```dart
import 'dart:ui';
import 'package:flutter/material.dart';

/// Spacing tokens — accessible via context.spacing
class AppSpacing extends ThemeExtension<AppSpacing> {
  final double xs;
  final double sm;
  final double md;
  final double lg;
  final double xl;
  final double xxl;

  const AppSpacing({
    this.xs = 4,
    this.sm = 8,
    this.md = 16,
    this.lg = 24,
    this.xl = 32,
    this.xxl = 48,
  });

  @override
  AppSpacing copyWith({
    double? xs, double? sm, double? md,
    double? lg, double? xl, double? xxl,
  }) => AppSpacing(
    xs: xs ?? this.xs,
    sm: sm ?? this.sm,
    md: md ?? this.md,
    lg: lg ?? this.lg,
    xl: xl ?? this.xl,
    xxl: xxl ?? this.xxl,
  );

  @override
  AppSpacing lerp(AppSpacing? other, double t) {
    if (other is! AppSpacing) return this;
    return AppSpacing(
      xs: lerpDouble(xs, other.xs, t)!,
      sm: lerpDouble(sm, other.sm, t)!,
      md: lerpDouble(md, other.md, t)!,
      lg: lerpDouble(lg, other.lg, t)!,
      xl: lerpDouble(xl, other.xl, t)!,
      xxl: lerpDouble(xxl, other.xxl, t)!,
    );
  }
}

/// Border radius tokens — accessible via context.radius
class AppRadius extends ThemeExtension<AppRadius> {
  final double sm;
  final double md;
  final double lg;
  final double full;

  const AppRadius({
    this.sm = 4,
    this.md = 12,
    this.lg = 16,
    this.full = 999,
  });

  BorderRadius get smAll => BorderRadius.circular(sm);
  BorderRadius get mdAll => BorderRadius.circular(md);
  BorderRadius get lgAll => BorderRadius.circular(lg);
  BorderRadius get fullAll => BorderRadius.circular(full);

  @override
  AppRadius copyWith({
    double? sm, double? md, double? lg, double? full,
  }) => AppRadius(
    sm: sm ?? this.sm,
    md: md ?? this.md,
    lg: lg ?? this.lg,
    full: full ?? this.full,
  );

  @override
  AppRadius lerp(AppRadius? other, double t) {
    if (other is! AppRadius) return this;
    return AppRadius(
      sm: lerpDouble(sm, other.sm, t)!,
      md: lerpDouble(md, other.md, t)!,
      lg: lerpDouble(lg, other.lg, t)!,
      full: lerpDouble(full, other.full, t)!,
    );
  }
}

/// Elevation tokens — accessible via context.elevations
class AppElevations extends ThemeExtension<AppElevations> {
  final double none;
  final double low;
  final double medium;
  final double high;

  const AppElevations({
    this.none = 0,
    this.low = 1,
    this.medium = 3,
    this.high = 6,
  });

  @override
  AppElevations copyWith({
    double? none, double? low, double? medium, double? high,
  }) => AppElevations(
    none: none ?? this.none,
    low: low ?? this.low,
    medium: medium ?? this.medium,
    high: high ?? this.high,
  );

  @override
  AppElevations lerp(AppElevations? other, double t) {
    if (other is! AppElevations) return this;
    return AppElevations(
      none: lerpDouble(none, other.none, t)!,
      low: lerpDouble(low, other.low, t)!,
      medium: lerpDouble(medium, other.medium, t)!,
      high: lerpDouble(high, other.high, t)!,
    );
  }
}
```

### Type-Safe Context Extensions

```dart
/// Clean access to all token extensions.
/// Import this file wherever you use tokens.
extension ThemeExtensions on BuildContext {
  AppSpacing get spacing =>
      Theme.of(this).extension<AppSpacing>()!;

  AppRadius get radius =>
      Theme.of(this).extension<AppRadius>()!;

  AppElevations get elevations =>
      Theme.of(this).extension<AppElevations>()!;

  // Shorthand for M3 color scheme
  ColorScheme get colorScheme =>
      Theme.of(this).colorScheme;

  // Shorthand for text theme
  TextTheme get textTheme =>
      Theme.of(this).textTheme;
}
```

### Usage in Widgets

```dart
class ExerciseScoreCard extends StatelessWidget {
  final int score;
  final String exerciseName;

  const ExerciseScoreCard({
    super.key,
    required this.score,
    required this.exerciseName,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: context.elevations.low,
      shape: RoundedRectangleBorder(
        borderRadius: context.radius.lgAll,
      ),
      child: Padding(
        padding: EdgeInsets.all(context.spacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(exerciseName, style: context.textTheme.titleMedium),
            SizedBox(height: context.spacing.sm),
            Text(
              '$score / 100',
              style: context.textTheme.headlineMedium?.copyWith(
                color: context.colorScheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

## Responsive Layout Templates

**Context:** SKILL.md Section 3 — Responsive scaffolds with adaptive navigation.

### Full Adaptive Scaffold

```dart
import 'package:flutter/material.dart';

/// Scaffold that switches navigation pattern based on available width.
/// Compact: BottomNavigationBar
/// Medium: NavigationRail
/// Expanded: NavigationRail + extended labels (or permanent drawer)
class AdaptiveScaffold extends StatefulWidget {
  final List<AdaptiveDestination> destinations;
  final List<Widget> bodies;

  const AdaptiveScaffold({
    super.key,
    required this.destinations,
    required this.bodies,
  });

  @override
  State<AdaptiveScaffold> createState() => _AdaptiveScaffoldState();
}

class AdaptiveDestination {
  final IconData icon;
  final IconData selectedIcon;
  final String label;

  const AdaptiveDestination({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });
}

class _AdaptiveScaffoldState extends State<AdaptiveScaffold> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Compact: < 600dp
        if (constraints.maxWidth < 600) {
          return _buildCompact();
        }
        // Medium: 600–840dp
        if (constraints.maxWidth < 840) {
          return _buildMedium(extended: false);
        }
        // Expanded: > 840dp
        return _buildMedium(extended: true);
      },
    );
  }

  Widget _buildCompact() {
    return Scaffold(
      body: widget.bodies[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (i) => setState(() => _selectedIndex = i),
        destinations: widget.destinations
            .map((d) => NavigationDestination(
                  icon: Icon(d.icon),
                  selectedIcon: Icon(d.selectedIcon),
                  label: d.label,
                ))
            .toList(),
      ),
    );
  }

  Widget _buildMedium({required bool extended}) {
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            extended: extended,
            selectedIndex: _selectedIndex,
            onDestinationSelected: (i) =>
                setState(() => _selectedIndex = i),
            destinations: widget.destinations
                .map((d) => NavigationRailDestination(
                      icon: Icon(d.icon),
                      selectedIcon: Icon(d.selectedIcon),
                      label: Text(d.label),
                    ))
                .toList(),
          ),
          const VerticalDivider(width: 1),
          Expanded(child: widget.bodies[_selectedIndex]),
        ],
      ),
    );
  }
}
```

### List-Detail (Master-Detail) Pattern

```dart
/// On compact screens: list view, tap navigates to detail.
/// On expanded screens: list and detail side by side.
class ListDetailLayout<T> extends StatefulWidget {
  final List<T> items;
  final Widget Function(T item, bool isSelected) listItemBuilder;
  final Widget Function(T item) detailBuilder;
  final Widget emptyDetailBuilder;

  const ListDetailLayout({
    super.key,
    required this.items,
    required this.listItemBuilder,
    required this.detailBuilder,
    required this.emptyDetailBuilder,
  });

  @override
  State<ListDetailLayout<T>> createState() => _ListDetailLayoutState<T>();
}

class _ListDetailLayoutState<T> extends State<ListDetailLayout<T>> {
  T? _selected;

  @override
  Widget build(BuildContext context) {
    final isExpanded = MediaQuery.sizeOf(context).width >= 840;

    if (isExpanded) {
      return Row(
        children: [
          SizedBox(
            width: 360,
            child: _buildList(isExpanded: true),
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: _selected != null
                ? widget.detailBuilder(_selected as T)
                : widget.emptyDetailBuilder,
          ),
        ],
      );
    }

    // Compact: full-screen list, push detail on selection
    return _buildList(isExpanded: false);
  }

  Widget _buildList({required bool isExpanded}) {
    return ListView.builder(
      itemCount: widget.items.length,
      itemBuilder: (context, index) {
        final item = widget.items[index];
        return GestureDetector(
          onTap: () {
            if (isExpanded) {
              setState(() => _selected = item);
            } else {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => Scaffold(
                    appBar: AppBar(),
                    body: widget.detailBuilder(item),
                  ),
                ),
              );
            }
          },
          child: widget.listItemBuilder(item, _selected == item),
        );
      },
    );
  }
}
```

## Animation Templates

**Context:** SKILL.md Section 5 — Animation implementation patterns.

### Hero Transition Between Routes

```dart
// Source screen
Hero(
  tag: 'exercise-${exercise.id}',
  child: ClipRRect(
    borderRadius: BorderRadius.circular(12),
    child: Image.network(exercise.thumbnailUrl,
      width: 80, height: 80, fit: BoxFit.cover),
  ),
);

// Destination screen
Hero(
  tag: 'exercise-${exercise.id}',
  child: ClipRRect(
    borderRadius: BorderRadius.circular(0), // Animate to full-width
    child: Image.network(exercise.imageUrl,
      width: double.infinity, height: 300, fit: BoxFit.cover),
  ),
);
```

**WHY matching `tag`:** Flutter finds `Hero` pairs by matching tags across routes. Mismatched tags = no animation. Use a unique, stable identifier (never index).

### AnimatedSwitcher for Widget Swap

```dart
AnimatedSwitcher(
  duration: const Duration(milliseconds: 300),
  switchInCurve: Curves.easeOut,
  switchOutCurve: Curves.easeIn,
  transitionBuilder: (child, animation) {
    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.1),
          end: Offset.zero,
        ).animate(animation),
        child: child,
      ),
    );
  },
  // KEY is critical: without it, Flutter can't tell
  // old and new children apart for the cross-fade.
  child: isLoading
    ? const CircularProgressIndicator(key: ValueKey('loading'))
    : ContentWidget(key: ValueKey('content'), data: data),
);
```

### Staggered List Animation

```dart
class StaggeredListAnimation extends StatefulWidget {
  final List<Widget> children;
  const StaggeredListAnimation({super.key, required this.children});

  @override
  State<StaggeredListAnimation> createState() =>
      _StaggeredListAnimationState();
}

class _StaggeredListAnimationState extends State<StaggeredListAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(
        milliseconds: 200 + (widget.children.length * 100),
      ),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final count = widget.children.length;
    return Column(
      children: List.generate(count, (index) {
        // Each item starts slightly after the previous one
        final start = (index / count) * 0.6; // 60% of duration for stagger
        final end = start + 0.4; // Each takes 40% of total duration

        final opacity = Tween(begin: 0.0, end: 1.0).animate(
          CurvedAnimation(
            parent: _controller,
            curve: Interval(start, end, curve: Curves.easeOut),
          ),
        );
        final slideY = Tween(begin: 20.0, end: 0.0).animate(
          CurvedAnimation(
            parent: _controller,
            curve: Interval(start, end, curve: Curves.easeOutCubic),
          ),
        );

        return AnimatedBuilder(
          animation: _controller,
          builder: (context, child) => Opacity(
            opacity: opacity.value,
            child: Transform.translate(
              offset: Offset(0, slideY.value),
              child: child,
            ),
          ),
          child: widget.children[index],
        );
      }),
    );
  }
}
```

### Spring-Based Drag Dismiss

```dart
class DragDismissible extends StatefulWidget {
  final Widget child;
  final VoidCallback onDismiss;

  const DragDismissible({
    super.key,
    required this.child,
    required this.onDismiss,
  });

  @override
  State<DragDismissible> createState() => _DragDismissibleState();
}

class _DragDismissibleState extends State<DragDismissible>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  double _dragOffset = 0;

  @override
  void initState() {
    super.initState();
    // WHY unbounded: SpringSimulation produces pixel values (e.g., 150.0 → 0).
    // Default AnimationController clamps to [0, 1], breaking the animation.
    _controller = AnimationController.unbounded(vsync: this);
    // Single listener set up once — NOT inside _onDragEnd (that leaks listeners)
    _controller.addListener(_onAnimationTick);
  }

  void _onAnimationTick() {
    setState(() => _dragOffset = _controller.value);
  }

  @override
  void dispose() {
    _controller.removeListener(_onAnimationTick);
    _controller.dispose();
    super.dispose();
  }

  void _onDragUpdate(DragUpdateDetails details) {
    setState(() => _dragOffset += details.delta.dy);
  }

  void _onDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    if (_dragOffset.abs() > 100 || velocity.abs() > 700) {
      widget.onDismiss();
    } else {
      // Spring back to origin
      final simulation = SpringSimulation(
        const SpringDescription(mass: 1, stiffness: 400, damping: 25),
        _dragOffset, 0, velocity / 1000,
      );
      _controller.animateWith(simulation);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onVerticalDragUpdate: _onDragUpdate,
      onVerticalDragEnd: _onDragEnd,
      child: Transform.translate(
        offset: Offset(0, _dragOffset),
        child: Opacity(
          opacity: (1 - (_dragOffset.abs() / 300)).clamp(0.3, 1.0),
          child: widget.child,
        ),
      ),
    );
  }
}
```

## Widgetbook Setup

**Context:** SKILL.md Section 8 — Component catalog with knobs and golden tests.

### Use Case with Knobs

```dart
import 'package:widgetbook/widgetbook.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart';

@UseCase(name: 'Default', type: AppButton)
Widget appButtonUseCase(BuildContext context) {
  return AppButton(
    label: context.knobs.string(
      label: 'Label',
      initialValue: 'Submit',
    ),
    isLoading: context.knobs.boolean(
      label: 'Loading',
      initialValue: false,
    ),
    onPressed: context.knobs.boolean(label: 'Enabled', initialValue: true)
        ? () {}
        : null,
    style: context.knobs.list(
      label: 'Style',
      options: [ButtonStyle.primary, ButtonStyle.secondary],
      initialOption: ButtonStyle.primary,
      labelBuilder: (style) => style.name,
    ),
  );
}

@UseCase(name: 'Default', type: ExerciseScoreCard)
Widget exerciseScoreCardUseCase(BuildContext context) {
  return ExerciseScoreCard(
    score: context.knobs.double
        .slider(label: 'Score', min: 0, max: 100, initialValue: 85)
        .toInt(),
    exerciseName: context.knobs.string(
      label: 'Exercise',
      initialValue: 'Back Squat',
    ),
  );
}
```

### Golden Test Suite

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';

/// Golden test helper — wraps widget in themed MaterialApp
/// with a constrained size for deterministic screenshots.
Widget goldenWrapper({
  required Widget child,
  ThemeData? theme,
  Size size = const Size(400, 200),
}) {
  return MaterialApp(
    theme: theme ?? lightTheme,
    debugShowCheckedModeBanner: false,
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: size.width,
          height: size.height,
          child: child,
        ),
      ),
    ),
  );
}

void main() {
  group('AppButton goldens', () {
    testWidgets('primary - light theme', (tester) async {
      await tester.pumpWidget(goldenWrapper(
        child: AppButton(label: 'Submit', onPressed: () {}),
      ));
      await expectLater(
        find.byType(AppButton),
        matchesGoldenFile('goldens/app_button_primary_light.png'),
      );
    });

    testWidgets('primary - dark theme', (tester) async {
      await tester.pumpWidget(goldenWrapper(
        theme: darkTheme,
        child: AppButton(label: 'Submit', onPressed: () {}),
      ));
      await expectLater(
        find.byType(AppButton),
        matchesGoldenFile('goldens/app_button_primary_dark.png'),
      );
    });

    testWidgets('disabled state', (tester) async {
      await tester.pumpWidget(goldenWrapper(
        child: const AppButton(label: 'Submit', onPressed: null),
      ));
      await expectLater(
        find.byType(AppButton),
        matchesGoldenFile('goldens/app_button_disabled.png'),
      );
    });

    testWidgets('loading state', (tester) async {
      await tester.pumpWidget(goldenWrapper(
        child: AppButton(
          label: 'Submit', onPressed: () {}, isLoading: true,
        ),
      ));
      await tester.pump(const Duration(milliseconds: 500));
      await expectLater(
        find.byType(AppButton),
        matchesGoldenFile('goldens/app_button_loading.png'),
      );
    });
  });
}
```

## Atomic Design File Templates

**Context:** SKILL.md Section 7 — Concrete examples for each atomic design level.

### Atom: AppButton

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Atom: Minimal button with loading state.
/// Takes only primitives — no business logic, no state management.
class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;

  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: isLoading ? null : () {
        HapticFeedback.mediumImpact();
        onPressed?.call();
      },
      child: isLoading
          ? const SizedBox(
              width: 20, height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Text(label),
    );
  }
}
```

### Atom: AppAvatar

```dart
import 'package:flutter/material.dart';

/// Atom: Circular avatar with fallback initials.
class AppAvatar extends StatelessWidget {
  final String? imageUrl;
  final String name;
  final double size;

  const AppAvatar({
    super.key,
    this.imageUrl,
    required this.name,
    this.size = 40,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final initials = name.split(' ')
        .take(2)
        .map((w) => w.isNotEmpty ? w[0].toUpperCase() : '')
        .join();

    return CircleAvatar(
      radius: size / 2,
      backgroundImage: imageUrl != null ? NetworkImage(imageUrl!) : null,
      backgroundColor: scheme.primaryContainer,
      child: imageUrl == null
          ? Text(initials,
              style: TextStyle(
                color: scheme.onPrimaryContainer,
                fontSize: size * 0.36,
                fontWeight: FontWeight.w600,
              ))
          : null,
    );
  }
}
```

### Molecule: UserChip

```dart
import 'package:flutter/material.dart';

/// Molecule: Avatar + name + optional subtitle.
/// Composes atoms, still no business logic.
class UserChip extends StatelessWidget {
  final String name;
  final String? subtitle;
  final String? avatarUrl;
  final VoidCallback? onTap;

  const UserChip({
    super.key,
    required this.name,
    this.subtitle,
    this.avatarUrl,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final spacing = Theme.of(context).extension<AppSpacing>()!;
    return MergeSemantics(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: spacing.sm,
            vertical: spacing.xs,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppAvatar(name: name, imageUrl: avatarUrl, size: 32),
              SizedBox(width: spacing.sm),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(name,
                    style: Theme.of(context).textTheme.labelLarge),
                  if (subtitle != null)
                    Text(subtitle!,
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

### Organism: ExerciseCard

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Organism: Full exercise card with image, score, and actions.
/// Can hold local state (e.g., expanded/collapsed).
/// Does NOT access global state (providers, repositories).
class ExerciseCard extends StatelessWidget {
  final String name;
  final String imageUrl;
  final int score;
  final String category;
  final VoidCallback onTap;
  final VoidCallback? onFavorite;
  final bool isFavorited;

  const ExerciseCard({
    super.key,
    required this.name,
    required this.imageUrl,
    required this.score,
    required this.category,
    required this.onTap,
    this.onFavorite,
    this.isFavorited = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final spacing = Theme.of(context).extension<AppSpacing>()!;
    final radius = Theme.of(context).extension<AppRadius>()!;

    return Semantics(
      label: '$name exercise, score $score out of 100, $category',
      child: Card(
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: radius.lgAll),
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image with score overlay
              Stack(
                children: [
                  AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Image.network(imageUrl, fit: BoxFit.cover),
                  ),
                  Positioned(
                    top: spacing.sm,
                    right: spacing.sm,
                    child: _ScoreBadge(score: score),
                  ),
                ],
              ),
              // Content
              Padding(
                padding: EdgeInsets.all(spacing.md),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name,
                            style: Theme.of(context).textTheme.titleMedium),
                          SizedBox(height: spacing.xs),
                          Text(category,
                            style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: scheme.onSurfaceVariant)),
                        ],
                      ),
                    ),
                    if (onFavorite != null)
                      IconButton(
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          onFavorite!();
                        },
                        icon: Icon(
                          isFavorited
                            ? Icons.favorite
                            : Icons.favorite_border,
                          color: isFavorited ? scheme.error : null,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScoreBadge extends StatelessWidget {
  final int score;
  const _ScoreBadge({required this.score});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$score',
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: scheme.onPrimaryContainer,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
```

### Template: DashboardTemplate

```dart
/// Template: Layout structure with named slots.
/// No data fetching, no business logic.
/// Pages fill these slots with real data.
class DashboardTemplate extends StatelessWidget {
  final Widget header;
  final Widget body;
  final Widget? sidebar;
  final Widget? floatingAction;

  const DashboardTemplate({
    super.key,
    required this.header,
    required this.body,
    this.sidebar,
    this.floatingAction,
  });

  @override
  Widget build(BuildContext context) {
    final isExpanded = MediaQuery.sizeOf(context).width >= 840;

    return Scaffold(
      floatingActionButton: floatingAction,
      body: SafeArea(
        child: Column(
          children: [
            header,
            Expanded(
              child: isExpanded && sidebar != null
                  ? Row(
                      children: [
                        Expanded(flex: 3, child: body),
                        const VerticalDivider(width: 1),
                        Expanded(flex: 1, child: sidebar!),
                      ],
                    )
                  : body,
            ),
          ],
        ),
      ),
    );
  }
}
```

## Accessibility Testing Patterns

**Context:** SKILL.md Section 9 — Programmatic accessibility verification.

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';

void main() {
  group('Accessibility', () {
    testWidgets('interactive elements have semantic labels', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ExerciseCard(
            name: 'Back Squat',
            imageUrl: 'https://example.com/squat.jpg',
            score: 85,
            category: 'Strength',
            onTap: () {},
          ),
        ),
      ));

      final semantics = tester.getSemantics(find.byType(ExerciseCard));
      expect(semantics.label, contains('Back Squat'));
      expect(semantics.label, contains('85'));
    });

    testWidgets('meets minimum touch target size', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () {},
          ),
        ),
      ));

      final size = tester.getSize(find.byType(IconButton));
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));
    });

    testWidgets('decorative elements excluded from semantics',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ExcludeSemantics(
            child: DecorativeGradientBackground(),
          ),
        ),
      ));

      // Should not find any semantics for the decorative widget
      expect(
        tester.getSemantics(find.byType(DecorativeGradientBackground)),
        isNull,
      );
    });

    testWidgets('merged semantics read as single announcement',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: MergeSemantics(
            child: Row(
              children: [
                const Icon(Icons.timer),
                const Text('3:45 remaining'),
              ],
            ),
          ),
        ),
      ));

      final semantics = tester.getSemantics(find.byType(MergeSemantics));
      // Should be one merged announcement, not "timer icon" + "3:45 remaining"
      expect(semantics.label, contains('3:45 remaining'));
    });
  });
}
```
