---
name: optimizing-flutter-performance
description: Optimizes Flutter app performance using framework-aware decisions. Use when diagnosing jank, reducing rebuilds, optimizing lists/images, profiling with DevTools, fixing memory leaks, or improving startup time. Starts with mechanism explanations so you fix root causes, not symptoms.
user-invocable: true
---

# Optimizing Flutter Performance

Performance optimization starts with understanding Flutter's rendering pipeline. Without knowing WHY something is slow, you'll apply cargo-cult fixes that add complexity without measurable improvement. This skill teaches the mechanism first, then the fix.

## When to Use This Skill

- App has jank (dropped frames) or slow scrolling
- Diagnosing excessive widget rebuilds
- Optimizing list rendering or image loading
- Profiling with Flutter DevTools
- Detecting and fixing memory leaks
- Improving app startup time

## When NOT to Use This Skill

This skill covers rendering and runtime performance. It does NOT cover:

- **Architecture decisions** (choosing Riverpod vs Bloc, app structure) — use state management skill
- **State management patterns** (where to put state, how to structure providers) — wrong lever for performance
- **UI/UX design** (layout choices, navigation patterns) — performance constraints shouldn't drive design decisions upfront
- **Build-time optimization** (tree shaking, AOT compilation flags) — handled by Flutter toolchain defaults

**Rule of thumb:** If you haven't profiled yet, don't optimize. Premature optimization based on intuition is wrong more often than right. Profile first (`flutter run --profile`), identify the bottleneck, then apply the relevant section below.

## Performance Targets

| Metric | Target | Red Flag |
|--------|--------|----------|
| Frame time (60fps) | <16ms | >32ms |
| Frame time (120fps) | <8ms | >16ms |
| Jank rate | <1% of frames | >5% |
| App memory | <150MB simple apps | Continuous growth |
| Cold start | <3 seconds | >5 seconds |

## Flutter's Rendering Pipeline — The Mental Model

Understanding this pipeline tells you WHERE your bottleneck lives:

```
Widget tree → Element tree → RenderObject tree → Layer tree → GPU
  (build)     (reconcile)      (layout/paint)     (composite)
```

1. **Build phase** (UI thread): Your `build()` methods run. Flutter diffs the new widget tree against the element tree.
2. **Layout phase** (UI thread): RenderObjects compute sizes and positions.
3. **Paint phase** (UI thread): RenderObjects paint to layers.
4. **Composite phase** (Raster thread): Layers are flattened and sent to the GPU.

**Key insight:** Most performance problems live in the build phase — doing too much work in `build()`, rebuilding too many widgets, or triggering rebuilds unnecessarily.

## Build Optimization

### Use `const` Constructors

**Mechanism:** When Flutter reconciles the widget tree, it compares new widgets to existing ones. A `const` widget is canonicalized at compile time — the same instance is reused. Flutter's `Widget.operator==` sees the identical instance and skips the entire subtree reconciliation.

```dart
// WITHOUT const: new instance every build, forces subtree diff
SizedBox(height: 16),
Text('Static text'),

// WITH const: same instance reused, subtree skipped entirely
const SizedBox(height: 16),
const Text('Static text'),
```

**Trade-off:** None. `const` is free. The only cost is remembering to add it. Enable `prefer_const_constructors` lint to catch misses.

**To enable const on your widgets:** Add `const` constructor + make all fields `final`. See [REFERENCE.md -> Const Widget Pattern](REFERENCE.md#const-widget-pattern).

### Minimize Rebuild Scope

**Mechanism:** `setState()` marks the entire `State` object dirty. Flutter rebuilds that widget AND its entire subtree. If `setState` is called on a widget high in the tree, everything below it rebuilds — even widgets whose data didn't change.

```dart
// BAD: setState at top rebuilds everything
class _HomeState extends State<Home> {
  int _counter = 0;
  void _increment() => setState(() => _counter++);

  Widget build(BuildContext context) {
    return Column(children: [
      ExpensiveHeader(),   // Rebuilds unnecessarily!
      Text('$_counter'),   // Only this needs the counter
      ExpensiveFooter(),   // Rebuilds unnecessarily!
    ]);
  }
}
```

**Fix:** Push state down to the smallest widget that needs it. Extract the counter into its own `StatefulWidget` so `setState` only rebuilds the counter display.

**Trade-off:** More widget classes = more files to navigate. Don't split widgets that are already cheap to build (<1ms). Only split when profiling shows the parent `build()` is expensive.

### Don't Compute in build()

**Mechanism:** `build()` can be called 60+ times per second during animations. Any computation inside it runs every frame. Flutter gives you no warning — it just gets slower.

```dart
// BAD: O(n log n) sort runs every frame
Widget build(BuildContext context) {
  final sorted = List.from(items)..sort();
  return ListView(children: sorted.map(ItemWidget.new).toList());
}

// GOOD: sort once when data changes, not on every build
void _onDataChanged(List<Item> newItems) {
  _sorted = List.from(newItems)..sort();
  setState(() {});
}
```

**Trade-off:** Caching results means managing cache invalidation. For simple cases, just move the computation to the event handler that triggers `setState`.

## RepaintBoundary

**Mechanism:** By default, Flutter paints the entire RenderObject subtree into a single layer. When ANY widget in that subtree changes, the entire layer repaints. `RepaintBoundary` creates a NEW compositing layer — isolating its subtree so changes inside don't trigger repaints outside (and vice versa).

```dart
// Isolate an animation from the rest of the UI
RepaintBoundary(
  child: AnimatedProgressBar(), // Only this layer repaints
)
```

**Good candidates:** Animations, scrolling content, video players, custom painters that update frequently.

**Trade-off:** Each `RepaintBoundary` allocates a separate GPU layer. Layers consume GPU memory (~1-4MB each depending on size). Too many boundaries = GPU memory pressure and compositing overhead. **Profile with `debugRepaintRainbowEnabled = true`** to see which areas actually repaint before adding boundaries.

**Rule:** Don't add `RepaintBoundary` speculatively. Only add when DevTools shows a specific repaint problem.

## List Optimization

### Use ListView.builder for Long Lists

**Mechanism:** `ListView(children: [...])` instantiates ALL child widgets immediately, regardless of visibility. For 10,000 items, that's 10,000 widget builds before the first frame renders. `ListView.builder` is lazy — it only builds widgets currently visible in the viewport (plus a small buffer), and disposes them when they scroll out.

```dart
// BAD: 10,000 widgets built upfront
ListView(
  children: items.map((item) => ItemWidget(item)).toList(),
)

// GOOD: only ~15 visible items built at a time
ListView.builder(
  itemCount: items.length,
  itemBuilder: (context, i) => ItemWidget(item: items[i]),
)
```

**Trade-off:** `ListView.builder` can't intrinsically know total scroll extent without building items. If items have variable heights, scroll position estimation is approximate (the scrollbar may jump). Fix with `itemExtent` for fixed-height items — this gives O(1) scroll offset calculation.

### Use itemExtent or prototypeItem

**Mechanism:** Without a known item height, Flutter must build and layout items to compute scroll extent. `itemExtent` tells Flutter the exact height, enabling O(1) offset computation and eliminating layout passes for offscreen items.

```dart
ListView.builder(
  itemCount: items.length,
  itemExtent: 72.0,  // Every item is exactly 72px
  itemBuilder: (context, i) => ItemWidget(item: items[i]),
)
```

**Trade-off:** Only works when all items are the same height. For variable-height items, use `prototypeItem` (Flutter measures one instance and assumes the rest match) or accept the approximate scrollbar.

### Keys for Stable List Identity

**Mechanism:** When Flutter reconciles a list, it matches widgets by position by default. If an item is inserted at index 0, every existing item appears to have "changed" (item at index 1 looks like it used to be at index 0, etc.), forcing all items to rebuild. `ValueKey` lets Flutter match by identity, preserving state and minimizing rebuilds.

```dart
ListView.builder(
  itemBuilder: (context, index) => ProductCard(
    key: ValueKey(products[index].id), // Match by ID, not position
    product: products[index],
  ),
)
```

**Trade-off:** Keys add a small per-item comparison cost during reconciliation. Only use when list order changes (reorder, insert, delete). For append-only lists, positional matching is fine.

## Image Optimization

### Decode at Display Size

**Mechanism:** `Image.network(url)` decodes the full-resolution image into GPU memory. A 4000x3000 photo = ~48MB in RGBA. If displayed at 100x100, that's 47.9MB wasted. `cacheWidth`/`cacheHeight` tell the image codec to downsample during decode — the full image never enters memory.

```dart
// BAD: 48MB in GPU memory for a thumbnail
Image.network(url)

// GOOD: ~160KB in GPU memory (100x100 * 2 for retina)
Image.network(
  url,
  cacheWidth: 200, cacheHeight: 200,
  fit: BoxFit.cover,
)
```

**Trade-off:** If the same image is displayed at multiple sizes (thumbnail then fullscreen), each size requires a separate decode. Use `cached_network_image` package to manage multiple resolutions with disk caching. See [REFERENCE.md -> Image Caching Setup](REFERENCE.md#image-caching-setup).

### Precache Critical Images

**Mechanism:** `precacheImage` loads and decodes the image before the widget that displays it is built, avoiding a visible pop-in during the first frame.

```dart
@override
void didChangeDependencies() {
  super.didChangeDependencies();
  precacheImage(const AssetImage('assets/hero.png'), context);
}
```

**Trade-off:** Precaching consumes memory immediately, even if the user never scrolls to that image. Only precache above-the-fold images that are visible on first render.

## Heavy Computation — Isolates

**Mechanism:** Dart is single-threaded. The UI thread runs your code AND Flutter's rendering pipeline on the same thread. If your code takes 100ms, that's 6 dropped frames. `compute()` spawns a new Dart isolate (separate memory + thread), runs the function, and returns the result via message passing.

```dart
// BAD: blocks UI thread for ~500ms
void processData() {
  final result = items.map((i) => expensiveTransform(i)).toList();
  setState(() => data = result);
}

// GOOD: runs on separate isolate
void processData() async {
  final result = await compute(expensiveTransform, items);
  setState(() => data = result);
}
// Must be top-level or static function (closures can't cross isolate boundary)
static List<Item> expensiveTransform(List<Item> input) { ... }
```

**Trade-off:** `compute()` has ~2-5ms overhead for isolate spawn + message serialization. For operations under 16ms, the overhead makes it slower than running on the UI thread. **Rule of thumb:** only use `compute()` for operations that take >50ms.

**For frequent heavy work:** Spawn a long-lived isolate with `Isolate.spawn` instead of paying the spawn cost every time. See [REFERENCE.md -> Long-Lived Isolates](REFERENCE.md#long-lived-isolates).

## Memory Leak Prevention

**Mechanism:** Flutter widgets have a lifecycle: `initState` -> `build` -> `dispose`. Any resource acquired in `initState` that holds a reference to the widget's `State` (listeners, subscriptions, controllers) will prevent garbage collection if not released in `dispose()`. The `State` object stays alive, and so does everything it references.

### The One Rule: Acquire in initState, Release in dispose

Every resource follows the same pattern: create/subscribe in `initState`, clean up in `dispose`.

```dart
class _MyState extends State<MyWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animCtrl;
  late final StreamSubscription _sub;
  final _textCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(vsync: this, duration: 300.ms);
    _sub = someStream.listen((data) => setState(() {}));
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _sub.cancel();
    _textCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }
}
```

**Common leak sources and their cleanup:**

| Resource | Acquire | Clean up in dispose() |
|----------|---------|----------------------|
| `StreamSubscription` | `.listen()` | `.cancel()` |
| `TextEditingController` | constructor | `.dispose()` |
| `ScrollController` | constructor | `.dispose()` |
| `AnimationController` | constructor | `.dispose()` |
| `FocusNode` | constructor | `.dispose()` |
| `ChangeNotifier` listener | `.addListener()` | `.removeListener()` |

**Trade-off:** None. This is not optional. Undisposed resources are bugs, not trade-offs. If you find yourself managing many resources, consider using `hooks_riverpod` or `flutter_hooks` which auto-dispose.

**Detecting leaks:** Use DevTools Memory tab. Navigate to a screen and back 10 times. If memory grows linearly, something on that screen isn't being disposed. See [REFERENCE.md -> Memory Leak Detection Workflow](REFERENCE.md#memory-leak-detection-workflow).

## Common Anti-Patterns

### Opacity Widget for Hiding

**Mechanism:** `Opacity(opacity: 0, child: widget)` still lays out AND paints the child — it just makes the result invisible. The child's `build()`, layout, and paint all execute. For complex widgets, this is pure waste.

```dart
// BAD: still builds, lays out, and paints
Opacity(opacity: 0, child: ExpensiveWidget())

// GOOD: removed from tree entirely
if (isVisible) ExpensiveWidget(),

// GOOD: Visibility handles it, maintains layout space if needed
Visibility(visible: isVisible, child: ExpensiveWidget())
```

**Trade-off:** Removing from the tree (`if`) loses widget state. If you need to preserve state while hidden, use `Offstage` (maintains state, skips paint, still runs layout) or `Visibility(maintainState: true)`.

### Unbounded Image Cache

**Mechanism:** Flutter's `ImageCache` defaults to 1000 images / 100MB. For image-heavy apps (social feeds, galleries), this can consume excessive memory. Set reasonable limits based on your app's usage pattern.

```dart
PaintingBinding.instance.imageCache.maximumSize = 100;
PaintingBinding.instance.imageCache.maximumSizeBytes = 50 << 20; // 50MB
```

**Trade-off:** Smaller cache = more network re-fetches. Monitor cache hit rate via `ImageCache.liveImageCount` vs `ImageCache.currentSize` to find the right balance.

## Impeller Renderer

Impeller is Flutter's modern rendering engine replacing Skia:

- **iOS**: Default since Flutter 3.16
- **Android**: Default since Flutter 3.38
- **Key benefit**: Eliminates shader compilation jank (all shaders pre-compiled at build time)

**Impact on profiling:** If you see first-frame jank with Impeller, it's widget building or data loading, not shaders. Focus on the build phase.

## DevTools Profiling

### Quick Start

```bash
flutter run --profile  # ALWAYS profile in profile mode, not debug
# Press 'v' to open DevTools in browser
```

### Reading the Timeline

| What You See | Meaning | Fix |
|-------------|---------|-----|
| Tall UI bars (>16ms) | Expensive `build()` methods | Reduce rebuild scope, move computation out |
| Tall Raster bars (>16ms) | Complex painting operations | Add RepaintBoundary, simplify custom painters |
| Both tall | Overall architecture issue | Profile specific screens, isolate the bottleneck |
| Regular spikes | Periodic work (timers, polling) | Debounce, move to isolate |

### Custom Timeline Markers

```dart
import 'dart:developer' as developer;

developer.Timeline.startSync('expensive_operation');
// ... operation ...
developer.Timeline.finishSync();
```

## Optimization Checklist

- [ ] Profiled in `--profile` mode (not debug) — debug is 10x slower
- [ ] `const` constructors on all eligible widgets
- [ ] `ListView.builder` for lists >20 items
- [ ] Images decoded at display size (`cacheWidth`/`cacheHeight`)
- [ ] Heavy computation (>50ms) off UI thread via `compute()`
- [ ] All controllers, subscriptions, and listeners disposed
- [ ] `RepaintBoundary` only where profiling shows repaint problems
- [ ] No expensive operations in `build()`
- [ ] No `Opacity(0)` for hiding widgets
- [ ] Memory stable over repeated navigation (check in DevTools)

## Quick Diagnosis

| Symptom | Likely Cause | Mechanism | Fix |
|---------|-------------|-----------|-----|
| Scroll jank | ListView without builder | All items built upfront | `ListView.builder` |
| First-frame lag | Expensive `build()` | Too much work before first paint | Move computation outside build |
| Growing memory | Undisposed resources | References prevent GC | Dispose in `dispose()` |
| Slow images | Full-resolution decode | 48MB per 4K image in GPU memory | `cacheWidth`/`cacheHeight` |
| Choppy animations | Repaints crossing boundaries | Entire layer repainted | `RepaintBoundary` (profile first) |
| UI freezes | Computation on UI thread | Single-threaded Dart | `compute()` for >50ms work |
