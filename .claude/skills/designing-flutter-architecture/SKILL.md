---
name: designing-flutter-architecture
description: Guides Clean Architecture implementation for Flutter apps. Use when deciding which layer code belongs in, structuring new features, or establishing dependency rules. Covers model/data/domain/presentation layers, feature-based organization, and file structure conventions.
user-invocable: true
---

# Designing Flutter Architecture

Architecture decisions depend on your app's complexity. A weekend prototype and a 50-screen production app need fundamentally different structures. This skill helps you choose the right level of architecture — not just copy Clean Architecture because it's popular.

## When to Use This Skill

- Starting a new Flutter project and choosing its structure
- Deciding which layer new code belongs in
- Structuring a new feature module
- Refactoring code to the correct architectural boundary
- Resolving dependency violations between layers

## When NOT to Use This Skill

- **State management choices** (Riverpod vs Bloc vs Provider) — this skill is layer-agnostic
- **Routing / navigation** — use the routing skill or package docs
- **Testing strategy** — architecture enables testability, but test patterns are a separate concern
- **Animations / UI polish** — purely presentation-layer, no architectural decision involved
- **Package selection** — this skill tells you WHERE code goes, not WHICH package to use

## Step 1: Determine Your Complexity Tier

Before creating folders, answer: **How many features does this app have, and how many developers work on it?**

### Complexity Tier Decision Matrix

| Question | If Yes | If No |
|----------|--------|-------|
| Will 3+ developers work on this codebase concurrently? | Tier 3 | Continue |
| Does it have 10+ distinct feature areas with shared business logic? | Tier 3 | Continue |
| Does it have 3-10 features with some shared logic? | Tier 2 | Continue |
| Is it a prototype, MVP, or single-feature app? | Tier 1 | Tier 2 (default) |

### Architecture Tiers

| Tier | Example Apps | Structure | Trade-off |
|------|-------------|-----------|-----------|
| **Tier 1: Simple** | Todo app, calculator, single-screen tool | Flat folders by type (`screens/`, `models/`, `services/`) | Fast to build, but shared state gets tangled beyond ~5 screens |
| **Tier 2: Feature-based** | E-commerce, social app, fitness tracker | Feature folders with data/domain/presentation split | Good isolation, moderate boilerplate. Sweet spot for most apps |
| **Tier 3: Strict Clean Architecture** | Banking, enterprise, multi-team projects | Full layer separation with use cases, DTOs, abstract repositories | Maximum testability and team independence, significant boilerplate cost |

**Default to Tier 2.** Most Flutter apps with user accounts land here. Tier 3 on a small app adds 2-3x more files with no proportional benefit.

## When This Architecture Is Overkill

Premature architecture is one of the most common mistakes in Flutter projects. Every unnecessary abstraction adds a file, an import, and a mental indirection. Here is when to skip things:

**Skip the domain layer entirely when:**
- Simple CRUD with no business rules (just fetch, display, save)
- Prototype or MVP where speed beats maintainability
- Single developer, under 5 screens, unlikely to grow

**Skip use cases when:**
- The use case would just delegate to the repository with zero logic
- Business rules are trivial (no validation, no orchestration of multiple repositories)
- A `LoginUseCase` that only calls `_repository.login()` is a pass-through that helps nobody — add it later when real business logic appears

**Skip DTOs / separate models when:**
- Your API response maps 1:1 to your domain entity
- You control both client and server (schema changes are coordinated)
- You are in prototype phase and the schema is still changing daily

**The cost of getting this wrong:** A 10-screen app with full Tier 3 architecture will have ~3x more files than a Tier 2 equivalent. Each feature adds 6-8 files instead of 3-4. The boilerplate slows development without improving correctness or testability — because there is nothing complex enough to benefit from the extra layers.

## Step 2: Understand the Dependency Rule

**Problem:** Without a clear dependency direction, changes in the API layer cascade into UI code, and business logic gets trapped inside widgets where it cannot be tested or reused.

**Cost of ignoring:** A single API response format change forces updates across widgets, controllers, and tests. You spend days on what should be a 20-minute change.

```
Presentation → Domain ← Data
```

- **Presentation** depends on Domain (calls use cases, reads entities)
- **Data** depends on Domain (implements repository interfaces defined in Domain)
- **Domain** depends on NOTHING (pure Dart, no Flutter imports, no packages)

**Why "inward only" matters:** When the API response format changes, you update the Data layer's DTO mapping. Domain entities and Presentation widgets do not change. This is the core value proposition — change isolation.

**Violations that break the architecture:**

| Violation | Why it is dangerous | Fix |
|-----------|-------------------|-----|
| Domain imports Data or Presentation | Business logic coupled to implementation details | Define interfaces in Domain, implement in Data |
| Presentation imports Data directly | Bypasses the abstraction boundary | Go through Domain (use case or repository interface) |

## Step 3: Know Where Code Belongs

**Problem:** "Where do I put this?" is the #1 architecture question. Wrong placement causes coupling, untestable logic, and circular dependencies.

| I need to... | Layer | Why here? |
|--------------|-------|-----------|
| Show UI, handle user gestures | Presentation | Only layer that imports Flutter |
| Manage screen state | Presentation | State is a UI concern (controllers/notifiers live here) |
| Validate business rules, orchestrate operations | Domain | Must be testable without Flutter or network |
| Define data contracts (entities, repo interfaces) | Domain | Owned by business logic, implemented by Data |
| Access API / database | Data | Implementation detail that Domain should not know about |
| Map JSON to/from entities | Data | Serialization is a data concern, not a business rule |

## Step 4: Structure Your Features

**Problem:** Without a convention, developers put files in inconsistent places and cross-feature imports create hidden coupling.

### Tier 2 Feature Structure (Recommended Default)

```
lib/
├── core/                          # Shared infrastructure (errors, network, theme)
│   ├── errors/failures.dart       # Sealed failure types for typed error handling
│   ├── network/api_client.dart    # HTTP client config, interceptors
│   └── theme/app_theme.dart       # Design tokens, color schemes
├── features/                      # One folder per feature, self-contained
│   └── authentication/            # Example feature
│       ├── data/                  # API calls, DTOs, repository implementations
│       ├── domain/                # Entities, repo interfaces, use cases (if needed)
│       └── presentation/          # Pages, widgets, controllers
└── shared/                        # Cross-feature widgets and extensions
    └── widgets/primary_button.dart
```

**Feature folder rules:**
- Each feature folder is self-contained — it should be deletable without breaking other features
- Shared code between features goes to `core/` (infrastructure) or `shared/` (UI components)
- If Feature A needs Feature B's entity, extract it to `core/domain/` — do not create cross-feature imports

See [REFERENCE.md](REFERENCE.md) for complete layer implementation templates.

## Step 5: Error Handling — Exceptions vs Either

This is the most contentious architectural choice in Flutter Clean Architecture. Both approaches work. Choose based on your team and codebase, then **commit to one for the entire project**.

### Option A: Sealed Failures with Either (`fpdart` or `dartz`)

**Choose when:** You want the type system to force callers to handle errors. Every return type explicitly documents its failure modes. Teams with functional programming experience will find this natural.

**Cost:** Extra dependency, unfamiliar syntax for developers new to FP patterns, more verbose call sites (must `fold`/`match` every result).

```dart
// Package: fpdart (recommended, ~2.1.0) or dartz (~0.10.1)
// Repository returns Either — caller MUST handle Left (failure)
Future<Either<Failure, User>> login(String email, String pass) async {
  try {
    final dto = await _remote.login(email, pass);
    return Right(dto.toEntity());
  } on ServerException catch (e) {
    return Left(ServerFailure(e.message));
  }
}
```

### Option B: Exceptions with Sealed Types

**Choose when:** Your team prefers standard Dart try/catch patterns, or you want to avoid the `fpdart`/`dartz` dependency. Dart 3 sealed classes give you exhaustive pattern matching on catch.

**Cost:** Callers can forget to catch exceptions — errors are invisible in the function signature. Uncaught exception = crash in production.

```dart
// No extra dependency needed (Dart 3 sealed classes)
// Repository throws typed exceptions — caller catches
Future<User> login(String email, String pass) async {
  try {
    final dto = await _remote.login(email, pass);
    return dto.toEntity();
  } on SocketException {
    throw NetworkFailure('No connection');
  }
}
```

### Decision Framework

| Factor | Either (`fpdart`/`dartz`) | Sealed Exceptions |
|--------|--------------------------|-------------------|
| Error visibility in types | Explicit — return type shows it | Implicit — must read docs/code |
| Team familiarity required | FP knowledge | Standard Dart patterns |
| Forgotten error handling | Compile-time reminder (must fold/match) | Silent — uncaught = crash |
| Boilerplate per call site | Higher (fold, map, match) | Lower (try/catch only where needed) |
| External dependency | `fpdart` or `dartz` | None (Dart 3 built-in) |
| Best for | Strict codebases, FP-experienced teams | Rapid development, teams new to Clean Architecture |

**Rule:** Pick one for the entire project. Mixing both creates confusion about which pattern to follow. Document the choice in your project's CLAUDE.md or architecture decision record.

## Step 6: DTOs vs Single Model — When Separation Pays Off

**Problem:** If your domain entity has `toJson()`, your business logic layer knows about serialization — a data concern that should not leak upward. But separate DTOs add real cost.

**The mapping cost:** Every DTO requires `toEntity()` and `fromEntity()` methods. For a model with 15 fields, that is ~30 lines of mapping boilerplate per model. Worth it when it prevents cascading changes; wasteful when API and domain are identical.

### Decision Table

| Scenario | Separate DTO? | Why |
|----------|--------------|-----|
| API returns fields your domain does not need | **Yes** | Domain stays clean, DTO absorbs API noise |
| Entity used in multiple data sources (API + cache + local DB) | **Yes** | Each source has its own serialization format |
| API format changes frequently (3rd party, versioned) | **Yes** | DTO absorbs changes, domain entity stays stable |
| You control both client and server, 1:1 mapping | **No** | Separate DTO is just a copy with extra steps |
| Prototype / MVP, schema still evolving | **No** | Add separation when the schema stabilizes |

See [REFERENCE.md](REFERENCE.md) for DTO and entity implementation templates.

## Common Violations and Fixes

| Violation | Why it is a problem | Fix |
|-----------|-------------------|-----|
| Widget calls API directly | Skips all layers, untestable, no error boundary | Widget -> Controller -> UseCase -> Repo |
| Domain imports `package:http` | Framework dependency in pure Dart layer | Abstract interface in Domain, implement in Data |
| Data layer validates business rules | Logic in wrong place, cannot reuse from other entry points | Move validation to Domain use case |
| Feature A imports Feature B's data layer | Tight coupling, cannot evolve independently | Extract shared code to `core/` |
| Entity has `toJson()` | Domain knows about serialization | Use separate DTO in Data layer (if warranted by Step 6) |
| Use case just calls repository method | Pass-through abstraction adding no value | Delete use case, call repository directly from controller |

**The most common violation — business logic in widgets:**

```dart
// ❌ BAD: Business logic in widget — untestable, no reuse
onPressed: () async {
  if (email.contains('@') && password.length >= 8) {
    final user = await apiClient.post('/login', ...);
  }
}

// ✅ GOOD: Widget delegates to controller
onPressed: () => controller.login(email, password),
```

## Quick Checklist (New Feature)

Run through this before writing code for a new feature:

- [ ] Decided if this feature needs a domain layer or if Data -> Presentation is sufficient?
- [ ] Domain entities are pure Dart with no framework imports?
- [ ] Repository interface defined in Domain (if using domain layer)?
- [ ] Repository implementation in Data?
- [ ] Error handling follows the project's chosen pattern (Either OR exceptions, not both)?
- [ ] Dependencies flow inward (Presentation -> Domain <- Data)?
- [ ] Shared code extracted to `core/` or `shared/`?
- [ ] Feature folder is self-contained (deletable without breaking other features)?
