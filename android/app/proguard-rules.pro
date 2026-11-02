# Debug and info logging is removed from release builds. Plugins such as
# app_links and url_launcher log addresses, and invitation links hold a token.
-assumenosideeffects class android.util.Log {
    public static int v(...);
    public static int d(...);
    public static int i(...);
}
