# Add project specific ProGuard rules here.
# Keep default rules; Flutter apps generally need no extra rules unless using
# native code that relies on reflection.

# just_audio and its EXO-player dependency:
-keep class com.google.android.exoplayer2.** { *; }
-dontwarn org.xmlpull.v1.**
-dontwarn org.kxml2.io.**

# youtube_explode_dart
-dontwarn org.w3c.dom.**