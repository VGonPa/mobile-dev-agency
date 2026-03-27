# Deploying Flutter iOS — Reference Templates

Copy-paste templates for iOS deployment. See `SKILL.md` for decision guidance on when and why to use each.

## PrivacyInfo.xcprivacy Template

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
      <string>NSPrivacyAccessedAPICategoryFileTimestamp</string>
      <key>NSPrivacyAccessedAPITypeReasons</key>
      <array><string>C617.1</string></array>
    </dict>
    <dict>
      <key>NSPrivacyAccessedAPIType</key>
      <string>NSPrivacyAccessedAPICategoryUserDefaults</string>
      <key>NSPrivacyAccessedAPITypeReasons</key>
      <array><string>CA92.1</string></array>
    </dict>
  </array>
</dict>
</plist>
```

## Info.plist Common Permissions

```xml
<!-- ios/Runner/Info.plist — add only the permissions your app actually uses -->
<key>NSCameraUsageDescription</key>
<string>Take photos for your workout journal</string>

<key>NSPhotoLibraryUsageDescription</key>
<string>Choose a profile photo from your library</string>

<key>NSLocationWhenInUseUsageDescription</key>
<string>Find nearby gyms and training facilities</string>

<key>NSMicrophoneUsageDescription</key>
<string>Record audio for video feedback sessions</string>

<key>NSMotionUsageDescription</key>
<string>Track movement data during exercises</string>

<key>NSHealthShareUsageDescription</key>
<string>Read health data to personalize your training plan</string>

<key>NSFaceIDUsageDescription</key>
<string>Securely sign in with Face ID</string>
```

## Fastlane Fastfile

```ruby
# ios/fastlane/Fastfile
default_platform(:ios)

platform :ios do
  lane :beta do
    increment_build_number(xcodeproj: "Runner.xcodeproj")

    build_app(
      scheme: "Runner",
      export_method: "app-store",
      output_directory: "./build/Runner",
    )

    upload_to_testflight(
      # WHY skip_waiting: Build processing on Apple's side takes 10-30 min.
      # Without this flag Fastlane blocks until processing completes, which
      # wastes CI minutes and delays the pipeline. The build still processes
      # — you just don't wait for it.
      skip_waiting_for_build_processing: true,
      distribute_external: true,
      groups: ["Beta Testers"],
      changelog: "Bug fixes and improvements",
    )
  end

  lane :release do
    ensure_git_status_clean

    increment_build_number(xcodeproj: "Runner.xcodeproj")

    build_app(scheme: "Runner", export_method: "app-store")

    upload_to_app_store(
      # WHY force: Skips the interactive HTML preview of App Store metadata
      # that Fastlane normally opens in your browser. Essential for CI (no
      # browser) and convenient locally once you trust your metadata.
      force: true,
      submit_for_review: false,
      automatic_release: false,
    )

    commit_version_bump(
      message: "Version Bump",
      xcodeproj: "Runner.xcodeproj",
    )
    add_git_tag(tag: "v#{get_version_number(xcodeproj: 'Runner.xcodeproj')}")
    push_to_git_remote
  end

  lane :certificates do
    # WHY readonly: Prevents Match from creating new certificates or profiles
    # if existing ones are missing. In CI this avoids accidentally revoking a
    # shared certificate; locally it protects against surprise cert rotation.
    # Remove readonly only when you intentionally need to regenerate.
    match(type: "appstore", app_identifier: "com.yourcompany.appname", readonly: true)
  end
end
```

## Fastlane Environment Variables

```bash
# ios/fastlane/.env (add to .gitignore)
FASTLANE_USER="your@email.com"
FASTLANE_APPLE_APPLICATION_SPECIFIC_PASSWORD="xxxx-xxxx-xxxx-xxxx"
MATCH_PASSWORD="your-match-encryption-password"
```

Create app-specific password at https://appleid.apple.com → Security.

## Fastlane Setup Commands

```bash
sudo gem install fastlane
cd ios
fastlane init
# Choose option 2: Automate TestFlight distribution

# Run lanes
fastlane beta      # Upload to TestFlight
fastlane release   # Submit to App Store
```

## CI/CD: GitHub Actions Workflow

```yaml
# .github/workflows/ios-deploy.yml
name: iOS Deploy
on:
  push:
    tags: ['v*']

jobs:
  deploy:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v4
      # WHY subosito/flutter-action: Installs Flutter SDK on the runner and
      # caches it between runs. Pin the version to avoid surprise breakage
      # from a new Flutter release mid-pipeline.
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.41.0'

      # WHY flutter pub get before test: Restores all Dart dependencies so
      # both tests and the subsequent IPA build use the same resolved versions.
      - run: flutter pub get
      # WHY run tests in CI: Catches regressions before spending 10+ minutes
      # on the expensive IPA build step. Fail fast, save macOS runner minutes.
      - run: flutter test

      - name: Install certificates
        env:
          P12_BASE64: ${{ secrets.P12_CERTIFICATE_BASE64 }}
          P12_PASSWORD: ${{ secrets.P12_PASSWORD }}
          PROVISION_PROFILE_BASE64: ${{ secrets.PROVISIONING_PROFILE_BASE64 }}
          KEYCHAIN_PASSWORD: ${{ secrets.KEYCHAIN_PASSWORD }}
        run: |
          # Create temporary keychain (CI machines don't have a persistent one)
          security create-keychain -p "$KEYCHAIN_PASSWORD" build.keychain
          security default-keychain -s build.keychain
          security unlock-keychain -p "$KEYCHAIN_PASSWORD" build.keychain

          # Import certificate
          echo "$P12_BASE64" | base64 --decode > certificate.p12
          security import certificate.p12 -k build.keychain -P "$P12_PASSWORD" -T /usr/bin/codesign
          security set-key-partition-list -S apple-tool:,apple: -s -k "$KEYCHAIN_PASSWORD" build.keychain

          # Install provisioning profile
          mkdir -p ~/Library/MobileDevice/Provisioning\ Profiles
          echo "$PROVISION_PROFILE_BASE64" | base64 --decode > ~/Library/MobileDevice/Provisioning\ Profiles/profile.mobileprovision

      - name: Build IPA
        run: flutter build ipa --release --export-options-plist=ios/ExportOptions.plist

      - name: Upload to TestFlight
        run: |
          gem install fastlane
          cd ios && fastlane beta
        env:
          FASTLANE_APPLE_APPLICATION_SPECIFIC_PASSWORD: ${{ secrets.APP_SPECIFIC_PASSWORD }}
          FASTLANE_USER: ${{ secrets.APPLE_ID }}

      - name: Cleanup keychain
        if: always()
        run: security delete-keychain build.keychain
```

## ExportOptions.plist Template

Referenced by the CI workflow's `flutter build ipa --export-options-plist` flag. This file tells `xcodebuild` how to sign and package the IPA without interactive prompts.

```xml
<!-- ios/ExportOptions.plist -->
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <!-- WHY method "app-store": Produces an IPA suitable for TestFlight and
       App Store submission. Use "ad-hoc" only for direct device installs. -->
  <key>method</key>
  <string>app-store</string>

  <!-- Replace with your Apple Developer Team ID (10-char alphanumeric).
       Find it at https://developer.apple.com/account → Membership Details. -->
  <key>teamID</key>
  <string>YOUR_TEAM_ID</string>

  <!-- WHY uploadSymbols: Sends dSYM files to Apple so that crash reports
       in App Store Connect are fully symbolicated. -->
  <key>uploadSymbols</key>
  <true/>

  <!-- WHY uploadBitcode false: Bitcode is deprecated since Xcode 14.
       Setting this to true causes build failures on modern toolchains. -->
  <key>uploadBitcode</key>
  <false/>

  <!-- Maps each bundle ID to its provisioning profile name.
       The profile name must match exactly what appears in
       Apple Developer Portal or Fastlane Match output. -->
  <key>provisioningProfiles</key>
  <dict>
    <key>com.yourcompany.appname</key>
    <string>match AppStore com.yourcompany.appname</string>
  </dict>
</dict>
</plist>
```

## Encode Secrets for CI

```bash
# Certificate (.p12)
base64 -i Certificates.p12 | pbcopy
# Paste into GitHub Secrets as P12_CERTIFICATE_BASE64

# Provisioning profile
base64 -i profile.mobileprovision | pbcopy
# Paste into GitHub Secrets as PROVISIONING_PROFILE_BASE64
```

**Tip:** For simpler CI setup, use `fastlane match` to manage certificates in a private Git repo — avoids manual Base64 encoding entirely.
