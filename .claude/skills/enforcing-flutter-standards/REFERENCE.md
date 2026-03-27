# Enforcing Flutter Standards — Reference

Lookup tables and templates for standards described in [SKILL.md](SKILL.md). Every entry here supports a principle in SKILL.md — don't apply without understanding the reasoning first.

## Naming Conventions Table

| Element | Convention | Example | WHY |
|---------|-----------|---------|-----|
| Files | `snake_case` | `user_repository.dart` | Dart convention, filesystem-safe across platforms |
| Classes | `PascalCase` | `UserRepository` | Distinguishes types from instances at a glance |
| Variables | `camelCase` | `currentUser` | Dart convention, consistent with SDK |
| Constants | `camelCase` | `defaultTimeout` | Dart style — NOT `kPrefix` (that's Objective-C) |
| Private members | `_` prefix | `_internalState` | Dart's privacy mechanism (library-scoped) |
| Enums | `PascalCase` name, `camelCase` values | `enum Status { active, inactive }` | Dart 3 pattern — values are lowercase |
| Extensions | `PascalCase` on type | `extension StringX on String` | Convention: suffix with `X` or descriptive name |
| Typedefs | `PascalCase` | `typedef JsonMap = Map<String, dynamic>` | Type alias reads like a type |
| Test descriptions | lowercase sentence | `'should return user when found'` | Reads naturally in test output |

## Recommended analysis_options.yaml

Use this as a starter when the project doesn't have one. For existing projects, defer to the project's file.

```yaml
# analysis_options.yaml
include: package:flutter_lints/flutter.yaml

analyzer:
  errors:
    missing_return: error
    missing_required_param: error
    dead_code: warning
  exclude:
    - "**/*.g.dart"
    - "**/*.freezed.dart"
    - "lib/generated/**"

linter:
  rules:
    # Error prevention — catch real bugs
    avoid_print: true                              # print() persists in crash logs
    avoid_relative_lib_imports: true                # Breaks when moving files
    avoid_returning_null_for_future: true           # Null futures cause runtime errors
    avoid_slow_async_io: true                       # Use async alternatives
    cancel_subscriptions: true                      # Memory leaks
    close_sinks: true                               # Resource leaks
    no_duplicate_case_values: true                  # Dead code in switches

    # Const enforcement — rebuild optimization
    prefer_const_constructors: true                 # Skip subtree rebuilds
    prefer_const_constructors_in_immutables: true   # Immutable classes should be const
    prefer_const_declarations: true                 # Compile-time constants
    prefer_const_literals_to_create_immutables: true # Const collections

    # Style — consistency and readability
    always_declare_return_types: true               # Explicit contracts
    annotate_overrides: true                        # Makes inheritance visible
    avoid_empty_else: true                          # Usually a bug
    avoid_init_to_null: true                        # Dart defaults to null
    avoid_unnecessary_containers: true              # Widget tree noise
    prefer_final_fields: true                       # Immutability by default
    prefer_final_locals: true                       # Signals intent: won't change
    prefer_if_null_operators: true                  # ?? is more readable
    prefer_single_quotes: true                      # Consistency
    prefer_spread_collections: true                 # Cleaner list composition
    sized_box_for_whitespace: true                  # SizedBox over Container for spacing
    sort_child_properties_last: true                # child: always last (readability)
    unnecessary_brace_in_string_interps: true       # $var not ${var} for simple cases
    unnecessary_const: true                         # Don't double-const
    unnecessary_new: true                           # Dart 2+ doesn't need new
    unnecessary_this: true                          # Only use this. when disambiguating
    use_key_in_widget_constructors: true            # Keys enable proper reconciliation

    # Documentation
    slash_for_doc_comments: true                    # /// not /** */
    public_member_api_docs: false                   # Enable for library packages

    # Dart 3 patterns
    use_enums: true                                 # Enhanced enums
    use_super_parameters: true                      # super.key not Key? key
```

## Custom Lint Rules with custom_lint

**When to consider:** When your team has project-specific rules that the standard linter doesn't cover (e.g., "all providers must be in a `providers/` directory").

```yaml
# pubspec.yaml
dev_dependencies:
  custom_lint: ^0.6.0
  your_custom_lints: # your package or local rules
```

```yaml
# analysis_options.yaml (add to existing)
analyzer:
  plugins:
    - custom_lint
```

**Popular lint packages:**
- `flutter_lints` — Official Flutter team rules (recommended base)
- `very_good_analysis` — Strict rules from Very Good Ventures (good for teams wanting maximum enforcement)
- `lint` — Community-curated opinionated rules

## Code Generation Part Directives

Quick reference for which annotation produces which generated file:

| Annotation Source | Part Directive | Generated Content |
|-------------------|---------------|-------------------|
| `@riverpod` | `part 'file.g.dart';` | Provider definitions |
| `@freezed` / `@Freezed()` | `part 'file.freezed.dart';` | copyWith, equality, pattern matching |
| `@JsonSerializable()` | `part 'file.g.dart';` | fromJson / toJson |
| `@riverpod` + `@JsonSerializable()` | `part 'file.g.dart';` (shared) | Provider definitions + fromJson/toJson |

**Build command:**
```bash
dart run build_runner build --delete-conflicting-outputs
```

**Watch mode (during development):**
```bash
dart run build_runner watch --delete-conflicting-outputs
```

## Import Organization Quick Reference

```
┌──────────────────────────────────────┐
│ 1. dart:*          (SDK)             │
│    import 'dart:async';              │
│    import 'dart:io';                 │
├──────────────────────────────────────┤
│ 2. package:flutter/* (Framework)     │
│    import 'package:flutter/material';│
├──────────────────────────────────────┤
│ 3. package:*       (External)        │
│    import 'package:freezed.../...';  │
│    import 'package:riverpod.../...'; │
├──────────────────────────────────────┤
│ 4. Project imports (Internal)        │
│    import '../model/user.dart';      │  ← relative within feature
│    import 'package:app/auth/...';    │  ← package for cross-feature
└──────────────────────────────────────┘
  Blank line between each group.
  Alphabetical within each group.
```

## Error Handling Layer Quick Reference

```
┌─────────────┐     ┌──────────┐     ┌──────────────┐
│  Controller  │────▶│  Service  │────▶│  Repository  │
│              │     │          │     │              │
│ AsyncValue   │     │ try/catch│     │ Either<F,T>  │
│ .guard()     │     │ log +    │     │              │
│              │     │ rethrow  │     │ Left(Failure)│
│ Sets loading,│     │          │     │ Right(Entity)│
│ data, error  │     │ Adds     │     │              │
│ for UI       │     │ context  │     │ Makes failure│
│              │     │ to errors│     │ explicit     │
└─────────────┘     └──────────┘     └──────────────┘
```
