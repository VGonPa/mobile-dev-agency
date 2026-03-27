# Building Flutter Widgets — Implementation Reference

Copyable templates for patterns described in [SKILL.md](SKILL.md). Every template here corresponds to a decision made in SKILL.md — don't implement without reading the decision context first.

## ThemeExtension Full Template

**When needed:** App-wide design tokens (spacing, radii, semantic colors) used across 3+ widgets. Read SKILL.md Step 5 decision boundaries before implementing.

```dart
import 'dart:ui';

class AppSpacing extends ThemeExtension<AppSpacing> {
  final double xs, sm, md, lg, xl;

  const AppSpacing({
    required this.xs,
    required this.sm,
    required this.md,
    required this.lg,
    required this.xl,
  });

  static const regular = AppSpacing(xs: 4, sm: 8, md: 16, lg: 24, xl: 32);

  @override
  AppSpacing copyWith({double? xs, double? sm, double? md, double? lg, double? xl}) {
    return AppSpacing(
      xs: xs ?? this.xs,
      sm: sm ?? this.sm,
      md: md ?? this.md,
      lg: lg ?? this.lg,
      xl: xl ?? this.xl,
    );
  }

  @override
  AppSpacing lerp(covariant AppSpacing? other, double t) {
    if (other == null) return this;
    return AppSpacing(
      xs: lerpDouble(xs, other.xs, t)!,
      sm: lerpDouble(sm, other.sm, t)!,
      md: lerpDouble(md, other.md, t)!,
      lg: lerpDouble(lg, other.lg, t)!,
      xl: lerpDouble(xl, other.xl, t)!,
    );
  }
}
```

**Registration in ThemeData:**

```dart
ThemeData(
  useMaterial3: true,
  colorScheme: colorScheme,
  extensions: [AppSpacing.regular],
)
```

**Usage in widgets:**

```dart
final spacing = Theme.of(context).extension<AppSpacing>()!;
Padding(padding: EdgeInsets.all(spacing.md), child: child)
```

## App Theme Setup Template

**When needed:** Every Flutter app. This is the starting point for M3 theming with light/dark mode and custom extensions.

```dart
import 'package:flutter/material.dart';

class AppTheme {
  static ThemeData light() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF1A73E8), // Replace with brand color
      brightness: Brightness.light,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      extensions: [AppSpacing.regular],
    );
  }

  static ThemeData dark() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF1A73E8),
      brightness: Brightness.dark,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      extensions: [AppSpacing.regular],
    );
  }
}

// In main.dart:
MaterialApp(
  theme: AppTheme.light(),
  darkTheme: AppTheme.dark(),
  themeMode: ThemeMode.system,
)
```

## Responsive Layout Template

**When needed:** Any screen that must work across phone, tablet, and desktop widths.

```dart
class ResponsiveLayout extends StatelessWidget {
  const ResponsiveLayout({
    super.key,
    required this.mobile,
    this.tablet,
    this.desktop,
  });

  final Widget mobile;
  final Widget? tablet;
  final Widget? desktop;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      if (constraints.maxWidth >= 1200) return desktop ?? tablet ?? mobile;
      if (constraints.maxWidth >= 600) return tablet ?? mobile;
      return mobile;
    });
  }
}
```

## Adaptive Navigation Template

**When needed:** Apps with 3-5 top-level destinations that must work across form factors.

```dart
class AdaptiveScaffold extends StatelessWidget {
  const AdaptiveScaffold({
    super.key,
    required this.destinations,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.body,
  });

  final List<NavigationDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final Widget body;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      // Desktop: NavigationDrawer
      if (constraints.maxWidth >= 1200) {
        return Row(children: [
          NavigationDrawer(
            selectedIndex: selectedIndex,
            onDestinationSelected: onDestinationSelected,
            children: destinations
                .map((d) => NavigationDrawerDestination(
                      icon: d.icon,
                      label: Text(d.label),
                    ))
                .toList(),
          ),
          Expanded(child: body),
        ]);
      }
      // Tablet: NavigationRail
      if (constraints.maxWidth >= 600) {
        return Row(children: [
          NavigationRail(
            selectedIndex: selectedIndex,
            onDestinationSelected: onDestinationSelected,
            labelType: NavigationRailLabelType.all,
            destinations: destinations
                .map((d) => NavigationRailDestination(
                      icon: d.icon,
                      label: Text(d.label),
                    ))
                .toList(),
          ),
          Expanded(child: body),
        ]);
      }
      // Phone: NavigationBar
      return Scaffold(
        body: body,
        bottomNavigationBar: NavigationBar(
          selectedIndex: selectedIndex,
          onDestinationSelected: onDestinationSelected,
          destinations: destinations,
        ),
      );
    });
  }
}
```

## Composed Widget Template

**When needed:** Creating a reusable widget that wraps Material components with app-specific defaults.

```dart
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final spacing = Theme.of(context).extension<AppSpacing>()!;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: padding ?? EdgeInsets.all(spacing.md),
          child: child,
        ),
      ),
    );
  }
}
```

## Semantic Widget Template

**When needed:** Custom widgets that render non-text content (images, icons, charts) or group related content.

```dart
// Image with semantic label
Semantics(
  label: 'User profile photo for $userName',
  image: true,
  child: CircleAvatar(backgroundImage: NetworkImage(url)),
)

// Grouped content (read as single unit)
MergeSemantics(
  child: ListTile(
    leading: Icon(Icons.email),
    title: Text(email),
    subtitle: Text('Email address'),
  ),
)

// Decorative element (excluded from screen reader)
ExcludeSemantics(child: DecorativeBackground())

// Dynamic announcement
SemanticsService.announce('Item added to cart', TextDirection.ltr);
```
