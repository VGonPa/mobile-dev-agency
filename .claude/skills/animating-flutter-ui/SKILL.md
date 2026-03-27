---
name: animating-flutter-ui
user-invocable: true
description: Implements Flutter animations and transitions. Use when adding implicit/explicit animations, page transitions, Hero animations, staggered lists, or integrating Rive/Lottie. Covers AnimationController, Curves, Tween, TweenAnimationBuilder, and Material 3 motion patterns.
---

# Animating Flutter UI

Animation patterns, decision frameworks, and motion design for Flutter applications.

## When to Use This Skill

- Choosing between implicit and explicit animations
- Adding animations to widgets (fade, slide, scale, rotate)
- Implementing page transitions or Hero animations
- Creating staggered list animations
- Deciding between custom animations and third-party libraries (Rive, Lottie)
- Following Material 3 motion guidelines
- Ensuring accessibility with reduced motion support

## Animation Decision Framework

### Complexity Ladder

Start at the top. Only move down when the simpler approach can't do what you need.

```
Level 1: Implicit Animation (AnimatedContainer, AnimatedOpacity)
  → Property changes triggered by state. No controller. Flutter interpolates.
  → 90% of UI animations belong here.

Level 2: TweenAnimationBuilder
  → One-shot or state-driven animation, still no controller.
  → Combines multiple properties (scale + opacity) in one builder.

Level 3: AnimatedSwitcher
  → Automatic cross-fade/scale when swapping between child widgets.
  → Loading → loaded, tab switching, icon toggling.

Level 3.5: AnimatedBuilder
  → Rebuilds only the builder function when an Animation changes.
  → Most common explicit animation widget — pairs with AnimationController.
  → Use over *Transition widgets when combining multiple effects or custom painting.

Level 4: Explicit Animation (AnimationController)
  → Full control: repeat, reverse, sequence, gesture-driven, stagger.
  → Loading spinners, complex choreography, physics-based motion.
  → Requires lifecycle management (init, dispose, vsync).

Level 5: Third-Party (flutter_animate, Lottie, Rive)
  → Designer-created assets, complex declarative chains, interactive vector art.
  → Adds dependency. Use when custom code would be disproportionate effort.
```

### When NOT to Animate

- **Data loading without visual feedback** — Show skeleton/shimmer instead of custom animation
- **Every state change** — Animation fatigue degrades UX. Reserve for meaningful transitions
- **Complex sequences on low-end devices** — Profile first; skip or simplify if janky
- **When the user has reduced motion enabled** — Always check `MediaQuery.disableAnimationsOf(context)`

## Implicit Animations

**WHY:** Simplest approach. You declare the end state; Flutter interpolates to it automatically. No controller, no lifecycle management, no dispose. Covers ~90% of UI animation needs.

**WHEN:** Any property change triggered by `setState()` or state management rebuild — size, color, position, padding, opacity.

**WHEN NOT:** Continuous/repeating motion, complex sequencing, gesture-driven animation, or animating between two different child widgets (use AnimatedSwitcher for that).

```dart
// AnimatedContainer — the most versatile implicit widget
// WHY this one: animates size, color, padding, margin, decoration all at once
class ExpandableCard extends StatefulWidget {
  const ExpandableCard({super.key});
  @override
  State<ExpandableCard> createState() => _ExpandableCardState();
}

class _ExpandableCardState extends State<ExpandableCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => setState(() => _expanded = !_expanded),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300), // M3: 200-500ms for simple transitions
        curve: Curves.easeInOutCubicEmphasized,       // M3 standard curve
        width: _expanded ? 200 : 100,
        height: _expanded ? 200 : 100,
        decoration: BoxDecoration(
          color: _expanded
              ? Theme.of(context).colorScheme.primaryContainer
              : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(_expanded ? 16 : 8),
        ),
        child: Center(child: Icon(_expanded ? Icons.close : Icons.add)),
      ),
    );
  }
}
```

### Choosing the Right Implicit Widget

> See the **Implicit Animation Widgets** table in [REFERENCE.md](REFERENCE.md) for the full list of widgets, what they animate, and when to use each one.

## TweenAnimationBuilder

**WHY:** Bridges the gap between implicit (too simple) and explicit (too complex). Lets you combine multiple animated properties in one builder function — without managing an AnimationController.

**WHEN:** Entrance animations on build, progress-driven UI, combining scale + opacity, animating a value that isn't covered by an implicit widget.

**WHEN NOT:** Repeating/looping animations (use explicit). Gesture-driven scrubbing (use explicit with `_controller.value = gestureProgress`).

```dart
// WHY TweenAnimationBuilder here: combines scale + opacity in one animation,
// plays automatically on build, no controller to manage
TweenAnimationBuilder<double>(
  tween: Tween(begin: 0.0, end: _isVisible ? 1.0 : 0.0),
  duration: const Duration(milliseconds: 300),
  curve: Curves.easeOutCubic,  // M3 entering curve
  builder: (context, value, child) {
    return Transform.scale(
      scale: 0.8 + (0.2 * value),  // Scale from 80% to 100%
      child: Opacity(opacity: value, child: child),
    );
  },
  child: const Card(child: Text('Animated content')),  // child is cached, not rebuilt
)
```

**Key insight:** The `child` parameter is passed through to `builder` without rebuilding. Put expensive widgets there.

## AnimatedSwitcher

**WHY:** Automatically animates when you swap one child widget for another. The old child fades/scales out while the new one fades/scales in.

**WHEN:** Loading → loaded state, tab content switching, icon toggling (check ↔ close), counter digit changes.

**CRITICAL:** AnimatedSwitcher detects changes via the child's `key`. Without a unique key per state, it won't animate because it thinks nothing changed.

```dart
// WHY AnimatedSwitcher: automatically cross-fades between two widget states
AnimatedSwitcher(
  duration: const Duration(milliseconds: 300),
  transitionBuilder: (child, animation) {
    return FadeTransition(
      opacity: animation,
      child: ScaleTransition(scale: animation, child: child),
    );
  },
  // CRITICAL: ValueKey tells AnimatedSwitcher the child changed
  child: _isComplete
      ? const Icon(Icons.check, key: ValueKey('check'))
      : const Icon(Icons.close, key: ValueKey('close')),
)
```

**Common mistake:** Forgetting the `key` — without it, AnimatedSwitcher sees "same widget type" and does nothing.

## Explicit Animations (AnimationController)

**WHY:** Full control over timing, direction, repetition, and sequencing. You own the animation lifecycle.

**WHEN:** Repeating/pulsing animations (loading spinner), gesture-driven scrubbing, staggered sequences, physics-based motion, animations that need to reverse or pause.

**WHEN NOT:** Simple property changes on state update (use implicit — it's 80% less code). One-shot entrance animations (use TweenAnimationBuilder).

```dart
// WHY explicit here: repeating pulse animation that implicit can't do
class PulsingDot extends StatefulWidget {
  const PulsingDot({super.key});
  @override
  State<PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<PulsingDot>
    with SingleTickerProviderStateMixin {  // vsync prevents off-screen ticking
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,  // REQUIRED: ties animation to widget's visibility
    );
    _scale = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _controller.repeat(reverse: true);  // Continuous pulse
  }

  @override
  void dispose() {
    _controller.dispose();  // ALWAYS dispose — prevents memory leaks
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(scale: _scale, child: const CircularAvatar());
  }
}
```

### Lifecycle Rules (Non-Negotiable)

1. **`vsync: this`** — Always use `SingleTickerProviderStateMixin` (one controller) or `TickerProviderStateMixin` (multiple). Prevents animation ticking when widget is off-screen.
2. **`dispose()`** — Always dispose the controller. Forgetting this is the #1 animation memory leak.
3. **`mounted` check** — If starting animation after an async gap (`Future.delayed`, API call), check `if (mounted)` before calling `_controller.forward()`.

> See [REFERENCE.md](REFERENCE.md) for controller methods, transition widget mapping, and Tween types.

## Page Transitions

**WHY:** Screen-to-screen transitions define app personality. The default `MaterialPageRoute` uses a platform-appropriate transition, but custom transitions create a distinctive feel.

**WHEN:** The default platform transition doesn't match your design language, or you want consistent cross-platform transitions.

**WHEN NOT:** Standard navigation where platform conventions are appropriate — users expect familiar transitions.

```dart
// Material 3 recommended: subtle fade + slide up
// WHY this combination: feels modern, works on both platforms, respects M3 motion tokens
class M3PageRoute<T> extends PageRouteBuilder<T> {
  final Widget page;
  M3PageRoute({required this.page})
      : super(
          transitionDuration: const Duration(milliseconds: 500),     // M3 standard
          reverseTransitionDuration: const Duration(milliseconds: 200), // M3 exit
          pageBuilder: (_, __, ___) => page,
          transitionsBuilder: (_, animation, __, child) {
            final curvedAnimation = CurvedAnimation(
              parent: animation,
              curve: Curves.easeInOutCubicEmphasized,  // M3 standard curve
            );
            return FadeTransition(
              opacity: curvedAnimation,
              child: SlideTransition(
                position: Tween(
                  begin: const Offset(0, 0.05),  // Subtle: only 5% vertical offset
                  end: Offset.zero,
                ).animate(curvedAnimation),
                child: child,
              ),
            );
          },
        );
}
```

**GoRouter integration:**

```dart
// CustomTransitionPage applies custom transitions within GoRouter
GoRoute(
  path: '/details',
  pageBuilder: (context, state) => CustomTransitionPage(
    child: const DetailsScreen(),
    transitionsBuilder: (context, animation, secondaryAnimation, child) =>
        FadeTransition(opacity: animation, child: child),
  ),
)
```

## Hero Animations

**WHY:** Creates visual continuity between screens. The user's eye follows a shared element (image, avatar, card) from one screen to the next, reducing cognitive load.

**WHEN:** List → detail screens, profile avatar → profile page, thumbnail → full-screen image.

**WHEN NOT:** When the two screens don't share a visually similar element — forced Hero transitions feel unnatural.

```dart
// Source screen — wrap the tappable element
Hero(
  tag: 'product-${product.id}',  // Must be globally unique
  child: Image.network(product.imageUrl, width: 80, height: 80),
)

// Destination screen — same tag, same widget type
Hero(
  tag: 'product-${product.id}',  // Identical tag triggers the animation
  child: Image.network(product.imageUrl, width: double.infinity, height: 300),
)
```

**Rules:**
- `tag` must be **unique across the entire widget tree** (use entity IDs, not indices)
- Both Hero children should be the **same widget type** for smooth morphing
- Works automatically with `MaterialPageRoute`; custom routes need `transitionsBuilder`
- **Pitfall:** Duplicate tags cause runtime errors — common with list items using index as tag

## Staggered List Animation

**WHY:** Sequentially revealing list items (each delayed slightly after the previous) feels polished and intentional. All items appearing simultaneously feels abrupt.

**WHEN:** Dashboard cards, onboarding steps, search results, any vertical list on first load.

**WHEN NOT:** Lists that scroll infinitely (only animate visible items on first build), or when the user has reduced motion enabled.

**Pattern:** Each item gets an `AnimationController` with a delayed start based on its index (`index * 100ms`). Combine `SlideTransition` (vertical offset) + `FadeTransition` (opacity 0→1).

**Key implementation points:**
- Check `if (mounted)` before calling `forward()` after `Future.delayed`
- Dispose every controller — each list item has its own
- Cap the delay for large lists (e.g., max 10 items animated, rest appear instantly)
- Use `Curves.easeOut` for entering elements (M3 convention)

**AnimatedList:** For lists where items are inserted or removed dynamically, use Flutter's built-in `AnimatedList` widget with a `GlobalKey<AnimatedListState>` — it animates insertions and removals automatically via `insertItem()` / `removeItem()`.

> See [REFERENCE.md](REFERENCE.md) for complete staggered list and AnimatedList (insert/remove) implementations.

## Third-Party Animation Libraries

### Decision Table

| Library | Best For | Adds Dependency | Skill Required |
|---------|----------|----------------|----------------|
| **None (built-in)** | Most UI animations | No | Flutter animation API |
| **flutter_animate** | Declarative chaining of multiple effects | ~50KB | Minimal |
| **Lottie** | Designer-created After Effects animations | ~200KB + JSON assets | Designer + developer |
| **Rive** | Interactive vector animations with state machines | ~300KB + .riv assets | Rive editor + developer |

### When to Use Each

**flutter_animate** — When you want to chain multiple animation effects declaratively without managing controllers. Good for prototyping and one-off flourishes.

```dart
// WHY flutter_animate: 4 chained effects in 4 lines vs ~60 lines of manual code
Text('Hello')
    .animate()
    .fadeIn(duration: 600.ms)
    .slideY(begin: 0.3, end: 0)
    .then(delay: 200.ms)  // Sequential timing
    .shake();
```

**Lottie** — When designers deliver After Effects animations as JSON. Common for: success/error states, onboarding illustrations, branded loading spinners. Don't use for simple fades or slides — overkill.

**Rive** — When you need **interactive** vector animations with state machines (button hover states, character reactions, data visualizations that respond to input). Higher setup cost than Lottie but far more interactive.

> See [REFERENCE.md](REFERENCE.md) for Lottie and Rive initialization code snippets.

## Accessibility: Reduced Motion

**Non-negotiable.** Some users experience motion sickness, vestibular disorders, or simply prefer less movement. Always check the platform's reduced motion setting.

```dart
@override
Widget build(BuildContext context) {
  // Checks iOS "Reduce Motion", Android "Remove Animations", and app-level overrides
  final reduceMotion = MediaQuery.disableAnimationsOf(context);

  return AnimatedContainer(
    duration: reduceMotion
        ? Duration.zero                          // Instant transition
        : const Duration(milliseconds: 300),
    curve: Curves.easeInOut,
    // ... properties
  );
}

// For explicit animations: jump to end state immediately
if (!reduceMotion) {
  _controller.forward();
} else {
  _controller.value = 1.0;  // Skip animation, show final state
}
```

**Rule:** Essential animations (loading indicators, progress bars) can still animate with reduced motion — shorten duration and simplify the curve. Decorative animations must be eliminated entirely.

## Performance

1. **RepaintBoundary** — Wrap animated widgets to isolate repaints from siblings. Critical for animations inside complex layouts.
2. **Dispose controllers** — The #1 animation memory leak. No exceptions.
3. **Transform over layout** — `Transform.translate` is a paint-only operation (cheap). Changing `Padding` or `Positioned` triggers layout (expensive).
4. **vsync** — Always use `TickerProviderStateMixin`. Without it, animations tick even when the widget is off-screen.
5. **Impeller renderer** — Eliminates shader compilation jank. Animations are smooth from the first frame on iOS (default) and Android (opt-in).
6. **Limit concurrent animations** — More than 3-4 simultaneous explicit animations on low-end devices causes jank. Stagger or simplify.

## Common Pitfalls

| Pitfall | Symptom | Fix |
|---------|---------|-----|
| Missing `key` on AnimatedSwitcher children | No animation when child changes | Add `ValueKey` per state |
| Forgetting `controller.dispose()` | Memory leak, "called after dispose" errors | Always dispose in `dispose()` |
| Using `pumpAndSettle()` in tests | Test timeout with infinite animations | Use `pump(duration)` instead |
| Animating layout properties | Janky on low-end devices | Use `Transform` (paint-only) instead |
| Ignoring reduced motion | Accessibility violation, motion sickness | Check `MediaQuery.disableAnimationsOf` |
| `Future.delayed` without `mounted` check | "setState called after dispose" | Guard with `if (mounted)` |
