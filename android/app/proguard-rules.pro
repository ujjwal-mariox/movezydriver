# Flutter
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**

# Google ML Kit (text recognition for OCR)
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.mlkit.**
-dontwarn com.google.android.gms.**

# Razorpay — reflection-heavy SDK that breaks under R8 without explicit keeps.
-keep class com.razorpay.** { *; }
-keepclassmembers class * {
    @com.razorpay.* <fields>;
    @com.razorpay.* <methods>;
}
-dontwarn com.razorpay.**
-dontwarn proguard.annotation.**
-keep class proguard.annotation.Keep
-keep class proguard.annotation.KeepClassMembers

# Gson / reflection-based JSON (used by several plugins)
-keepattributes Signature
-keepattributes *Annotation*
-keep class com.google.gson.** { *; }
-keepclassmembers,allowobfuscation class * {
  @com.google.gson.annotations.SerializedName <fields>;
}

# OkHttp / retrofit (transitively used)
-dontwarn okhttp3.**
-dontwarn okio.**
-dontwarn javax.annotation.**

# Image picker / camera plugins
-keep class androidx.camera.** { *; }
-dontwarn androidx.camera.**

# Geolocator
-keep class com.baseflow.geolocator.** { *; }
