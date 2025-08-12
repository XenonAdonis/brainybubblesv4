# Brainy Bubbles – v0.2.0

This release includes:
- Settings screen with **Fewer Bubbles** toggle
- Adjustable spawn speed (start/end) and ramp duration
- **Max bubbles on screen** cap
- **Background music on/off** (persists). Safe if MP3 asset is not present.

## How to apply to your repo
1. Extract this zip into the root of your Flutter project.
2. Ensure your `pubspec.yaml` contains:
   ```yaml
   dependencies:
     audioplayers: ^5.2.0
     shared_preferences: ^2.2.2

   flutter:
     uses-material-design: true
     assets:
       - assets/icons/
       - assets/images/
       - assets/audio/
   ```
3. Add your MP3 to `assets/audio/brainy_bubbles_bg.mp3` (optional).  
4. Run `flutter pub get` and `flutter run`.

## Android notes
- App-level `build.gradle.kts` should pin: `compileSdk = 35`, `targetSdk = 35`, `ndkVersion = "27.0.12077973"`
- Ensure only one `MainActivity.kt` exists and its package matches your `applicationId`.
