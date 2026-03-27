---
name: implementing-riverpod
description: Guides Riverpod 2.x state management with decision-first approach. Use when choosing provider types, implementing controllers, handling async state, deciding lifecycle (keepAlive vs autoDispose), or testing providers. Starts with WHY before HOW.
user-invocable: true
---

# Implementing Riverpod

State management decisions depend on what your state represents and how it changes. A derived value and a form controller need fundamentally different providers. This skill helps you make the right decisions — not just copy Riverpod boilerplate.

## When to Use This Skill

- Choosing the right provider type for a use case
- Implementing new providers or controllers
- Handling async state with AsyncValue
- Deciding keepAlive vs autoDispose lifecycle
- Understanding watch/read/listen and avoiding common mistakes
- Testing Riverpod providers

## When NOT to Use This Skill

- **Simple app-wide constants or config**: Use plain Dart constants or `String.fromEnvironment`. Providers add overhead for values that never change.
- **Ephemeral UI state** (animation controllers, scroll positions, TextEditingController): Use `StatefulWidget` or hooks. Providers exist for shared/cross-widget state, not local widget state.
- **Complex forms with many fields**: Consider `flutter_form_builder` or a dedicated form library. Riverpod Notifiers work for simple forms but become unwieldy with validation, field dependencies, and conditional logic across 10+ fields.
- **Global mutable singletons** (shared across the whole app with no reactive consumers): If nothing watches the value, a provider adds indirection without benefit. A plain service class suffices.

## Code Generation Setup

All providers use `@riverpod` annotation. Generated files: `*.g.dart` (providers), `*.freezed.dart` (immutable state with Freezed).

```yaml
# pubspec.yaml
dependencies:
  flutter_riverpod: ^2.6.1
  riverpod_annotation: ^2.6.1
dev_dependencies:
  riverpod_generator: ^2.6.3
  build_runner: ^2.4.0
```

```bash
dart run build_runner build --delete-conflicting-outputs
```

## Step 1: Choose the Right Provider Type

Before writing code, answer two questions:

1. **Does this state have methods that mutate it?** (Yes = class-based Notifier, No = function-based Provider)
2. **Is the initial value async?** (Yes = Future/Stream variant, No = sync variant)

### Provider Type Decision Matrix

| Your situation | Provider type | WHY this one |
|----------------|--------------|--------------|
| Derived/computed value, DI singleton | `@riverpod` function | No mutation needed — just compute and return. Rebuilds when dependencies change. |
| One-time async fetch, no mutations | `@riverpod` async function (FutureProvider) | Data flows one way (source → UI). Mutations go through a separate controller. |
| Real-time data stream | `@riverpod` Stream function (StreamProvider) | Wraps existing streams (Firestore, WebSocket) into reactive providers. |
| Sync state with methods | `@riverpod` class (Notifier) | State lives in memory, changed by user actions. `build()` returns initial value synchronously. |
| Async state with methods | `@riverpod` class with async `build()` (AsyncNotifier) | **Most common for screen controllers.** Fetches initial data, exposes mutation methods. |

### When Two Types Seem Equivalent

**FutureProvider vs AsyncNotifier with no methods?** Use FutureProvider. If you later need mutations, promote to AsyncNotifier — code generation makes this a one-line change (add a class wrapper).

**Notifier vs AsyncNotifier?** If `build()` does any I/O (API call, DB read), use AsyncNotifier. Notifier's `build()` must return synchronously.

## Step 2: Implement the Pattern

### Function-Based Providers (No Mutation)

```dart
// DI singleton — keepAlive because the repo outlives any screen
@Riverpod(keepAlive: true)
AuthRepository authRepository(Ref ref) {
  return AuthRepository(ref.watch(apiClientProvider));
}

// Parameterized fetch — autoDispose (default) because
// data is only needed while the screen displaying it exists
@riverpod
Future<Product> product(Ref ref, String id) async {
  return ref.watch(productRepoProvider).getById(id);
}
```

### AsyncNotifier Controller (Primary Screen Pattern)

**WHY AsyncNotifier for screen controllers:** It unifies loading/error/data states for the initial fetch AND subsequent mutations into one `AsyncValue<T>`, which the widget handles with a single `.when()`.

```dart
@riverpod
class LoginController extends _$LoginController {
  @override
  FutureOr<bool?> build() => null; // No initial fetch

  Future<bool> submit(String email, String password) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await ref.read(authServiceProvider).signIn(email, password);
      return true;
    });
    return !state.hasError;
  }
}
```

**Key detail:** `AsyncValue.guard()` replaces try-catch. It wraps the result as `AsyncData` or catches exceptions as `AsyncError` — no manual error handling needed.

### Notifier (Synchronous State)

**WHY Notifier over AsyncNotifier:** When state is local and synchronous (filters, toggles, counters), Notifier avoids unnecessary `AsyncValue` wrapping. The widget reads `state` directly without `.when()`.

```dart
@riverpod
class FilterNotifier extends _$FilterNotifier {
  @override
  ProductFilter build() => const ProductFilter();

  void setCategory(String? cat) {
    state = state.copyWith(category: cat);
  }
  void reset() => state = const ProductFilter();
}
```

See [REFERENCE.md → StreamProvider and Family Patterns](REFERENCE.md#streamprovider-and-family-patterns) for StreamProvider and multi-parameter family examples.

## Step 3: Consume Providers — watch, read, listen

These three methods exist because **widgets and callbacks have different lifecycle needs**. Using the wrong one causes bugs that are silent until production.

### The Rule and the WHY

| Method | Where | Rebuilds? | WHY it works there |
|--------|-------|-----------|-------------------|
| `ref.watch()` | `build()` | Yes | `build()` can be called many times. `watch` subscribes so the framework re-calls `build()` when state changes. This is reactive. |
| `ref.read()` | Callbacks, notifier methods | No | Callbacks fire once per interaction. You need the current value at that instant, not a subscription. `read` is a one-shot read. |
| `ref.listen()` | `build()` | No | For side effects (snackbars, navigation) that should trigger on state change but should NOT cause a widget rebuild. |

### Annotated Example

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

### The Three Mistakes That Burn Everyone

| Mistake | What happens | Fix |
|---------|-------------|-----|
| `ref.watch()` in a callback | Creates a new subscription every tap. Causes rebuild loops or memory leaks. | `ref.read()` |
| `ref.read()` in `build()` | Reads once, never updates. UI shows stale data silently. | `ref.watch()` |
| `ref.read(provider)` instead of `ref.read(provider.notifier)` | Reads the state value, not the controller. Methods don't exist on the value. | Add `.notifier` |

## Step 4: Handle Async State with AsyncValue

**WHY AsyncValue matters:** Every async provider wraps its state in `AsyncValue<T>`, which is a sealed union of `AsyncData`, `AsyncLoading`, and `AsyncError`. Handling all three prevents blank screens and swallowed errors.

### .when() — Exhaustive (Preferred)

```dart
asyncValue.when(
  data: (data) => ContentWidget(data: data),
  loading: () => const CircularProgressIndicator(),
  error: (error, stack) => ErrorWidget(message: '$error'),
)
```

### Refresh Without Losing Data

**Problem:** On pull-to-refresh, `.when()` shows the loading spinner, hiding the current data.

```dart
// Solution: skipLoadingOnRefresh keeps old data visible
asyncValue.when(
  skipLoadingOnRefresh: true,
  data: (data) => ContentWidget(data: data),
  loading: () => const LoadingIndicator(),
  error: (e, s) => ErrorWidget(error: e),
)
```

**WHY this works:** When `skipLoadingOnRefresh` is true and previous data exists, Riverpod treats the intermediate loading state as "data + loading" rather than pure loading, so the `data` callback still fires.

## Step 5: Decide Lifecycle — keepAlive vs autoDispose

**The default is autoDispose** (lowercase `@riverpod`). The provider is disposed when no widget watches it. This is correct for most cases.

### Decision Framework

| State type | Lifecycle | Annotation | WHY |
|-----------|-----------|------------|-----|
| Repository / Service | App lifetime | `@Riverpod(keepAlive: true)` | Shared infrastructure. Creating/destroying on each screen is wasteful and loses connection state. |
| Screen controller | Screen lifetime | `@riverpod` (default) | State is screen-specific. Keeping it alive leaks memory and shows stale data on re-entry. |
| User session | Until logout | `@Riverpod(keepAlive: true)` | Must survive screen transitions. Invalidate manually on logout. |
| Search results, form state | While viewing | `@riverpod` (default) | Ephemeral. User expects fresh state on return. |
| Cached API response | Time-limited | `@riverpod` + `ref.keepAlive()` | Auto-dispose by default, but extend with a timer for cache windows. |

### Conditional Cache Pattern

```dart
@riverpod
Future<UserProfile> userProfile(Ref ref, String userId) async {
  final link = ref.keepAlive(); // Prevent auto-dispose
  Timer(const Duration(minutes: 5), link.close); // Auto-expire
  return ref.watch(userRepoProvider).getProfile(userId);
}
```

**WHY this pattern:** Bridges the gap between "dispose immediately" and "keep forever". Useful for data that is expensive to fetch but stale after a time window.

## Step 6: Invalidation and Refresh

```dart
ref.invalidate(productsProvider);      // Mark stale, rebuild on next read
ref.refresh(productsProvider);          // Invalidate + immediate rebuild
ref.invalidate(productProvider('abc')); // Invalidate specific family instance
ref.invalidateSelf();                   // Inside a notifier, invalidate yourself
```

**WHY invalidate vs refresh:** Use `invalidate` when you know data is stale but no one may be watching (lazy rebuild). Use `refresh` when you need the new value right now (e.g., pull-to-refresh returning a Future).

## Architecture Integration

```
Widget (ConsumerWidget)
    | ref.watch()
Controller (AsyncNotifier, autoDispose)
    | ref.read()
Service (Provider, keepAlive)
    | ref.watch()
Repository (Provider, keepAlive)
    |
Data Source (API, Database)
```

**Rules and WHY:**
- **Widgets `watch` controllers** — reactive UI updates
- **Controllers `read` services in methods** — one-shot action, not a subscription (methods are callbacks)
- **Services `watch` repos in `build()`** — `build()` is reactive context, dependencies are injected reactively
- **Repos/Services are `keepAlive`** — shared infrastructure, outlives any screen
- **Controllers are `autoDispose`** — screen-scoped, prevents stale state and memory leaks

## Testing Strategy

### Philosophy

Riverpod's testability comes from **dependency injection via overrides**. The pattern is always:

1. Create a `ProviderContainer` with mock overrides for dependencies
2. Read the provider under test
3. Assert on the result

You are NOT testing Riverpod's framework — you are testing YOUR logic. Override the layer below, test the layer you care about.

### Annotated Test Example

```dart
test('LoginController.submit returns true on success', () async {
  // 1. Override the dependency, not the provider under test
  final container = ProviderContainer(overrides: [
    authServiceProvider.overrideWithValue(MockAuthService()),
  ]);
  addTearDown(container.dispose);

  // 2. Stub the mock behavior
  when(() => container.read(authServiceProvider).signIn(any(), any()))
      .thenAnswer((_) async {});

  // 3. Exercise the notifier
  final notifier = container.read(loginControllerProvider.notifier);
  final result = await notifier.submit('a@b.com', 'pass');

  // 4. Assert on both return value and state
  expect(result, true);
  expect(container.read(loginControllerProvider).hasError, false);
});
```

**Widget tests** follow the same pattern but wrap with `ProviderScope(overrides: [...])` instead of `ProviderContainer`. See [REFERENCE.md → Widget Testing](REFERENCE.md#widget-testing-with-riverpod) for the template.

### What to Test, What to Skip

| Test | Worth it? | WHY |
|------|-----------|-----|
| AsyncNotifier methods (submit, delete, update) | Yes | Your business logic lives here |
| Provider that just returns a repository instance | No | Testing constructor delegation, not logic |
| `.when()` rendering in widget test | Yes, sparingly | Verify loading/error/data states render correctly |
| Family provider with different params | Yes, if logic varies by param | Ensures parameterized behavior |

## Pre-Implementation Checklist

- [ ] Chose provider type using Step 1 decision matrix?
- [ ] Correct lifecycle? (keepAlive for services, autoDispose for controllers)
- [ ] `watch` in build, `read` in callbacks, `listen` for side effects?
- [ ] AsyncValue handled with `.when()` — all three states covered?
- [ ] Family parameters use records for multiple values?
- [ ] Tests override dependencies, not the provider under test?
- [ ] Ran `dart run build_runner build` after changes?
