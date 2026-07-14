# Capacitor
-keep class com.getcapacitor.** { *; }
-keepclassmembers class com.getcapacitor.** { *; }

# Capacitor plugins
-keep class com.capacitorjs.plugins.** { *; }
-keepclassmembers class com.capacitorjs.plugins.** { *; }

# FileProvider
-keep class androidx.core.content.FileProvider { *; }

# Keep annotated classes
-keep @androidx.annotation.Keep class * { *; }
-keepclassmembers @androidx.annotation.Keep class * { *; }

# WebView / JS Bridge
-keepclassmembers class * {
    @android.webkit.JavascriptInterface <methods>;
}
