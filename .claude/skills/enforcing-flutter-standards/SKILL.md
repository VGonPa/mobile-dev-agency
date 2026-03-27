---
name: enforcing-flutter-standards
description: Enforces Flutter code quality standards with reasoning-driven rules. Use PROACTIVELY when creating Dart files, writing functions, implementing features, or reviewing code. Covers code style, const usage, widget design, error handling patterns, import organization, and file size management. Starts with context assessment to apply rules proportionally.
user-invocable: true
---

# Enforcing Flutter Standards

Every rule here has a WHY. If you can't explain why a rule matters, you're enforcing cargo cult — not quality. This skill provides reasoning-driven code standards so the right choice is obvious in context.

## When to Use This Skill

- Creating new Dart files or classes
- Writing functions, methods, or providers
- Implementing features or fixing bugs
- Reviewing code for quality issues
- Deciding between competing patterns (Either vs AsyncValue.guard vs try/catch)

## When NOT to Use This Skill

| Situation | Use Instead |
|-----------|-------------|
| Architecture decisions (feature structure, layer boundaries) | `designing-flutter-architecture` |
| State management strategy (Riverpod patterns, when to use StateNotifier vs AsyncNotifier) | `designing-flutter-architecture` |
| Security concerns (storage, API keys, pinning) | `securing-flutter-apps` |
| Deployment, CI/CD, release configuration | Project-specific documentation |
| Performance profiling and optimization | Flutter DevTools + project benchmarks |

## Const Usage — Why It Matters

**WHY:** `const` widgets are canonicalized at compile time. The framework skips the entire subtree rebuild because it knows the widget instance hasn't changed (same identity in memory). On a screen with 200 widgets, marking 50 as `const` means 50 fewer `build()` calls on every frame that triggers a rebuild.

**Rule:** Add `const` wherever the analyzer suggests it.

### Where const applies

```dart
// Widget constructors — mark const when all fields are final
// WHY: Lets parent rebuilds skip this entire subtree
class ProfileCard extends StatelessWidget {
  const ProfileCard({super.key, required this.name});
  final String name;
}

// Widget instances with literal arguments
// WHY: Compile-time constant = zero allocation at runtime
const SizedBox(height: 16),
const EdgeInsets.all(8),
const Text('Static text'),

// Collections with known values
// WHY: Allocated once, shared across all usages
const colors = [Colors.red, Colors.blue];
```

### Where const does NOT apply

```dart
// Dynamic values — the compiler cannot evaluate these at compile time
SizedBox(height: spacing),   // Variable
Text(userName),               // Variable
```

## Widget Design — Classes Over Functions

**WHY:** Widget functions (`Widget buildHeader()`) look simpler but bypass three Flutter optimizations:
1. **No `Key` support** — Flutter can't track identity across rebuilds, causing state loss in lists
2. **No `const` possible** — parent rebuilds always rebuild the function's output
3. **No rebuild boundary** — the function's output is part of the parent's `build()`, so any parent state change rebuilds it

```dart
// AVOID: Widget function — no key, no const, no rebuild boundary
Widget buildHeader() => Container(
  padding: const EdgeInsets.all(16),
  child: const Text('Header'),
);

// PREFER: Widget class — has key, can be const, is a rebuild boundary
class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: const Text('Header'),
    );
  }
}
```

### When to extract a sub-widget

Extract when any of these apply:
- Widget tree branch exceeds ~40 lines (readability threshold)
- Same subtree appears in 2+ places (DRY)
- Section has its own distinct state or logic (separation of concerns)
- File is approaching 300 lines (see File Size below)

## Error Handling — Choosing the Right Pattern

Three patterns exist. Each belongs to a specific layer. Using the wrong one creates inconsistency and leaks concerns across boundaries.

### Decision Table

| Layer | Pattern | WHY This Pattern |
|-------|---------|-----------------|
| **Controllers / Notifiers** | `AsyncValue.guard()` | Riverpod's `AsyncValue` is the UI contract. `guard()` catches exceptions and wraps them into `AsyncError`, which `ref.watch()` can pattern-match in the widget. Manual try/catch would require you to manually set `state = AsyncError(...)` — `guard()` does it in one line. |
| **Services** | `try/catch` → log + `rethrow` | Services are the logging boundary. They add context (what operation failed, with what inputs) then rethrow so the controller can handle it. Swallowing exceptions here hides bugs. |
| **Repositories** | `Either<Failure, T>` | Repositories talk to external systems (Firestore, HTTP). `Either` makes failure a first-class return value — the caller is forced to handle both paths. This prevents "forgot to catch" bugs that crash the app when the network is flaky. |

### Pattern Examples

```dart
// CONTROLLER: AsyncValue.guard — lets Riverpod manage loading/error/data states
Future<bool> submit(Data data) async {
  state = const AsyncValue.loading();
  state = await AsyncValue.guard(() async {
    await _service.process(data);
    return true;
  });
  return !state.hasError;
}

// SERVICE: try/catch — log context, then rethrow for caller to handle
Future<Result> process(Data data) async {
  try {
    return await _repository.save(data);
  } catch (e, st) {
    _logger.severe('Failed to process data=${data.id}', e, st);
    rethrow; // Controller's AsyncValue.guard will catch this
  }
}

// REPOSITORY: Either — makes failure explicit in the type signature
Future<Either<Failure, Entity>> getEntity(String id) async {
  try {
    final doc = await _firestore.collection('entities').doc(id).get();
    if (!doc.exists) return Left(NotFoundFailure('Entity $id not found'));
    return Right(Entity.fromJson(doc.data()!));
  } catch (e) {
    return Left(ServerFailure(e.toString()));
  }
}
```

### When patterns overlap

| Scenario | Decision |
|----------|----------|
| Controller calls repository directly (no service layer) | Use `AsyncValue.guard()`. The controller is still the UI boundary. |
| Service doesn't need logging | Still use try/catch + rethrow — the pattern keeps the option open and is consistent. A bare `await` that throws gives no stack context. |
| Simple one-shot operation (e.g., toggle a boolean) | `AsyncValue.guard()` in the controller is sufficient. No need for Either in a trivial repo call. |
| Repository operation that can't meaningfully fail differently | Return the value directly (no Either). Reserve Either for operations with distinguishable failure modes. |

## Import Organization

**WHY:** Consistent import ordering makes it instantly visible whether a file depends on external packages, Flutter framework, or internal code — critical for understanding coupling at a glance.

**Strict order: Dart SDK -> Flutter SDK -> External packages -> Project imports**

```dart
// 1. Dart SDK
import 'dart:async';
import 'dart:io';

// 2. Flutter SDK
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// 3. External packages (alphabetical)
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

// 4. Project imports (relative within feature, package for cross-feature)
import '../model/user.dart';
import 'user_repository.dart';
```

**Rules and reasoning:**
- **Blank line between each group** — visual separator makes the grouping scannable
- **Alphabetical within each group** — eliminates merge conflicts from random ordering
- **Relative imports within the same feature** — signals "this is internal to this feature"
- **Package imports for cross-feature** — signals "this is a dependency on another feature"
- **Never import `dart:mirrors`** — not available in AOT-compiled Flutter, will crash at runtime

## File Size — 200-300 Lines Target

**WHY:** Files over 300 lines have measurably higher defect density. They're harder to review in PRs (reviewers skim after ~250 lines), harder to test in isolation, and create merge conflicts more frequently because multiple developers touch the same file.

### Splitting strategies

**1. Extract sub-widgets** — most common for UI files:
```
Before: screens/profile_screen.dart (350 lines)
After:  screens/profile_screen.dart (80 lines)
        widgets/profile_header.dart (70 lines)
        widgets/profile_stats.dart (60 lines)
```

**2. Split large services** — separate by responsibility:
```
Before: services/user_service.dart (400 lines)
After:  services/user_auth_service.dart (120 lines)
        services/user_profile_service.dart (150 lines)
```

**3. Extract constants** — when magic numbers accumulate:
```dart
// constants/profile_constants.dart
const maxBioLength = 300;
const defaultAvatarSize = 80.0;
const profilePadding = EdgeInsets.all(16);
```

**4. Separate model concerns** — when a model grows sub-objects:
```
models/user.dart          // Core user model
models/user_stats.dart    // Stats sub-model
models/user_settings.dart // Settings sub-model
```

## Boolean Naming

**WHY:** Booleans without predicates read ambiguously. `bool open` — is it "open the thing" (imperative) or "is it open?" (state)? The `is/has/can/should` prefix makes the intent unambiguous and reads naturally in conditionals: `if (isOpen)` vs `if (open)`.

```dart
// AVOID: Ambiguous
bool open = true;
bool data = false;

// PREFER: Predicate prefix makes meaning clear
bool isOpen = true;      // State
bool hasData = false;    // Possession
bool canSubmit = true;   // Capability
bool shouldRefresh = false; // Recommendation
```

## Naming Smells

**WHY:** Vague names force every reader to trace back to the source to understand what `data` or `temp` contains. Descriptive names make the code self-documenting and reduce the need for comments.

```dart
// AVOID: Forces reader to look up what getData() returns
var data = getData();
Widget buildThing() => ...;

// PREFER: Name describes the content
var userProfile = getUserProfile();
Widget buildUserAvatar() => ...;
```

## Code Generation Files

**WHY:** Forgetting `part` directives causes confusing "undefined class" errors that look like import problems. Forgetting to run `build_runner` after changes causes stale generated code that compiles but behaves incorrectly (old JSON keys, missing freezed methods).

```dart
// Always include part directives for generated code
part 'my_controller.g.dart';   // Riverpod
part 'user.freezed.dart';      // Freezed
part 'user.g.dart';            // JSON serialization

// After ANY change to annotated code:
// dart run build_runner build --delete-conflicting-outputs
```

## analysis_options.yaml — Principles

**WHY:** The linter is your first line of defense — it catches issues before code review. But a 76-rule YAML dump teaches nothing. Here are the principles; see your project's `analysis_options.yaml` for the actual rules.

### Key principles

1. **Start from a base ruleset** (`package:flutter_lints/flutter.yaml` or `very_good_analysis`) — don't hand-pick 50 rules
2. **Exclude generated files** — `*.g.dart`, `*.freezed.dart`, `lib/generated/**` should never trigger lint errors
3. **Promote warnings to errors** for critical rules — `missing_return: error`, `missing_required_param: error`
4. **Enable const enforcement** — `prefer_const_constructors`, `prefer_const_literals_to_create_immutables`
5. **Enable Dart 3 patterns** — `use_enums`, `use_super_parameters`

If the project doesn't have an `analysis_options.yaml`, see [REFERENCE.md -> Recommended analysis_options.yaml](REFERENCE.md#recommended-analysis_optionsyaml) for a starter configuration.

## Quick Checklist and Fixes

Use before committing or submitting code for review.

| Check | WHY | Fix if Violated |
|-------|-----|-----------------|
| File under 300 lines? | Defect density, reviewability | Extract widgets, split services |
| Imports ordered (Dart -> Flutter -> Packages -> Project)? | Coupling visibility, merge conflicts | Reorder with blank-line separators |
| `const` used wherever possible? | Skips subtree rebuilds | Add const to constructors and literals |
| Widget classes, not widget functions? | Key support, const, rebuild boundary | Extract to StatelessWidget |
| `super.key` in widget constructors? | Dart 3 syntax, less boilerplate | Replace `Key? key` with `super.key` |
| Part directives for generated files? | Prevents "undefined class" errors | Add `part 'file.g.dart';` |
| Error handling matches layer? | Consistent error flow | Controller: AsyncValue.guard, Service: try/catch+rethrow, Repo: Either |
| No `print()` statements? | Logs persist in crash reports, visible via logcat | Use logging service or `debugPrint` |
| No magic numbers? | Unreadable, hard to change globally | Extract to named constants |
| Booleans use is/has/can/should prefix? | Ambiguity in conditionals | Rename with predicate |
| Descriptive names (no `data`, `temp`)? | Self-documenting code | Rename to describe content |

See [REFERENCE.md](REFERENCE.md) for lookup tables (naming conventions, analysis_options.yaml template, custom lint setup).
