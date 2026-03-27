---
name: integrating-flutter-backend
user-invocable: true
description: Backend integration decisions for Flutter apps. Use when choosing between REST/Firebase/GraphQL, selecting HTTP clients, designing repository patterns, implementing error handling strategies, or configuring authentication flows. Decision-first guide — code templates in REFERENCE.md.
---

# Integrating Flutter Backend

Decision guide for connecting Flutter apps to backend services. Focuses on WHEN and WHY to use each approach. For full code templates, see [REFERENCE.md](REFERENCE.md).

## When to Use This Skill

- Choosing between REST API, Firebase, or GraphQL
- Selecting an HTTP client (Dio vs http)
- Designing repository pattern and error handling
- Implementing authentication flows
- Deciding serialization strategy

## When NOT to Use This Skill

- **State management** (Riverpod, Bloc, Provider) — see `implementing-riverpod` skill
- **UI patterns** (widgets, layouts, navigation, theming) — see Flutter UI skills
- **Testing** (unit, widget, integration tests) — see `testing-flutter` skill
- **Deployment** (CI/CD, app store, Firebase Hosting) — see deployment-specific skills

## Backend Technology Decision

Choose your backend integration based on your situation, not your preference:

| Situation | Recommended | Why |
|-----------|-------------|-----|
| Existing REST API | Dio + Repository pattern | API contract already defined; wrap it cleanly |
| Greenfield with real-time needs | Firebase (Firestore) | Built-in real-time streams, offline persistence, auth |
| Complex nested data from single API | GraphQL (graphql_flutter) | Fetch exactly what you need; avoid N+1 REST calls |
| Simple CRUD, no real-time | REST or Firebase | Either works; pick based on team familiarity |
| Multiple data sources (API + cache) | Repository pattern + Either | Abstraction lets you swap/combine sources |

**When NOT each:**
- **REST**: Avoid when you need real-time sync — polling is wasteful vs Firestore streams
- **Firebase**: Avoid when you need complex queries (joins, aggregations) — Firestore is a document DB, not SQL
- **GraphQL**: Avoid for simple CRUD with flat data — the schema/codegen overhead isn't worth it

## HTTP Client Selection

| Client | Use When | Skip When |
|--------|----------|-----------|
| `http` package | Simple GET/POST, no auth, <3 endpoints | Need interceptors, retry, or multipart uploads |
| `Dio` | Interceptors (auth, retry, logging), cancel tokens, multipart | Simple scripts or one-off API calls |
| `Retrofit` (on Dio) | 5+ typed endpoints, want compile-time API contract | <5 endpoints — code-gen overhead exceeds benefit |

```dart
// Dio is the default choice for production apps because interceptors
// compose cleanly: auth → retry → logging → error mapping.
// The http package can't do this without manual wrapper code.
final dio = Dio(BaseOptions(
  baseUrl: 'https://api.example.com',
  connectTimeout: const Duration(seconds: 10),
  receiveTimeout: const Duration(seconds: 5),
));
```

## Authentication Strategy

Two distinct approaches — choose based on your backend:

### Firebase Auth (Firebase backend)

Firebase Auth manages token refresh automatically. Do NOT add a Dio auth interceptor on top — you'll have redundant, potentially conflicting refresh logic.

```dart
// Firebase Auth handles token refresh internally.
// Just get the current token when needed:
final token = await FirebaseAuth.instance.currentUser?.getIdToken();
// Pass to Dio via a simple interceptor that reads (never refreshes) the token.
```

### JWT/OAuth (Custom REST backend)

Use a Dio auth interceptor that attaches tokens and handles 401 refresh. See [Auth Interceptor in REFERENCE.md](REFERENCE.md#authentication-interceptor).

```dart
// The interceptor pattern works because:
// 1. Transparent to all API calls (no per-request auth code)
// 2. Automatic retry after refresh (caller doesn't know a refresh happened)
// 3. Single place to handle logout on refresh failure
```

**Decision:** If your backend is Firebase, use Firebase Auth directly. If custom REST, use Dio auth interceptor. Never both.

## Retry Strategy

Retry transient failures (timeouts, 5xx) but with critical safety rules:

```dart
bool _shouldRetry(DioException err) {
  // Only retry on transient server/network errors
  return err.type == DioExceptionType.connectionTimeout ||
      err.type == DioExceptionType.receiveTimeout ||
      (err.response?.statusCode ?? 0) >= 500;
}
```

### CRITICAL: Idempotency Rule

**NEVER retry non-idempotent operations (POST, PATCH) without an idempotency key.** Retrying a `POST /orders` without a unique request ID creates duplicate orders.

```dart
// SAFE: GET and DELETE are idempotent — retry freely
// SAFE: PUT replaces the resource — retry freely
// DANGEROUS: POST creates a new resource — retry ONLY with idempotency key

// Add idempotency key for non-idempotent retries:
options.headers['Idempotency-Key'] = uuid.v4();
```

**When NOT to retry:**
- 4xx errors (client mistakes — retrying won't fix bad input)
- 401 (handle via auth interceptor, not retry)
- Non-idempotent requests without idempotency keys

Full implementation: [Retry Interceptor in REFERENCE.md](REFERENCE.md#retry-interceptor).

## Error Handling Strategy

Three approaches exist — don't mix them without a clear boundary:

| Approach | Use When | Layer |
|----------|----------|-------|
| `Either<Failure, T>` | Repository returns to controller; caller MUST handle both paths | Data → Domain boundary |
| `AsyncValue` (Riverpod) | Controller exposes state to UI; loading/error/data states | Presentation layer |
| Exceptions (throw/catch) | Internal to a layer; unexpected errors, infrastructure failures | Within Data layer |

```dart
// Either forces the caller to handle failure — can't accidentally ignore errors.
// Use when crossing layer boundaries (data → domain → presentation).
Future<Either<Failure, User>> getUser(String id) async {
  try {
    final doc = await _firestore.collection('users').doc(id).get();
    if (!doc.exists) return Left(NotFoundFailure('User $id not found'));
    return Right(UserModel.fromJson(doc.data()!).toEntity());
  } on FirebaseException catch (e) {
    return Left(ServerFailure(e.message ?? 'Firestore error'));
  }
}
```

**When Either is overkill:** Simple apps with <3 failure types. If you only distinguish "success" vs "error", `AsyncValue.guard()` in your controller is simpler than `Either` + `Failure` hierarchy.

### Sealed Failure Types

Use Dart 3 sealed classes for exhaustive error handling — the compiler ensures you handle every case. Full hierarchy with `statusCode` and `fieldErrors` fields: [Sealed Failure Hierarchy in REFERENCE.md](REFERENCE.md#sealed-failure-hierarchy).

## Repository Pattern Decisions

| Scenario | Repository Approach | Why |
|----------|-------------------|-----|
| 1-2 simple API calls | Direct Dio/Firestore in controller | Layer ceremony costs more than it saves |
| 3+ endpoints, same data source | Concrete repository class | Testability, single responsibility |
| Multiple data sources (API + cache) | Abstract interface + implementation | Swap/compose sources without touching callers |
| 3+ Firestore collections with same CRUD | Generic `FirestoreRepository<T>` | Eliminate repetitive CRUD code |

**When generic repository is overkill:** If each collection has unique query patterns (different filters, ordering, pagination), a generic repo forces awkward abstractions. Use collection-specific repos instead.

Full implementations: [Repository Pattern in REFERENCE.md](REFERENCE.md#repository-pattern-with-either).

## Firestore Data Modeling Decisions

These are the actual hard decisions in Firestore integration — the CRUD code is trivial:

| Decision | Choose A | Choose B |
|----------|----------|----------|
| Subcollections vs root | Data always accessed with parent (user's orders) | Data queried independently (all orders by date) |
| Denormalize vs reference | Read-heavy, rarely updated (user name on every order) | Write-heavy, frequently updated (use reference + join) |
| `withConverter<T>` vs raw maps | Production code (type safety, compile-time checks) | Prototyping or admin scripts (flexibility) |
| Batch vs transaction | Independent writes (import 50 items) | Dependent writes (transfer: debit A, credit B) |

## Serialization Strategy

| Approach | Use When | Skip When |
|----------|----------|-----------|
| `Freezed` | Models need: immutability, copyWith, equality, sealed unions | Simple DTOs with only fromJson/toJson |
| `json_serializable` | Just need fromJson/toJson, no copyWith | Models need immutability guarantees |
| Manual fromJson | 1-2 simple models, avoiding build_runner | 5+ models — manual serialization doesn't scale |

**Freezed** is the default for domain models because it gives you immutability + copyWith + equality + JSON serialization in one annotation. `json_serializable` alone is sufficient for data-layer DTOs that just shuttle JSON to/from the API without domain behavior. Full Freezed template: [JSON Serialization with Freezed in REFERENCE.md](REFERENCE.md#json-serialization-with-freezed).

## Real-Time Data Decisions

| Source | Pattern | Use When |
|--------|---------|----------|
| Firestore | `StreamProvider` wrapping `snapshots()` | Real-time document/collection updates |
| WebSocket | `StreamProvider` wrapping WebSocket stream | Custom backend real-time |
| Polling | `Timer` + `ref.invalidate()` | REST API without real-time support |

**Firestore offline:** Firestore has built-in offline persistence (enabled by default on mobile). Don't add Hive/SharedPreferences as a cache layer on top — it's redundant. Use Hive only for data that doesn't come from Firestore.

## Common Pitfalls

| Pitfall | Fix |
|---------|-----|
| Not handling null Firestore documents | Always check `snap.exists` before accessing `.data()` |
| Throwing exceptions from repositories | Return `Either<Failure, T>` instead — callers can't forget to handle |
| Forgetting to dispose stream subscriptions | Use `ref.onDispose()` in providers or `cancel()` in StatefulWidgets |
| Hardcoding base URLs | Use `--dart-define-from-file` or flavor-based configuration |
| Retrying POST without idempotency key | Add `Idempotency-Key` header or skip retry for non-idempotent ops |
| Using Dio auth interceptor with Firebase Auth | Firebase handles token refresh — interceptor causes conflicts |
| Silent error swallowing in catch blocks | Always log errors before returning `Left()` |
| Adding Hive cache on top of Firestore | Firestore has built-in offline persistence — Hive is redundant |
