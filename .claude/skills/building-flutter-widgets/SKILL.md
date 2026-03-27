---
name: building-flutter-widgets
description: Guides Flutter widget composition, Material Design 3 theming, responsive layouts, accessibility, and extraction patterns. Use when building UI components, designing responsive screens, setting up ThemeExtension, or deciding when to extract widgets. Starts with composition decisions before any code.
user-invocable: true
---

# Building Flutter Widgets

Widget decisions in Flutter look simple but compound fast — one wrong abstraction forces prop-drilling across 20 files, one hardcoded color breaks dark mode everywhere, and one missing Semantics node makes a screen invisible to 15% of users. This skill helps you make the right structural decisions before writing widget code.

## When to Use This Skill

- Building new UI components or screens
- Deciding whether to extract a widget or inline it
- Setting up app-wide theming with ThemeExtension
- Making layouts responsive across phone/tablet/desktop
- Adding accessibility (Semantics) to custom widgets
- Choosing between Material 3 widgets for a given use case

## When NOT to Use This Skill

- **State management** (Riverpod, Bloc, etc.) — this skill covers widget structure, not how data flows into widgets
- **Routing / navigation** (GoRouter, auto_route) — widget composition stops at the page boundary
- **Widget testing** — test strategy is a separate concern; this skill covers testability through extraction, not test code
- **Animations** (AnimationController, Hero, page transitions) — animation is a rendering concern, not a composition concern
- **Backend integration** (HTTP clients, Firebase, APIs) — widgets should receive data, not fetch it

## Step 1: Composition Over Inheritance — And Why

**Problem:** Flutter's widget tree is designed for composition. Extending Material widgets (e.g., `class MyButton extends ElevatedButton`) breaks because Material widgets have complex internal state, rendering pipelines, and theme interactions that assume they control their own subtree. Your override will collide with framework assumptions.

**When composition is the answer:** Always, for Material widgets. Wrap them, configure them, combine them — never subclass them.

**When inheritance IS acceptable:** Abstract base classes you own (e.g., a `BaseFormField` with shared validation logic that your team controls).

```dart
// BAD: Subclassing Material widgets breaks theme/state
class MyButton extends ElevatedButton { ... }

// GOOD: Compose — wrap and configure
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({super.key, required this.onPressed, required this.label});
  final VoidCallback? onPressed;
  final String label;

  @override
  Widget build(BuildContext context) {
    return FilledButton(onPressed: onPressed, child: Text(label));
  }
}
```

## Step 2: StatelessWidget vs StatefulWidget

**Problem:** Developers default to StatefulWidget "just in case," which adds lifecycle complexity and prevents `const` optimization. Others use StatelessWidget when they actually need disposal, causing memory leaks.

| Use StatelessWidget | Use StatefulWidget |
|--------------------|--------------------|
| UI depends only on constructor args | Widget owns mutable state (counters, toggles) |
| State comes from external source (Riverpod) | Owns controllers (Animation, TextEditing, Scroll, Focus) |
| Pure display / layout component | Needs initState/dispose for resource cleanup |

**Key rule:** If you find yourself using `late` variables or manual lifecycle management, you need StatefulWidget. If all data comes via constructor or provider, stay Stateless.

### Const Constructors

**Why it matters:** `const` lets Flutter skip rebuild entirely for subtrees whose inputs haven't changed. Without it, every parent rebuild recreates child widget objects even when nothing changed.

```dart
class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.label, this.color});
  final String label;
  final Color? color;
  // ...
}

// const at usage site — skip rebuild when parent rebuilds
const StatusBadge(label: 'Active')
```

**When `const` is NOT possible:** Constructor takes runtime values (`DateTime.now()`, API data), or uses non-const default values.

## Step 3: Choosing Material 3 Widgets

Instead of memorizing the full M3 catalog, apply these selection principles:

### Button Selection (by emphasis)

**Problem:** Teams pick buttons by visual preference, creating inconsistent action hierarchies that confuse users about what's important.

**Rule: One FilledButton per screen section.** It signals the primary action. Everything else descends in emphasis.

| Emphasis | Widget | When to use |
|----------|--------|-------------|
| Highest | `FilledButton` | Primary action (Submit, Save, Confirm) — one per visual group |
| High | `FilledButton.tonal` | Important but not primary (Edit, Share) |
| Medium | `OutlinedButton` | Alternative actions (Cancel, Skip) |
| Low | `TextButton` | Tertiary actions (Learn more, See details) |
| Icon-only | `IconButton` | When label is obvious from context (close, menu) |
| Screen-level | `FloatingActionButton` | The single most important action on the screen |

### Navigation Selection (by screen width)

| Width | Widget | Why |
|-------|--------|-----|
| Phone (<600px) | `NavigationBar` | Thumb-reachable, 3-5 destinations max |
| Tablet (600-1200px) | `NavigationRail` | Saves vertical space, works with landscape |
| Desktop (>1200px) | `NavigationDrawer` | Screen real estate available for labels |

### Input Selection

| Need | Widget | NOT this |
|------|--------|----------|
| Select from list | `DropdownMenu` | ~~DropdownButton~~ (legacy) |
| Toggle between 2-5 options | `SegmentedButton` | ~~ToggleButtons~~ (legacy) |
| Filter/tag selection | `FilterChip` / `ChoiceChip` | Custom containers with GestureDetector |
| Search | `SearchBar` + `SearchAnchor` | Custom TextField with manual overlay |

### The Catch-All Rule

**Before building a custom widget, check if M3 already has it.** The Flutter Material library covers ~95% of standard UI patterns. Custom widgets should be compositions of M3 widgets, not replacements.

## Step 4: Theming — ColorScheme and TextTheme

**Problem:** Hardcoded colors and font sizes create apps that break in dark mode, ignore accessibility settings, and require shotgun surgery to update branding.

**Rule: Never hardcode colors or text styles.** Always read from `Theme.of(context)`.

```dart
// BAD: Breaks in dark mode, ignores theme changes
Container(color: Color(0xFF6200EE))
Text('Error', style: TextStyle(color: Colors.red))

// GOOD: Adapts to theme automatically
final cs = Theme.of(context).colorScheme;
Container(color: cs.primaryContainer)
Text('Error', style: TextStyle(color: cs.error))
```

### ColorScheme Roles (mental model)

Think of roles in pairs — **surface + content on that surface**:

- `primary` / `onPrimary` — Brand actions and text on them
- `primaryContainer` / `onPrimaryContainer` — Subtle brand backgrounds
- `surface` / `onSurface` — Card and sheet backgrounds
- `error` / `onError` — Error states
- `secondary` / `onSecondary` — Accent elements

### TextTheme Scale

```dart
final tt = Theme.of(context).textTheme;
// Scale: display > headline > title > body > label
// Each has Large / Medium / Small variants
```

**Decision:** Use `bodyLarge`/`bodyMedium` for content, `titleMedium`/`titleLarge` for section headers, `labelSmall`/`labelMedium` for captions and chips. Display styles are for hero text only.

See [REFERENCE.md → App Theme Setup Template](REFERENCE.md#app-theme-setup-template) for a full light/dark theme setup with ColorScheme.fromSeed and ThemeExtension registration.

## Step 5: ThemeExtension — When and Why

**Problem:** Apps need design tokens beyond what ColorScheme and TextTheme provide (spacing scales, border radii, custom semantic colors). Without ThemeExtension, these become scattered constants that can't adapt to dark mode or respond to theme changes.

### Decision Boundaries

| Scenario | Use ThemeExtension? | Why |
|----------|-------------------|-----|
| Consistent spacing scale (xs/sm/md/lg) used across 10+ widgets | **Yes** | Shared token that should be theme-aware |
| App-specific semantic colors (successGreen, warningAmber) | **Yes** | Must adapt between light/dark mode |
| One-off padding on a single screen | **No** | `const EdgeInsets` is fine — don't over-engineer |
| Brand-specific elevation/shadow values | **Yes** | Changes if brand guidelines change |
| A margin between two specific widgets | **No** | Local constant, not a design token |

**Rule: Do NOT create a ThemeExtension for values used in fewer than 3 widgets.** Use a local constant instead. ThemeExtension earns its boilerplate only when the value is a genuine design token shared across the app.

### ThemeExtension Skeleton

```dart
class AppSpacing extends ThemeExtension<AppSpacing> {
  final double xs, sm, md, lg, xl;
  const AppSpacing({/* required fields */});

  static const regular = AppSpacing(xs: 4, sm: 8, md: 16, lg: 24, xl: 32);

  @override
  AppSpacing copyWith({/* nullable fields */}) => AppSpacing(/* ?? merge */);

  @override
  AppSpacing lerp(covariant AppSpacing? other, double t) {
    if (other == null) return this;
    return AppSpacing(/* lerpDouble each field */);
  }
}
```

**Why `lerp` matters:** Flutter calls `lerp` during animated theme transitions (`AnimatedTheme`, `Theme` changes in `MaterialApp`). Without it, your custom tokens snap instead of animating. If your app never animates theme changes, `lerp` still must exist (framework requires it) but can simply return `this`.

**Registration:** Add to `ThemeData(extensions: [AppSpacing.regular, ...])`.

**Usage:** `Theme.of(context).extension<AppSpacing>()!`

See [REFERENCE.md → ThemeExtension Full Template](REFERENCE.md#themeextension-full-template) for copyable implementation.

## Step 6: Responsive Layouts

**Problem:** Flutter runs on phones, tablets, and desktops. A single-column layout wastes tablet space; a multi-column layout is unusable on phones. You need breakpoint-driven layout switching.

### LayoutBuilder vs MediaQuery

| Tool | Use for | Why |
|------|---------|-----|
| `LayoutBuilder` | Widget-level responsiveness | Responds to available space (works inside dialogs, side panels) |
| `MediaQuery.sizeOf(context)` | Screen-level decisions | Full screen dimensions for top-level layout |

**Warning:** Always use `MediaQuery.sizeOf(context)`, never `MediaQuery.of(context).size`. The latter rebuilds on ANY MediaQuery change (keyboard, rotation, insets). The specific accessor only rebuilds when size changes.

### Breakpoint Pattern

**Breakpoint values:** 600/1200 are simplified from Material Design 3 window size classes (Compact <600, Medium 600–840, Expanded >840, Large >1200).

```dart
class ResponsiveLayout extends StatelessWidget {
  const ResponsiveLayout({super.key, required this.mobile, this.tablet, this.desktop});
  final Widget mobile;
  final Widget? tablet;
  final Widget? desktop;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      // >= 1200 → desktop, >= 600 → tablet, else → mobile
      // Fallback chain: desktop ?? tablet ?? mobile
    });
  }
}
```

See [REFERENCE.md → Responsive Layout Template](REFERENCE.md#responsive-layout-template) for full implementation.

### Adaptive Grid (No Breakpoints Needed)

**Why this is often better than breakpoints:** `SliverGridDelegateWithMaxCrossAxisExtent` lets Flutter calculate column count automatically. No magic numbers, works at every width.

```dart
GridView.builder(
  itemCount: items.length,
  gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
    maxCrossAxisExtent: 300, // Flutter calculates columns
    mainAxisSpacing: 16,
    crossAxisSpacing: 16,
  ),
  itemBuilder: (context, index) => ItemCard(item: items[index]),
)
```

## Step 7: Accessibility

**Problem:** 15-20% of users rely on assistive technology. Missing Semantics nodes make custom widgets invisible to screen readers. Fixed-height text containers break when users increase text size.

### The Three Rules

1. **Label non-text interactive/image elements** — screen readers need text for everything
2. **Touch targets >= 48x48 logical pixels** — motor impairment requires larger targets
3. **Never put text in fixed-height containers** — text scaling will clip or overflow

```dart
// Label images
Semantics(
  label: 'User profile photo',
  image: true,
  child: CircleAvatar(backgroundImage: NetworkImage(url)),
)

// Merge grouped content into single announcement
MergeSemantics(child: ListTile(leading: Icon(Icons.email), title: Text(email)))

// Exclude decorative elements from screen reader
ExcludeSemantics(child: DecorativeBackground())
```

```dart
// BAD: Clips text when user increases font size
SizedBox(height: 20, child: Text('Label'))

// GOOD: Grows with text
Text('Label', style: tt.bodyMedium)
```

**Contrast:** M3 ColorScheme handles contrast ratios automatically (4.5:1 normal text, 3:1 large text). If you use custom colors, verify contrast manually.

## Step 8: Widget Extraction — When and How

**Problem:** Developers either extract too early (premature abstraction with unused flexibility) or too late (300-line build methods that nobody can read or test).

### When to Extract

| Signal | Action |
|--------|--------|
| build() > 80 lines | Extract sub-widgets for readability |
| Same widget tree in 2+ places | Extract to shared widget (DRY) |
| Widget has its own state/logic | Extract to StatefulWidget |
| Needs independent testing | Extract for testability |

### When NOT to Extract

| Signal | Leave inline |
|--------|-------------|
| Widget tree used exactly once and < 40 lines | Extraction adds indirection without benefit |
| Extraction would require passing 5+ parameters | Prop-drilling is worse than inline code |
| "Might reuse later" without concrete second use | YAGNI — extract when the second use appears |

### Three Extraction Strategies

**Strategy 1: Private widget in same file** — for screen sections that don't need reuse.
```dart
class ProductPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(children: [_Header(), _ProductList(), _Footer()]);
  }
}
class _Header extends StatelessWidget { /* ... */ }
```

**Strategy 2: Public widget in separate file** — for cross-feature reuse.
```dart
// widgets/product_card.dart
class ProductCard extends StatelessWidget {
  const ProductCard({super.key, required this.product, this.onTap});
  // ...
}
```

**Strategy 3: Builder callback** — when extraction would create prop-drilling.
```dart
class DataList<T> extends StatelessWidget {
  const DataList({super.key, required this.items, required this.itemBuilder});
  final List<T> items;
  final Widget Function(BuildContext, T) itemBuilder;
  // ...
}
```

### File Organization

```
features/<name>/presentation/
├── pages/          # Screen-level widgets (Scaffold)
│   └── product_list_page.dart
└── widgets/        # Feature-scoped reusable widgets
    ├── product_card.dart
    └── product_filters.dart

shared/widgets/     # App-wide reusable widgets
├── buttons/
├── feedback/
└── layout/
```

## Common Anti-Patterns

| Anti-Pattern | Why it hurts | Fix |
|-------------|-------------|-----|
| Hardcoded colors/sizes | Breaks dark mode, ignores theme | Use ColorScheme, TextTheme, ThemeExtension |
| `MediaQuery.of(context)` | Rebuilds on ANY MediaQuery change | Use `MediaQuery.sizeOf(context)` |
| Deep nesting (>5 levels) | Unreadable, untestable | Extract sub-widgets (Step 8) |
| Business logic in build() | Mixing UI and logic | Move to controller/provider |
| Missing const constructors | Missed rebuild optimization | Add `const` to constructor and usage sites |
| ThemeExtension for one-off values | Boilerplate without benefit | Use local `const` instead |

## Quick Checklist (New Widget)

- [ ] `const` constructor if possible?
- [ ] Uses `Theme.of(context)` for colors/typography (no hardcoded values)?
- [ ] Responsive to different screen sizes?
- [ ] Semantic labels on interactive/image elements?
- [ ] Touch targets >= 48x48?
- [ ] build() under 80 lines?
- [ ] No hardcoded strings (use localization)?
- [ ] Key provided for list items?
