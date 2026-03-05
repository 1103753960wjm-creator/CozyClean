# Spec: APK Packaging & Installation Guide

This document defines the standards for packaging the CozyClean APK and troubleshooting common installation issues like "Parse Error".

## 1. Requirement Overview
- **Device**: Huawei Mate 40 Pro (HarmonyOS / Android 12)
- **Architecture**: arm64-v8a (Modern 64-bit)
- **Installation Context**: First-time install

## 2. Common Fixes for "Parse Error"
Based on user feedback, the following steps must be followed for the next build:

### 2.1 Clean State
- Always run `flutter clean` before a release build to remove stale build artifacts.
- Run `flutter pub get` after cleaning.

### 2.2 Build Target
- Build a universal APK or a split APK for the target architecture (`arm64-v8a`).
- Recommendation: Use `flutter build apk --release` (Universal) but ensure no corrupted artifacts.

### 2.3 Signing Configuration
- Current: Uses `debug` signing for release builds.
- Potential Issue: Some Huawei devices with strict security (HarmonyOS) might block debug-signed release APKs if they detect a signature mismatch or lack of a proper V2/V3 signature.
- **Action**: For the next build, we will stick to default release building but double-check the signature validity.

### 2.4 SDK Versions (Verified)
- `minSdk`: Default (typically 21 or higher)
- `targetSdk`: Default (typically 33/34)
- Verified in `build.gradle.kts` that these are controlled by Flutter.

## 3. Mandatory Build Procedure
1. `flutter clean`
2. `flutter pub get`
3. `flutter build apk --release`
4. Copy to `E:\CozyClean\apk\app-release.apk`
5. Verify file size is consistent (~102-108 MB).

## 4. Troubleshooting Steps for User
If "Parse Error" persists:
1. Enable "Install from Unknown Sources" on Huawei settings.
2. Check if "Google Play Protect" or Huawei's "App Advisor" is blocking the install.
3. Try standard `flutter install` if the device is connected via USB.
