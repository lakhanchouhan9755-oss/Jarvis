
Jarvis - Script to Cartoon Video (Flutter)
-----------------------------------------
This is a starter Flutter project for the Jarvis app that converts script text into colorful placeholder cartoon frames and assembles them into a video using FFmpeg.

How to build APK:
1. Install Flutter and Android SDK, set up ANDROID_HOME.
2. From project root run:
   flutter pub get
   flutter build apk --release
3. The generated APK will be at build/app/outputs/flutter-apk/app-release.apk

Notes:
- Add necessary Android permissions in android/app/src/main/AndroidManifest.xml (INTERNET, WRITE_EXTERNAL_STORAGE on older Android).
- ffmpeg_kit_flutter_full may require additional Android setup; consult its package docs.
