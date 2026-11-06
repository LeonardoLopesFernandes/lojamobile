# Flutter / plugins
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class * implements io.flutter.embedding.engine.plugins.FlutterPlugin { *; }
-keep class * implements io.flutter.embedding.engine.plugins.activity.ActivityAware { *; }
-keep class io.ir.** { *; }
-dontwarn io.flutter.embedding.**

# ML Kit / scanner
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.mlkit.**
-dontwarn com.google.android.gms.**

# Cronet (cronet_http)
-keep class org.chromium.** { *; }
-dontwarn org.chromium.**

# Reflection / serializacao
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes InnerClasses
-keepattributes EnclosingMethod
