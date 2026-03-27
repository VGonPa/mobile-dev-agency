# Optimizing Flutter Performance — Implementation Reference

Implementation templates for patterns described in [SKILL.md](SKILL.md). Every template here corresponds to a mechanism explained in SKILL.md — don't implement without understanding the WHY first.

## Const Widget Pattern

**Mechanism:** Enables Flutter's widget identity optimization. See SKILL.md Build Optimization.

```dart
// Making your widget const-eligible:
class MetricCard extends StatelessWidget {
  const MetricCard({super.key, required this.label, required this.value});
  final String label;  // All fields must be final
  final int value;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(children: [
        Text(label),
        Text('$value', style: Theme.of(context).textTheme.headlineMedium),
      ]),
    );
  }
}

// Now usable as const when arguments are known at compile time:
const MetricCard(label: 'Steps', value: 0) // Canonicalized, never rebuilt
```

**Lint rule:** Add to `analysis_options.yaml`:

```yaml
linter:
  rules:
    prefer_const_constructors: true
    prefer_const_declarations: true
    prefer_const_literals_to_create_immutables: true
```

## Image Caching Setup

**Mechanism:** Manages multiple image resolutions with disk + memory caching. See SKILL.md Image Optimization.
**When needed:** Apps displaying remote images at multiple sizes (thumbnails + detail views).

```dart
// pubspec.yaml: cached_network_image: ^3.3.0

import 'package:cached_network_image/cached_network_image.dart';

CachedNetworkImage(
  imageUrl: url,
  memCacheWidth: 200,     // Memory cache at display size
  placeholder: (_, __) => const SizedBox(
    width: 100, height: 100,
    child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
  ),
  errorWidget: (_, __, ___) => const Icon(Icons.broken_image),
  fadeInDuration: const Duration(milliseconds: 200),
)
```

**Cache configuration (app startup):**

```dart
// Limit disk cache to prevent unbounded storage growth
// Default: 200 files, 500MB — adjust for your app
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

final cacheManager = CacheManager(Config(
  'app_image_cache',
  stalePeriod: const Duration(days: 7),
  maxNrOfCacheObjects: 200,
));
```

## Long-Lived Isolates

**Mechanism:** Avoids repeated isolate spawn overhead (~2-5ms). See SKILL.md Heavy Computation.
**When needed:** Frequent heavy operations (real-time data processing, continuous JSON parsing).

```dart
import 'dart:async';
import 'dart:isolate';

/// Long-lived worker for repeated heavy operations of the same type.
/// Use instead of compute() when the same operation runs frequently.
///
/// Usage:
///   final worker = await ReusableWorker.spawn(expensiveTransform);
///   final result = await worker.run(inputData);
///   worker.dispose(); // When done
class ReusableWorker<T, R> {
  final Isolate _isolate;
  final SendPort _commandPort;

  ReusableWorker._(this._isolate, this._commandPort);

  /// [function] must be a top-level or static function.
  static Future<ReusableWorker<T, R>> spawn<T, R>(
    R Function(T) function,
  ) async {
    final initPort = ReceivePort();
    final isolate = await Isolate.spawn(
      _entry<T, R>,
      (initPort.sendPort, function),
    );
    // First message from isolate is its command SendPort
    final commandPort = await initPort.first as SendPort;
    return ReusableWorker._(isolate, commandPort);
  }

  /// Send work to the isolate and await the result.
  Future<R> run(T input) async {
    final responsePort = ReceivePort();
    _commandPort.send((input, responsePort.sendPort));
    return await responsePort.first as R;
  }

  void dispose() => _isolate.kill(priority: Isolate.beforeNextEvent);

  static void _entry<T, R>((SendPort, R Function(T)) init) {
    final (initPort, function) = init;
    final commandPort = ReceivePort();
    initPort.send(commandPort.sendPort);

    commandPort.listen((message) {
      final (T input, SendPort replyPort) = message;
      replyPort.send(function(input));
    });
  }
}
```

**Trade-off:** Long-lived isolates consume memory even when idle (~2-5MB). Dispose when no longer needed. For infrequent operations, `compute()` is simpler.

## Memory Leak Detection Workflow

**When needed:** Memory grows over time, especially after navigating between screens.

### Step-by-Step in DevTools

1. **Open DevTools** → Memory tab
2. **Take a baseline snapshot** on the home screen
3. **Navigate to the suspect screen** and back, 10 times
4. **Take another snapshot** — compare to baseline
5. **If memory grew:** The leak is on the screen you navigated to

### What to Look For

```
Snapshot 1 (baseline):   45MB
After 10 navigations:    45MB ± 2MB  → No leak
After 10 navigations:    65MB        → Leak! ~2MB per navigation
```

### Common Culprits Checklist

```dart
// Check 1: Stream subscriptions without cancel
// Search for: .listen( without corresponding .cancel()
// Fix: Store subscription, cancel in dispose()

// Check 2: Controllers without dispose
// Search for: Controller() without .dispose()
// Fix: Dispose in dispose()

// Check 3: addListener without removeListener
// Search for: .addListener( without .removeListener(
// Fix: Store callback reference, remove in dispose()

// Check 4: Closures capturing BuildContext
// Search for: callbacks storing context long-term
// Fix: Use widget references, not context, in long-lived callbacks
```

### Automated Leak Detection (debug mode)

```dart
// Enable in your app's main.dart (debug only)
void main() {
  // Flutter's built-in leak tracker (available since 3.18)
  // Reports leaks to console when widgets are GC'd without dispose
  assert(() {
    LeakTracking.start();
    return true;
  }());
  runApp(const MyApp());
}
```

## SliverList for Mixed Scrollable Content

**When needed:** Combining app bars, grids, and lists in a single scrollable view.
**Mechanism:** Slivers share a single viewport, enabling lazy building across heterogeneous content types.

```dart
CustomScrollView(
  slivers: [
    const SliverAppBar(
      title: Text('Products'),
      floating: true,
    ),
    SliverPadding(
      padding: const EdgeInsets.all(16),
      sliver: SliverList.builder(
        itemCount: products.length,
        itemBuilder: (context, i) => ProductCard(
          key: ValueKey(products[i].id),
          product: products[i],
        ),
      ),
    ),
  ],
)
```

**Trade-off:** Slivers are more complex to compose than regular widgets. Only use `CustomScrollView` when you need multiple scrollable sections (app bar + list, or grid + list). For a simple list, `ListView.builder` is sufficient.

## Performance Overlay Setup

**Quick toggle for frame-time visualization during development:**

```dart
MaterialApp(
  showPerformanceOverlay: true, // Two graphs: UI thread (top), Raster (bottom)
)
```

**Reading the overlay:**
- Green line = 16ms target (60fps)
- Bars above the green line = jank
- Top graph spikes = expensive `build()` or layout
- Bottom graph spikes = expensive paint or compositing
