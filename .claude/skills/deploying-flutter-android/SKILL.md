---
name: deploying-flutter-android
user-invocable: true
description: Android deployment guide for Flutter apps. Use when creating keystores, configuring signing in build.gradle, uploading to Google Play Console, setting up internal/beta/production tracks, configuring ProGuard/R8, or automating with Fastlane. Covers app bundles, staged rollouts, and Play App Signing.
---

# Deploying Flutter Android

Guide for deploying Flutter apps to the Google Play Store — focused on decisions, trade-offs, and the WHY behind each step.

**Templates and full configs:** See `REFERENCE.md` in this skill directory.

## When to Use This Skill

- Creating upload keystores and configuring signing
- Configuring build.gradle for release builds
- Setting up Google Play Console and release tracks
- Configuring ProGuard/R8 rules
- Building app bundles (AAB) or APKs
- Setting up Fastlane for Android CI/CD
- Troubleshooting signing or build errors

## When NOT to Use This Skill

- **iOS deployment** — Use the iOS/Apple deployment skill instead (completely different signing, provisioning, and App Store Connect flow)
- **Firebase App Distribution** — Different tool and workflow; not Play Store deployment
- **Web or desktop builds** — This skill is Android-specific (Play Store, AAB, keystore signing)
- **Play Console admin tasks** — Account management, payment setup, or team permissions are outside scope

## Prerequisites

```bash
# Google Play Console account ($25 one-time fee)
# WHY one-time vs Apple's annual: Google's model has lower barrier to entry,
# but the $25 fee helps filter spam submissions.
# Processing time: ~48 hours for new account activation.

flutter doctor
flutter doctor --android-licenses
# WHY accept licenses: Required for building release APKs/AABs.
# These are Google's SDK license agreements.
```

## Keystore and Signing

### The Two-Key System

**WHY Android has two keys:**
1. **App Signing Key** — Google manages this (Play App Signing). Signs the APK users download.
2. **Upload Key** — You manage this. Signs the AAB you upload to Play Console.

This separation means: if you lose your upload key, Google can reset it. If there were only one key and you lost it, your app would be permanently un-updatable.

### Create Upload Keystore

```bash
keytool -genkey -v -keystore ~/upload-keystore.jks \
  -keyalg RSA \
  -keysize 2048 \
  -validity 10000 \
  -alias upload

# WHY 10000 days validity: ~27 years. Your upload key must outlive your app.
# A shorter validity means you'd need to re-register with Play Console.
#
# CRITICAL: Back up this file securely (password manager, encrypted drive).
# Loss = cannot update your app until Google resets your upload key.
```

### Configure Signing

```properties
# android/key.properties (CREATE THIS — add to .gitignore)
# WHY a separate file: Keeps secrets out of build.gradle,
# which IS committed to git. key.properties is gitignored.
storePassword=your-keystore-password
keyPassword=your-key-password
keyAlias=upload
storeFile=/Users/yourname/upload-keystore.jks
```

See `REFERENCE.md` for the complete `build.gradle` signing configuration.

## AAB vs APK: Which to Build

| Format | Choose When | Why |
|--------|------------|-----|
| **AAB** (App Bundle) | Always for Play Store | Google generates optimized APKs per device — 15-30% smaller downloads |
| **APK** | Direct distribution (no store) | Self-contained, no Google Play processing needed |
| **Split APK** | Testing size per architecture | Useful for debugging; Play Store handles this automatically for AABs |

```bash
# AAB (default choice for Play Store)
flutter build appbundle --release

# APK (only for direct distribution or testing)
flutter build apk --release
```

**WHY AAB is required:** Google Play requires AAB for new apps. It enables Dynamic Delivery — users only download the code and resources their specific device needs.

## Product Flavors: When to Use

| Situation | Use Flavors? | Why |
|-----------|-------------|-----|
| Single environment | **No** | Unnecessary complexity |
| Dev + Prod backends | **Yes** | Different `applicationId` means both can be installed simultaneously for testing |
| White-label apps | **Yes** | Different branding, icons, and bundle IDs per client |
| A/B testing at build level | **Rarely** | Use Remote Config instead — no separate builds needed |

**WHY `applicationIdSuffix`:** Adding `.dev` creates `com.yourcompany.app.dev` — a completely separate app from the user's perspective. You can have dev and prod installed side by side on the same device.

### Flavors vs `--dart-define`: Decision Rule

| Need | Use | Why |
|------|-----|-----|
| Different API URLs per environment | `--dart-define` | Simpler — no Gradle changes, just compile-time constants |
| Different app icons, names, or bundle IDs | **Flavors** | `--dart-define` can't change native resources |
| Separate Firebase projects per environment | **Flavors** | Different `google-services.json` per flavor |
| Only changing a few config values | `--dart-define` | Flavors are overkill for simple config |

**Rule of thumb:** Start with `--dart-define`. Switch to flavors only when you need different native resources (icons, app name, Firebase config) or separate app IDs on the same device.

See `REFERENCE.md` for the flavors template.

## ProGuard / R8: When and Why

**WHY R8 matters:** R8 (ProGuard's successor, built into Android) removes unused code and obfuscates class names. This makes your APK smaller and harder to reverse-engineer.

| Setting | Default | WHY |
|---------|---------|-----|
| `minifyEnabled true` | Off | Shrinks code — removes unused classes. Can break reflection-based libraries (Firebase, Gson). |
| `shrinkResources true` | Off | Removes unused resources (images, strings). Requires `minifyEnabled`. |

**WHY you need `-keep` rules:** R8 removes code it thinks is unused. But libraries using reflection (Firebase, Gson) access classes by name at runtime — R8 can't see those references. The `-keep` rules tell R8 "don't remove these."

**Debugging strategy:** If release builds crash but debug works, R8 is removing something needed. Temporarily set `minifyEnabled false` to confirm, then add specific `-keep` rules.

See `REFERENCE.md` for the complete ProGuard rules template.

## Google Play Console

### Release Tracks: Decision Guide

| Track | When to Use | Why This Track |
|-------|------------|----------------|
| **Internal** | Every build, first | Instant access, no review, up to 100 testers. Catches obvious issues before wider release. |
| **Closed** | Feature validation with selected users | Invite-only. Good for beta features you don't want public yet. |
| **Open** | Public beta | Anyone can join (up to 200K). Builds community trust. Requires Google review. |
| **Production** | Launch / updates | Public release. Always use staged rollout for updates. |

**WHY Internal first, always:** Zero review delay. Your build is available within minutes. Use this as your "it builds and runs" gate before any wider distribution.

### Staged Rollout Strategy

```
Internal → Closed Beta → Production (10%) → 50% → 100%
```

**WHY staged rollout:** If a crash-inducing bug slips through testing, it only affects 10% of users. You can halt the rollout, fix, and re-release. Going straight to 100% means every user gets the bug.

**Key metrics to monitor at each stage:**
- **Crash rate**: Should be <1%. Halt if >2%.
- **ANR rate** (App Not Responding): Should be <0.5%.
- **Uninstall rate**: Spike = something broke or upset users.

### Data Safety Section (Required)

**WHY this is critical:** Data safety is the **#1 cause of app rejections and removals** on Google Play. Google can suspend your app without warning for incomplete or inaccurate declarations.

**What to declare — common Flutter SDK data collection:**

| SDK / Feature | Data Collected | Purpose to Declare |
|---------------|---------------|-------------------|
| Firebase Analytics | Device ID, app interactions, screen views | Analytics |
| Firebase Crashlytics | Crash logs, device state, stack traces | App functionality (crash reporting) |
| Firebase Auth | Email, name, phone (if used) | Account management |
| Google AdMob | Advertising ID, device info | Advertising |
| Location services | Precise/approximate location | App functionality or analytics |
| Camera / Photos | Photos, videos | App functionality |

**Common mistakes that trigger rejection:**
1. **Not declaring Firebase Analytics** — it collects data even if you never call it explicitly
2. **Claiming "no data shared"** when using AdMob — ad networks share data by definition
3. **Missing data deletion disclosure** — you must state whether users can request deletion
4. **Forgetting Crashlytics** — crash logs contain device identifiers

**Process:** Play Console → App content → Data safety → Complete the form for every data type. Review every third-party SDK's documentation for what it collects. When in doubt, declare it — under-declaration gets rejected, over-declaration does not.

### Store Listing Metadata

| Field | Limit | Optimization Tip |
|-------|-------|-----------------|
| App name | 30 chars | Front-load primary keyword |
| Short description | 80 chars | Value proposition in one sentence |
| Full description | 4000 chars | Keywords in first 2 sentences — Play search indexes this |

## Play App Signing

**WHY Play App Signing exists:** Before PAS, if you lost your signing key, your app was dead — you'd have to publish under a new package name, losing all reviews and installs. PAS solves this.

- Google manages the app signing key in Cloud KMS (Hardware Security Module)
- You only need your upload key
- **Lost upload key? Google can reset it.** No more app death.
- Required for AABs (which are required for new apps)

```bash
# Get SHA fingerprints for Firebase, Maps API keys, etc.
# WHY you need this: Firebase and Google Maps verify your app identity via
# SHA fingerprint. You need BOTH the upload key SHA AND the app signing key SHA.
keytool -list -v -keystore ~/upload-keystore.jks -alias upload

# App signing key SHA: Play Console → Setup → App Integrity → App signing tab
```

## 16KB Page Size Alignment

**WHY this matters (since November 2025):** Android 15+ devices use 16KB memory pages. Apps compiled for 4KB pages crash on these devices. Google Play now requires 16KB support.

- Use NDK r28+, AGP 8.5.1+, Gradle 8.14+
- Flutter 3.22+ handles this automatically with recommended tool versions
- **Check:** If you pinned older NDK/AGP versions, update them

**Verify alignment after building:**

```bash
# Check if native libraries in your AAB/APK are 16KB aligned
# WHY: Google Play rejects uploads with misaligned native libs since Nov 2025
zipalign -c -P 16 -v 4 build/app/outputs/bundle/release/app-release.aab

# For APKs, extract and check .so files directly
unzip -l app-release.apk | grep '\.so$'
# Alignment offset should be 0 (mod 16384) for each .so file
```

## Fastlane vs Manual: When to Automate

| Situation | Choose | Why |
|-----------|--------|-----|
| First app, learning | **Manual** (Play Console) | Understand the upload flow before automating |
| Releasing monthly+ | **Fastlane** | Manual uploads take 10-15 min; Fastlane takes 1-2 min |
| CI/CD pipeline | **Fastlane** (required) | CI can't use Play Console GUI |
| Staged rollout management | **Fastlane `promote`** | One command to expand rollout percentage |

**WHY Fastlane needs a Service Account:** The Play Developer API requires authentication. A service account (JSON key) lets Fastlane upload without your personal Google credentials.

See `REFERENCE.md` for Fastlane setup, Fastfile template, and CI/CD workflow.

## Pre-Submission Checklist

- [ ] Version and versionCode updated in `pubspec.yaml` (versionCode MUST be higher than previous upload)
- [ ] `key.properties` configured and in `.gitignore`
- [ ] Signing config in `build.gradle` loads from `key.properties`
- [ ] ProGuard/R8 rules cover Flutter, Firebase, and any reflection-based libraries
- [ ] App icons generated (all densities: mdpi through xxxhdpi)
- [ ] AAB builds successfully with `flutter build appbundle --release`
- [ ] Tested release build on **physical device** (R8 can break things not caught in debug)
- [ ] Data safety section complete and accurate in Play Console
- [ ] Privacy policy URL configured
- [ ] Content rating questionnaire complete
- [ ] Store listing metadata and screenshots uploaded
- [ ] Target SDK meets Play Store requirements (35+ as of August 2025)

## Troubleshooting

| Problem | Why It Happens | Fix |
|---------|---------------|-----|
| "Failed to sign APK" | `key.properties` has wrong path or password | Verify with `keytool -list -v -keystore your.jks` |
| "App not properly signed" | Stale build artifacts with old signing config | `flutter clean && flutter build appbundle --release` |
| R8 crashes in release only | R8 removed a class accessed via reflection | Add `-keep` rule to `proguard-rules.pro`; temporarily `minifyEnabled false` to confirm |
| "Duplicate class found" | Two dependencies include the same library | Exclude transitive dep in `build.gradle`: `exclude group: 'com.example'` |
| "Version code already used" | Build number wasn't incremented | Increment `+N` in `pubspec.yaml` version |
| "Cannot rollout — no upgrade path" | New versionCode ≤ previous | Ensure new versionCode > all previous uploads across all tracks |
| Policy violation | Data safety, privacy policy, or content issues | Read email carefully — Google specifies exactly which policy and section |
