# Designing Flutter Architecture — Implementation Reference

Implementation templates for architectural patterns described in [SKILL.md](SKILL.md). Every template here corresponds to a decision made in SKILL.md — don't implement without reading the decision context first.

**Error handling pattern:** These templates use exceptions (Option B from [SKILL.md](SKILL.md) Step 5) consistently. For Either-based alternatives (Option A), see [SKILL.md](SKILL.md) Step 5.

## Domain Layer: Entity

**When needed:** Any feature with business logic worth isolating (Tier 2+).
**Key rule:** Pure Dart only. No Flutter imports, no serialization, no package dependencies.

```dart
// domain/entities/user.dart
// Pure Dart — no toJson(), no framework imports, no package deps
class User {
  final String id;
  final String email;
  final String displayName;
  final DateTime createdAt;
  const User({required this.id, required this.email,
      required this.displayName, required this.createdAt});
}
```

## Domain Layer: Repository Interface

**When needed:** When you want the Domain layer to define the contract without knowing the implementation (database, API, cache).
**Key rule:** Defined in Domain, implemented in Data. This is how the dependency rule works — Domain owns the interface, Data provides the implementation.

```dart
// domain/repositories/user_repository.dart
// Abstract contract — no implementation details
abstract class UserRepository {
  Future<User> getUser(String id);
  Future<void> updateProfile(User user);
  Future<void> deleteAccount(String id);
  Stream<User?> watchAuthState(); // Reactive pattern — common in Flutter
}
```

## Domain Layer: Use Case (Only When Logic Exists)

**When needed:** When there is actual business logic to encapsulate — validation, orchestration of multiple repositories, or transformation rules.
**When NOT needed:** If the use case would just delegate to the repository with zero logic, skip it (see [SKILL.md](SKILL.md) "When This Architecture Is Overkill").

```dart
// EXISTS because it validates + orchestrates (not a pass-through)
class UpdateProfileUseCase {
  final UserRepository _userRepo;
  final ImageRepository _imageRepo;
  UpdateProfileUseCase(this._userRepo, this._imageRepo);
  Future<void> call(UpdateProfileParams p) async {
    if (p.displayName.length < 2) throw ValidationFailure('Too short');
    if (p.newAvatar != null) await _imageRepo.upload(p.newAvatar!);
    await _userRepo.updateProfile(p.toUser());
  }
}
```

## Data Layer: DTO (When Separation Is Warranted)

**When needed:** See [SKILL.md](SKILL.md) Step 6 decision table. Use when API shape differs from domain shape, or when multiple data sources serialize differently.

```dart
class UserDto {
  final String id;
  final String email;
  final String displayName;
  final DateTime createdAt;
  UserDto.fromJson(Map<String, dynamic> j)
      : id = j['id'] as String, email = j['email'] as String,
        displayName = j['display_name'] as String,
        createdAt = DateTime.parse(j['created_at'] as String);
  User toEntity() => User(id: id, email: email,
      displayName: displayName, createdAt: createdAt);
}
```

## Data Layer: Repository Implementation

**When needed:** Every repository interface defined in Domain needs exactly one implementation in Data (per data source).

```dart
// Implements domain interface — translates API → entities
class UserRepositoryImpl implements UserRepository {
  final ApiClient _api;
  UserRepositoryImpl(this._api);
  @override
  Future<User> getUser(String id) async {
    try {
      final resp = await _api.get('/users/$id');
      return UserDto.fromJson(resp.data).toEntity();
    } on DioException catch (e) { throw ServerFailure(e.message ?? ''); }
  }
}
```

## Presentation Layer: Controller / Notifier

**When needed:** Every screen that manages state beyond simple stateless display.
**Note:** This example uses Riverpod `StateNotifier` (works in 2.x). For Riverpod 3.x+, replace with `Notifier`/`AsyncNotifier` — same pattern, updated API. The layer placement principle applies to any state management.

```dart
// presentation/controllers/profile_controller.dart
// State management lives in Presentation — it is a UI concern
class ProfileController extends StateNotifier<AsyncValue<User>> {
  final UserRepository _repository;
  ProfileController(this._repository) : super(const AsyncLoading());

  Future<void> loadProfile(String userId) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _repository.getUser(userId));
  }
}
```

## Sealed Failure Types

**When needed:** Any app that uses typed error handling (Either or sealed exceptions).
**Key rule:** Define in `core/errors/` so all features share the same failure vocabulary.

```dart
// core/errors/failures.dart — Dart 3 sealed class for exhaustive matching
sealed class Failure {
  final String message;
  const Failure(this.message);
}
class ServerFailure extends Failure {
  final int? statusCode;
  const ServerFailure(super.message, {this.statusCode});
}
class NetworkFailure extends Failure { const NetworkFailure(super.message); }
class CacheFailure extends Failure { const CacheFailure(super.message); }
class ValidationFailure extends Failure { const ValidationFailure(super.message); }
```

## Tier 1: Simple Structure (Flat Folders)

**When appropriate:** Prototypes, MVPs, single-feature apps, under 5 screens.

```
lib/
├── models/          # Data classes (can include toJson)
├── screens/         # One file per screen
├── services/        # API calls, local storage
├── widgets/         # Reusable UI components
└── main.dart
```

No domain layer, no use cases, no DTOs. Add structure when complexity demands it.

## Tier 3: Full Feature Structure

**When appropriate:** Multi-team projects, banking/enterprise apps, 10+ features with shared business logic.

```
lib/features/authentication/
├── data/
│   ├── datasources/                       # Remote + local data sources
│   ├── models/user_dto.dart               # JSON serialization
│   └── repositories/auth_repo_impl.dart   # Implements domain interface
├── domain/
│   ├── entities/user.dart                 # Pure Dart, no dependencies
│   ├── repositories/auth_repository.dart  # Abstract interface
│   └── use_cases/login_use_case.dart      # Business logic
└── presentation/
    ├── controllers/login_controller.dart  # State management
    └── pages/login_page.dart              # Screen widgets
```

**Note the cost:** This is 10+ files for a single feature. Only justified when the business logic and team size warrant it.
