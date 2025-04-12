# Add project specific ProGuard rules here.
# You can control the set of applied configuration files using the
# proguardFiles setting in build.gradle.

# Keep speech_to_text plugin classes
-keep class com.csdcorp.speech_to_text.** { *; }
-keep class com.google.android.gms.** { *; }

# Keep Dio plugin classes
-keep class io.flutter.plugins.** { *; }
-keep class com.example.transcription.** { *; }

# Keep permission_handler plugin classes
-keep class com.baseflow.permissionhandler.** { *; }

# Flutter wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.plugin.editing.** { *; } 