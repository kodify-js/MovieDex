-keep class * implements androidx.lifecycle.LifecycleObserver {
    <init>(...);
}
-keepclassmembers class * extends androidx.lifecycle.ViewModel {
    <init>(...);
}
-keepclassmembers class androidx.lifecycle.Lifecycle$* { *; }
-keepclassmembers class * {
    @androidx.lifecycle.OnLifecycleEvent *;
}

# Keep Flutter plugins
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.view.** { *; }

# Keep open_filex
-keep class com.crazecoder.openfile.** { *; }

# Keep FileProvider
-keep class androidx.core.content.FileProvider { *; }

# Flutter specific rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# MainActivity
-keep class com.moviedex.app.MainActivity { *; }

# Hive
-keep class hive.** { *; }
-keep class **\$HiveFieldAdapter { *; }

# Background service
-keep class io.flutter.plugins.flutter_background_service.** { *; }

# Firebase
-keep class com.google.firebase.** { *; }

# Prevent obfuscation that can cause crashes
-dontwarn com.moviedex.app.**
-keep class com.moviedex.app.** { *; }

# General Android rules
-keepattributes *Annotation*
-keepattributes SourceFile,LineNumberTable
-keep public class * extends android.app.Activity
-keep public class * extends android.app.Application
-keep public class * extends android.app.Service
-keep public class * extends android.content.BroadcastReceiver
-keep public class * extends android.content.ContentProvider

## Don't obfuscate
-dontobfuscate
