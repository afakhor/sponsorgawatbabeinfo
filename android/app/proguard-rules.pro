# App Native Package Protection
-keep class com.example.sponsorbabeinfogawat.** { *; }

# Flutter Native Wrapper Protection
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.provider.** { *; }
-keep class io.flutter.plugins.** { *; }

# FlutterGL & Three.js Native Protection (PREVENT DEATHSCREEN)
-keep class com.futouapp.flutter_gl.** { *; }
-keep class com.futouapp.threeegl.** { *; }
-keep class flutter.plugins.3d.** { *; }
-dontwarn com.futouapp.**

# FFmpeg Kit Protection
-keep class com.arthenica.ffmpegkit.** { *; }

# Audio Waveforms
-keep class com.cometchat.pro.** { *; }

# SHADER BLACKHOLE - JANGAN DI OBFUSCATE!
-keep class io.flutter.view.FlutterView { *; }
-keep class io.flutter.embedding.android.FlutterFragment { *; }