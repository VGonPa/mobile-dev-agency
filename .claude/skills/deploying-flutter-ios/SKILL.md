---
name: deploying-flutter-ios
user-invocable: true
description: iOS deployment guide for Flutter apps. Use when configuring code signing, uploading to TestFlight, submitting to App Store, setting up Fastlane automation, or troubleshooting iOS build issues. Covers certificates, provisioning profiles, Info.plist, entitlements, and privacy manifests.
---

# Deploying Flutter iOS

Guide for deploying Flutter apps to the Apple App Store — focused on decisions, trade-offs, and the WHY behind each step.

**Templates and full configs:** See `REFERENCE.md` in this skill directory.

## When to Use This Skill

- Setting up iOS code signing (certificates, provisioning profiles)
- Configuring Xcode project settings for release
- Uploading builds to TestFlight
- Submitting apps to App Store
- Setting up Fastlane for iOS CI/CD
- Troubleshooting code signing or build errors

## When NOT to Use This Skill

- **Android deployment** -- use a dedicated Android/Play Store skill instead
- **iOS UI debugging** -- this skill covers build & release, not runtime UI issues
- **Simulator testing** -- simulators don't involve code signing or distribution; standard Flutter docs suffice
- **General Flutter questions** -- for widget development, state management, or non-iOS topics use other skills

## Prerequisites

```bash
# Apple Developer Program ($99/year) required for distribution
# WHY: Free accounts can only run on personal devices, not distribute via
# TestFlight or App Store. The $99 covers code signing infrastructure.

xcode-select --install

# WHY: Swift Package Manager is Flutter's recommended dependency manager
# since 3.24, replacing CocoaPods. Faster builds, better Xcode integration.
flutter config --enable-swift-package-manager

# Fallback: CocoaPods only if a plugin doesn't support SPM yet
# sudo gem install cocoapods
```

## Code Signing: Automatic vs Manual

### Decision Guide

| Situation | Choose | Why |
|-----------|--------|-----|
| Solo dev or small team | **Automatic** | Xcode handles certificates and profiles — zero maintenance |
| CI/CD pipeline | **Manual** or **Fastlane Match** | CI machines can't use Xcode's automatic signing (no GUI) |
| Multiple teams/apps | **Fastlane Match** | Shares certificates via encrypted Git repo — prevents the "2 certs per account" bottleneck |
| Enterprise distribution | **Manual** | Enterprise profiles require explicit management |

### Automatic Signing (Default Choice)

1. Open `ios/Runner.xcworkspace` in Xcode
2. Select Runner target → Signing & Capabilities
3. Check "Automatically manage signing"
4. Select your Team

**WHY this is the default:** Xcode creates, renews, and manages certificates and provisioning profiles. You never think about expiration dates or UDID lists. Only move to manual signing when you have a specific reason.

### Manual Signing (When You Need It)

**Certificate types:**

| Type | Purpose | Validity | Limit |
|------|---------|----------|-------|
| Development | Testing on devices | 1 year | Unlimited |
| Distribution | App Store & TestFlight | 1 year | Max 3 per account |

**WHY the 3-certificate limit matters:** If multiple team members each create Distribution certificates, you'll hit the cap. This is the #1 reason teams adopt Fastlane Match — it shares one certificate across all developers.

**Provisioning profiles — when to use each:**

| Profile | Use Case | Why This One |
|---------|----------|--------------|
| Development | Physical device testing | Tied to specific UDIDs — only registered devices can run |
| Ad Hoc | External testing (up to 100 devices) | For testers outside your org who can't use TestFlight |
| App Store | App Store & TestFlight | No device limit — Apple handles distribution |

**WHY Ad Hoc is rarely the right choice:** TestFlight supports 10,000 external testers with no UDID management. Use Ad Hoc only when testers can't install TestFlight (e.g., corporate-managed devices that block it).

## Xcode Project Configuration

### Essential Settings

In Xcode → Runner target → General:
- **Bundle Identifier**: `com.yourcompany.appname` (must match App ID — cannot change after first App Store submission)
- **Version**: From `pubspec.yaml` (user-visible: "1.2.0")
- **Build**: Increment for every upload (Apple rejects duplicate build numbers)
- **Minimum Deployments**: iOS 16.0+ recommended

**WHY iOS 16.0 minimum:** iOS 15 and below represent <5% of active devices. Supporting older versions adds maintenance burden (deprecated APIs, conditional code) with minimal reach. Check Apple's latest stats before deciding.

### Info.plist Permissions

**WHY this matters:** Every permission your app requests MUST have a usage description string. Missing descriptions cause **immediate App Store rejection** — Apple's automated checks catch this before human review.

**Rule:** Write permission strings from the user's perspective — what they gain, not what the app does technically.

**Template:** See `REFERENCE.md` → "Info.plist Common Permissions" for a copy-paste list of common permission keys with example user-benefit strings.

### Entitlements and Capabilities

| Capability | When Needed | Why Not Always On |
|-----------|-------------|-------------------|
| Push Notifications | FCM or APNs | Requires APNs key setup; unnecessary overhead if unused |
| Sign in with Apple | Apple login | Mandatory if you offer ANY third-party login (Apple policy) |
| Associated Domains | Universal links | Requires server-side `apple-app-site-association` file |
| HealthKit | Health data | Triggers additional App Store review scrutiny |

**WHY Sign in with Apple is special:** If your app offers Google, Facebook, or any other social login, Apple REQUIRES you also offer Sign in with Apple. Omitting it = rejection.

### Privacy Manifest (Required Since Spring 2024)

**WHY this exists:** Apple's privacy crackdown. Every app must declare which "required reason APIs" it uses and why. Missing manifests cause App Store rejection.

**Common Flutter triggers:**

| API Category | What Triggers It | Reason Code | Meaning |
|-------------|-----------------|-------------|---------|
| UserDefaults | SharedPreferences, most plugins | CA92.1 | App functionality |
| File timestamp | File I/O operations | C617.1 | App functionality |
| System boot time | Analytics packages | 35F9.1 | Measure time intervals |
| Disk space | Storage-checking packages | E174.1 | Check before write |

**HOW to determine which you need:** Build with `flutter build ios`, then check Xcode warnings for "Required Reason API" violations. Also audit your dependencies — each plugin may trigger additional API categories.

See `REFERENCE.md` for the full `PrivacyInfo.xcprivacy` template.

## Building for Release

### Version Management

```yaml
# pubspec.yaml
version: 1.0.0+1
# WHY the +N suffix: Apple requires a unique build number per upload.
# The semver part (1.0.0) is user-facing; the +1 is internal.
# Increment +N for every TestFlight/App Store upload, even if version stays same.
```

### Build Commands

```bash
flutter clean          # WHY: Stale build artifacts cause cryptic signing errors
flutter pub get
cd ios && pod install && cd ..  # WHY: Ensures native deps match pubspec.lock

flutter build ipa --release
# Output: build/ios/ipa/app.ipa
```

**WHY `flutter build ipa` over Xcode Archive:** Consistent, scriptable, and works in CI. Use Xcode Archive only when debugging Xcode-specific issues.

### Build via Xcode (When to Use)

Use Xcode's Product → Archive when:
- Diagnosing signing issues (better error messages)
- First-time setup verification
- Xcode-specific build settings need debugging

## TestFlight: Internal vs External

### Decision Guide

| Need | Choose | Why |
|------|--------|-----|
| Quick team testing | **Internal** | Instant access, no review, up to 100 testers |
| Beta with real users | **External** | Up to 10,000 testers, but requires Beta App Review (1-2 days) |
| Stakeholder demos | **Internal** | Faster iteration — no review wait |

**WHY Internal Testing is always the first step:** Immediate availability. Add your team in App Store Connect → TestFlight → Internal Testing. No waiting for Apple review.

**WHY External Testing requires review:** Apple checks for crashes, placeholder content, and broken features. They're more lenient than full App Store review but still reject obvious issues.

## App Store Connect

### Required Metadata

| Field | Limit | WHY It Matters |
|-------|-------|----------------|
| App Name | 30 chars | Searchable — front-load keywords |
| Subtitle | 30 chars | Shows below name in search results |
| Keywords | 100 chars | Comma-separated, no spaces after commas — maximize the 100 chars |
| Privacy Policy URL | Required | Rejection without it — even for apps collecting zero data |

### Screenshots

| Device | Resolution | Required? |
|--------|-----------|-----------|
| 6.9" (iPhone 16 Pro Max) | 1320 x 2868 | Yes (largest iPhone) |
| 6.7" (iPhone 15 Pro Max) | 1290 x 2796 | Yes |
| iPad Pro 13" (M4) | 2064 x 2752 | Only if supporting iPad |

**WHY you need the largest iPhone size:** Apple requires at least the newest device size. Older sizes auto-scale from larger screenshots. Upload 6.9" and 6.7" at minimum.

## Fastlane vs Manual: When to Automate

| Situation | Choose | Why |
|-----------|--------|-----|
| First app, learning the process | **Manual** (Xcode) | Understand what Fastlane automates before using it |
| Releasing more than once/month | **Fastlane** | Manual uploads take 15-20 min each; Fastlane takes 2 min |
| Team of 2+ developers | **Fastlane Match** | Prevents certificate conflicts and the 3-cert limit |
| CI/CD pipeline | **Fastlane** (required) | CI can't use Xcode GUI; Fastlane scripts are the standard |

**WHY Fastlane Match specifically:** It stores certificates in an encrypted Git repo. Every developer and CI machine pulls the same cert. No more "works on my machine" signing issues.

**CI/CD cost note:** GitHub Actions macOS runners cost 10x more than Linux runners. For solo devs or small teams, running Fastlane locally is cheaper than CI/CD. CI pays off when multiple developers need consistent releases or you want hands-off deployment on git tag push.

See `REFERENCE.md` for complete Fastlane and CI/CD templates.

## Common App Store Rejection Reasons

| Guideline | Rejection | How to Avoid |
|-----------|-----------|-------------|
| 2.1 — App Completeness | Crashes, broken features, placeholder content | Test every flow on physical device; remove "Coming Soon" screens |
| 4.3 — Spam | Too similar to existing apps (including your own) | Ensure unique value proposition; don't submit slight variants |
| 5.1.1 — Data Collection | Missing privacy policy or inadequate data safety disclosures | Privacy policy URL required even if you collect nothing; list ALL data types |
| 5.1.2 — Data Use | Using data for undisclosed purposes (tracking, analytics) | Privacy manifest must match actual API usage; declare all SDKs |
| 2.5.1 — API Usage | Using private APIs | Only use public Flutter/iOS APIs; audit native plugins |
| 4.0 — Design | Doesn't feel native, broken on newer devices | Test on latest iPhone; respect Safe Area and Dynamic Island |

**WHY this matters:** Rejection adds 1-3 days per cycle (fix, rebuild, resubmit, re-review). Knowing the top reasons lets you pre-check before submitting.

## Pre-Submission Checklist

- [ ] Version and build number updated in `pubspec.yaml`
- [ ] App icons generated (all sizes — use a generator tool)
- [ ] Launch screen configured (not the default Flutter one)
- [ ] Info.plist permissions have **user-benefit** description strings
- [ ] Privacy manifest (`PrivacyInfo.xcprivacy`) present and accurate
- [ ] Required capabilities enabled in entitlements
- [ ] Tested on **physical device** (not just simulator)
- [ ] TestFlight beta testing complete with real users
- [ ] All App Store Connect metadata filled
- [ ] Screenshots uploaded for required device sizes
- [ ] Privacy policy URL configured
- [ ] Export compliance answered (usually "No" for standard encryption)

## Troubleshooting

| Problem | Why It Happens | Fix |
|---------|---------------|-----|
| "No signing certificate found" | Certificate expired or not on this machine | Xcode → Settings → Accounts → Download Manual Profiles, or create new cert |
| "Provisioning profile doesn't include signing certificate" | Profile was created with a different cert | Toggle Automatic Signing off/on, or regenerate profile at developer.apple.com |
| "Invalid entitlements" | Runner.entitlements doesn't match App ID capabilities | Verify entitlements match, then `flutter clean` |
| CocoaPods module errors | Pod versions out of sync with lock file | `cd ios && pod deintegrate && pod install && cd .. && flutter clean` |
| Archive fails in Xcode | Wrong build target or stale cache | Target must be "Any iOS Device"; Cmd+Shift+K to clean; delete DerivedData |
| Privacy manifest rejection | Missing or incorrect API reason declarations | Audit all "required reason APIs" used by your app AND its dependencies |
| App Store rejection | Many possible causes | Read rejection message carefully; most common: missing permissions text, broken features, placeholder content |
