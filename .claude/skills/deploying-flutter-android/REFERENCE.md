# Deploying Flutter Android — Reference Templates

Copy-paste templates for Android deployment. See `SKILL.md` for decision guidance on when and why to use each.

## build.gradle Signing Configuration

```groovy
// android/app/build.gradle

// Load keystore properties from gitignored file
def keystoreProperties = new Properties()
def keystorePropertiesFile = rootProject.file('key.properties')
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(new FileInputStream(keystorePropertiesFile))
}

android {
    namespace "com.yourcompany.appname"
    compileSdk 35

    compileOptions {
        sourceCompatibility JavaVersion.VERSION_17
        targetCompatibility JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = '17'
    }

    defaultConfig {
        applicationId "com.yourcompany.appname"
        minSdk 21
        targetSdk 35  // Required for new Play Store submissions (Aug 2025+)
        versionCode flutterVersionCode.toInteger()
        versionName flutterVersionName
        multiDexEnabled true
    }

    signingConfigs {
        release {
            keyAlias keystoreProperties['keyAlias']
            keyPassword keystoreProperties['keyPassword']
            storeFile keystoreProperties['storeFile'] ?
                file(keystoreProperties['storeFile']) : null
            storePassword keystoreProperties['storePassword']
        }
    }

    buildTypes {
        release {
            signingConfig signingConfigs.release
            minifyEnabled true
            shrinkResources true
            proguardFiles getDefaultProguardFile(
                'proguard-android-optimize.txt'), 'proguard-rules.pro'
        }
    }
}
```

## Product Flavors Template

```groovy
// Add inside the android { } block in build.gradle
flavorDimensions "environment"
productFlavors {
    dev {
        dimension "environment"
        applicationIdSuffix ".dev"
        versionNameSuffix "-dev"
    }
    staging {
        dimension "environment"
        applicationIdSuffix ".staging"
        versionNameSuffix "-staging"
    }
    prod {
        dimension "environment"
    }
}
```

```bash
# Build specific flavor
flutter build appbundle --flavor prod --release
```

## ProGuard / R8 Rules

```proguard
# android/app/proguard-rules.pro

# Flutter core — required for all Flutter apps
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Keep application class
-keep class com.yourcompany.yourapp.** { *; }

# Firebase (if used) — uses reflection extensively
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**

# Gson (if used) — needs type info at runtime
-keepattributes Signature
-keepattributes *Annotation*
-keep class com.google.gson.** { *; }

# Native methods — JNI calls by name
-keepclasseswithmembernames class * {
    native <methods>;
}
```

## Fastlane Setup

### Service Account for API Access

1. Google Cloud Console → Enable "Google Play Android Developer API"
2. IAM & Admin → Service Accounts → Create
3. Create JSON key → Download as `api-key.json`
4. Play Console → Users and permissions → Invite service account email → Grant "Release manager"

### Fastfile

```ruby
# android/fastlane/Fastfile
default_platform(:android)

platform :android do
  lane :internal do
    gradle(task: "bundle", build_type: "Release")

    upload_to_play_store(
      track: 'internal',
      aab: '../build/app/outputs/bundle/release/app-release.aab',
      # WHY skip_upload_metadata/images/screenshots: Internal track is for
      # build verification only — no need to update store listing each time.
      # Uploading metadata on every internal push is slow and unnecessary.
      skip_upload_metadata: true,
      skip_upload_images: true,
      skip_upload_screenshots: true,
    )
  end

  lane :beta do
    gradle(task: "bundle", build_type: "Release")

    upload_to_play_store(
      track: 'beta',
      aab: '../build/app/outputs/bundle/release/app-release.aab',
      # WHY release_status: 'draft': Uploads the AAB but does NOT publish it.
      # You must manually review and confirm in Play Console before testers see it.
      # Prevents accidental pushes to beta users from CI.
      release_status: 'draft',
    )
  end

  lane :production do
    ensure_git_status_clean

    gradle(task: "bundle", build_type: "Release")

    upload_to_play_store(
      track: 'production',
      aab: '../build/app/outputs/bundle/release/app-release.aab',
      # WHY release_status: 'draft': Production drafts require explicit approval
      # in Play Console. This is a safety net — no accidental production deploys.
      release_status: 'draft',
      rollout: '0.1',  # 10% staged rollout
    )

    git_commit(path: "app/build.gradle", message: "Version Bump")
    add_git_tag(tag: "android/v#{get_version_name(
      gradle_file_path: 'app/build.gradle')}")
    push_to_git_remote
  end

  lane :promote do |options|
    percentage = options[:percentage] || '0.5'
    upload_to_play_store(
      track: 'production',
      rollout: percentage,
      # WHY skip everything: promote only changes the rollout percentage.
      # No new binary or metadata — just expanding reach to more users.
      skip_upload_apk: true,
      skip_upload_aab: true,
      skip_upload_metadata: true,
      skip_upload_images: true,
      skip_upload_screenshots: true,
    )
  end
end
```

## CI/CD: GitHub Actions Workflow

```yaml
# .github/workflows/android-deploy.yml
name: Android Deploy
on:
  push:
    tags: ['v*']

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      # WHY Zulu distribution: Azul Zulu is a free, TCK-certified OpenJDK build
      # with long-term support. Unlike adoptium/temurin, Zulu provides consistent
      # builds across all platforms and is the recommended choice for CI pipelines.
      # WHY Java 17: Android Gradle Plugin 8.x requires JDK 17 minimum.
      # JDK 21 works too, but 17 is the safest baseline for Flutter compatibility.
      - uses: actions/setup-java@v4
        with:
          distribution: 'zulu'
          java-version: '17'
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.41.0'

      - run: flutter pub get
      - run: flutter test

      # WHY base64 for keystore: GitHub Secrets only store text (UTF-8 strings).
      # A .jks keystore is a binary file. Base64 encodes it as text so it can be
      # stored as a secret, then decoded back to binary in CI.
      # To create: base64 -i upload-keystore.jks | pbcopy → paste into secret.
      - name: Decode keystore
        run: echo "${{ secrets.KEYSTORE_BASE64 }}" | base64 --decode > android/upload-keystore.jks

      - name: Create key.properties
        run: |
          cat > android/key.properties <<EOF
          storePassword=${{ secrets.STORE_PASSWORD }}
          keyPassword=${{ secrets.KEY_PASSWORD }}
          keyAlias=${{ secrets.KEY_ALIAS }}
          storeFile=../upload-keystore.jks
          EOF

      - run: flutter build appbundle --release

      - name: Deploy to Play Store
        uses: ruby/setup-ruby@v1
        with:
          ruby-version: '3.0'
      - run: gem install fastlane
      - run: cd android && fastlane internal
        env:
          SUPPLY_JSON_KEY_DATA: ${{ secrets.PLAY_STORE_CONFIG_JSON }}
```

### Encode Keystore for CI

```bash
base64 -i upload-keystore.jks | pbcopy
# Paste into GitHub Secrets as KEYSTORE_BASE64
```
