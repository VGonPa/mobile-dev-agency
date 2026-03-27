# Backend Integration Reference

Code templates for backend integration patterns. See [SKILL.md](SKILL.md) for decision guidance on WHEN and WHY to use each pattern.

## REST API with Dio

### Dio Client Setup

```dart
import 'package:dio/dio.dart';

class ApiClient {
  late final Dio _dio;

  ApiClient({required String baseUrl, String? authToken}) {
    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 5),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ));
    _setupInterceptors();
  }

  void _setupInterceptors() {
    _dio.interceptors.addAll([
      _AuthInterceptor(_dio),
      _RetryInterceptor(_dio),
      LogInterceptor(requestBody: true, responseBody: true),
    ]);
  }

  Dio get dio => _dio;
}
```

### Authentication Interceptor

For custom REST backends with JWT/OAuth. Do NOT use with Firebase Auth (see SKILL.md).

```dart
class _AuthInterceptor extends Interceptor {
  final Dio _dio;

  // WHY accept Dio instance: we need the configured baseUrl and timeouts
  // for token refresh and request retry. A bare Dio() has no baseUrl, so
  // relative paths like '/auth/refresh' would fail.
  _AuthInterceptor(this._dio);

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    final token = await TokenStorage.getAccessToken();
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode == 401) {
      try {
        final newToken = await _refreshToken();
        final opts = err.requestOptions;
        opts.headers['Authorization'] = 'Bearer $newToken';
        // Use the configured Dio instance so baseUrl and timeouts apply.
        final response = await _dio.fetch(opts);
        return handler.resolve(response);
      } catch (_) {
        return handler.reject(err);
      }
    }
    handler.next(err);
  }

  Future<String> _refreshToken() async {
    final refreshToken = await TokenStorage.getRefreshToken();
    // Use the configured Dio instance — bare Dio() has no baseUrl and
    // the relative path '/auth/refresh' would not resolve.
    final response = await _dio.post(
      '/auth/refresh',
      data: {'refresh_token': refreshToken},
    );
    final newToken = response.data['access_token'] as String;
    await TokenStorage.saveAccessToken(newToken);
    return newToken;
  }
}
```

### Retry Interceptor

Retries transient failures. See SKILL.md for idempotency rules.

```dart
class _RetryInterceptor extends Interceptor {
  final Dio _dio;
  final int maxRetries;
  _RetryInterceptor(this._dio, {this.maxRetries = 3});

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final retryCount = err.requestOptions.extra['retry_count'] as int? ?? 0;

    if (_shouldRetry(err) && retryCount < maxRetries && _isIdempotent(err.requestOptions)) {
      err.requestOptions.extra['retry_count'] = retryCount + 1;
      await Future.delayed(Duration(seconds: retryCount + 1)); // Linear backoff
      try {
        // Use the configured Dio instance so baseUrl/timeouts/interceptors apply.
        final response = await _dio.fetch(err.requestOptions);
        return handler.resolve(response);
      } catch (_) {}
    }
    handler.next(err);
  }

  bool _shouldRetry(DioException err) {
    return err.type == DioExceptionType.connectionTimeout ||
        err.type == DioExceptionType.receiveTimeout ||
        (err.response?.statusCode ?? 0) >= 500;
  }

  // CRITICAL: Never retry non-idempotent operations without idempotency key
  bool _isIdempotent(RequestOptions options) {
    final method = options.method.toUpperCase();
    if (method == 'GET' || method == 'PUT' || method == 'DELETE' || method == 'HEAD') {
      return true; // Safe to retry
    }
    // POST/PATCH: only retry if idempotency key is present
    return options.headers.containsKey('Idempotency-Key');
  }
}
```

### Sealed Failure Hierarchy

```dart
sealed class Failure {
  final String message;
  const Failure(this.message);
}

class NetworkFailure extends Failure {
  const NetworkFailure(super.message);
}

class ServerFailure extends Failure {
  final int? statusCode;
  const ServerFailure(super.message, {this.statusCode});
}

class AuthFailure extends Failure {
  const AuthFailure(super.message);
}

class NotFoundFailure extends Failure {
  const NotFoundFailure(super.message);
}

class ValidationFailure extends Failure {
  final Map<String, List<String>>? fieldErrors;
  const ValidationFailure(super.message, {this.fieldErrors});
}
```

### Type-Safe API with Retrofit

```dart
import 'package:retrofit/retrofit.dart';
import 'package:dio/dio.dart';

part 'api_service.g.dart';

@RestApi()
abstract class ApiService {
  factory ApiService(Dio dio, {String baseUrl}) = _ApiService;

  @GET('/items')
  Future<List<ItemModel>> getItems(
    @Query('page') int page,
    @Query('limit') int limit,
  );

  @GET('/items/{id}')
  Future<ItemModel> getItem(@Path('id') String id);

  @POST('/items')
  Future<ItemModel> createItem(@Body() ItemModel item);

  @PUT('/items/{id}')
  Future<ItemModel> updateItem(@Path('id') String id, @Body() ItemModel item);

  @DELETE('/items/{id}')
  Future<void> deleteItem(@Path('id') String id);
}

// Generate: dart run build_runner build --delete-conflicting-outputs
```

## Repository Pattern with Either

### Abstract Repository

```dart
import 'package:dartz/dartz.dart'; // or fpdart

abstract class ItemRepository {
  Future<Either<Failure, List<Item>>> getItems({int page = 1, int limit = 20});
  Future<Either<Failure, Item>> getItem(String id);
  Future<Either<Failure, Item>> createItem(Item item);
  Future<Either<Failure, Item>> updateItem(Item item);
  Future<Either<Failure, void>> deleteItem(String id);
}
```

### Repository Implementation (REST)

```dart
class ItemRepositoryImpl implements ItemRepository {
  final ApiClient _apiClient;
  ItemRepositoryImpl(this._apiClient);

  @override
  Future<Either<Failure, List<Item>>> getItems({
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final response = await _apiClient.dio.get(
        '/items',
        queryParameters: {'page': page, 'limit': limit},
      );
      final items = (response.data as List)
          .map((json) => ItemModel.fromJson(json))
          .toList();
      return Right(items);
    } on DioException catch (e) {
      return Left(_mapDioException(e));
    } catch (e) {
      return Left(ServerFailure('Unexpected error: $e'));
    }
  }

  Failure _mapDioException(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
        return const NetworkFailure('Connection timeout');
      case DioExceptionType.badResponse:
        return _mapStatusCode(e.response?.statusCode, e.response?.data);
      default:
        return const NetworkFailure('Network error');
    }
  }

  Failure _mapStatusCode(int? code, dynamic data) => switch (code) {
    400 => ValidationFailure(data?['message'] ?? 'Bad request'),
    401 => const AuthFailure('Unauthorized'),
    403 => const AuthFailure('Forbidden'),
    404 => const NotFoundFailure('Resource not found'),
    _ => ServerFailure('Server error', statusCode: code),
  };
}
```

## Firebase Integration

### Firebase Setup

```bash
dart pub global activate flutterfire_cli
flutterfire configure
```

```dart
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}
```

### Firestore Repository (Generic)

```dart
import 'package:cloud_firestore/cloud_firestore.dart';

// WHY generic: eliminates repetitive CRUD boilerplate across collections.
// Each collection only needs to supply fromJson/toJson — all reads, writes,
// watches, and deletes are handled here once.
class FirestoreRepository<T> {
  final FirebaseFirestore _firestore;
  final String collectionPath;
  final T Function(Map<String, dynamic> json) fromJson;
  final Map<String, dynamic> Function(T item) toJson;

  FirestoreRepository({
    required this.collectionPath,
    required this.fromJson,
    required this.toJson,
    // WHY optional: allows injecting a mock FirebaseFirestore in tests.
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  // WHY withConverter: gives us type-safe reads/writes — no raw Map<String,
  // dynamic> leaking into business logic. Firestore handles serialization at
  // the boundary.
  CollectionReference<T> get _collection =>
      _firestore.collection(collectionPath).withConverter<T>(
            fromFirestore: (snap, _) => fromJson(snap.data()!),
            toFirestore: (item, _) => toJson(item),
          );

  Future<T?> get(String id) async {
    final snap = await _collection.doc(id).get();
    return snap.data();
  }

  Stream<T?> watch(String id) {
    return _collection.doc(id).snapshots().map((snap) => snap.data());
  }

  Stream<List<T>> watchAll({Query<T> Function(Query<T>)? queryBuilder}) {
    Query<T> query = _collection;
    if (queryBuilder != null) query = queryBuilder(query);
    return query.snapshots().map(
      (snap) => snap.docs.map((doc) => doc.data()).toList(),
    );
  }

  Future<String> create(T item) async {
    final ref = await _collection.add(item);
    return ref.id;
  }

  Future<void> set(String id, T item, {bool merge = false}) async {
    await _collection.doc(id).set(item, SetOptions(merge: merge));
  }

  Future<void> update(String id, Map<String, dynamic> data) async {
    await _firestore.collection(collectionPath).doc(id).update(data);
  }

  Future<void> delete(String id) async {
    await _collection.doc(id).delete();
  }
}
```

### Firebase Auth Service

```dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

// WHY wrapper service: centralizes auth logic (sign-in, sign-out, error
// mapping) so controllers/providers never touch FirebaseAuth directly.
// Also enables testing via constructor injection of mock FirebaseAuth.
class AuthService {
  final FirebaseAuth _auth;
  final GoogleSignIn _googleSignIn;

  AuthService({FirebaseAuth? auth, GoogleSignIn? googleSignIn})
      : _auth = auth ?? FirebaseAuth.instance,
        _googleSignIn = googleSignIn ?? GoogleSignIn();

  // WHY authStateChanges stream: lets Riverpod/Bloc reactively rebuild UI
  // on login/logout without polling or manual state management.
  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  Future<Either<Failure, UserCredential>> signInWithEmail(
    String email, String password,
  ) async {
    try {
      final result = await _auth.signInWithEmailAndPassword(
        email: email, password: password,
      );
      return Right(result);
    } on FirebaseAuthException catch (e) {
      return Left(AuthFailure(_mapAuthCode(e.code)));
    }
  }

  Future<Either<Failure, UserCredential>> signInWithGoogle() async {
    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return Left(const AuthFailure('Cancelled'));
      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      return Right(await _auth.signInWithCredential(credential));
    } on FirebaseAuthException catch (e) {
      return Left(AuthFailure(_mapAuthCode(e.code)));
    }
  }

  Future<void> signOut() async {
    await Future.wait([_auth.signOut(), _googleSignIn.signOut()]);
  }

  // WHY map codes to user-friendly messages: Firebase error codes are
  // developer-facing (e.g., 'user-not-found'); never show them raw in UI.
  String _mapAuthCode(String code) => switch (code) {
    'user-not-found' => 'No account found for this email',
    'wrong-password' => 'Wrong password',
    'email-already-in-use' => 'An account already exists for this email',
    'weak-password' => 'Password is too weak',
    'too-many-requests' => 'Too many attempts. Try again later',
    _ => 'Authentication failed',
  };
}
```

### Firebase Storage

```dart
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';

class StorageService {
  final FirebaseStorage _storage;

  StorageService({FirebaseStorage? storage})
      : _storage = storage ?? FirebaseStorage.instance;

  Future<String> uploadFile({
    required File file,
    required String path,
    void Function(double)? onProgress,
  }) async {
    final ref = _storage.ref().child(path);
    final task = ref.putFile(file);

    if (onProgress != null) {
      task.snapshotEvents.listen((snap) {
        onProgress(snap.bytesTransferred / snap.totalBytes);
      });
    }

    await task;
    return await ref.getDownloadURL();
  }

  Future<void> deleteFile(String path) async {
    await _storage.ref().child(path).delete();
  }
}
```

## GraphQL Integration

```dart
import 'package:graphql_flutter/graphql_flutter.dart';

class GraphQLService {
  late final GraphQLClient _client;

  GraphQLService({required String endpoint, String? authToken}) {
    final httpLink = HttpLink(endpoint);
    // NOTE: authToken is captured by value here. If the token can change
    // (e.g., after refresh), pass a callback instead:
    //   AuthLink(getToken: () async => 'Bearer ${await getToken()}')
    final authLink = AuthLink(getToken: () async => 'Bearer $authToken');
    // WHY concat order: auth runs first, then HTTP — ensures every request
    // has the Authorization header before it hits the network.
    final link = authLink.concat(httpLink);

    _client = GraphQLClient(
      // WHY InMemoryStore: simple default; swap to HiveStore for offline
      // persistence if the app needs it.
      link: link,
      cache: GraphQLCache(store: InMemoryStore()),
    );
  }

  // WHY Either return: callers must handle failure explicitly — no silent nulls
  // or uncaught exceptions leaking to the UI layer.
  Future<Either<Failure, T>> query<T>({
    required String document,
    Map<String, dynamic>? variables,
    // WHY parser callback: keeps GraphQL response shape decoupled from domain
    // models — this service never imports model classes.
    required T Function(Map<String, dynamic>) parser,
  }) async {
    try {
      final result = await _client.query(QueryOptions(
        document: gql(document),
        variables: variables ?? {},
      ));
      if (result.hasException) {
        return Left(ServerFailure(result.exception.toString()));
      }
      return Right(parser(result.data!));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  Future<Either<Failure, T>> mutate<T>({
    required String document,
    Map<String, dynamic>? variables,
    required T Function(Map<String, dynamic>) parser,
  }) async {
    try {
      final result = await _client.mutate(MutationOptions(
        document: gql(document),
        variables: variables ?? {},
      ));
      if (result.hasException) {
        return Left(ServerFailure(result.exception.toString()));
      }
      return Right(parser(result.data!));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  Stream<T> subscribe<T>({
    required String document,
    Map<String, dynamic>? variables,
    required T Function(Map<String, dynamic>) parser,
  }) {
    return _client
        .subscribe(SubscriptionOptions(
          document: gql(document),
          variables: variables ?? {},
        ))
        .where((result) => !result.hasException && result.data != null)
        .map((result) => parser(result.data!));
  }
}
```

## JSON Serialization with Freezed

```dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'item_model.freezed.dart';
part 'item_model.g.dart';

@freezed
class ItemModel with _$ItemModel {
  const factory ItemModel({
    required String id,
    required String name,
    @JsonKey(name: 'created_at') required DateTime createdAt,
    @Default(false) bool isActive,
    String? description,
  }) = _ItemModel;

  factory ItemModel.fromJson(Map<String, dynamic> json) =>
      _$ItemModelFromJson(json);
}

// Generate: dart run build_runner build --delete-conflicting-outputs
```
