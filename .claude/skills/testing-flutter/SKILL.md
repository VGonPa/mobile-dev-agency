---
name: testing-flutter
description: Guides Flutter testing strategy and implementation. Use when deciding what to test, writing unit/widget/integration/golden tests, mocking with mocktail, testing Riverpod state management, or structuring test suites. Starts with what to test vs skip, then mock boundaries, then patterns.
user-invocable: true
---

# Testing Flutter

Testing strategy, mock boundaries, and decision frameworks for Flutter applications. This skill helps you decide WHAT to test and WHERE to mock — not just how to write test syntax.

## When to Use This Skill

- Deciding what tests to write for new or changed code
- Choosing between unit, widget, integration, or golden tests
- Determining where to place mock boundaries
- Testing Riverpod providers and state management
- Structuring test files and naming conventions
- Debugging flaky or failing tests

## When NOT to Use This Skill

- **Setting up CI pipelines** — that's DevOps, not test strategy
- **Debugging app behavior** — use the debugger or logging, not tests
- **Learning Riverpod** — read the Riverpod docs first, then come back to test it
- **Performance profiling** — use Flutter DevTools, not test assertions

## Testing Philosophy

### The Core Principle

**Test behavior, not implementation.** A good test answers: "does this produce the right output for a given input?" A bad test answers: "does this call method X exactly once?"

Why: Implementation tests break when you refactor. Behavior tests break when actual behavior changes — which is exactly when you want them to break.

### What to Test (Priority Order)

| Priority | What | Why | Coverage Target |
|----------|------|-----|-----------------|
| 1 | Business logic (Services/Use Cases) | Core value of the app, complex rules | >=90% |
| 2 | State management (Controllers) | User-facing behavior, state transitions | >=80% |
| 3 | Repositories (data access) | Data integrity, error handling | >=80% |
| 4 | Widgets (user interactions) | UX correctness for key flows | Key flows only |
| 5 | Models (if has logic) | Data consistency | Custom methods only |

### What NOT to Test

- **Generated code** (`.g.dart`, `.freezed.dart`) — already tested by package authors
- **Framework internals** — Flutter/Riverpod work; don't verify they do
- **Trivial getters/setters** — no logic means no bugs to catch
- **UI styling details** — golden tests for visual regression are brittle; use sparingly
- **Third-party package behavior** — you don't own it, don't test it

**100% coverage is NOT the goal.** Meaningful tests that catch real bugs are. Chasing coverage numbers leads to testing trivial code and ignoring error paths.

## Test Type Decision Guide

```
"I need to test..."

Business logic, calculations, rules?
  -> Unit test (fast, isolated, most valuable)

State changes in response to user actions?
  -> Unit test with ProviderContainer

Widget renders correctly for different states?
  -> Widget test with provider overrides

User flow across multiple screens?
  -> Integration test (slow, use sparingly — max 3-5 critical flows)

Visual appearance hasn't regressed?
  -> Golden test (brittle — only for design-system components)
```

## Mock Boundary Strategy

### Where to Mock (and Why There)

```
Controller (REAL)       <-- Tests real state transitions
    |
Service (REAL)          <-- Tests real business logic
    |
Repository (MOCKED)    <-- Mock HERE: this is the I/O boundary
    |
Firebase / HTTP / DB    <-- Never touched in tests
```

**Why mock at the repository boundary:**

1. **Repositories are I/O boundaries.** They talk to Firebase, HTTP, databases — things that are slow, stateful, and non-deterministic. Everything above them is pure logic.
2. **Mocking higher up skips the logic you care about.** If you mock the service, you're not testing your business rules at all.
3. **Mocking lower down (e.g., `HttpClient`) couples tests to implementation.** If you switch from Dio to `http`, every test breaks — even though behavior hasn't changed.

**Exception:** Mock at the service level when testing a controller that orchestrates multiple services. You've already tested each service independently.

### Mocking with Mocktail

**Why mocktail over mockito:** No code generation. Mocks are plain Dart classes, readable and fast.

```dart
// Create mocks — one line each, at top of test file
class MockUserRepository extends Mock implements UserRepository {}

// Fakes: required when using any() matchers
// Why: Dart needs a real type to pass as fallback when matcher doesn't match
class FakeUser extends Fake implements User {}

void main() {
  setUpAll(() {
    registerFallbackValue(FakeUser()); // Register ONCE, before all tests
  });
}
```

**Rule:** Only mock what you own. If you don't control the interface, wrap it in a class you do control, then mock the wrapper.

## The Annotated Test Pattern

Every test follows Arrange-Act-Assert (AAA). Here is one fully annotated example — all other test types are variations of this pattern.

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

// WHY setUp + late: each test gets a fresh mock, preventing state bleed
// between tests. Shared mutable state is the #1 cause of flaky tests.
class MockUserRepository extends Mock implements UserRepository {}

void main() {
  late UserService service;
  late MockUserRepository mockRepo;

  setUp(() {
    mockRepo = MockUserRepository();
    service = UserService(mockRepo);
  });

  group('UserService', () {
    group('getUser', () {
      test('should return user when found', () async {
        // Arrange — configure the mock to return a known value
        // WHY thenAnswer (not thenReturn): the method returns a Future
        when(() => mockRepo.getUser('123'))
            .thenAnswer((_) async => testUser);

        // Act — call the ONE thing being tested
        final result = await service.getUser('123');

        // Assert — verify the BEHAVIOR (output), not the implementation
        expect(result, equals(testUser));
        // NOTE: we do NOT verify mockRepo.getUser was called.
        // That's testing implementation. If the result is correct,
        // it doesn't matter HOW the service got it.
      });

      test('should throw when user not found', () async {
        // WHY test error paths: the happy path is obvious.
        // Bugs hide in error handling, null states, and edge cases.
        when(() => mockRepo.getUser('999'))
            .thenThrow(UserNotFoundException());

        expect(
          () => service.getUser('999'),
          throwsA(isA<UserNotFoundException>()),
        );
      });
    });
  });
}
```

### When to Use `verify()`

Use `verify()` only when the **side effect IS the behavior**:

```dart
// GOOD: the purpose of logout IS to clear the session
test('logout clears session', () async {
  await service.logout();
  verify(() => mockRepo.clearSession()).called(1);
});

// BAD: verifying internal wiring, not behavior
test('getUser calls repository', () async {
  when(() => mockRepo.getUser(any())).thenAnswer((_) async => testUser);
  await service.getUser('123');
  verify(() => mockRepo.getUser('123')).called(1); // So what?
});
```

## Riverpod Testing

### ProviderContainer for Unit Tests

```dart
test('authProvider returns authenticated state', () async {
  final mockRepo = MockAuthRepository();
  when(() => mockRepo.getCurrentUser())
      .thenAnswer((_) async => testUser);

  final container = ProviderContainer(
    overrides: [
      // WHY overrideWithValue: inject mock at the provider level,
      // so the real provider tree uses our mock for I/O
      authRepositoryProvider.overrideWithValue(mockRepo),
    ],
  );
  // WHY addTearDown: ProviderContainers hold state and listeners.
  // Without disposal: memory leaks, state bleeds across tests,
  // and you get mysterious flaky failures that pass in isolation.
  addTearDown(container.dispose);

  final authState = await container.read(authProvider.future);
  expect(authState, isA<Authenticated>());
});
```

### Widget Tests with Riverpod

```dart
testWidgets('displays user name from provider', (tester) async {
  // WHY ProviderScope with overrides: same mock boundary strategy,
  // but now the widget tree reads from overridden providers
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        userProvider.overrideWith((ref) => testUser),
      ],
      child: const MaterialApp(home: UserPage()),
    ),
  );

  expect(find.text(testUser.name), findsOneWidget);
});
```

## Widget Test Timing

| Method | Use When | Why |
|--------|----------|-----|
| `pump()` | Advance one frame | You need precise control over timing |
| `pump(duration)` | Animations, debounce | Wait a specific amount of time |
| `pumpAndSettle()` | Wait for all frames to finish | Convenient but dangerous — see below |

**Pitfall:** `pumpAndSettle()` times out if there's an infinite animation (loading spinner, shimmer effect). It waits forever for "no more frames," which never happens. Use `pump()` instead and assert against the intermediate state.

## Common Pitfalls

| Pitfall | Why It Hurts | Fix |
|---------|-------------|-----|
| Testing implementation, not behavior | Refactoring breaks tests even when behavior is correct | Assert on outputs, not on mock call counts |
| Too many assertions per test | When it fails, you don't know which behavior broke | One test = one behavior |
| Shared mutable state | State from test A leaks into test B = flaky | Fresh mocks in `setUp()`, dispose in `addTearDown()` |
| Not testing error paths | Happy path is obvious; bugs hide in errors and edge cases | Write at least one error test per method |
| `pumpAndSettle` timeout | Infinite animation present | Use `pump()` and assert intermediate state |
| Missing `await` | Test passes before async work completes | Always `await` async operations before assertions |

## Test Organization

### File Structure

```
test/
├── unit/
│   ├── services/        # Business logic tests (highest priority)
│   ├── controllers/     # State management tests
│   └── repositories/    # Data access tests (mocking external APIs)
├── widget/
│   ├── pages/           # Full page widget tests
│   └── widgets/         # Reusable component tests
├── integration/         # End-to-end flows (keep minimal)
├── mocks/               # Shared mock classes (DRY across test files)
├── fixtures/            # JSON test data, factory methods
└── helpers/             # pumpApp extensions, test utilities
```

### Test Naming

```dart
group('ClassName', () {
  group('methodName', () {
    test('should [expected behavior] when [condition]', () {});
  });
});
```

**Why this format:** When a test fails, the output reads as a sentence: `ClassName > methodName > should return user when found`. You know exactly what broke without reading the test body.

## Coverage

```bash
flutter test --coverage
genhtml coverage/lcov.info -o coverage/html
open coverage/html/index.html
```

Use coverage to find **untested error paths**, not to chase a number.

See [REFERENCE.md](REFERENCE.md) for full test templates (widget tests, integration tests, golden tests, model tests, test helpers).
