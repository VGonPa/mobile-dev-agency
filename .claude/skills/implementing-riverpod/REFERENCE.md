# Implementing Riverpod — Implementation Reference

Implementation templates for patterns described in [SKILL.md](SKILL.md). Every template here corresponds to a decision made in SKILL.md — don't implement without reading the decision context first.

## Full Widget Example — watch/read/listen

Complete annotated `ConsumerWidget` showing all three ref methods in context. See [SKILL.md → Step 3](SKILL.md#step-3-consume-providers--watch-read-listen) for the decision rules.

```dart
class ProductListScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // WATCH: reactive — rebuilds when products change
    final productsAsync = ref.watch(productsProvider);

    // LISTEN: side effect — shows snackbar, no rebuild
    ref.listen(cartProvider, (prev, next) {
      if (next.items.length > (prev?.items.length ?? 0)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Added to cart')),
        );
      }
    });

    return productsAsync.when(
      data: (products) => ListView.builder(
        itemCount: products.length,
        itemBuilder: (_, i) => ProductCard(
          product: products[i],
          // READ: one-shot in callback — no subscription needed
          onAddToCart: () =>
              ref.read(cartProvider.notifier).add(products[i]),
        ),
      ),
      loading: () => const CircularProgressIndicator(),
      error: (err, _) => ErrorDisplay(error: err),
    );
  }
}
```

**WHY this structure:** `watch` in `build()` creates the reactive subscription. `listen` hooks into the same reactive flow but triggers side effects without rebuilding. `read` in the `onAddToCart` callback is a one-shot — no subscription, just the current value at tap time.

## StreamProvider and Family Patterns

**When needed:** Real-time data from Firestore, WebSocket, or any `Stream` source.

```dart
// StreamProvider wraps an existing stream into Riverpod's
// reactive system. The widget gets AsyncValue<T> automatically.
@riverpod
Stream<List<Message>> messages(Ref ref, String channelId) {
  final repo = ref.watch(messageRepositoryProvider);
  return repo.watchMessages(channelId);
}
// Usage: ref.watch(messagesProvider('general'))
```

### Multiple Parameters — Use Records

**WHY records:** Riverpod code generation requires a single parameter for family providers. Dart records give you named fields with automatic equality (no manual `==` or `hashCode`).

```dart
@riverpod
Future<List<Product>> filteredProducts(
  Ref ref,
  ({String category, double? maxPrice}) filter,
) async {
  return ref.watch(productRepoProvider).filter(
    category: filter.category,
    maxPrice: filter.maxPrice,
  );
}
// Usage: ref.watch(filteredProductsProvider(
//   (category: 'shoes', maxPrice: 100),
// ))
```

## Provider Scoping and Overrides

**When needed:** Environment-specific configuration, feature-level theme/config overrides.

```dart
// App-level override (environment config)
void main() {
  runApp(ProviderScope(
    overrides: [
      apiBaseUrlProvider.overrideWithValue('https://staging.api.com'),
    ],
    child: const MyApp(),
  ));
}

// Feature-level scoping (nested ProviderScope)
ProviderScope(
  overrides: [themeProvider.overrideWithValue(darkTheme)],
  child: SettingsPage(),
)
```

**WHY ProviderScope for overrides:** Riverpod's DI container is the `ProviderScope`. Nesting scopes lets you override providers for a subtree without affecting the rest of the app — useful for theming, feature flags, or testing.

## AsyncValue Advanced Patterns

### Loading Overlay (Keep Previous Data Visible)

**When needed:** Pull-to-refresh, pagination, or any reload where hiding current data hurts UX.

```dart
// Manual check for "loading but has previous data"
if (asyncValue.isLoading && asyncValue.hasValue) {
  return Stack(children: [
    ContentWidget(data: asyncValue.value!),
    const LoadingOverlay(),
  ]);
}
```

### AsyncValue.guard() — Try-Catch Replacement

**WHY guard:** Eliminates boilerplate try-catch in every notifier method. Wraps the async operation and sets state to either `AsyncData(result)` or `AsyncError(exception)` automatically.

```dart
// Inside an AsyncNotifier method:
state = const AsyncValue.loading();
state = await AsyncValue.guard(() async {
  return await repository.fetchData();
});
// state is now AsyncData(result) or AsyncError(exception)
```

## Widget Testing with Riverpod

**Pattern:** Same as unit testing but use `ProviderScope` wrapping `MaterialApp` instead of bare `ProviderContainer`.

```dart
testWidgets('ProductList shows products', (tester) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        productsProvider.overrideWith((ref) => [
          Product(id: '1', name: 'Widget Test Product'),
        ]),
      ],
      child: const MaterialApp(home: ProductListScreen()),
    ),
  );
  await tester.pumpAndSettle();
  expect(find.text('Widget Test Product'), findsOneWidget);
});
```

**WHY `overrideWith` in widget tests:** In unit tests you override dependencies (the layer below). In widget tests you may also override the provider itself to control exactly what the widget sees — skipping the real async fetch entirely.

## Common Anti-Patterns Reference

| Anti-Pattern | Problem | Root Cause | Fix |
|-------------|---------|------------|-----|
| `ref.watch()` in callback | Rebuild loop | `watch` creates a subscription; callbacks fire outside `build()` | Use `ref.read()` |
| `ref.read()` in build | Stale data | `read` is a one-shot; `build()` never re-triggers | Use `ref.watch()` |
| Missing `.notifier` | Reads value, not controller | `ref.read(p)` returns state; `ref.read(p.notifier)` returns the class | Add `.notifier` for method calls |
| `keepAlive` on controllers | Memory leak, stale state | Controller outlives its screen, shows old data on re-entry | Use default autoDispose |
| Watching in notifier constructor | Lifecycle crash | Notifier isn't fully initialized during construction | Watch in `build()` method only |
| Not running code generation | Provider not found at runtime | `*.g.dart` files are stale or missing | Run `build_runner build` |
