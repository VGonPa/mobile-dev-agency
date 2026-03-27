---
name: flutter-ui-craft
description: Implements Flutter UI using Material 3 theming, design tokens via ThemeExtension, responsive/adaptive layouts, animation, haptics, atomic design patterns, Widgetbook catalogs, and accessibility. Use when building UI components, setting up theming systems, creating responsive layouts, adding animations or haptic feedback, organizing widget architecture, or auditing accessibility. Starts with WHY behind each design-to-code decision.
user-invocable: true
---

# Flutter UI Craft

Design systems exist to make consistent UI inevitable, not aspirational. This skill bridges Figma designs and Flutter code — helping you build themeable, responsive, accessible interfaces that work across phones, tablets, and desktop.

> **Common Mistakes This Skill Prevents**
>
> - Using `MediaQuery.of(context)` in build methods (triggers full rebuild on ANY MediaQuery change — keyboard, orientation, padding)
> - Checking `Platform.isIOS` for layout decisions (breaks on web, ignores tablets, conflates platform with screen size)
> - Hardcoding colors/spacing instead of using theme tokens (makes dark mode and rebranding a nightmare)
> - Creating `ThemeExtension` without `lerp` (breaks theme transitions and animated theme switching)
> - Putting animation logic inside StatelessWidget or rebuilding AnimationController on every build
> - Skipping `Semantics` widgets and relying on default labels (screen readers announce "button" with no context)
> - Building one-size layouts that look broken on tablets or landscape orientation

## When to Use This Skill

- Setting up or extending an M3 theme system
- Creating design tokens with ThemeExtension
- Building responsive layouts that adapt to screen size
- Adding platform-adaptive behavior (iOS vs Android patterns)
- Implementing animations and haptic feedback
- Organizing widgets using atomic design
- Setting up Widgetbook for component catalogs
- Auditing or improving accessibility

## When NOT to Use This Skill

- **State management** — Riverpod/Bloc architecture, data flow patterns
- **Navigation/routing** — GoRouter setup, deep linking, route guards
- **Backend integration** — API clients, Firebase, data serialization
- **Performance profiling** — DevTools, frame budgets, shader warmup
- **Testing logic** — unit tests, integration tests (Widgetbook golden tests ARE covered)

## Section 1: Material 3 Theming

**WHY M3 over custom theming:** M3's `ColorScheme.fromSeed()` generates a mathematically harmonious 30+ color palette from a single brand color, including dark mode variants. Building this by hand is error-prone and produces inconsistent results.

### Setting Up ThemeData

```dart
final theme = ThemeData(
  // useMaterial3 is true by default since Flutter 3.16 — no need to set it
  colorScheme: ColorScheme.fromSeed(
    seedColor: const Color(0xFF1B5E20), // Brand green
    brightness: Brightness.light,
  ),
  textTheme: GoogleFonts.interTextTheme(),
);
```

**WHY `fromSeed` instead of manual `ColorScheme`:** Manual schemes require you to define 30+ color slots that must meet contrast ratios against each other. `fromSeed` guarantees this mathematically. Override individual slots only when brand guidelines demand a specific color.

### Component Theme Customization

Override M3 component defaults when your design system diverges from stock M3:

```dart
ThemeData(
  // ... colorScheme, textTheme ...
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    ),
  ),
  cardTheme: const CardThemeData(
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(16)),
    ),
  ),
);
```

**Decision:** Override component themes at the `ThemeData` level, not per-widget. Per-widget overrides scatter design decisions across the codebase and make updates painful.

### Dynamic Color (Material You)

**What it does:** On Android 12+, the OS extracts colors from the user's wallpaper. Your app can adopt these colors while keeping its visual identity.

**Decision framework:**

| Scenario | Use dynamic color? | Why |
|----------|-------------------|-----|
| Consumer app, brand-flexible | Yes | Feels native, users love personalization |
| Strong brand identity (banking, enterprise) | No | Brand colors are non-negotiable |
| Hybrid approach | Partial | Use dynamic for surfaces, keep brand for primary actions |

```dart
// With dynamic_color package
DynamicColorBuilder(
  builder: (lightDynamic, darkDynamic) {
    final scheme = lightDynamic ?? fallbackLightScheme;
    return MaterialApp(
      theme: ThemeData(colorScheme: scheme),
    );
  },
);
```

See [REFERENCE.md → Full Theme Setup](REFERENCE.md#full-theme-setup) for complete `MaterialApp` configuration with dynamic color support.

## Section 2: Design Tokens via ThemeExtension

**WHY ThemeExtension over global constants:** Constants are static — they can't change at runtime (dark mode, dynamic color, A/B tests). `ThemeExtension` integrates with Flutter's theme system, supports `lerp` for smooth theme transitions, and is accessible anywhere via `Theme.of(context)`.

### Token Hierarchy: Primitive → Semantic → Component

Design systems use three layers of abstraction. Each layer adds meaning:

| Layer | Example | Changes when... |
|-------|---------|----------------|
| **Primitive** | `blue500 = Color(0xFF2196F3)` | Brand palette changes |
| **Semantic** | `interactive = blue500` | Design language evolves |
| **Component** | `buttonBackground = interactive` | Component redesigned |

**Rule:** Widgets reference only **component tokens**. Never use primitive tokens directly in widgets — when the brand palette changes, you'd have to find every widget using `blue500`.

### Creating a ThemeExtension

```dart
class AppSpacing extends ThemeExtension<AppSpacing> {
  final double xs, sm, md, lg, xl;

  const AppSpacing({
    this.xs = 4, this.sm = 8,
    this.md = 16, this.lg = 24, this.xl = 32,
  });

  @override
  AppSpacing copyWith({double? xs, double? sm,
      double? md, double? lg, double? xl}) =>
    AppSpacing(
      xs: xs ?? this.xs, sm: sm ?? this.sm,
      md: md ?? this.md, lg: lg ?? this.lg,
      xl: xl ?? this.xl,
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
    );
  }
}
```

**WHY `lerp` is mandatory:** Without it, animated theme transitions (dark↔light, dynamic color changes) snap instead of smoothly interpolating. Flutter calls `lerp` during `AnimatedTheme` — if you return `this`, your custom tokens won't animate.

### Accessing Tokens Type-Safely

```dart
// Extension method for clean access
extension ThemeExtensions on BuildContext {
  AppSpacing get spacing =>
    Theme.of(this).extension<AppSpacing>()!;
}

// Usage in widgets
Padding(padding: EdgeInsets.all(context.spacing.md));
```

See [REFERENCE.md → Complete Token System](REFERENCE.md#complete-token-system) for full primitive/semantic/component token classes.

## Section 3: Responsive Layout

**WHY responsive matters:** A phone layout on a tablet wastes 60%+ of the screen. Users on large screens expect content to fill the space, not stretch a phone column to 1200px.

### The Critical API Choice

```dart
// WRONG: Triggers rebuild on ANY MediaQuery change
// (keyboard appears, status bar changes, padding updates)
final size = MediaQuery.of(context).size;

// RIGHT: Only rebuilds when size actually changes
final size = MediaQuery.sizeOf(context);
```

**WHY this matters:** `MediaQuery.of(context)` subscribes to ALL MediaQuery properties. When the keyboard opens, `viewInsets` changes, triggering a rebuild of every widget using `.of()` — even those that only care about screen width. `MediaQuery.sizeOf()` subscribes only to size changes.

### Breakpoint System

Use the M3 canonical breakpoints — don't invent your own unless your design system demands it:

| Window class | Width | Typical device | Layout pattern |
|-------------|-------|----------------|----------------|
| **Compact** | < 600dp | Phone | Single column, bottom nav |
| **Medium** | 600–840dp | Tablet portrait, foldable | Two-pane optional, rail nav |
| **Expanded** | > 840dp | Tablet landscape, desktop | Multi-pane, side nav |

### Layout Pattern

```dart
class ResponsiveScaffold extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 600) {
          return _CompactLayout();
        } else if (constraints.maxWidth < 840) {
          return _MediumLayout();
        }
        return _ExpandedLayout();
      },
    );
  }
}
```

**WHY `LayoutBuilder` over `MediaQuery.sizeOf`:** `LayoutBuilder` gives you the *available space for this widget*, not the full screen size. A widget inside a side panel needs to know its 300dp constraint, not the 1200dp screen width. Use `MediaQuery.sizeOf` only for top-level scaffold decisions.

**Rule:** Never check device type (`Platform.isIOS`, `kIsWeb`). A phone in landscape, a tablet in split-screen, and a Chrome window at 400px wide all need the same compact layout. Screen size is the only input that matters.

See [REFERENCE.md → Responsive Layout Templates](REFERENCE.md#responsive-layout-templates) for full scaffold with NavigationBar/Rail/Drawer switching.

## Section 4: Cross-Platform Adaptation

**WHY separate responsive from adaptive:** Responsive = how content fills space (layout). Adaptive = how interactions feel native to each platform (behavior). A tablet layout is responsive. iOS-style swipe-to-dismiss is adaptive. They're orthogonal concerns.

### What to Adapt vs. What to Unify

| Adapt per platform | Unify across platforms |
|-------------------|----------------------|
| Navigation patterns (tabs vs. drawer) | Brand colors, typography |
| Date/time pickers | Content hierarchy and layout |
| Scroll physics (bouncing vs. clamping) | Animation timing and curves |
| Page transitions | Iconography and illustration |
| Haptic feedback intensity | Business logic, data flow |

### Platform-Adaptive Navigation

```dart
Widget buildNavigation(BuildContext context) {
  final platform = Theme.of(context).platform;
  if (platform == TargetPlatform.iOS ||
      platform == TargetPlatform.macOS) {
    return CupertinoTabBar(/* iOS-native tabs */);
  }
  return NavigationBar(/* M3 bottom nav */);
}
```

**Decision:** Use `Theme.of(context).platform` — NOT `Platform.isIOS`. Theme-based checks work on all platforms (including web) and can be overridden in tests.

### Adaptive Scroll Physics

```dart
ScrollPhysics get adaptivePhysics =>
  Theme.of(context).platform == TargetPlatform.iOS
    ? const BouncingScrollPhysics()
    : const ClampingScrollPhysics();
```

**WHY:** iOS users expect rubber-band bounce at scroll limits. Android users expect edge glow with clamping. Using the wrong physics feels "off" even if users can't articulate why.

## Section 5: Animation Implementation

**WHY animate:** Animation communicates state changes, directs attention, and provides spatial context. A card that slides in from the right tells the user "this came from over there." A fade tells them "this appeared." Without animation, state changes feel broken — content teleports.

### Decision Framework: Which Animation API?

| Need | API | Why |
|------|-----|-----|
| Simple property change (color, size, padding) | `AnimatedContainer`, `AnimatedOpacity` | Zero boilerplate, handles controller internally |
| Widget swap with transition | `AnimatedSwitcher` | Automatic cross-fade between old/new child |
| Shared element across routes | `Hero` | Flutter manages flight animation between routes |
| Custom curve/spring physics | `AnimationController` + `SpringSimulation` | Full control over physics and timing |
| Staggered sequence | `AnimationController` + `Interval` | Multiple elements animating in choreographed sequence |

### Implicit Animations (80% of cases)

```dart
AnimatedContainer(
  duration: const Duration(milliseconds: 300),
  curve: Curves.easeOutCubic,
  padding: isExpanded
    ? const EdgeInsets.all(24)
    : const EdgeInsets.all(8),
  decoration: BoxDecoration(
    color: isSelected
      ? colorScheme.primaryContainer
      : colorScheme.surface,
    borderRadius: BorderRadius.circular(16),
  ),
  child: content,
);
```

**Rule:** Start with implicit animations. Only reach for `AnimationController` when you need springs, staggering, or frame-level control.

### Spring Physics (Natural-Feeling Motion)

```dart
final controller = AnimationController(vsync: this);
final simulation = SpringSimulation(
  const SpringDescription(
    mass: 1, stiffness: 300, damping: 20,
  ),
  0, 1, 0, // start, end, velocity
);
controller.animateWith(simulation);
```

**WHY springs over curves:** Duration-based curves (300ms ease-out) feel mechanical. Springs respond to velocity — flick harder, it moves further. This matches real-world physics and feels more natural, especially for drag-to-dismiss and pull-to-refresh.

### Staggered Animations

```dart
// In AnimationController with 1000ms duration:
final item1Opacity = Tween(begin: 0.0, end: 1.0).animate(
  CurvedAnimation(
    parent: controller,
    curve: const Interval(0.0, 0.3, curve: Curves.easeOut),
  ),
);
final item2Opacity = Tween(begin: 0.0, end: 1.0).animate(
  CurvedAnimation(
    parent: controller,
    curve: const Interval(0.15, 0.45, curve: Curves.easeOut),
  ),
);
// Each Interval defines when within the overall duration
// this particular animation is active (0.0 = start, 1.0 = end)
```

See [REFERENCE.md → Animation Templates](REFERENCE.md#animation-templates) for Hero setup, AnimatedSwitcher patterns, and staggered list animations.

## Section 6: Haptic Feedback

**WHY haptics:** Haptics confirm that a touch was registered without requiring the user to look at the screen. They transform flat glass into something that feels like it has texture and mechanical response. Used well, they make an app feel premium. Overused, they annoy.

### Feedback Intensity Decision

| Intensity | Method | Use When | Example |
|-----------|--------|----------|---------|
| **Light** | `HapticFeedback.lightImpact()` | Selections, toggles, subtle confirmations | Toggling a switch, selecting a list item |
| **Medium** | `HapticFeedback.mediumImpact()` | Actions, confirmations | Completing a task, adding to cart |
| **Heavy** | `HapticFeedback.heavyImpact()` | Destructive or critical actions | Deleting, completing a purchase |
| **Selection** | `HapticFeedback.selectionClick()` | Picker scrolling, slider ticks | Scrolling through a date picker |

```dart
import 'package:flutter/services.dart';

// On toggle
onChanged: (value) {
  HapticFeedback.lightImpact();
  setState(() => _isEnabled = value);
},

// On destructive action confirmation
onConfirmDelete: () {
  HapticFeedback.heavyImpact();
  deleteItem();
},
```

**Rules:**
1. **Never haptics on scroll** — it fires 60 times/second and drains battery
2. **Never haptics on every tap** — only on state changes (toggle, select, confirm)
3. **Match intensity to consequence** — light for reversible, heavy for destructive
4. **Test on real devices** — simulators don't produce haptic feedback

## Section 7: Atomic Design in Flutter

**WHY atomic design:** Without a component hierarchy, teams build "page widgets" — 500-line build methods that mix layout, styling, and business logic. Atomic design forces separation: small pieces compose into larger ones, each testable and reusable independently.

### The Five Levels

| Level | Definition | Flutter Example |
|-------|-----------|----------------|
| **Atoms** | Smallest UI unit, single responsibility | `AppButton`, `AppAvatar`, `AppBadge` |
| **Molecules** | 2-3 atoms combined with a specific purpose | `SearchBar` (TextField + IconButton), `UserChip` (Avatar + Text) |
| **Organisms** | Complex sections with business logic | `ExerciseCard`, `WorkoutSummaryPanel` |
| **Templates** | Page-level layout structure, no real data | `DashboardTemplate(header:, body:, sidebar:)` |
| **Pages** | Templates filled with real data and state | `DashboardPage` (connects Riverpod state to `DashboardTemplate`) |

### File Organization

```
lib/
  ui/
    atoms/          # AppButton, AppAvatar, AppBadge, AppIcon
    molecules/      # SearchBar, UserChip, StatDisplay
    organisms/      # ExerciseCard, WorkoutTimeline
    templates/      # DashboardTemplate, ProfileTemplate
    pages/          # DashboardPage, ProfilePage
```

### Practical Rules

1. **Atoms have ZERO business logic** — they accept primitives (`String`, `Color`, `VoidCallback`)
2. **Molecules combine atoms** — still no business logic, but have a coherent purpose
3. **Organisms can hold local state** — but should not directly access global state (Riverpod providers)
4. **Templates define layout slots** — they take child widgets, never fetch data themselves
5. **Pages connect state to templates** — this is where `ref.watch` and data fetching live

**Decision:** If a widget takes a provider/repository as input → it's a Page. If it takes only primitives and callbacks → it's an Atom/Molecule. This boundary keeps your component library testable without mocking state management.

## Section 8: Widgetbook

**WHY Widgetbook:** You can't verify that a `Button` looks correct in all states (loading, disabled, error, dark mode, RTL) by running the app and navigating to where it's used. Widgetbook renders every widget in every state in a catalog — you see all combinations at once.

### Setup

```yaml
# pubspec.yaml (separate package or dev dependency)
dev_dependencies:
  widgetbook: ^3.0.0
  widgetbook_annotation: ^3.0.0
  widgetbook_generator: ^3.0.0
  build_runner: ^2.4.0
```

```dart
// widgetbook/main.dart
@App()
class WidgetbookApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Widgetbook.material(
      addons: [
        DeviceFrameAddon(devices: Devices.all),
        ThemeAddon(
          themes: [
            WidgetbookTheme(name: 'Light', data: lightTheme),
            WidgetbookTheme(name: 'Dark', data: darkTheme),
          ],
        ),
      ],
      directories: directories, // Generated
    );
  }
}
```

### Golden Tests for Visual Regression

```dart
testWidgets('AppButton golden test', (tester) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: lightTheme,
      home: Scaffold(
        body: AppButton(
          label: 'Submit',
          onPressed: () {},
        ),
      ),
    ),
  );
  await expectLater(
    find.byType(AppButton),
    matchesGoldenFile('goldens/app_button_light.png'),
  );
});
```

**Workflow:** Run `flutter test --update-goldens` to generate baseline images. CI compares future renders pixel-by-pixel. Any visual change fails the build until the golden is explicitly updated.

See [REFERENCE.md → Widgetbook Setup](REFERENCE.md#widgetbook-setup) for full catalog configuration with use-case knobs.

## Section 9: Accessibility in Code

**WHY accessibility is engineering, not QA:** Accessibility isn't a final polish step. Retrofitting semantics onto a finished UI is 5x harder than building it in. Screen readers, switch controls, and voice access rely on the semantic tree — if it's wrong, your app is unusable for ~15% of users.

### Semantics Widgets Decision

| Widget | Use When | Example |
|--------|----------|---------|
| `Semantics` | Custom widget needs a label/role | Decorative container acting as button |
| `ExcludeSemantics` | Widget is purely decorative | Background gradient, decorative divider |
| `MergeSemantics` | Group of widgets = one logical element | Icon + Text that should read as one announcement |

### Adding Semantics

```dart
// Custom interactive widget needs semantic label
Semantics(
  label: 'Exercise score: 85 out of 100',
  value: '85',
  hint: 'Double tap to view details',
  child: ScoreRingWidget(score: 85),
);

// Decorative elements: exclude from screen reader
ExcludeSemantics(
  child: DecorativeGradientBackground(),
);

// Icon + label = one announcement, not two
MergeSemantics(
  child: Row(
    children: [
      Icon(Icons.timer),
      Text('3:45 remaining'),
    ],
  ),
);
```

### Contrast and Touch Targets

**Minimum contrast ratios (WCAG 2.1 AA):**
- Normal text: **4.5:1** against background
- Large text (18sp+ or 14sp+ bold): **3:1**
- UI components (icons, borders): **3:1**

**Minimum touch targets:**
- M3 specifies **48x48dp** minimum for interactive elements
- Use `SizedBox` or `ConstrainedBox` to enforce, even when the visual element is smaller

```dart
// Small icon, but accessible touch target
SizedBox(
  width: 48, height: 48,
  child: IconButton(
    icon: const Icon(Icons.close, size: 18),
    onPressed: onDismiss,
  ),
);
```

### Testing Accessibility

```dart
testWidgets('score widget has semantic label', (tester) async {
  await tester.pumpWidget(/* widget */);
  final semantics = tester.getSemantics(
    find.byType(ScoreRingWidget),
  );
  expect(semantics.label, contains('score'));
});
```

**Pre-release checklist:**
- [ ] Run `flutter test` with semantics assertions
- [ ] Enable TalkBack (Android) / VoiceOver (iOS) and navigate every screen
- [ ] Verify no "button" or "image" announced without context
- [ ] Check contrast ratios with Accessibility Scanner (Android) or Xcode Accessibility Inspector
- [ ] All interactive elements ≥ 48x48dp touch target
- [ ] `MergeSemantics` on icon+label pairs
- [ ] `ExcludeSemantics` on decorative elements
