---
name: securing-flutter-apps
description: Secures Flutter applications using threat-model-driven decisions. Use when implementing secure storage, protecting API keys, adding certificate pinning, validating input, configuring platform security, or auditing app security before release. Starts with threat profile assessment to determine WHICH measures are needed vs overkill.
user-invocable: true
---

# Securing Flutter Apps

Security decisions depend on your app's threat profile. A fitness tracker and a banking app need fundamentally different security postures. This skill helps you make the right decisions — not just copy security code.

> **Common Mistakes This Skill Prevents**
>
> - Using `SharedPreferences` for auth tokens (plain text on disk)
> - Adding AES encryption on top of `flutter_secure_storage` (security theater — it's already encrypted)
> - Implementing certificate pinning on a consumer app with no rotation plan (bricks the app when certs rotate)
> - Setting `NSAllowsArbitraryLoads = true` in production (disables all iOS transport security)
> - Reusing IVs in AES-CBC encryption (breaks the encryption scheme entirely)
> - Hard-blocking rooted/jailbroken devices instead of warn-and-limit (locks out legitimate users)
> - Relying on client-side validation alone for security (attackers bypass the app and call the API directly)

## When to Use This Skill

- Deciding which security measures your app actually needs
- Storing sensitive data (tokens, credentials, user data)
- Protecting API keys and secrets
- Evaluating whether to add certificate pinning
- Configuring platform security (iOS/Android)
- Pre-release security audit

## When NOT to Use This Skill

This skill covers **Flutter client-side mobile app security only**. It does NOT cover:

- **Server-side security** — backend hardening, API rate limiting, WAF configuration, database security
- **Web app security** — CORS, CSP headers, cookie security, browser-specific vulnerabilities
- **CI/CD pipeline security** — secrets management in GitHub Actions/Codemagic, build artifact signing
- **Dependency scanning** beyond `dart pub outdated` — for deep supply chain audits, use dedicated tools (Snyk, Dependabot, OSV-Scanner)
- **Penetration testing** — this skill provides defensive implementation, not offensive testing methodology

## Step 1: Determine Your Threat Profile

Before implementing ANY security measure, answer: **What are you protecting, and from whom?**

### Threat Profile Decision Matrix

| Question | If Yes → | If No → |
|----------|----------|---------|
| Does the app handle payment data? | Tier 3 | Continue |
| Does the app handle health/medical data? | Tier 3 | Continue |
| Does the app have user accounts with PII? | Tier 2 | Continue |
| Does the app access authenticated APIs? | Tier 2 | Continue |
| Is it a content-only / no-login app? | Tier 1 | Tier 2 (default) |

### Security Tiers

| Tier | Example Apps | Required Measures |
|------|-------------|-------------------|
| **Tier 1: Public** | News reader, calculator, weather | HTTPS, code obfuscation, no hardcoded secrets |
| **Tier 2: User Data** | Social app, fitness tracker, task manager | Tier 1 + secure storage, token management, input validation, platform hardening |
| **Tier 3: Sensitive** | Banking, health records, enterprise | Tier 2 + certificate pinning, biometric gates, enhanced logging controls, screenshot prevention |

**Default to Tier 2.** Most Flutter apps with user accounts land here. Tier 3 measures on a Tier 2 app add complexity without proportional security benefit.

## Step 2: Secure Storage (Tier 2+)

**Threat:** Malware or physical access reading stored credentials from unencrypted storage.

**Rule:** `SharedPreferences` stores data in **plain text XML/plist**. Anyone with device access (or root/jailbreak) can read it.

```dart
// NEVER: SharedPreferences is NOT encrypted
await prefs.setString('auth_token', token); // Plain text on disk!

// ALWAYS: flutter_secure_storage uses Keychain (iOS) / Keystore (Android)
final storage = FlutterSecureStorage();
await storage.write(key: 'auth_token', value: token);
```

### Platform Storage Decision

**iOS Keychain accessibility** — controls WHEN the OS allows reads:

| Option | Tradeoff | Use When |
|--------|----------|----------|
| `first_unlock_this_device` | More secure. Data lost on device transfer/restore. | Auth tokens (re-login is acceptable) |
| `first_unlock` | Less secure. Migrates via backup. | User preferences that feel like "settings" |

**Android** — always enable `encryptedSharedPreferences: true` (uses Android Keystore-backed AES).

See [REFERENCE.md → Secure Storage Configuration](REFERENCE.md#secure-storage-configuration) for full setup.

## Step 3: API Key Protection (All Tiers)

**Threat:** API keys in source code → pushed to GitHub → scraped by bots → abused.

### What Works

```bash
# Compile-time injection (keeps keys out of source)
flutter run --dart-define-from-file=env.json  # env.json in .gitignore!
```

```dart
static const apiKey = String.fromEnvironment('API_KEY');
```

### ⚠️ WARNING: `--dart-define` Is NOT Truly Secret

**`--dart-define` values are embedded in the compiled binary.** A motivated attacker can extract them with `strings` or reverse engineering tools. This approach protects against:
- ✅ Keys ending up in Git history
- ✅ Keys visible in source code reviews

It does NOT protect against:
- ❌ Binary reverse engineering (APK/IPA decompilation)
- ❌ Runtime extraction on rooted devices

**Decision:**
- **Low-sensitivity keys** (analytics, maps, crash reporting): `--dart-define` is sufficient.
- **High-sensitivity keys** (payment APIs, admin endpoints): **Proxy through your backend.** The client never sees the real key. This is the only truly secure approach.

## Step 4: Network Security (Tier 2+)

**Threat:** Man-in-the-middle (MITM) attacks intercepting API traffic.

### HTTPS: Non-Negotiable

Both iOS (App Transport Security) and Android (Network Security Config, API 28+) block cleartext HTTP by default. **Don't weaken these defaults.**

**When you DO need to allow cleartext:** Local development only. Use platform-specific debug exceptions — never disable globally. See [REFERENCE.md → Platform Security Configuration](REFERENCE.md#platform-security-configuration).

### Certificate Pinning: A Tier 3 Decision

**What it protects against:** Compromised Certificate Authorities, corporate MITM proxies, government-level surveillance.

**What it does NOT protect against:** Device compromise, app reverse engineering, server-side breaches.

**⚠️ CRITICAL: Certificate Pinning Has Operational Cost**

When you pin a certificate and that certificate **rotates** (which happens annually for most CAs), your app **stops working** until you ship an update that users install. This can brick your app for days.

**Decision framework:**

| Scenario | Pin? | Why |
|----------|------|-----|
| Banking/health/regulated app | Yes | Regulatory requirement. Worth operational cost. |
| App with sensitive PII, dedicated security team | Maybe | Use SPKI pinning for longer rotation windows. |
| Consumer app, small team | No | Cert rotation risk outweighs MITM risk. HTTPS is sufficient. |
| App with no user data | No | Nothing worth intercepting. |

**If you DO pin:**
1. Pin the **Subject Public Key Info (SPKI)**, not the leaf certificate — survives cert renewals if the key stays the same
2. Pin **backup keys** (next rotation's key) so rotation doesn't break the app
3. Have a **kill switch** (remote config flag to disable pinning in emergencies)
4. Never pin ALL endpoints — leave non-critical endpoints unpinned as fallback

See [REFERENCE.md → Certificate Pinning Implementation](REFERENCE.md#certificate-pinning-implementation) for code.

## Step 5: Authentication Security (Tier 2+)

**Threat:** Token theft, session hijacking, unauthorized access after token expiry.

### Token Management Decision

**Using Firebase Auth?** Token refresh is handled automatically by the Firebase SDK. **You do NOT need custom token refresh logic.** Skip to biometrics.

**Using custom auth / non-Firebase backend?** You need:
- Secure token storage (Step 2)
- Automatic token refresh via interceptor
- Logout on refresh failure (don't leave stale tokens)

See [REFERENCE.md → Token Refresh Implementation](REFERENCE.md#token-refresh-implementation) for the interceptor pattern.

### Biometric Authentication (Tier 3, or Tier 2 for specific actions)

**Threat:** Unauthorized access on a stolen/unlocked device.

**When to require biometrics:**

| Operation | Biometric Gate? | Why |
|-----------|----------------|-----|
| Payment / purchase | Yes | Financial consequence |
| Viewing sensitive data (health, financial) | Yes | Privacy protection |
| Changing security settings (password, email) | Yes | Prevent account takeover |
| Normal app launch | **No** | UX friction without proportional security benefit |
| Viewing non-sensitive content | **No** | Annoying, users will disable |

**Key rule:** `biometricOnly: false` — always allow PIN/passcode fallback. Not all devices have biometrics. Not all users can use biometrics (accessibility).

See [REFERENCE.md → Biometric Authentication](REFERENCE.md#biometric-authentication) for implementation.

## Step 6: Data Encryption — When You Actually Need It

**Threat:** Data at rest accessed by malware or physical device access.

### ⚠️ Common Anti-Pattern: Double Encryption

`flutter_secure_storage` already encrypts data using the platform's hardware-backed encryption:
- **iOS:** Keychain (Secure Enclave on supported hardware)
- **Android:** AES-256 via Android Keystore

**Adding AES encryption on top of `flutter_secure_storage` is security theater.** The data is already encrypted. Custom encryption adds complexity and potential bugs (key management, IV handling) with zero additional security.

### When You DO Need Custom Encryption

| Scenario | Why Built-in Isn't Enough |
|----------|--------------------------|
| Encrypted SQLite/Hive database | `flutter_secure_storage` is key-value only. Database files sit on disk unencrypted. |
| File-level encryption (exported documents, cached files) | Files in app storage aren't encrypted by default. |
| End-to-end encrypted messaging | Encryption must happen before data leaves the device. |
| Compliance requirement (HIPAA, PCI-DSS) specifying algorithm | Auditor needs to see specific algorithm in application code. |

**If none of these apply → don't add custom encryption.** Use `flutter_secure_storage` for secrets and trust the platform.

See [REFERENCE.md → Custom Encryption](REFERENCE.md#custom-encryption-when-actually-needed) for implementation when genuinely needed.

## Step 7: Input Validation

**Threat:** Injection attacks (XSS, SQL injection) and malformed data causing crashes.

### The One Rule

**Client-side validation is UX. Server-side validation is security.**

Never rely on client-side validation alone. A determined attacker bypasses your Flutter app entirely and calls your API directly. Client validation prevents user mistakes and improves UX. Server validation prevents attacks.

**What to validate client-side (UX):**
- Email format, password strength → better error messages
- URL format → prevent navigation errors

**What MUST be validated server-side (security):**
- All input that touches a database query
- All input that gets rendered as HTML/web content
- File uploads (type, size, content)
- Any input used in server-side operations

See [REFERENCE.md → Input Validation](REFERENCE.md#input-validation) for validator patterns.

## Step 8: Platform Security Hardening (Tier 2+)

### Android: Network Security Config

Block cleartext traffic explicitly. Android 9+ does this by default, but explicit config ensures it across all API levels and satisfies auditors.

### iOS: App Transport Security

ATS blocks HTTP by default. **Never set `NSAllowsArbitraryLoads` to `true` in production** — this disables ALL transport security.

### iOS Privacy Manifests (Required since Spring 2024)

Apple rejects apps that use certain APIs without declaring WHY. Common Flutter triggers:

| API Category | Flutter Trigger | Required Reason Code |
|-------------|----------------|---------------------|
| UserDefaults | SharedPreferences, most Flutter plugins | CA92.1 (app functionality) |
| File timestamp | Some file I/O operations | C617.1 (app functionality) |
| System boot time | Analytics packages | 35F9.1 (measure time intervals) |
| Disk space | Storage-checking packages | E174.1 (check storage before write) |

**How to determine which you need:** Run `flutter build ios`, then check Xcode warnings for "Required Reasons API" violations.

See [REFERENCE.md → Platform Security Configuration](REFERENCE.md#platform-security-configuration) for config files.

## Step 9: Additional Hardening (Tier 3)

### Screenshot Prevention

**When appropriate:** Banking, health records, enterprise apps with confidential data.
**When NOT appropriate:** Social apps, content apps, most consumer apps. Users expect to screenshot.

**Android:** `FLAG_SECURE` on the window.
**iOS:** No direct API. Detect screen recording via `UIScreen.capturedDidChangeNotification` and blur sensitive content.

### Root/Jailbreak Detection

**Important:** Root/jailbreak detection is **bypassable** by determined attackers. Use as defense-in-depth signal, never as the sole security gate.

**Decision:** Detect and **warn** or **limit functionality**, don't hard-block. Users with legitimate rooted devices (developers, custom ROM users) will leave 1-star reviews.

### Code Obfuscation

```bash
# Always for release builds — no reason not to
flutter build apk --obfuscate --split-debug-info=./debug-info
flutter build ios --obfuscate --split-debug-info=./debug-info
```

**What it protects:** Makes reverse engineering harder (not impossible). Raises the bar for casual attackers.
**What it doesn't protect:** Determined attackers with decompilation tools. Obfuscation is delay, not prevention.
**`--split-debug-info`** is required — it removes debug symbols. Without it, obfuscation flag has minimal effect. Keep the `debug-info/` directory for crash symbolication but **never ship it**.

### Secure Deep Links

**Threat:** Malicious apps registering the same deep link scheme to intercept sensitive data (login tokens, reset codes).

**Rule:** Use Universal Links (iOS) / App Links (Android) with HTTPS verification, not custom URL schemes. Custom schemes (`yourapp://`) can be hijacked by any app.

### Logging Security

```dart
// NEVER log sensitive data — even in debug mode
logger.d('Password: $password');   // NEVER! Logs persist in crash reports
logger.d('Token: $token');         // NEVER! Accessible via logcat/Console

// GOOD: Log actions, not data
logger.i('Login attempt for user ID: ${user.id}');
logger.i('Payment processed: txn_${transaction.id}');
```

**Production rule:** Use `Logger` with a production filter that drops debug/verbose logs. Or check `kReleaseMode` before logging.

## OWASP Mobile Top 10 → Skill Cross-Reference

| # | Risk | Where Addressed |
|---|------|----------------|
| M1 | Improper Credential Usage | Step 2 (Secure Storage), Step 3 (API Keys) |
| M2 | Inadequate Supply Chain | Lock versions in pubspec.lock, audit with `dart pub outdated` |
| M3 | Insecure Auth/Authorization | Step 5 (Token Management, Biometrics) |
| M4 | Insufficient Input/Output Validation | Step 7 (Input Validation) |
| M5 | Insecure Communication | Step 4 (HTTPS, Certificate Pinning) |
| M6 | Inadequate Privacy Controls | Step 8 (Privacy Manifests, minimum permissions) |
| M7 | Insufficient Binary Protections | Step 9 (Obfuscation) |
| M8 | Security Misconfiguration | Step 8 (Platform Hardening) |
| M9 | Insecure Data Storage | Step 2 (Secure Storage), Step 6 (Encryption) |
| M10 | Insufficient Cryptography | Step 6 (When to encrypt, anti-patterns) |

## Pre-Release Security Audit

### Tier 1 (Every App)

- [ ] No hardcoded API keys in source code
- [ ] HTTPS for all network requests
- [ ] Code obfuscation enabled for release builds
- [ ] Debug logs removed from production builds
- [ ] `env.json` / `.env` files in `.gitignore`
- [ ] Dependencies audited (`dart pub outdated`, check advisories)

### Tier 2 (User Data Apps) — includes all Tier 1

- [ ] All secrets in `flutter_secure_storage` (not SharedPreferences)
- [ ] Token refresh implemented (or using Firebase Auth)
- [ ] Input validation on all user-facing inputs
- [ ] Server-side validation for all security-critical inputs
- [ ] Android network security config blocks cleartext
- [ ] iOS ATS not weakened
- [ ] iOS Privacy Manifest configured
- [ ] Minimum permissions requested (audit `AndroidManifest.xml` and `Info.plist`)
- [ ] Deep links use Universal Links / App Links (not custom schemes for sensitive flows)

### Tier 3 (Sensitive Data Apps) — includes all Tier 1 + 2

- [ ] Certificate pinning on critical endpoints with rotation plan documented
- [ ] Backup pins configured for next certificate rotation
- [ ] Kill switch for pinning failures (remote config)
- [ ] Biometric auth gates sensitive operations (with PIN fallback)
- [ ] Screenshot prevention on sensitive screens
- [ ] Root/jailbreak detection as defense-in-depth signal
- [ ] Sensitive data never logged (audit all logger calls)
- [ ] Data encryption for database/files if required by compliance
