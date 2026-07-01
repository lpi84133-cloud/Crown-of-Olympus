# --------------------------------------------------------------------------
# Crown of Olympus — R8 / ProGuard rules
# --------------------------------------------------------------------------

# --- Flutter engine ---------------------------------------------------------
-keep class io.flutter.**            { *; }
-keep class io.flutter.embedding.**  { *; }
-keep class io.flutter.plugins.**    { *; }

# --- Play Core / Deferred components ---------------------------------------
-dontwarn com.google.android.play.core.**

# --- Firebase & AppsFlyer reflection ----------------------------------------
-keep class com.google.firebase.**   { *; }
-dontwarn com.google.firebase.**

-keep class com.appsflyer.**         { *; }
-dontwarn com.appsflyer.**

# --- WebView bridge ---------------------------------------------------------
-keep class io.flutter.plugins.webviewflutter.** { *; }
-keep class org.chromium.**          { *; }

# --- Preserve JNI methods & Parcelables ------------------------------------
-keepclasseswithmembernames class * { native <methods>; }
-keep class * implements android.os.Parcelable {
    public static final android.os.Parcelable$Creator *;
}

# --- Strip logs in release --------------------------------------------------
-assumenosideeffects class android.util.Log {
    public static int v(...);
    public static int d(...);
    public static int i(...);
    public static int w(...);
}
