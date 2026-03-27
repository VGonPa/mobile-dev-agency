# Securing Flutter Apps — Implementation Reference

Implementation templates for security measures described in [SKILL.md](SKILL.md). Every template here corresponds to a decision made in SKILL.md — don't implement without reading the decision context first.

## Secure Storage Configuration

**Threat mitigated:** Credential theft from unencrypted storage.
**When needed:** Any app storing auth tokens, API keys, or user credentials (Tier 2+).

```dart
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const secureStorage = FlutterSecureStorage(
  aOptions: AndroidOptions(
    encryptedSharedPreferences: true, // AES via Android Keystore
  ),
  iOptions: IOSOptions(
    // first_unlock_this_device: most secure, data lost on device transfer
    // first_unlock: less secure, migrates via backup
    // Choose based on SKILL.md Step 2 decision table
    accessibility: KeychainAccessibility.first_unlock_this_device,
  ),
);

// Basic operations
await secureStorage.write(key: 'auth_token', value: token);
final token = await secureStorage.read(key: 'auth_token');
await secureStorage.delete(key: 'auth_token');
await secureStorage.deleteAll(); // Use on logout
```

## Certificate Pinning Implementation

**Threat mitigated:** MITM via compromised CA or corporate proxy.
**When needed:** Tier 3 apps only. Read SKILL.md Step 4 decision framework before implementing.

```dart
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'dart:io';
import 'dart:convert';
import 'package:crypto/crypto.dart';

class PinnedApiClient {
  final Dio dio;

  /// [pinnedHashes]: SPKI SHA-256 hashes (primary + backup).
  /// [pinningEnabled]: Remote config kill switch for emergencies.
  PinnedApiClient({
    required List<String> pinnedHashes,
    required bool pinningEnabled,
  }) : dio = Dio() {
    if (!pinningEnabled) return; // Kill switch: skip pinning if disabled

    dio.httpClientAdapter = IOHttpClientAdapter(
      createHttpClient: () {
        final client = HttpClient();
        client.badCertificateCallback = (cert, host, port) {
          // Compare against ALL pinned hashes (primary + backup keys)
          final certHash = sha256.convert(cert.der).toString();
          return pinnedHashes.contains(certHash);
        };
        return client;
      },
    );
  }
}

// Usage with kill switch via remote config:
// final client = PinnedApiClient(
//   pinnedHashes: [
//     'current_cert_spki_hash',   // Primary
//     'next_rotation_cert_hash',  // Backup — CRITICAL for rotation
//   ],
//   pinningEnabled: remoteConfig.getBool('enable_cert_pinning'),
// );
```

**Rotation planning checklist:**
- [ ] SPKI pin (not leaf cert) — survives cert renewal if key unchanged
- [ ] Backup hash for next rotation's certificate
- [ ] Remote config kill switch tested and documented
- [ ] Team knows the "cert rotated, app broken" emergency playbook
- [ ] Monitoring for pin validation failures (don't discover via user reports)

## Token Refresh Implementation

**Threat mitigated:** Session hijacking, use of expired tokens.
**When needed:** Apps with custom (non-Firebase) auth backends.
**When NOT needed:** Firebase Auth apps — the SDK handles refresh automatically.

```dart
class AuthInterceptor extends Interceptor {
  final FlutterSecureStorage _storage;
  // WHY separate Dio: If we reuse the main Dio instance for the refresh call,
  // the 401 response from a failed refresh triggers THIS SAME interceptor again,
  // causing infinite recursion: 401 → refresh → 401 → refresh → stack overflow.
  // A bare Dio instance has no interceptors, so the refresh call completes cleanly.
  final Dio _tokenDio;

  AuthInterceptor(this._storage) : _tokenDio = Dio();

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    final token = await _storage.read(key: 'auth_token');
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode == 401) {
      final refreshed = await _attemptRefresh();
      if (refreshed) {
        // Retry original request with new token
        final token = await _storage.read(key: 'auth_token');
        err.requestOptions.headers['Authorization'] = 'Bearer $token';
        final response = await _tokenDio.fetch(err.requestOptions);
        return handler.resolve(response);
      }
      // Refresh failed — force logout
      await _clearTokens();
    }
    handler.next(err);
  }

  Future<bool> _attemptRefresh() async {
    try {
      final refreshToken = await _storage.read(key: 'refresh_token');
      if (refreshToken == null) return false;

      final response = await _tokenDio.post(
        '/auth/refresh',
        data: {'refresh_token': refreshToken},
      );

      await _storage.write(key: 'auth_token', value: response.data['access_token']);
      await _storage.write(key: 'refresh_token', value: response.data['refresh_token']);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<void> _clearTokens() async {
    await _storage.deleteAll();
    // Navigate to login — implement via callback or event bus
  }
}
```

**Key detail:** Use a separate `Dio` instance (`_tokenDio`) for the refresh call. If you use the same instance, the refresh request triggers the same interceptor, causing infinite recursion on 401.

## Biometric Authentication

**Threat mitigated:** Unauthorized access on stolen/unlocked device.
**When needed:** Gating sensitive operations (payments, viewing PII, changing security settings).

```dart
import 'package:local_auth/local_auth.dart';

class BiometricGate {
  final LocalAuthentication _auth = LocalAuthentication();

  /// Returns true if device supports biometrics or passcode.
  Future<bool> isAvailable() async {
    try {
      return await _auth.canCheckBiometrics || await _auth.isDeviceSupported();
    } catch (e) {
      return false; // Fail open for availability check
    }
  }

  /// Prompt user for biometric/passcode verification.
  /// [reason] shown to user — be specific: "Confirm payment of €49.99"
  Future<bool> authenticate({required String reason}) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          // WHY stickyAuth: Without this, the auth dialog is dismissed if the user
          // briefly switches apps (e.g., to check a 2FA code). That forces them to
          // restart the entire flow — terrible UX for legitimate users.
          stickyAuth: true,
          // WHY not biometricOnly: Not all devices have biometrics, and not all users
          // CAN use biometrics (accessibility). PIN/passcode fallback ensures no one
          // is locked out of their own account.
          biometricOnly: false,
          // WHY sensitiveTransaction: Tells the OS this is a high-stakes operation
          // (payment, data access). On Android, this forces strong biometric class
          // (fingerprint/face, not just device unlock) when available.
          sensitiveTransaction: true,
        ),
      );
    } catch (e) {
      return false;
    }
  }
}
```

**Platform configuration:**

```xml
<!-- iOS: ios/Runner/Info.plist -->
<key>NSFaceIDUsageDescription</key>
<string>Authenticate to confirm sensitive actions</string>

<!-- Android: android/app/src/main/AndroidManifest.xml -->
<uses-permission android:name="android.permission.USE_BIOMETRIC"/>
```

## Custom Encryption (When Actually Needed)

**When needed:** Encrypted databases, file encryption, E2E messaging, compliance requirements.
**When NOT needed:** Data already in `flutter_secure_storage` (it's already encrypted).

```dart
import 'package:encrypt/encrypt.dart';
import 'dart:math';
import 'dart:convert';

class AppEncryption {
  final Encrypter _encrypter;

  AppEncryption._(Key key) : _encrypter = Encrypter(AES(key));

  /// Load or generate encryption key, stored in secure storage.
  static Future<AppEncryption> create() async {
    const storage = FlutterSecureStorage();
    var keyString = await storage.read(key: 'app_encryption_key');
    if (keyString == null) {
      // Generate 256-bit key from secure random
      keyString = base64.encode(
        List<int>.generate(32, (_) => Random.secure().nextInt(256)),
      );
      await storage.write(key: 'app_encryption_key', value: keyString);
    }
    return AppEncryption._(Key.fromBase64(keyString));
  }

  /// Encrypt with fresh IV per operation (CRITICAL: reusing IVs breaks AES-CBC).
  ///
  /// WHY AES-CBC (not GCM): The `encrypt` package defaults to CBC. GCM (Galois/Counter Mode)
  /// provides authenticated encryption (integrity + confidentiality) and is preferred for
  /// network protocols. But for local storage encryption, CBC with unique IVs is sufficient
  /// and more widely supported across Flutter encryption packages. If you need tamper
  /// detection (e.g., detecting if someone modified the ciphertext), switch to GCM or
  /// add an HMAC over the ciphertext.
  String encrypt(String plainText) {
    final iv = IV.fromSecureRandom(16);
    final encrypted = _encrypter.encrypt(plainText, iv: iv);
    // WHY IV stored with ciphertext: The IV is not secret — it just needs to be unique.
    // Storing it alongside the ciphertext lets us decrypt without external state.
    return '${iv.base64}:${encrypted.base64}';
  }

  String decrypt(String encryptedText) {
    final parts = encryptedText.split(':');
    final iv = IV.fromBase64(parts[0]);
    return _encrypter.decrypt(Encrypted.fromBase64(parts[1]), iv: iv);
  }
}
```

**Encryption decision tree:**
- Data in `flutter_secure_storage` → Already encrypted. Stop.
- Data in SQLite/Hive → Use `sqflite_sqlcipher` or Hive's built-in encryption.
- Files on disk → Use `AppEncryption` above.
- Data sent over network → HTTPS handles it. Don't encrypt twice.

## Input Validation

**Threat mitigated:** XSS, injection attacks (when paired with server-side validation), malformed data crashes.

```dart
class InputValidator {
  // WHY client-side validation exists at all: These validators are NOT security
  // boundaries — an attacker can skip the Flutter app entirely and call your API.
  // Client-side validation exists for UX: instant feedback, fewer server round trips,
  // and clear error messages. The server MUST re-validate everything independently.

  /// Email format (UX only — server must re-validate)
  /// WHY this regex: Simple and intentionally permissive. RFC 5322 email regex is
  /// 6,000+ chars and still doesn't cover all edge cases. Let the server (which
  /// actually sends the verification email) do the real validation.
  static bool isValidEmail(String email) {
    return RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$')
        .hasMatch(email);
  }

  /// Password strength (UX feedback — server enforces policy)
  /// WHY check client-side: So the user sees "needs uppercase" immediately,
  /// not after a round trip. The server's policy is the source of truth.
  static bool isStrongPassword(String password) {
    if (password.length < 8) return false;
    return password.contains(RegExp(r'[A-Z]')) &&
           password.contains(RegExp(r'[a-z]')) &&
           password.contains(RegExp(r'[0-9]')) &&
           password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));
  }

  /// HTML sanitization — prevents XSS if rendering user content in WebViews
  /// WHY entity encoding: Replacing < > " ' with HTML entities ensures that
  /// user input is rendered as TEXT, not parsed as HTML/JS. Without this,
  /// `<script>alert('xss')</script>` would execute in a WebView.
  static String sanitizeHtml(String input) {
    return input
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#x27;');
  }

  /// URL validation — prevents navigation to malicious schemes
  /// WHY scheme allowlist: Without this, an attacker could pass `javascript:`,
  /// `file:`, or custom schemes to trigger unintended behavior in WebViews
  /// or deep link handlers. Only http/https are safe for general navigation.
  static bool isValidUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https');
    } catch (e) {
      return false;
    }
  }
}
```

**Remember:** These are UX validators. Server-side validation is what actually prevents attacks.

## Platform Security Configuration

### Android: Network Security Config

**Threat mitigated:** Cleartext traffic interception.

```xml
<!-- android/app/src/main/AndroidManifest.xml -->
<application android:networkSecurityConfig="@xml/network_security_config">
```

```xml
<!-- android/app/src/main/res/xml/network_security_config.xml -->
<?xml version="1.0" encoding="utf-8"?>
<network-security-config>
  <base-config cleartextTrafficPermitted="false"/>
  <!-- Debug exception for local development -->
  <debug-overrides>
    <trust-anchors>
      <certificates src="system"/>
    </trust-anchors>
  </debug-overrides>
</network-security-config>
```

### iOS: App Transport Security

```xml
<!-- ios/Runner/Info.plist -->
<key>NSAppTransportSecurity</key>
<dict>
  <key>NSAllowsArbitraryLoads</key>
  <false/>
  <!-- For local development only: -->
  <!-- <key>NSExceptionDomains</key>
  <dict>
    <key>localhost</key>
    <dict>
      <key>NSExceptionAllowsInsecureHTTPLoads</key>
      <true/>
    </dict>
  </dict> -->
</dict>
```

### iOS Privacy Manifest

```xml
<!-- ios/Runner/PrivacyInfo.xcprivacy -->
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>NSPrivacyTracking</key>
  <false/>
  <key>NSPrivacyTrackingDomains</key>
  <array/>
  <key>NSPrivacyCollectedDataTypes</key>
  <array/>
  <key>NSPrivacyAccessedAPITypes</key>
  <array>
    <dict>
      <key>NSPrivacyAccessedAPIType</key>
      <string>NSPrivacyAccessedAPICategoryUserDefaults</string>
      <key>NSPrivacyAccessedAPITypeReasons</key>
      <array><string>CA92.1</string></array>
    </dict>
    <!-- Add entries based on Xcode build warnings -->
  </array>
</dict>
</plist>
```

## Screenshot Prevention

**When appropriate:** Banking, health records, enterprise confidential data.
**When NOT appropriate:** Most consumer apps. Users expect screenshots.

```kotlin
// android/app/src/main/kotlin/.../MainActivity.kt
import android.view.WindowManager

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        window.setFlags(
            WindowManager.LayoutParams.FLAG_SECURE,
            WindowManager.LayoutParams.FLAG_SECURE
        )
    }
}
```

**iOS:** No direct equivalent. Detect screen recording via `UIScreen.capturedDidChangeNotification` and overlay/blur sensitive content while recording is active.

## Root/Jailbreak Detection

**Important:** This is bypassable. Defense-in-depth only — never the sole security gate.

```dart
// dependencies: flutter_jailbreak_detection: ^1.10.0
import 'package:flutter_jailbreak_detection/flutter_jailbreak_detection.dart';

Future<bool> isDeviceCompromised() async {
  try {
    return await FlutterJailbreakDetection.jailbroken;
  } catch (e) {
    return false; // Fail open — don't lock legitimate users out
  }
}

// Recommended: warn + limit, don't hard-block
// if (await isDeviceCompromised()) {
//   showWarningDialog('Device may be compromised. Some features restricted.');
//   disablePaymentFeatures();
// }
```

## Deep Link Validation

**Threat mitigated:** URL scheme hijacking, malicious parameter injection.

```dart
class DeepLinkHandler {
  static const _allowedHosts = {'yourdomain.com', 'www.yourdomain.com'};

  static Future<void> handleDeepLink(Uri uri) async {
    // Only accept verified schemes (Universal Links / App Links)
    if (uri.scheme != 'https') {
      throw SecurityException('Only HTTPS deep links accepted');
    }
    // Validate against allowlist
    if (!_allowedHosts.contains(uri.host)) {
      throw SecurityException('Unrecognized host: ${uri.host}');
    }
    // Sanitize parameters before routing
    final safeParams = uri.queryParameters.map(
      (key, value) => MapEntry(key, InputValidator.sanitizeHtml(value)),
    );
    // Route with validated params
  }
}
```
