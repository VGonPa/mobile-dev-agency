# Designing Flutter Architecture — Implementation Reference

Implementation templates for architectural patterns described in [SKILL.md](SKILL.md). Every template here corresponds to a decision made in SKILL.md — don't implement without reading the decision context first.

## Domain Layer: Entity

**When needed:** Any feature with business logic worth isolating (Tier 2+).
**Key rule:** Pure Dart only. No Flutter imports, no serialization, no package dependencies.

```dart
// domain/entities/user.dart
// Pure Dart — no toJson(), no framework imports
class User {
  final String id;
  final String email;
  final String displayName;
  final DateTime createdAt;

  const User({
    required this.id,
    required this.email,
    required this.displayName,
    required this.createdAt,
  });
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
}
```

## Domain Layer: Use Case (Only When Logic Exists)

**When needed:** When there is actual business logic to encapsulate — validation, orchestration of multiple repositories, or transformation rules.
**When NOT needed:** If the use case would just delegate to the repository with zero logic, skip it (see SKILL.md "When This Architecture Is Overkill").

```dart
// domain/use_cases/update_profile.dart
// This use case EXISTS because it validates + orchestrates
class UpdateProfileUseCase {
  final UserRepository _userRepo;
  final ImageRepository _imageRepo;

  UpdateProfileUseCase(this._userRepo, this._imageRepo);

  Future<Either<Failure, User>> call(UpdateProfileParams params) async {
    // Business rule: display name constraints
    if (params.displayName.length < 2) {
      return Left(ValidationFailure('Name must be at least 2 characters'));
    }
    // Orchestration: upload image first, then update profile
    if (params.newAvatar != null) {
      final url = await _imageRepo.upload(params.newAvatar!);
      params = params.copyWith(avatarUrl: url);
    }
    return _userRepo.updateProfile(params.toUser());
  }
}
```

## Data Layer: DTO (When Separation Is Warranted)

**When needed:** See SKILL.md Step 6 decision table. Use when API shape differs from domain shape, or when multiple data sources serialize differently.

```dart
// data/models/user_dto.dart
// Knows about JSON — domain entity does not
class UserDto {
  final String id;
  final String email;
  final String display_name; // API uses snake_case
  final String created_at;   // API returns ISO string

  UserDto.fromJson(Map<String, dynamic> json)
      : id = json['id'],
        email = json['email'],
        display_name = json['display_name'],
        created_at = json['created_at'];

  // DTO -> Entity: mapping lives HERE, not in the entity
  User toEntity() => User(
        id: id,
        email: email,
        displayName: display_name,
        createdAt: DateTime.parse(created_at),
      );
}
```

## Data Layer: Repository Implementation

**When needed:** Every repository interface defined in Domain needs exactly one implementation in Data (per data source).

```dart
// data/repositories/user_repository_impl.dart
class UserRepositoryImpl implements UserRepository {
  final ApiClient _api;
  final UserLocalStorage _cache;

  UserRepositoryImpl(this._api, this._cache);

  @override
  Future<User> getUser(String id) async {
    try {
      final response = await _api.get('/users/$id');
      final dto = UserDto.fromJson(response.data);
      await _cache.save(dto); // Cache for offline
      return dto.toEntity();
    } on DioException catch (e) {
      // Translate network errors to domain failures
      throw ServerFailure(e.message ?? 'Unknown error');
    }
  }
}
```

## Presentation Layer: Controller / Notifier

**When needed:** Every screen that manages state beyond simple stateless display.
**Note:** This example uses Riverpod, but the pattern applies to any state management.

```dart
// presentation/controllers/profile_controller.dart
// State management lives in Presentation — it is a UI concern
class ProfileController extends StateNotifier<AsyncValue<User>> {
  final UserRepository _repository;

  ProfileController(this._repository) : super(const AsyncLoading());

  Future<void> loadProfile(String userId) async {
    state = const AsyncLoading();
    try {
      final user = await _repository.getUser(userId);
      state = AsyncData(user);
    } on Failure catch (e) {
      state = AsyncError(e, StackTrace.current);
    }
  }
}
```

## Sealed Failure Types

**When needed:** Any app that uses typed error handling (Either or sealed exceptions).
**Key rule:** Define in `core/errors/` so all features share the same failure vocabulary.

```dart
// core/errors/failures.dart
// Dart 3 sealed class — exhaustive pattern matching
sealed class Failure {
  final String message;
  const Failure(this.message);
}

class ServerFailure extends Failure {
  final int? statusCode;
  const ServerFailure(super.message, {this.statusCode});
}

class NetworkFailure extends Failure {
  const NetworkFailure(super.message);
}

class CacheFailure extends Failure {
  const CacheFailure(super.message);
}

class ValidationFailure extends Failure {
  const ValidationFailure(super.message);
}
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
│   ├── datasources/
│   │   ├── auth_remote_datasource.dart    # API calls only
│   │   └── auth_local_datasource.dart     # Token caching only
│   ├── models/
│   │   └── user_dto.dart                  # JSON serialization
│   └── repositories/
│       └── auth_repository_impl.dart      # Implements domain interface
├── domain/
│   ├── entities/
│   │   └── user.dart                      # Pure Dart, no dependencies
│   ├── repositories/
│   │   └── auth_repository.dart           # Abstract interface
│   └── use_cases/
│       └── login_use_case.dart            # Business logic
└── presentation/
    ├── controllers/
    │   └── login_controller.dart          # State management
    ├── pages/
    │   └── login_page.dart                # Screen widget
    └── widgets/
        └── login_form.dart                # Feature-specific widgets
```

**Note the cost:** This is 10+ files for a single feature. Only justified when the business logic and team size warrant it.
